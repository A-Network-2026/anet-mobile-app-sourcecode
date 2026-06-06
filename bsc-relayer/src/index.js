import { config } from './config.js';
import { log } from './log.js';
import { BscWatcher } from './bsc.js';
import { BscSender } from './bsc-sender.js';
import { VaultSender } from './vault.js';
import { L1Poller } from './l1-poller.js';
import {
  pool,
  getCursor,
  setCursor,
  insertSwapIfNew,
  getConfirmedPendingSwaps,
  markMinted,
  markSkipped,
  markFailed,
  markRefundRequired,
  mintedInLast24hAnet,
} from './db.js';
import {
  ANTS_PER_ANET,
  quoteAmountAnet,
  mintAnetOnL1,
  pingL1,
} from './l1.js';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const watcher = new BscWatcher();

async function scanOnce() {
  const latest = await watcher.getLatestBlock();
  let cursor = await getCursor();
  if (cursor == null) {
    cursor = config.startBlock - 1;
    log.info(`first run — starting from block ${config.startBlock}`);
  }

  // Don't scan into the "unsafe" zone where reorgs can still happen — we
  // explicitly want events to age MIN_CONFIRMATIONS deep before they're even
  // considered, so stay one chunk back from the absolute tip.
  const safeTip = latest - 1;
  if (cursor >= safeTip) {
    log.debug(`cursor ${cursor} caught up to tip ${safeTip}, idle`);
    return;
  }

  const from = cursor + 1;
  const to   = Math.min(safeTip, cursor + config.scanChunkBlocks);
  log.info(`scanning blocks ${from}..${to} (tip ${latest})`);

  const events = await watcher.fetchSwapEvents(from, to);
  if (events.length > 0) {
    log.info(`found ${events.length} SwapRequested event(s) in [${from}..${to}]`);
  }
  for (const ev of events) {
    const isNew = await insertSwapIfNew(ev);
    if (isNew) {
      log.info(
        `[detected] swap #${ev.swapId} tx=${ev.txHash} ${ev.tokenSymbol} ` +
        `net=${ev.netAmount} → L1=${ev.anetRecipient}`
      );
    } else {
      log.debug(`[duplicate] swap #${ev.swapId} tx=${ev.txHash}`);
    }
  }
  await setCursor(to);
}

async function mintConfirmed() {
  const latest = await watcher.getLatestBlock();
  const pending = await getConfirmedPendingSwaps(latest, config.minConfirmations);
  if (pending.length === 0) return;

  log.info(`processing ${pending.length} confirmed swap(s)`);

  for (const row of pending) {
    const tag = `swap #${row.swap_id} tx=${row.tx_hash}`;
    try {
      // 0) Token allowlist. The L1 DEX only has an ANET-USDC pool, so only
      // USDC can be quoted/credited. Any other token has no pool — flag it
      // for refund instead of failing forever (the deposit is safe in the
      // swap contract and must be returned to the sender).
      const sym = String(row.token_symbol || '').toUpperCase();
      if (!config.supportedBridgeTokens.has(sym)) {
        const msg =
          `unsupported bridge token ${sym || '(unknown)'} — only ` +
          `${[...config.supportedBridgeTokens].join(', ')} ` +
          `${config.supportedBridgeTokens.size === 1 ? 'is' : 'are'} ` +
          `supported (no L1 pool); flagged for refund`;
        log.warn(`${tag} refund_required: ${msg}`);
        await markRefundRequired(row.tx_hash, row.log_index, msg);
        continue;
      }

      // 1) AMM quote
      const ants = await quoteAmountAnet(row.token_symbol, BigInt(row.net_amount));
      const anetWhole = Number(ants) / Number(ANTS_PER_ANET);
      log.info(`${tag} quote → ${anetWhole} ANET (${ants} ants)`);

      // 2) Per-tx cap
      if (anetWhole > config.maxMintPerTxAnet) {
        const msg = `exceeds MAX_MINT_PER_TX_ANET (${anetWhole} > ${config.maxMintPerTxAnet})`;
        log.warn(`${tag} skipped: ${msg}`);
        await markSkipped(row.tx_hash, row.log_index, msg);
        continue;
      }

      // 3) Daily cap
      const used24h = await mintedInLast24hAnet();
      if (used24h + anetWhole > config.maxMintPerDayAnet) {
        const msg =
          `daily cap would be exceeded ` +
          `(used=${used24h}, +${anetWhole}, cap=${config.maxMintPerDayAnet})`;
        log.warn(`${tag} skipped: ${msg}`);
        await markSkipped(row.tx_hash, row.log_index, msg);
        continue;
      }

      // 4) Mint
      const l1TxId = await mintAnetOnL1(row.anet_recipient, ants, row.tx_hash);
      await markMinted(row.tx_hash, row.log_index, ants, l1TxId);
      log.info(`${tag} ✓ minted ${anetWhole} ANET to ${row.anet_recipient} (${l1TxId})`);
    } catch (e) {
      const msg = e.message || String(e);
      log.error(`${tag} FAILED: ${msg}`);
      await markFailed(row.tx_hash, row.log_index, msg);
    }
  }
}

async function tick() {
  try {
    await scanOnce();
    await mintConfirmed();
  } catch (e) {
    log.error('tick failed', e);
  }
}

async function main() {
  log.info('─────────────────────────────────────────────────────────');
  log.info(' ANET BSC↔L1 Relayer starting');
  log.info(`  contract:         ${config.anetSwapContract}`);
  log.info(`  L1 base:          ${config.anetL1BaseUrl}`);
  log.info(`  min confirmations: ${config.minConfirmations}`);
  log.info(`  scan chunk:       ${config.scanChunkBlocks} blocks`);
  log.info(`  poll interval:    ${config.pollIntervalMs} ms`);
  log.info(`  caps:             ${config.maxMintPerTxAnet} ANET/tx, ${config.maxMintPerDayAnet} ANET/day`);
  log.info(`  DRY_RUN:          ${config.dryRun}`);
  log.info(`  bridge burn:      ${config.bridgeBurnEnabled ? 'ENABLED' : 'disabled'}`);
  if (config.bridgeBurnEnabled) {
    log.info(`  burn poll:        ${config.burnPollIntervalMs} ms`);
    log.info(`  release mode:     ${config.bridgeReleaseMode}`);
    log.info(`  bsc ANET token:   ${config.bscAnetToken} (${config.bscAnetDecimals} dec)`);
    log.info(`  release caps:     ${config.maxReleasePerTxAnet} ANET/tx, ${config.maxReleasePerDayAnet} ANET/day`);
    if (config.bridgeReleaseMode === 'vault') {
      log.info(`  vault address:    ${config.vaultAddress}`);
      log.info(`  vault chainId:    ${config.vaultChainId}`);
    }
  }
  log.info('─────────────────────────────────────────────────────────');

  const l1Healthy = await pingL1().catch(() => false);
  if (!l1Healthy) {
    log.error('L1 chain /health is not OK — aborting startup');
    process.exit(1);
  }
  log.info('L1 health OK');

  // Graceful shutdown.
  let stopping = false;
  let burnLoopHandle = null;
  const shutdown = async (sig) => {
    if (stopping) return;
    stopping = true;
    log.info(`received ${sig}, draining…`);
    if (burnLoopHandle) clearTimeout(burnLoopHandle);
    await pool.end().catch(() => {});
    process.exit(0);
  };
  process.on('SIGINT',  () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  // Optionally bring up the L1 → BSC burn loop (separate cadence from BSC scan).
  if (config.bridgeBurnEnabled) {
    let sender;
    if (config.bridgeReleaseMode === 'vault') {
      sender = new VaultSender();
      await sender.warmup(); // domain check + signer authorization check
      log.info(`vault submitter wallet: ${sender.address}`);
      try {
        const bal = await sender.escrowBalance();
        log.info(`vault wANET balance: ${bal} wei (token ${config.bscAnetToken})`);
      } catch (e) {
        log.warn(`could not read vault balance at startup: ${e.message}`);
      }
    } else {
      sender = new BscSender();
      log.info(`BSC escrow wallet: ${sender.address}`);
      try {
        const bal = await sender.escrowBalance();
        log.info(`BSC escrow balance: ${bal} wei (token ${config.bscAnetToken})`);
      } catch (e) {
        log.warn(`could not read escrow balance at startup: ${e.message}`);
      }
    }
    const poller = new L1Poller(sender);
    const burnTick = async () => {
      if (stopping) return;
      try { await poller.tick(); } catch (e) { log.error('burn tick failed', e); }
      if (!stopping) burnLoopHandle = setTimeout(burnTick, config.burnPollIntervalMs);
    };
    burnLoopHandle = setTimeout(burnTick, config.burnPollIntervalMs);
  }

  // Main loop (BSC → L1 mint side).
  while (!stopping) {
    await tick();
    await sleep(config.pollIntervalMs);
  }
}

main().catch((e) => {
  log.error('fatal', e);
  process.exit(1);
});
