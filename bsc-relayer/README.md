# ANET BSC → L1 Relayer

A production watcher service that closes the loop between the AnetSwap
contract on BSC and the ANET L1 chain. It is the "Bitcoin-style" half of
the bridge: every BSC swap is followed for 12 confirmations and, once
final, the equivalent ANET (priced at the live L1 AMM rate) is credited
to the user's L1 wallet.

This is **Step 1 — BSC → L1 only.** The reverse direction (L1 → BSC
burn-and-release) will be added as Step 2 in its own module.

## Architecture

```
┌──────────────┐   eth_getLogs    ┌──────────────┐   POST /admin/anet/mint
│ BSC mainnet  │ ───────────────► │  Relayer     │ ─────────────────────────►  ANET L1
│ AnetSwap.sol │  SwapRequested   │  (this svc)  │  body: {address, ants,    chain
└──────────────┘                  │              │         admin_key}
                                   │  Postgres    │
                                   │  idempotency │
                                   └──────────────┘
```

The relayer is **idempotent at the database layer**: each
`(tx_hash, log_index)` is the primary key in the `swaps` table, so even
if the worker is restarted mid-scan, an RPC replays an event, or two
workers run in parallel, no swap will ever be minted twice.

## Safety rails

| Lever | Default | Purpose |
| --- | --- | --- |
| `MIN_CONFIRMATIONS` | `12` | Wait this many blocks before considering an event final. |
| `MAX_MINT_PER_TX_ANET` | `10000` | Per-event hard cap. Anything over → `status='skipped'`. |
| `MAX_MINT_PER_DAY_ANET` | `100000` | Rolling-24h cap. Once hit, mints pause. |
| `DRY_RUN` | `true` in `render.yaml` | Detects + records swaps but never calls the mint endpoint. |
| `ANET_DEX_ADMIN_KEY` | — | Shared secret with L1 server. Treat like a root password. |

## Deploy on Render

1. **Generate the admin key** locally:
   ```bash
   cd bsc-relayer
   npm install
   npm run generate-key
   ```
   Copy the printed value.

2. **On the L1 chain Render service** (`anet-private-mainnet`):
   - Set env `ANET_DEX_ADMIN_KEY` to the value from step 1.
   - Set env `ANET_BRIDGE_MINT_ENABLED=true` (the mint endpoint requires it).
   - Trigger a restart.

3. **Create the relayer** from `render.yaml`:
   - In Render: New + → Blueprint → point at this repo.
   - Set `ANET_DEX_ADMIN_KEY` on the worker to the SAME value.
   - Confirm `DRY_RUN=true` (the blueprint defaults to true).
   - Deploy.

4. **First migration**. Once the service is live, open its Shell and run:
   ```bash
   npm run migrate
   ```

5. **Soak in DRY_RUN.** Tail the logs for ~24h. Verify every BSC swap
   you do from the app shows up as `[detected]` then later as a
   `[DRY_RUN] would mint …` line with a sane ANET amount.

6. **Go live.** Flip `DRY_RUN=false` in the env vars and restart.

## Monitoring queries

```sql
-- pending pipeline depth
SELECT status, COUNT(*) FROM relayer.swaps GROUP BY status;

-- last 20 mints
SELECT swap_id, tx_hash, anet_recipient, anet_ants_minted, minted_at
  FROM relayer.swaps WHERE status='minted' ORDER BY minted_at DESC LIMIT 20;

-- failures needing attention
SELECT swap_id, tx_hash, error FROM relayer.swaps WHERE status='failed';
```

## Files

| Path | Role |
| --- | --- |
| `src/index.js` | Main loop (scan → mint). |
| `src/bsc.js`   | ethers v6 RPC wrapper, SwapRequested decoder, fallback RPC. |
| `src/l1.js`    | L1 quote + mint HTTP client. |
| `src/db.js`    | Postgres pool + idempotency helpers. |
| `src/config.js`| Env loading + validation. |
| `src/log.js`   | Structured stderr logger. |
| `schema.sql`   | Postgres schema (`swaps`, `cursor`). |
| `scripts/generate-key.js` | Hot-key generator. |
| `scripts/migrate.js`      | Apply `schema.sql`. |
| `render.yaml`  | Render Blueprint (worker + db). |
| `Dockerfile`   | Container image (optional, for non-Render hosts). |
