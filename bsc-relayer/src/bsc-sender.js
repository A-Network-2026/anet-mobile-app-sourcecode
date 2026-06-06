// BSC escrow → user ERC20 sender for the L1 → BSC bridge.
//
// Loads a single private key from BSC_ESCROW_PRIVATE_KEY at startup and
// uses it to call `transfer(recipient, amount)` on the configured ANET
// BEP-20 token contract for each released burn.

import { ethers } from 'ethers';
import { config } from './config.js';
import { log } from './log.js';

const ERC20_ABI = [
  'function transfer(address to, uint256 amount) returns (bool)',
  'function balanceOf(address account) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
];

const ANTS_PER_ANET = 100_000_000n; // 1 ANET = 10^8 ants (L1 fixed-point)

export class BscSender {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(config.bscRpcUrl);
    if (config.bscRpcUrlFallback) {
      this.fallbackProvider = new ethers.JsonRpcProvider(config.bscRpcUrlFallback);
    }
    this.wallet = new ethers.Wallet(config.bscEscrowPrivateKey, this.provider);
    this.token = new ethers.Contract(config.bscAnetToken, ERC20_ABI, this.wallet);
    this.address = this.wallet.address;
    this.decimals = BigInt(config.bscAnetDecimals);
    this.scaleAnts = 10n ** (this.decimals - 8n); // BSC token decimals - ant decimals
    if (this.decimals < 8n) {
      throw new Error(
        `BSC_ANET_DECIMALS must be >= 8 (got ${config.bscAnetDecimals})`,
      );
    }
  }

  /** Convert L1 ants → BSC token wei (handles decimals scaling). */
  antsToWei(ants) {
    return BigInt(ants) * this.scaleAnts;
  }

  /** Pretty-print L1 ants as a whole-ANET decimal string. */
  static formatAnet(ants) {
    const a = BigInt(ants);
    const whole = a / ANTS_PER_ANET;
    const frac = (a % ANTS_PER_ANET).toString().padStart(8, '0').replace(/0+$/, '');
    return frac.length ? `${whole}.${frac}` : `${whole}`;
  }

  /** Returns the escrow's current wANET balance, as a BigInt (wei). */
  async escrowBalance() {
    try {
      return await this.token.balanceOf(this.address);
    } catch (e) {
      if (this.fallbackProvider) {
        log.warn(`primary RPC failed for balanceOf, retrying fallback: ${e.message}`);
        const fb = new ethers.Contract(
          config.bscAnetToken,
          ERC20_ABI,
          this.fallbackProvider,
        );
        return await fb.balanceOf(this.address);
      }
      throw e;
    }
  }

  /**
   * Send `ants` worth of wANET to `recipient` on BSC.
   * Returns the BSC tx hash on success. Throws on failure.
   *
   * Honors DRY_RUN — when set, returns a fake hash without sending.
   */
  async releaseAnts(recipient, ants) {
    const amountWei = this.antsToWei(ants);
    const anetPretty = BscSender.formatAnet(ants);

    if (config.dryRun) {
      const fake = `0xdryrun${Date.now().toString(16).padStart(58, '0')}`;
      log.warn(
        `[DRY_RUN] would transfer ${anetPretty} ANET ` +
          `(${amountWei} wei) to ${recipient}`,
      );
      return { txHash: fake, amountWei };
    }

    // Refuse to send if escrow can't cover it — caller should retry later
    // after refunding the escrow.
    const bal = await this.escrowBalance();
    if (bal < amountWei) {
      throw new Error(
        `escrow underfunded: need ${amountWei} wei, have ${bal} wei. ` +
          `Top up ${this.address} on BSC before retrying.`,
      );
    }

    const tx = await this.token.transfer(recipient, amountWei);
    log.info(`BSC transfer broadcast tx=${tx.hash} → ${recipient} (${anetPretty} ANET)`);
    const receipt = await tx.wait(1); // 1-block confirmation for our records
    if (receipt.status !== 1) {
      throw new Error(`BSC transfer reverted in tx ${tx.hash}`);
    }
    return { txHash: tx.hash, amountWei };
  }
}
