# Decentralized Vault Signing — Deployment Guide

**Status:** code complete on local working tree. Not yet committed/pushed.

## What we built

Three pieces work together to remove all signing power from the relayer:

1. **L1 chain** (`anet-chain`) — new endpoints that store EIP-712 signatures for pending burns. No signing power; pure storage + ecrecover verification.
2. **anet-vault-signer** — single-key signing daemon. Each vault signer runs one independent instance on their own device.
3. **bsc-relayer** — when `VAULT_SIG_SOURCE=l1`, fetches signatures from L1 instead of signing locally. Holds **only** the submitter key (gas).

```
       ┌─────────────┐
  user │ wallet POST │ /bridge/burn
       └──────┬──────┘
              │
         ┌────▼──────────┐
         │   L1 chain    │  ─── stores burn + canonical 24h deadline
         └────┬──────────┘
              │  GET /digest, POST /sigs, GET /sigs
   ┌──────────┼───────────┬───────────┐
   │          │           │           │
 ┌─▼──┐    ┌──▼─┐      ┌──▼─┐      ┌──▼──────────┐
 │sgn1│    │sgn2│      │sgn3│      │ bsc-relayer │
 │PK1 │    │PK2 │      │PK3 │      │ submitter   │
 └────┘    └────┘      └────┘      └──┬──────────┘
  (laptop) (phone)     (cold)         │
                                      │ vault.releaseBurn(burnId, …, [sig1,sig2,sig3])
                                ┌─────▼──────┐
                                │ BSC vault  │ 0x31438362…168B49
                                └────────────┘
```

## L1 schema additions

The `db::ensure_schema()` migration is idempotent:

```sql
ALTER TABLE bridge_burns ADD COLUMN IF NOT EXISTS release_deadline BIGINT;

CREATE TABLE IF NOT EXISTS bridge_burn_signatures (
  burn_id     BIGINT NOT NULL REFERENCES bridge_burns(burn_id),
  signer      TEXT   NOT NULL,
  signature   TEXT   NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (burn_id, signer)
);
```

In-flight burns inserted before this deploy will have `release_deadline=NULL`; the new digest endpoint returns 503 for those, so manually fill them in or wait for them to drain:

```sql
UPDATE bridge_burns
SET release_deadline = EXTRACT(epoch FROM created_at)::bigint + 86400
WHERE release_deadline IS NULL AND status = 'pending';
```

## L1 env vars (new)

| Variable | Example | Required? |
|---|---|---|
| `BRIDGE_VAULT_ADDRESS` | `0x31438362a7667ce5559500023D025c7c14168B49` | yes (to enable sig endpoints) |
| `BRIDGE_VAULT_CHAIN_ID` | `56` | yes |
| `BRIDGE_VAULT_SIGNERS` | `0xa5d1…,0xcbe8…,0xdc74…` | yes |
| `BRIDGE_VAULT_THRESHOLD` | `2` | yes |
| `BRIDGE_DEADLINE_SECS` | `86400` (default) | no — clamped to ≤ 30 days |

## New L1 endpoints

| Verb | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/bridge/burns/:id/digest` | none | Canonical EIP-712 metadata + digest |
| POST | `/bridge/burns/:id/sigs` | ecrecover gate | Submit one signer's sig |
| GET | `/bridge/burns/:id/sigs` | none | List collected sigs (relayer reads) |

The POST handler:
1. parses `signer` + `signature` from body
2. fetches the burn row, recomputes the digest server-side
3. runs ecrecover, verifies recovered address == `signer` (case-insensitive)
4. verifies `signer ∈ BRIDGE_VAULT_SIGNERS`
5. INSERT ON CONFLICT DO UPDATE — idempotent re-posts

## Signer node deployment (per signer)

Each of the 3 vault signers does this **independently** on their own device:

```bash
git clone <repo> ~/anet
cd ~/anet/anet-mobile-app/anet-vault-signer
npm install
cp .env.example .env
chmod 600 .env

# edit .env, fill in:
#   SIGNER_PRIVATE_KEY=0x... (your single key)
#   L1_BASE_URL=https://...
#   L1_ADMIN_KEY=...

npm start
```

### systemd (laptop / VPS)

```
[Unit]
Description=anet-vault-signer
After=network.target

[Service]
User=anet
WorkingDirectory=/home/anet/anet-mobile-app/anet-vault-signer
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=10s
EnvironmentFile=/home/anet/anet-mobile-app/anet-vault-signer/.env

[Install]
WantedBy=multi-user.target
```

### Termux (phone)

```bash
pkg install nodejs git
git clone ...; cd anet-vault-signer; npm install
# put .env in $PREFIX/etc with chmod 600
nohup npm start > signer.log 2>&1 &
```

## Relayer config switch

On Render (or wherever bsc-relayer runs), set:

```
VAULT_SIG_SOURCE=l1
# REMOVE: VAULT_LOCAL_SIGNER_KEYS  (must be unset)
# KEEP:   VAULT_SUBMITTER_KEY      (gas only, no signing power)
```

`VAULT_SIG_SOURCE=l1` is mutually exclusive with `VAULT_LOCAL_SIGNER_KEYS` — the config loader rejects both being set.

When the relayer warms up it will log:
```
VaultSender sig source = L1 (decentralized). Relayer holds NO signer keys; fetching M-of-N from <l1>/bridge/burns/:id/sigs.
```

## End-to-end smoke test (after canary float)

1. Float a small amount of wANET into the vault (e.g. 100 wANET):
   ```bash
   cast send $VAULT_ADDR "depositForBridge(uint256)" 100000000000000000000 \
     --private-key $ADMIN_KEY --rpc-url https://bsc-dataseed1.binance.org
   ```
2. Do a 10-ANET burn from a wallet on L1.
3. Watch each signer daemon log:
   ```
   burn N: signed 10000000000000000000 wei → 0x… (deadline …)
   ```
4. Query L1: `curl $L1/bridge/burns/N/sigs` — should see 2-3 rows.
5. Watch relayer log:
   ```
   vault releaseBurn(burnId=N, 10 ANET → 0x…, sigs=2/2, source=l1)
   vault releaseBurn broadcast tx=0x…
   ```
6. Confirm on BscScan: `Released` event emitted.

## Rollback plan

If anything breaks in production:

- **Relayer side**: set `VAULT_SIG_SOURCE=local` and restore `VAULT_LOCAL_SIGNER_KEYS` on Render. Done — fully decoupled rollback.
- **L1 side**: the new endpoints/schema are additive. Reverting the binary does not require schema rollback (extra column/table is harmless).
- **Signer daemons**: stop them. Existing local-mode releases keep working.

## Audit checklist

- [ ] domain separator computed by `bridge_vault.rs` matches the on-chain vault's `DOMAIN_SEPARATOR()`. (Hard-coded in the rust unit test for vault `0x31438362…168B49` chain 56.)
- [ ] amount conversion `ants → wei` matches relayer's `antsToWei` (×10¹⁰).
- [ ] `BRIDGE_VAULT_SIGNERS` exactly matches the vault's `signers()` array (case-insensitive).
- [ ] each signer daemon's address ∈ that set.
- [ ] submitter address NOT in that set.
- [ ] each signer daemon's `MAX_AMOUNT_ANET_PER_BURN` ≤ vault `maxPerTx`.
- [ ] `BRIDGE_DEADLINE_SECS` (L1) ≥ realistic time for 2-of-3 signers to come online (86400 = 24h recommended).
- [ ] relayer logs show `sigSource=l1` after warmup.
- [ ] `VAULT_LOCAL_SIGNER_KEYS` unset on Render.
