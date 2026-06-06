// anet-vault-signer
//
// Bitcoin-principle decentralized signing daemon for the AnetBridgeVault.
// One signer = one device = one private key. Run this on a laptop / phone
// (via Termux) / cold-ish single-purpose machine. NEVER on the same host
// as the BSC relayer or the L1 chain node.
//
// Loop:
//   1. GET   {L1_BASE_URL}/bridge/burns?since=…       (or use status filter)
//   2. For each pending burn:
//        GET  {L1_BASE_URL}/bridge/burns/:id/digest
//        verify burn matches my expectations
//        sign digest with my single private key (EIP-712 typed data)
//        POST {L1_BASE_URL}/bridge/burns/:id/sigs   { signer, signature }
//   3. sleep POLL_INTERVAL_MS
//
// What this daemon does NOT do:
//   - Hold gas / move tokens
//   - Talk to BSC
//   - Need write access to Postgres
//   - Trust the relayer
//
// Required env:
//   SIGNER_PRIVATE_KEY            0x… hex, 32 bytes
//   L1_BASE_URL                   e.g. https://anet-chain.example
//   L1_ADMIN_KEY                  to read /bridge/burns pending list
//   VAULT_ADDRESS                 expected vault address (defense-in-depth)
//   VAULT_CHAIN_ID                expected chain id (defense-in-depth)
//   POLL_INTERVAL_MS              default 2000 (Phase 0 latency tune; was 30000)
//   MAX_AMOUNT_ANET_PER_BURN      hard refusal threshold, default 10000
//
// Exit codes:
//   0  clean shutdown
//   1  fatal config error
//   2  L1 unreachable for > 5 minutes (operator should investigate)

import 'dotenv/config';
import { Wallet, getAddress, isAddress, getBytes, hexlify, SigningKey } from 'ethers';

// ── config ─────────────────────────────────────────────────────────────────

function reqEnv(name) {
  const v = process.env[name];
  if (!v || !v.trim()) {
    console.error(`fatal: ${name} is required`);
    process.exit(1);
  }
  return v.trim();
}

const SIGNER_PK = reqEnv('SIGNER_PRIVATE_KEY');
const L1_BASE_URL = reqEnv('L1_BASE_URL').replace(/\/+$/, '');
const L1_ADMIN_KEY = reqEnv('L1_ADMIN_KEY');
const VAULT_ADDRESS = reqEnv('VAULT_ADDRESS').toLowerCase();
const VAULT_CHAIN_ID = Number(reqEnv('VAULT_CHAIN_ID'));
// Phase 0 bridge-latency tune (2026-05-26): default lowered from 30000 → 2000.
// The L1 /bridge/burns endpoint is cheap and rate-limit-friendly. With two
// independent signers each polling every ~2s, end-to-end L1 → wANET drops
// from ~30s worst-case to ~5–8s. Operators can still override via env.
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS || 2_000);
const MAX_AMOUNT_ANET = Number(process.env.MAX_AMOUNT_ANET_PER_BURN || 10_000);
const RUN_ONCE = (process.env.RUN_ONCE || '').toLowerCase() === 'true';

if (!isAddress(VAULT_ADDRESS) || !Number.isFinite(VAULT_CHAIN_ID) || VAULT_CHAIN_ID <= 0) {
  console.error('fatal: VAULT_ADDRESS or VAULT_CHAIN_ID invalid');
  process.exit(1);
}

const wallet = new Wallet(SIGNER_PK);
const MY_ADDRESS = wallet.address.toLowerCase();
console.log(`anet-vault-signer starting`);
console.log(`  signer address     : ${MY_ADDRESS}`);
console.log(`  l1                 : ${L1_BASE_URL}`);
console.log(`  vault              : ${VAULT_ADDRESS}`);
console.log(`  chain_id           : ${VAULT_CHAIN_ID}`);
console.log(`  max amount / burn  : ${MAX_AMOUNT_ANET} ANET`);
console.log(`  poll interval (ms) : ${POLL_INTERVAL_MS}`);

// ── http helpers ───────────────────────────────────────────────────────────

async function httpJson(method, path, body) {
  const url = `${L1_BASE_URL}${path}`;
  const res = await fetch(url, {
    method,
    headers: { 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`${method} ${path} -> ${res.status}: ${text.slice(0, 400)}`);
  }
  return text ? JSON.parse(text) : null;
}

async function fetchPendingBurns(since) {
  const params = new URLSearchParams({
    since: String(since),
    limit: '50',
    admin_key: L1_ADMIN_KEY,
  });
  return httpJson('GET', `/bridge/burns?${params}`);
}

async function fetchDigest(burnId) {
  return httpJson('GET', `/bridge/burns/${burnId}/digest`);
}

async function fetchSigs(burnId) {
  return httpJson('GET', `/bridge/burns/${burnId}/sigs`);
}

async function postSig(burnId, body) {
  return httpJson('POST', `/bridge/burns/${burnId}/sigs`, body);
}

// ── signing ────────────────────────────────────────────────────────────────

/**
 * Re-derive the EIP-712 digest from the L1-supplied metadata WITHOUT
 * trusting the L1's `digest` field. This is the security-critical step:
 * if L1 (or any MITM) gives us a wrong digest, signing it could authorize
 * a release of funds we didn't intend. We always recompute and verify.
 *
 * Returns { ok, computedDigest, reason? }.
 */
function recomputeAndVerifyDigest(meta) {
  // Defensive checks first
  if (meta.vault_address.toLowerCase() !== VAULT_ADDRESS) {
    return { ok: false, reason: `vault_address mismatch: ${meta.vault_address} vs ${VAULT_ADDRESS}` };
  }
  if (Number(meta.chain_id) !== VAULT_CHAIN_ID) {
    return { ok: false, reason: `chain_id mismatch: ${meta.chain_id} vs ${VAULT_CHAIN_ID}` };
  }
  if (!isAddress(meta.bsc_recipient)) {
    return { ok: false, reason: `bsc_recipient invalid: ${meta.bsc_recipient}` };
  }
  if (!meta.signers.map((s) => s.toLowerCase()).includes(MY_ADDRESS)) {
    return { ok: false, reason: `my address ${MY_ADDRESS} not in signer set` };
  }

  // Amount sanity (in ANET, before 1e18 scaling). amount_wei_decimal is 1e18-scaled.
  // 1 ANET = 1e18 wei (on BSC wANET), so ANET = wei / 1e18.
  const wei = BigInt(meta.amount_wei_decimal);
  const anetTimes1e18 = wei; // wei IS anet * 1e18
  const maxWei = BigInt(MAX_AMOUNT_ANET) * 10n ** 18n;
  if (anetTimes1e18 > maxWei) {
    return { ok: false, reason: `amount ${anetTimes1e18 / 10n ** 18n} ANET exceeds local cap ${MAX_AMOUNT_ANET}` };
  }
  if (anetTimes1e18 <= 0n) {
    return { ok: false, reason: 'amount must be > 0' };
  }

  // Deadline must be in the future, not too far out, not too close.
  const nowSec = Math.floor(Date.now() / 1000);
  const deadline = Number(meta.deadline);
  if (deadline <= nowSec + 60) {
    return { ok: false, reason: `deadline ${deadline} too soon (now=${nowSec})` };
  }
  if (deadline > nowSec + 30 * 24 * 3600) {
    return { ok: false, reason: `deadline ${deadline} too far in the future` };
  }

  // Build EIP-712 typed data and let ethers compute the digest.
  const typedData = buildTypedData({
    chainId: VAULT_CHAIN_ID,
    verifyingContract: VAULT_ADDRESS,
    burnId: BigInt(meta.burn_id),
    l1Sender: meta.l1_sender,
    recipient: getAddress(meta.bsc_recipient),
    amount: wei,
    deadline: BigInt(deadline),
  });

  const computed = typedDataDigest(typedData);
  if (computed.toLowerCase() !== meta.digest.toLowerCase()) {
    return {
      ok: false,
      reason: `digest mismatch — refusing to sign. computed=${computed} server=${meta.digest}`,
    };
  }
  return { ok: true, computedDigest: computed, typedData };
}

function buildTypedData({ chainId, verifyingContract, burnId, l1Sender, recipient, amount, deadline }) {
  return {
    domain: {
      name: 'AnetBridgeVault',
      version: '1',
      chainId,
      verifyingContract,
    },
    types: {
      Release: [
        { name: 'burnId', type: 'uint256' },
        { name: 'l1Sender', type: 'string' },
        { name: 'recipient', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    },
    primaryType: 'Release',
    value: { burnId, l1Sender, recipient, amount, deadline },
  };
}

// ethers v6 TypedDataEncoder
import { TypedDataEncoder } from 'ethers';
function typedDataDigest(td) {
  return TypedDataEncoder.hash(td.domain, td.types, td.value);
}

async function signTypedData(td) {
  // ethers v6: wallet.signTypedData (EIP-712)
  return wallet.signTypedData(td.domain, td.types, td.value);
}

// ── main loop ──────────────────────────────────────────────────────────────

let cursor = 0;
let lastSuccess = Date.now();

async function tick() {
  let burns;
  try {
    burns = await fetchPendingBurns(cursor);
  } catch (e) {
    console.error(`poll error: ${e.message}`);
    if (Date.now() - lastSuccess > 5 * 60 * 1000) {
      console.error('L1 unreachable for >5min; exiting with code 2');
      process.exit(2);
    }
    return;
  }
  lastSuccess = Date.now();

  if (!Array.isArray(burns) || burns.length === 0) {
    return;
  }

  for (const burn of burns) {
    cursor = Math.max(cursor, Number(burn.burn_id));
    try {
      await processBurn(burn);
    } catch (e) {
      console.error(`burn ${burn.burn_id} processing error: ${e.message}`);
    }
  }
}

async function processBurn(burn) {
  const burnId = Number(burn.burn_id);

  // Skip if we've already signed this one.
  const existing = await fetchSigs(burnId);
  if (existing.some((s) => s.signer.toLowerCase() === MY_ADDRESS)) {
    return; // idempotent
  }

  const meta = await fetchDigest(burnId);
  if (meta.status !== 'pending') {
    return;
  }
  const verdict = recomputeAndVerifyDigest(meta);
  if (!verdict.ok) {
    console.warn(`burn ${burnId}: REFUSING to sign — ${verdict.reason}`);
    return;
  }

  const signature = await signTypedData(verdict.typedData);
  await postSig(burnId, { signer: MY_ADDRESS, signature });
  console.log(
    `burn ${burnId}: signed ${meta.amount_wei_decimal} wei → ${meta.bsc_recipient} (deadline ${meta.deadline})`,
  );
}

async function main() {
  if (RUN_ONCE) {
    await tick();
    return;
  }
  // long-running loop
  // eslint-disable-next-line no-constant-condition
  while (true) {
    await tick();
    await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
  }
}

main().catch((e) => {
  console.error(`fatal: ${e.stack || e.message}`);
  process.exit(1);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM — exiting cleanly');
  process.exit(0);
});
process.on('SIGINT', () => {
  console.log('SIGINT — exiting cleanly');
  process.exit(0);
});
