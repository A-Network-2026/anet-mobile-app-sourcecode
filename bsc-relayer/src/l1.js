import { request } from 'undici';
import { config } from './config.js';
import { log } from './log.js';

const ANTS_PER_ANET = 100_000_000n;          // 10^8 — L1 native fixed-point unit.
const WEI_PER_ETH   = 10n ** 18n;             // BSC tokens are all 18-dec.

/**
 * Convert a netAmount (wei, 18-dec) from BSC into the equivalent ANET ants
 * to credit on L1, using the LIVE AMM quote from the L1 chain. This mirrors
 * what a user would receive if they swapped USDC→ANET inside the in-app L1
 * DEX, so the bridge price stays in sync with the AMM at all times.
 *
 * tokenSymbol must match a pool listed under /dex/pools (e.g. "USDC").
 * For native BNB swaps the L1 doesn't currently quote BNB pools directly —
 * callers should map BNB→a wrapped pair on their own before reaching here.
 */
export async function quoteAmountAnet(tokenSymbol, netAmountWei) {
  // The L1 chain stores stablecoin reserves in their NATIVE decimals (6 for
  // USDC, 18 for WBNB) but BSC tokens are uniformly 18-dec. Re-scale before
  // asking for a quote — otherwise we'd offer 1e12× the real value.
  const sixDec = new Set(['USDC', 'USDT', 'BUSD', 'DAI']);
  const amountIn = sixDec.has(tokenSymbol)
    ? Number(netAmountWei / 10n ** 12n)  // 18-dec → 6-dec
    : Number(netAmountWei);

  const url = `${config.anetL1BaseUrl}/dex/swap/quote`;
  const { statusCode, body } = await request(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      token_symbol: tokenSymbol,
      amount_in: amountIn,
      anet_to_token: false,        // token → ANET direction
    }),
  });
  const text = await body.text();
  if (statusCode !== 200) {
    throw new Error(`L1 quote failed (${statusCode}): ${text}`);
  }
  const data = JSON.parse(text);
  // The L1 quote endpoint returns ANET ants in `amount_out_ants`.
  const ants = BigInt(data.amount_out_ants ?? data.amount_out ?? 0);
  if (ants <= 0n) {
    throw new Error(`L1 quote returned zero amount_out: ${text}`);
  }
  return ants;
}

/**
 * Credit `amountAnts` to an L1 wallet via the production EVM bridge endpoint
 * `POST /admin/bridge/evm/credit`. Gated by `EVM_BRIDGE_CREDITS_ENABLED=true`
 * on the L1 server and authenticated with `ANET_DEX_ADMIN_KEY`.
 *
 * The endpoint dedups by `evm_tx_hash`, so re-calling with the same BSC tx
 * is safe (returns the original credit, never double-credits).
 *
 * Returns the L1's tx_id, which has the form `bridge:evm:<evm_tx_hash>` —
 * we store this as `l1_tx_id` for audit and explorer display.
 */
export async function mintAnetOnL1(anetRecipient, amountAnts, evmTxHash) {
  if (config.dryRun) {
    log.warn(`[DRY_RUN] would mint ${amountAnts} ants to ${anetRecipient}`);
    return `dryrun-${Date.now()}`;
  }
  if (!evmTxHash) {
    throw new Error('mintAnetOnL1: evmTxHash is required for /admin/bridge/evm/credit');
  }
  const url = `${config.anetL1BaseUrl}/admin/bridge/evm/credit`;
  const { statusCode, body } = await request(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      admin_key:    config.anetDexAdminKey,
      recipient:    anetRecipient,
      amount_ants:  Number(amountAnts),
      evm_tx_hash:  evmTxHash,
      evm_chain_id: 56,
    }),
  });
  const text = await body.text();
  if (statusCode !== 200) {
    throw new Error(`L1 mint failed (${statusCode}): ${text}`);
  }
  const data = JSON.parse(text);
  return data.tx_id ?? `bridge:evm:${evmTxHash}`;
}

/** Health check the L1 server before the main loop trusts it. */
export async function pingL1() {
  const { statusCode } = await request(`${config.anetL1BaseUrl}/health`, {
    method: 'GET',
  });
  return statusCode === 200;
}

export { ANTS_PER_ANET, WEI_PER_ETH };
