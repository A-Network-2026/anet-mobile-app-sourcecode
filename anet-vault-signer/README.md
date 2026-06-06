# anet-vault-signer

Self-hosted EIP-712 signing daemon for the AnetBridgeVault on BSC.

## Bitcoin principle

One signer = one device = one private key. Each of the 3 vault signers should run **one independent instance** of this daemon, ideally on hardware they control (laptop, phone via Termux, single-purpose VPS).

The relayer should **never** have signing power. This daemon:

- holds **one** private key (your signer)
- talks **only** to the L1 chain (read pending burns, read digest, post signature)
- never moves tokens, never talks to BSC, never needs an admin password to BSC
- if compromised, attacker gets your single seat in the M-of-N — **not** the bridge

## Quickstart

```bash
cd anet-vault-signer
npm install
cp .env.example .env
# edit .env — set SIGNER_PRIVATE_KEY and L1_BASE_URL
npm start
```

## Required env

| Variable | Example | Purpose |
|---|---|---|
| `SIGNER_PRIVATE_KEY` | `0x…` (32 bytes) | Your signer key. Treat like a Bitcoin seed. |
| `L1_BASE_URL` | `https://anet-chain.example` | Your A-Network L1 node |
| `L1_ADMIN_KEY` | (op-issued) | Reads pending list |
| `VAULT_ADDRESS` | `0x31438362a7667ce5559500023D025c7c14168B49` | Defense-in-depth check |
| `VAULT_CHAIN_ID` | `56` | BSC mainnet |
| `POLL_INTERVAL_MS` | `30000` | Default 30s |
| `MAX_AMOUNT_ANET_PER_BURN` | `10000` | Local refusal cap |

## What this daemon refuses to sign

- digest the L1 reports doesn't match what we re-computed locally
- vault address or chain id different from our env
- our address not in the vault's signer set
- amount > `MAX_AMOUNT_ANET_PER_BURN`
- deadline less than 60s away or more than 30 days out

## Threat model

- Compromised L1 host: cannot forge releases, because we re-derive the digest from the metadata and compare. A bad digest is silently dropped, never signed.
- Compromised relayer: irrelevant — relayer never sees this daemon's key.
- Compromised this daemon's host: attacker gets 1 of N signatures. Below M-of-N threshold, no funds move.

## Deployment notes

- Run as a systemd unit / launchd plist / Termux service.
- Keep the key file root-only (`chmod 600`).
- Rotate by adding a new signer to the vault (admin action) before removing the old one.
- Do **not** run more than one instance with the same key — duplicate sigs are merely overwritten but it's wasteful.
