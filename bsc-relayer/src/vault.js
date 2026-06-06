// VaultSender — L1 → BSC release path that targets AnetBridgeVault on BSC
// instead of the legacy hot-EOA `token.transfer()` path.
//
// Mirrors the public interface of BscSender (escrowBalance / releaseAnts /
// address) so L1Poller can use either without code changes — the switch is
// driven by `BRIDGE_RELEASE_MODE` in config.
//
// ── Trust model ───────────────────────────────────────────────────────────
// The vault on BSC enforces every safety rule in Solidity:
//   - M-of-N EIP-712 signatures from authorized relayer signers
//   - burnId deduplication (re-orgs / re-tries are safe)
//   - per-tx + per-recipient-24h + global-24h caps
//   - chainId baked into DOMAIN_SEPARATOR (cross-chain replay blocked)
// This file is just the off-chain "build a release bundle and submit it"
// component. The keys configured here have NO authority to move tokens
// beyond what the vault permits — that is the entire point of the migration.
//
// ── Transitional single-process multi-key mode (DEV / CANARY ONLY) ────────
// VAULT_LOCAL_SIGNER_KEYS allows one operator to hold every signer key in
// one process, sign locally, and submit. This is acceptable ONLY for the
// initial canary release. In production posture each signer key lives on
// independent infrastructure and signatures are gathered out of band (P2 of
// the audit decentralization plan). The code warns loudly when running in
// this mode.

import { ethers } from 'ethers';
import { config } from './config.js';
import { log } from './log.js';

const ANTS_PER_ANET = 100_000_000n;

const VAULT_ABI = [
  'function WANET() view returns (address)',
  'function admin() view returns (address)',
  'function paused() view returns (bool)',
  'function threshold() view returns (uint256)',
  'function signers() view returns (address[])',
  'function isSigner(address) view returns (bool)',
  'function maxPerTx() view returns (uint256)',
  'function maxPerRecipient24h() view returns (uint256)',
  'function maxGlobal24h() view returns (uint256)',
  'function burnIdConsumed(uint256) view returns (bool)',
  'function vaultBalance() view returns (uint256)',
  'function totalReleased() view returns (uint256)',
  'function DOMAIN_SEPARATOR() view returns (bytes32)',
  'function releaseBurn(uint256 burnId, string l1Sender, address recipient, uint256 amount, uint256 deadline, bytes[] signatures)',
  'event Released(uint256 indexed burnId, address indexed recipient, uint256 amount, string l1Sender, uint256 signaturesUsed)',
];

// EIP-712 types — MUST match AnetBridgeVault.sol byte-for-byte.
const DOMAIN_NAME    = 'AnetBridgeVault';
const DOMAIN_VERSION = '1';
const RELEASE_TYPES  = {
  Release: [
    { name: 'burnId',    type: 'uint256' },
    { name: 'l1Sender',  type: 'string'  },
    { name: 'recipient', type: 'address' },
    { name: 'amount',    type: 'uint256' },
    { name: 'deadline',  type: 'uint256' },
  ],
};

function parsePrivateKeyList(raw, name) {
  if (!raw || raw.trim() === '') return [];
  const parts = raw.split(',').map((s) => s.trim()).filter(Boolean);
  return parts.map((pk, i) => {
    try {
      return new ethers.Wallet(pk);
    } catch (e) {
      throw new Error(`${name}[${i}] is not a valid private key: ${e.message}`);
    }
  });
}

export class VaultSender {
  constructor() {
    if (!config.vaultAddress) {
      throw new Error('BRIDGE_RELEASE_MODE=vault requires VAULT_ADDRESS');
    }
    if (!config.vaultSubmitterKey) {
      throw new Error('BRIDGE_RELEASE_MODE=vault requires VAULT_SUBMITTER_KEY');
    }

    this.provider = new ethers.JsonRpcProvider(config.bscRpcUrl);
    if (config.bscRpcUrlFallback) {
      this.fallbackProvider = new ethers.JsonRpcProvider(config.bscRpcUrlFallback);
    }

    this.submitter = new ethers.Wallet(config.vaultSubmitterKey, this.provider);
    this.address   = this.submitter.address; // for parity with BscSender

    this.vault = new ethers.Contract(config.vaultAddress, VAULT_ABI, this.submitter);

    // Token decimals: ANET BEP-20 = 18 (validated in config).
    this.decimals  = BigInt(config.bscAnetDecimals);
    this.scaleAnts = 10n ** (this.decimals - 8n);

    // Local signer wallets — TRANSITIONAL. See header.
    this.localSigners = parsePrivateKeyList(
      config.vaultLocalSignerKeys,
      'VAULT_LOCAL_SIGNER_KEYS',
    );
    this.localSignerAddresses = this.localSigners.map((w) => w.address);
    this.sigSource = (config.vaultSigSource || 'local').toLowerCase();
    if (this.sigSource === 'l1') {
      log.info(
        `VaultSender sig source = L1 (decentralized). Relayer holds NO signer keys; ` +
          `fetching M-of-N from ${config.anetL1BaseUrl}/bridge/burns/:id/sigs.`,
      );
    } else if (this.localSigners.length > 0) {
      log.warn(
        '⚠  VaultSender running in single-process multi-key mode — ' +
          `${this.localSigners.length} signer key(s) held locally. ` +
          'This is acceptable only for the canary release. ' +
          'Production posture: VAULT_SIG_SOURCE=l1 with 1 key per independent operator.',
      );
    }

    // Domain stored as object; finalized after we read chainId at startup.
    this.domain = null;
    this.threshold = null;
  }

  /** Read on-chain invariants and cache domain. Call once before first release. */
  async warmup() {
    const net = await this.provider.getNetwork();
    const chainId = Number(net.chainId);
    if (config.vaultChainId && chainId !== config.vaultChainId) {
      throw new Error(
        `BSC RPC chainId ${chainId} != VAULT_CHAIN_ID ${config.vaultChainId} (refusing to sign)`,
      );
    }

    this.domain = {
      name:              DOMAIN_NAME,
      version:           DOMAIN_VERSION,
      chainId,
      verifyingContract: ethers.getAddress(config.vaultAddress),
    };

    // Cross-check: the EIP-712 domain separator we compute MUST match the
    // contract's on-chain DOMAIN_SEPARATOR(). If they diverge, every signature
    // we produce will be rejected — fail fast at startup rather than at burn time.
    const onchainSeparator = await this.vault.DOMAIN_SEPARATOR();
    const computedSeparator = ethers.TypedDataEncoder.hashDomain(this.domain);
    if (onchainSeparator.toLowerCase() !== computedSeparator.toLowerCase()) {
      throw new Error(
        `EIP-712 domain mismatch: contract=${onchainSeparator} computed=${computedSeparator}. ` +
          'Check VAULT_ADDRESS, VAULT_CHAIN_ID, and that the vault was deployed with name="AnetBridgeVault" version="1".',
      );
    }

    this.threshold = Number(await this.vault.threshold());
    const onchainSigners = (await this.vault.signers()).map((a) => a.toLowerCase());

    // Validate every locally-held key is actually authorized on-chain.
    for (const local of this.localSignerAddresses) {
      if (!onchainSigners.includes(local.toLowerCase())) {
        throw new Error(
          `Local signer ${local} is NOT in the vault's on-chain signer set. ` +
            `Authorized signers: [${onchainSigners.join(', ')}]`,
        );
      }
    }

    if (this.localSigners.length > 0 && this.localSigners.length < this.threshold) {
      log.warn(
        `Local signer keys (${this.localSigners.length}) below threshold (${this.threshold}). ` +
          'releaseAnts() will fail until additional signatures are gathered out of band.',
      );
    }

    log.info(
      `vault warmup OK: address=${config.vaultAddress} chainId=${chainId} ` +
        `threshold=${this.threshold}/${onchainSigners.length} ` +
        `sigSource=${this.sigSource} localKeys=${this.localSigners.length}`,
    );
  }

  /** Convert L1 ants → BSC wei (matches BscSender.antsToWei semantics). */
  antsToWei(ants) {
    return BigInt(ants) * this.scaleAnts;
  }

  static formatAnet(ants) {
    const a = BigInt(ants);
    const whole = a / ANTS_PER_ANET;
    const frac = (a % ANTS_PER_ANET).toString().padStart(8, '0').replace(/0+$/, '');
    return frac.length ? `${whole}.${frac}` : `${whole}`;
  }

  /** Wallet wANET balance, expressed as the vault's own `vaultBalance()` view. */
  async escrowBalance() {
    return await this.vault.vaultBalance();
  }

  /**
   * Produce an EIP-712 signature for a Release. Exposed so an external
   * orchestrator can call this on multiple machines (one key each) and
   * aggregate the signatures before submission.
   *
   * @param {object} msg { burnId, l1Sender, recipient, amount, deadline }
   * @param {ethers.Wallet} wallet
   */
  async signRelease(msg, wallet) {
    if (!this.domain) throw new Error('VaultSender.warmup() not called');
    return await wallet.signTypedData(this.domain, RELEASE_TYPES, msg);
  }

  /**
   * Build the typed-data digest the vault will verify. Useful for cross-
   * checking against the contract's recomputed digest in canary tests.
   */
  releaseDigest(msg) {
    if (!this.domain) throw new Error('VaultSender.warmup() not called');
    return ethers.TypedDataEncoder.hash(this.domain, RELEASE_TYPES, msg);
  }

  /**
   * BscSender-compatible release. Burn metadata is encoded into the burnId
   * via two extra params taken from the wider context — see overload in
   * `releaseBurn()` below for the full set.
   *
   * NOTE: BscSender.releaseAnts(recipient, ants) does not carry burnId / l1Sender.
   * L1Poller has them on the row; we extend the call there. Kept here only to
   * preserve the legacy interface name — callers should prefer releaseBurn().
   */
  async releaseAnts(recipient, ants, opts = {}) {
    return this.releaseBurn({
      burnId:    opts.burnId    ?? null,
      l1Sender:  opts.l1Sender  ?? '',
      recipient,
      ants,
      deadlineSecs: opts.deadlineSecs ?? config.vaultReleaseDeadlineSecs,
    });
  }

  /**
   * Build, sign locally with all available keys, and submit a vault release.
   * Returns { txHash, amountWei } on success. Throws on any precondition failure.
   */
  async releaseBurn({ burnId, l1Sender, recipient, ants, deadlineSecs }) {
    if (!this.domain) throw new Error('VaultSender.warmup() not called');
    if (burnId === null || burnId === undefined) {
      throw new Error('releaseBurn: burnId is required');
    }
    if (!l1Sender || typeof l1Sender !== 'string') {
      throw new Error('releaseBurn: l1Sender is required');
    }
    if (!ethers.isAddress(recipient)) {
      throw new Error(`releaseBurn: invalid recipient ${recipient}`);
    }

    const amountWei = this.antsToWei(ants);
    const anetPretty = VaultSender.formatAnet(ants);

    // Pre-flight reads — cheap, and they let us fail with a clear message
    // before we burn gas on a guaranteed-to-revert tx.
    if (await this.vault.paused()) {
      throw new Error('vault is paused — refusing to submit release');
    }
    if (await this.vault.burnIdConsumed(BigInt(burnId))) {
      throw new Error(`vault has already released burnId=${burnId}`);
    }
    const maxPerTx = await this.vault.maxPerTx();
    if (amountWei > maxPerTx) {
      throw new Error(`amount ${amountWei} wei exceeds vault.maxPerTx ${maxPerTx}`);
    }
    const balance = await this.vault.vaultBalance();
    if (balance < amountWei) {
      throw new Error(`vault underfunded: have ${balance} wei, need ${amountWei}`);
    }

    // Deadline: now + N seconds, based on the BSC chain block timestamp
    // (NOT Date.now()) so we don't accidentally produce expired sigs when
    // node clocks drift.
    //
    // In L1 sig mode the deadline is dictated by the L1 chain (canonical:
    // all signers signed over the SAME deadline) — we look that up below
    // and override before building the message.
    const tipBlock = await this.provider.getBlock('latest');
    let deadline = BigInt(tipBlock.timestamp + Number(deadlineSecs));

    let l1Meta = null;
    if (this.sigSource === 'l1') {
      l1Meta = await this.fetchL1Digest(burnId);
      if (l1Meta.bsc_recipient.toLowerCase() !== recipient.toLowerCase()) {
        throw new Error(
          `L1 digest recipient (${l1Meta.bsc_recipient}) != local recipient (${recipient})`,
        );
      }
      if (BigInt(l1Meta.amount_wei_decimal) !== amountWei) {
        throw new Error(
          `L1 digest amount (${l1Meta.amount_wei_decimal}) != local amount (${amountWei})`,
        );
      }
      if (l1Meta.vault_address.toLowerCase() !== config.vaultAddress.toLowerCase()) {
        throw new Error(
          `L1 digest vault_address (${l1Meta.vault_address}) != configured (${config.vaultAddress})`,
        );
      }
      deadline = BigInt(l1Meta.deadline);
      if (deadline <= BigInt(tipBlock.timestamp) + 60n) {
        throw new Error(
          `L1 canonical deadline ${deadline} is too close to BSC tip ${tipBlock.timestamp}`,
        );
      }
    }

    const message = {
      burnId:    BigInt(burnId),
      l1Sender:  String(l1Sender),
      recipient: ethers.getAddress(recipient),
      amount:    amountWei,
      deadline,
    };

    if (config.dryRun) {
      const digest = this.releaseDigest(message);
      const fake = `0xdryrun${Date.now().toString(16).padStart(58, '0')}`;
      log.warn(
        `[DRY_RUN] vault release: ${anetPretty} ANET → ${recipient} ` +
          `(burnId=${burnId}, deadline=${deadline}, digest=${digest})`,
      );
      return { txHash: fake, amountWei };
    }

    // ── Gather signatures ───────────────────────────────────────────────
    // L1 mode: fetch out-of-band sigs aggregated from independent signer
    //          daemons. The relayer never sees a private key.
    // local mode: sign in-process with every VAULT_LOCAL_SIGNER_KEYS entry.
    // In both modes, sort ascending by signer address (vault requires
    // strictly ascending to enforce uniqueness without a mapping).
    let signed;
    if (this.sigSource === 'l1') {
      signed = await this.collectL1Signatures(burnId, message);
    } else {
      signed = [];
      for (const wallet of this.localSigners) {
        const sig = await this.signRelease(message, wallet);
        signed.push({ addr: wallet.address.toLowerCase(), sig });
      }
    }
    signed.sort((a, b) => (BigInt(a.addr) < BigInt(b.addr) ? -1 : 1));
    const signatures = signed.map((s) => s.sig);

    if (signatures.length < this.threshold) {
      throw new Error(
        `have ${signatures.length} signature(s), vault requires ${this.threshold}. ` +
          (this.sigSource === 'l1'
            ? 'Waiting for additional signer daemons to POST sigs to L1.'
            : 'Configure additional VAULT_LOCAL_SIGNER_KEYS or implement out-of-band aggregation.'),
      );
    }

    // Submit. Gas is paid by the submitter wallet, which has no signer power.
    log.info(
      `vault releaseBurn(burnId=${burnId}, ${anetPretty} ANET → ${recipient}, ` +
        `sigs=${signatures.length}/${this.threshold}, source=${this.sigSource})`,
    );
    const tx = await this.vault.releaseBurn(
      message.burnId,
      message.l1Sender,
      message.recipient,
      message.amount,
      message.deadline,
      signatures,
    );
    log.info(`vault releaseBurn broadcast tx=${tx.hash}`);
    const receipt = await tx.wait(1);
    if (receipt.status !== 1) {
      throw new Error(`vault releaseBurn reverted in tx ${tx.hash}`);
    }
    return { txHash: tx.hash, amountWei };
  }

  // ── L1 signature-source helpers (VAULT_SIG_SOURCE=l1) ──────────────────

  /**
   * GET {L1}/bridge/burns/:id/digest — returns canonical EIP-712 metadata
   * (vault address, chain id, deadline, signer set, expected digest).
   * Used to align the relayer's local view of the burn with what the
   * independent signer daemons saw.
   */
  async fetchL1Digest(burnId) {
    const url = `${config.anetL1BaseUrl.replace(/\/+$/, '')}/bridge/burns/${burnId}/digest`;
    const res = await fetch(url);
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`L1 digest fetch ${burnId} -> ${res.status}: ${text.slice(0, 300)}`);
    }
    return JSON.parse(text);
  }

  /**
   * GET {L1}/bridge/burns/:id/sigs — returns all collected EIP-712
   * signatures for this burn. Each row: { burn_id, signer, signature, created_at }.
   * The relayer verifies each signature LOCALLY against the rebuilt digest
   * before submitting — defense-in-depth in case the L1 is compromised.
   */
  async collectL1Signatures(burnId, message) {
    const url = `${config.anetL1BaseUrl.replace(/\/+$/, '')}/bridge/burns/${burnId}/sigs`;
    const res = await fetch(url);
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`L1 sigs fetch ${burnId} -> ${res.status}: ${text.slice(0, 300)}`);
    }
    const rows = JSON.parse(text);
    if (!Array.isArray(rows)) {
      throw new Error(`L1 sigs response is not an array: ${text.slice(0, 200)}`);
    }

    const digest = this.releaseDigest(message);
    const accepted = [];
    const seen = new Set();
    for (const row of rows) {
      const signer = String(row.signer || '').toLowerCase();
      const sig = String(row.signature || '');
      if (!signer || !sig) continue;
      if (seen.has(signer)) continue;

      let recovered;
      try {
        recovered = ethers.recoverAddress(digest, sig).toLowerCase();
      } catch (e) {
        log.warn(`burn ${burnId}: bad sig from ${signer}: ${e.message}`);
        continue;
      }
      if (recovered !== signer) {
        log.warn(
          `burn ${burnId}: L1 sig signer=${signer} but ecrecover=${recovered} — dropping`,
        );
        continue;
      }
      // verify against on-chain authorized set
      const isOnchainSigner = await this.vault.isSigner(ethers.getAddress(signer));
      if (!isOnchainSigner) {
        log.warn(`burn ${burnId}: signer ${signer} not in vault on-chain set — dropping`);
        continue;
      }
      accepted.push({ addr: signer, sig });
      seen.add(signer);
    }
    return accepted;
  }
}
