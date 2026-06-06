import pg from 'pg';
import { config } from './config.js';
import { log } from './log.js';

const { Pool } = pg;

export const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl: config.databaseUrl.includes('localhost') ? false : { rejectUnauthorized: false },
  max: 4,
});

pool.on('error', (err) => log.error('pg pool error', err));

/** Read the last fully-scanned block (or null on first run). */
export async function getCursor() {
  const r = await pool.query('SELECT last_scanned FROM relayer.cursor WHERE id = 1');
  return r.rows[0]?.last_scanned ? Number(r.rows[0].last_scanned) : null;
}

export async function setCursor(blockNumber) {
  await pool.query(
    `INSERT INTO relayer.cursor (id, last_scanned, updated_at)
     VALUES (1, $1, NOW())
     ON CONFLICT (id) DO UPDATE SET last_scanned = EXCLUDED.last_scanned, updated_at = NOW()`,
    [blockNumber]
  );
}

/**
 * Insert a freshly-detected SwapRequested event. Idempotent on
 * (tx_hash, log_index). Returns true if newly inserted, false if dup.
 */
export async function insertSwapIfNew(swap) {
  const r = await pool.query(
    `INSERT INTO relayer.swaps (
        tx_hash, log_index, block_number, swap_id, evm_sender,
        anet_recipient, token_address, token_symbol,
        gross_amount, net_amount, fee_paid, bsc_timestamp, status
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,to_timestamp($12),'detected')
     ON CONFLICT (tx_hash, log_index) DO NOTHING
     RETURNING tx_hash`,
    [
      swap.txHash,
      swap.logIndex,
      swap.blockNumber,
      swap.swapId,
      swap.evmSender,
      swap.anetRecipient,
      swap.tokenAddress,
      swap.tokenSymbol,
      swap.grossAmount.toString(),
      swap.netAmount.toString(),
      swap.feePaid.toString(),
      Number(swap.timestamp),
    ]
  );
  return r.rowCount > 0;
}

/** All `detected` swaps whose block is now at least `minConfs` blocks deep. */
export async function getConfirmedPendingSwaps(latestBlock, minConfs) {
  const r = await pool.query(
    `SELECT * FROM relayer.swaps
     WHERE status = 'detected'
       AND block_number <= $1
     ORDER BY block_number ASC, log_index ASC
     LIMIT 50`,
    [latestBlock - minConfs]
  );
  return r.rows;
}

export async function markMinted(txHash, logIndex, antsMinted, l1TxId) {
  await pool.query(
    `UPDATE relayer.swaps SET status='minted', anet_ants_minted=$3, l1_tx_id=$4, minted_at=NOW()
     WHERE tx_hash=$1 AND log_index=$2`,
    [txHash, logIndex, antsMinted.toString(), l1TxId]
  );
}

export async function markSkipped(txHash, logIndex, reason) {
  await pool.query(
    `UPDATE relayer.swaps SET status='skipped', error=$3 WHERE tx_hash=$1 AND log_index=$2`,
    [txHash, logIndex, reason]
  );
}

export async function markFailed(txHash, logIndex, reason) {
  await pool.query(
    `UPDATE relayer.swaps SET status='failed', error=$3 WHERE tx_hash=$1 AND log_index=$2`,
    [txHash, logIndex, reason]
  );
}

// An unsupported token was deposited (no L1 pool to quote against). The funds
// are safe in the swap contract but cannot be credited on L1 — they must be
// refunded to the depositor. We use a distinct terminal status so these are
// never retried as mints and an operator can find them with a single query:
//   SELECT * FROM relayer.swaps WHERE status='refund_required';
export async function markRefundRequired(txHash, logIndex, reason) {
  await pool.query(
    `UPDATE relayer.swaps SET status='refund_required', error=$3 WHERE tx_hash=$1 AND log_index=$2`,
    [txHash, logIndex, reason]
  );
}

/**
 * Sum of ANET minted in the last rolling 24h (in whole ANET units,
 * not ants). Used to enforce daily caps before minting more.
 */
export async function mintedInLast24hAnet() {
  const r = await pool.query(
    `SELECT COALESCE(SUM(anet_ants_minted), 0)::TEXT AS total_ants
       FROM relayer.swaps
      WHERE status='minted' AND minted_at >= NOW() - INTERVAL '24 hours'`
  );
  const ants = BigInt(r.rows[0].total_ants);
  return Number(ants) / 1e8;
}

// ─────────────────────────────────────────────────────────────────────────
// L1 → BSC bridge (burn-and-release) state
// ─────────────────────────────────────────────────────────────────────────

/** Read the largest burn_id we've ingested from the L1 (or null on first run). */
export async function getBurnCursor() {
  const r = await pool.query('SELECT last_burn_id FROM relayer.burn_cursor WHERE id = 1');
  return r.rows[0]?.last_burn_id != null ? Number(r.rows[0].last_burn_id) : null;
}

export async function setBurnCursor(burnId) {
  await pool.query(
    `INSERT INTO relayer.burn_cursor (id, last_burn_id, updated_at)
     VALUES (1, $1, NOW())
     ON CONFLICT (id) DO UPDATE SET last_burn_id = EXCLUDED.last_burn_id, updated_at = NOW()`,
    [burnId]
  );
}

/**
 * Insert a freshly-fetched L1 burn. Idempotent on burn_id. Returns true
 * if newly inserted, false if we'd already seen it.
 */
export async function insertBurnIfNew(burn) {
  const r = await pool.query(
    `INSERT INTO relayer.burns (
        burn_id, l1_sender, bsc_recipient, ants, token_symbol, status
     ) VALUES ($1,$2,$3,$4,$5,'detected')
     ON CONFLICT (burn_id) DO NOTHING
     RETURNING burn_id`,
    [
      burn.burn_id,
      burn.l1_sender,
      burn.bsc_recipient,
      burn.ants.toString(),
      burn.token_symbol,
    ]
  );
  return r.rowCount > 0;
}

/**
 * Get burns that are ready for BSC release (status='detected'), oldest first.
 */
export async function getDetectedBurns(limit = 25) {
  const r = await pool.query(
    `SELECT * FROM relayer.burns
     WHERE status='detected'
     ORDER BY burn_id ASC
     LIMIT $1`,
    [limit]
  );
  return r.rows;
}

/** Mark a burn as in-flight (sending on BSC). Prevents duplicate sends. */
export async function markBurnSending(burnId) {
  const r = await pool.query(
    `UPDATE relayer.burns SET status='sending'
     WHERE burn_id = $1 AND status = 'detected'
     RETURNING burn_id`,
    [burnId]
  );
  return r.rowCount > 0;
}

export async function markBurnReleased(burnId, bscTxHash, bscAmountWei) {
  await pool.query(
    `UPDATE relayer.burns
        SET status='released', bsc_tx_hash=$2, bsc_amount_wei=$3,
            released_at=NOW(), error=NULL
      WHERE burn_id=$1`,
    [burnId, bscTxHash, bscAmountWei.toString()]
  );
}

export async function markBurnFailed(burnId, reason) {
  await pool.query(
    `UPDATE relayer.burns SET status='failed', error=$2 WHERE burn_id=$1`,
    [burnId, reason]
  );
}

export async function markBurnSkipped(burnId, reason) {
  await pool.query(
    `UPDATE relayer.burns SET status='skipped', error=$2 WHERE burn_id=$1`,
    [burnId, reason]
  );
}

/**
 * Sum of ANET released to BSC in the last rolling 24h (in whole ANET).
 * Used to enforce daily caps on the burn side, symmetric with mintedInLast24hAnet.
 */
export async function releasedInLast24hAnet() {
  const r = await pool.query(
    `SELECT COALESCE(SUM(ants), 0)::TEXT AS total_ants
       FROM relayer.burns
      WHERE status='released' AND released_at >= NOW() - INTERVAL '24 hours'`
  );
  const ants = BigInt(r.rows[0].total_ants);
  return Number(ants) / 1e8;
}
