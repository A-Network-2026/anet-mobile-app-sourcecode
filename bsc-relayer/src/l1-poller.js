// L1 → BSC bridge poller.
//
// Polls the L1 chain's /bridge/burns endpoint for new pending burns
// (the L1 has already debited the user's ANET balance when a row
// appears there). For each new burn:
//   1. Insert into relayer.burns (idempotent on burn_id)
//   2. Mark sending (atomic CAS — prevents duplicate BSC sends across restarts)
//   3. Use BscSender to transfer wANET on BSC
//   4. POST /bridge/burns/:id/released back to the L1
//   5. Mark released locally
//
// Daily and per-burn caps are enforced symmetrically with the mint side.

import { request } from 'undici';
import { config } from './config.js';
import { log } from './log.js';
import {
  getBurnCursor,
  setBurnCursor,
  insertBurnIfNew,
  getDetectedBurns,
  markBurnSending,
  markBurnReleased,
  markBurnFailed,
  markBurnSkipped,
  releasedInLast24hAnet,
} from './db.js';

const ANTS_PER_ANET = 100_000_000n;

export class L1Poller {
  constructor(bscSender) {
    this.bscSender = bscSender;
  }

  /** Poll L1 for new burns and write them into relayer.burns. */
  async fetchPendingFromL1() {
    let cursor = await getBurnCursor();
    if (cursor == null) cursor = 0;

    const url =
      `${config.anetL1BaseUrl}/bridge/burns` +
      `?since=${cursor}&limit=100&admin_key=${encodeURIComponent(config.anetDexAdminKey)}`;

    const { statusCode, body } = await request(url, { method: 'GET' });
    const text = await body.text();
    if (statusCode !== 200) {
      throw new Error(`L1 /bridge/burns failed (${statusCode}): ${text}`);
    }

    const rows = JSON.parse(text);
    if (!Array.isArray(rows)) {
      throw new Error(`L1 /bridge/burns returned non-array: ${text}`);
    }
    if (rows.length === 0) return 0;

    let newCount = 0;
    let maxId = cursor;
    for (const r of rows) {
      const burn = {
        burn_id: Number(r.burn_id),
        l1_sender: r.l1_sender,
        bsc_recipient: r.bsc_recipient,
        ants: BigInt(r.ants),
        token_symbol: r.token_symbol,
      };
      const inserted = await insertBurnIfNew(burn);
      if (inserted) {
        newCount += 1;
        log.info(
          `[detected] burn #${burn.burn_id} ${burn.ants} ants ` +
            `(${burn.token_symbol}) → ${burn.bsc_recipient}`,
        );
      }
      if (burn.burn_id > maxId) maxId = burn.burn_id;
    }
    if (maxId > cursor) await setBurnCursor(maxId);
    return newCount;
  }

  /** Process burns we've recorded locally that haven't yet been released on BSC. */
  async releaseDetected() {
    const pending = await getDetectedBurns(25);
    if (pending.length === 0) return;
    log.info(`processing ${pending.length} pending burn(s) for BSC release`);

    for (const row of pending) {
      const tag = `burn #${row.burn_id}`;
      try {
        const ants = BigInt(row.ants);
        const anetWhole = Number(ants) / Number(ANTS_PER_ANET);

        // 1) Token guard — only ANET supported for now.
        if (row.token_symbol !== 'ANET') {
          const msg = `unsupported token_symbol "${row.token_symbol}" (only ANET implemented)`;
          log.warn(`${tag} skipped: ${msg}`);
          await markBurnSkipped(row.burn_id, msg);
          await this.reportFailedToL1(row.burn_id, msg);
          continue;
        }

        // 2) Per-tx cap
        if (anetWhole > config.maxReleasePerTxAnet) {
          const msg = `exceeds MAX_RELEASE_PER_TX_ANET (${anetWhole} > ${config.maxReleasePerTxAnet})`;
          log.warn(`${tag} skipped: ${msg}`);
          await markBurnSkipped(row.burn_id, msg);
          await this.reportFailedToL1(row.burn_id, msg);
          continue;
        }

        // 3) Daily cap
        const used24h = await releasedInLast24hAnet();
        if (used24h + anetWhole > config.maxReleasePerDayAnet) {
          const msg =
            `daily release cap would be exceeded ` +
            `(used=${used24h}, +${anetWhole}, cap=${config.maxReleasePerDayAnet})`;
          log.warn(`${tag} skipped: ${msg}`);
          await markBurnSkipped(row.burn_id, msg);
          await this.reportFailedToL1(row.burn_id, msg);
          continue;
        }

        // 4) Atomic claim — if another worker (or our previous incarnation
        //    after a crash) already moved this row out of 'detected', skip.
        const claimed = await markBurnSending(row.burn_id);
        if (!claimed) {
          log.debug(`${tag} already claimed by another worker, skipping`);
          continue;
        }

        // 5) Send on BSC.
        //    BscSender ignores opts (legacy hot-EOA path).
        //    VaultSender uses opts.burnId / opts.l1Sender to build the
        //    EIP-712 Release digest that the AnetBridgeVault verifies on-chain.
        log.info(`${tag} sending ${anetWhole} ANET → ${row.bsc_recipient}`);
        const { txHash, amountWei } = await this.bscSender.releaseAnts(
          row.bsc_recipient,
          ants,
          { burnId: row.burn_id, l1Sender: row.l1_sender },
        );

        // 6) Persist locally + report back to L1
        await markBurnReleased(row.burn_id, txHash, amountWei);
        await this.reportReleasedToL1(row.burn_id, txHash);
        log.info(`${tag} ✓ released ${anetWhole} ANET on BSC tx=${txHash}`);
      } catch (e) {
        const msg = e.message || String(e);
        log.error(`${tag} FAILED: ${msg}`);
        await markBurnFailed(row.burn_id, msg);
        await this.reportFailedToL1(row.burn_id, msg).catch((err) =>
          log.error(`${tag} could not notify L1 of failure: ${err.message}`),
        );
      }
    }
  }

  async reportReleasedToL1(burnId, bscTxHash) {
    const url = `${config.anetL1BaseUrl}/bridge/burns/${burnId}/released`;
    const { statusCode, body } = await request(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        bsc_tx_hash: bscTxHash,
        admin_key: config.anetDexAdminKey,
      }),
    });
    const text = await body.text();
    if (statusCode !== 200) {
      // Local DB already shows released; L1 mismatch needs operator attention.
      log.warn(`burn #${burnId} L1 ack failed (${statusCode}): ${text}`);
    }
  }

  async reportFailedToL1(burnId, errorMsg) {
    const url = `${config.anetL1BaseUrl}/bridge/burns/${burnId}/failed`;
    const { statusCode, body } = await request(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        error: errorMsg.slice(0, 500),
        admin_key: config.anetDexAdminKey,
      }),
    });
    const text = await body.text();
    if (statusCode !== 200) {
      log.warn(`burn #${burnId} L1 fail-ack rejected (${statusCode}): ${text}`);
    }
  }

  async tick() {
    try {
      await this.fetchPendingFromL1();
    } catch (e) {
      log.error(`L1 burn poll failed: ${e.message}`);
    }
    try {
      await this.releaseDetected();
    } catch (e) {
      log.error(`burn release failed: ${e.message}`);
    }
  }
}
