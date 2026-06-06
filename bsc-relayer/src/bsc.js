import { ethers } from 'ethers';
import { config } from './config.js';
import { log } from './log.js';

// Canonical ABI fragment for the SwapRequested event. Source of truth is
// contracts/src/AnetSwap.sol — keep these in sync if the contract is upgraded.
const SWAP_REQUESTED_ABI = [
  'event SwapRequested(uint256 indexed id, address indexed evmSender, string anetRecipient, address tokenAddress, uint256 grossAmount, uint256 netAmount, uint256 feePaid, uint256 timestamp)',
];

// ERC-20 metadata fragment (decimals + symbol). Used to label native vs token
// swaps in the DB. address(0) means native BNB on BSC.
const ERC20_META_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
];

const tokenMetaCache = new Map();

export class BscWatcher {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(config.bscRpcUrl);
    this.fallback = config.bscRpcUrlFallback
      ? new ethers.JsonRpcProvider(config.bscRpcUrlFallback)
      : null;
    this.iface = new ethers.Interface(SWAP_REQUESTED_ABI);
    this.contract = new ethers.Contract(
      config.anetSwapContract,
      SWAP_REQUESTED_ABI,
      this.provider
    );
  }

  /** Latest BSC block height. Falls over to the backup RPC on failure. */
  async getLatestBlock() {
    try {
      return await this.provider.getBlockNumber();
    } catch (e) {
      log.warn('primary RPC getBlockNumber failed, trying fallback', e.message);
      if (!this.fallback) throw e;
      return await this.fallback.getBlockNumber();
    }
  }

  /**
   * Fetch SwapRequested events in [fromBlock, toBlock]. Public BSC RPCs cap
   * eth_getLogs around ~5000 blocks — caller is responsible for chunking.
   */
  async fetchSwapEvents(fromBlock, toBlock) {
    const filter = this.contract.filters.SwapRequested();
    let logs;
    try {
      logs = await this.contract.queryFilter(filter, fromBlock, toBlock);
    } catch (e) {
      log.warn(`primary RPC queryFilter failed (${e.message}), trying fallback`);
      if (!this.fallback) throw e;
      const c2 = new ethers.Contract(
        config.anetSwapContract,
        SWAP_REQUESTED_ABI,
        this.fallback
      );
      logs = await c2.queryFilter(filter, fromBlock, toBlock);
    }
    const out = [];
    for (const l of logs) {
      const args = l.args;
      out.push({
        txHash: l.transactionHash,
        logIndex: l.index,
        blockNumber: l.blockNumber,
        swapId: Number(args.id),
        evmSender: args.evmSender,
        anetRecipient: args.anetRecipient,
        tokenAddress: args.tokenAddress,
        tokenSymbol: await this._tokenSymbol(args.tokenAddress),
        grossAmount: args.grossAmount,
        netAmount: args.netAmount,
        feePaid: args.feePaid,
        timestamp: args.timestamp,
      });
    }
    return out;
  }

  async _tokenSymbol(addr) {
    const ZERO = '0x0000000000000000000000000000000000000000';
    if (!addr || addr.toLowerCase() === ZERO) return 'BNB';
    const cached = tokenMetaCache.get(addr.toLowerCase());
    if (cached) return cached;
    try {
      const c = new ethers.Contract(addr, ERC20_META_ABI, this.provider);
      const sym = await c.symbol();
      tokenMetaCache.set(addr.toLowerCase(), sym);
      return sym;
    } catch (_) {
      return 'UNKNOWN';
    }
  }
}
