// Recover a swap that was processed during DRY_RUN (or missed entirely).
//
// Usage (from Render Shell of anet-bsc-relayer, or locally with DATABASE_URL set):
//   node scripts/recover-swap.js 0xTX_HASH
//
// What it does:
//   1. Looks up the swap row by tx_hash in relayer.swaps.
//   2. If the row exists AND status='minted' AND l1_tx_id starts with 'dryrun-',
//      it resets the row to status='detected' so the main mintConfirmed() loop
//      will re-process it for real on the next tick.
//   3. If the row exists with status='detected' or 'failed', it resets/clears
//      error state so it can be retried.
//   4. If the row does NOT exist, it queries BSC for the tx receipt to find
//      its block number, then rewinds relayer.cursor.last_scanned to
//      (blockNumber - 1) so the next scan re-fetches the event.
//
// IMPORTANT: Set DRY_RUN=false on the relayer service BEFORE you run this,
// otherwise the recovery will just re-simulate again.

import { ethers } from 'ethers';
import { config } from '../src/config.js';
import { pool } from '../src/db.js';

const txHash = process.argv[2];
if (!txHash || !txHash.startsWith('0x') || txHash.length !== 66) {
  console.error('Usage: node scripts/recover-swap.js 0xTX_HASH');
  process.exit(1);
}

async function main() {
  console.log(`\n=== Swap recovery for ${txHash} ===\n`);
  console.log(`DRY_RUN currently: ${config.dryRun ? 'TRUE  ⚠️  flip to false before relying on this' : 'false ✓'}\n`);

  const r = await pool.query(
    `SELECT tx_hash, log_index, block_number, swap_id, anet_recipient,
            token_symbol, net_amount, status, l1_tx_id, anet_ants_minted,
            detected_at, minted_at, error
       FROM relayer.swaps
      WHERE tx_hash = $1
      ORDER BY log_index`,
    [txHash]
  );

  if (r.rows.length > 0) {
    console.log(`Found ${r.rows.length} swap row(s) for this tx:\n`);
    for (const row of r.rows) {
      console.log(`  swap_id=${row.swap_id} block=${row.block_number} status=${row.status}`);
      console.log(`    recipient=${row.anet_recipient} token=${row.token_symbol} net=${row.net_amount}`);
      console.log(`    l1_tx_id=${row.l1_tx_id || '(none)'} ants_minted=${row.anet_ants_minted || '(none)'}`);
      if (row.error) console.log(`    error=${row.error}`);
    }

    const upd = await pool.query(
      `UPDATE relayer.swaps
          SET status = 'detected',
              l1_tx_id = NULL,
              anet_ants_minted = NULL,
              minted_at = NULL,
              error = NULL
        WHERE tx_hash = $1
          AND (status IN ('minted','failed','skipped')
               OR l1_tx_id LIKE 'dryrun-%')
        RETURNING swap_id, log_index`,
      [txHash]
    );
    if (upd.rowCount > 0) {
      console.log(`\n✓ Reset ${upd.rowCount} row(s) to status='detected'.`);
      console.log(`  The mintConfirmed() loop will pick it up on the next tick`);
      console.log(`  (within ${config.pollIntervalMs || 5000} ms).`);
    } else {
      console.log(`\nℹ Row already in state 'detected' — no change needed.`);
    }
  } else {
    console.log('No swap row found for this tx — will rewind scan cursor instead.\n');

    const provider = new ethers.JsonRpcProvider(config.bscRpcUrl);
    const receipt = await provider.getTransactionReceipt(txHash);
    if (!receipt) {
      console.error('Could not fetch tx receipt from BSC RPC. Check tx hash.');
      process.exit(2);
    }
    const blockNumber = receipt.blockNumber;
    console.log(`Tx is in BSC block ${blockNumber}, status=${receipt.status === 1 ? 'success' : 'FAILED'}`);
    if (receipt.status !== 1) {
      console.error('Tx reverted on BSC — nothing to recover.');
      process.exit(3);
    }

    const rewindTo = blockNumber - 1;
    const cur = await pool.query('SELECT last_scanned FROM relayer.cursor WHERE id = 1');
    const before = cur.rows[0]?.last_scanned ?? null;
    console.log(`Cursor before: ${before}`);
    console.log(`Cursor after:  ${rewindTo} (block - 1)`);

    await pool.query(
      `INSERT INTO relayer.cursor (id, last_scanned, updated_at)
       VALUES (1, $1, NOW())
       ON CONFLICT (id) DO UPDATE SET last_scanned = EXCLUDED.last_scanned, updated_at = NOW()`,
      [rewindTo]
    );
    console.log('\n✓ Cursor rewound. The next scan will re-emit the SwapRequested event.');
  }

  console.log('\nDone.\n');
  await pool.end();
}

main().catch((e) => {
  console.error('Recovery failed:', e);
  process.exit(1);
});
