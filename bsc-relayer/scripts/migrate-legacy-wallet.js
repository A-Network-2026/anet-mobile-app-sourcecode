#!/usr/bin/env node
/**
 * migrate-legacy-wallet.js
 *
 * One-shot, Bitcoin-aligned, permissionless legacy → secp wallet migration.
 *
 *   Background: the original anet-chain shipped with a "legacy" address
 *   derivation:
 *       legacy_addr = RIPEMD160( SHA256( SHA256(seed)_hex_lower ) _hex_lower
 *                              ) _hex_upper [..36]   (prefixed "ANET")
 *   This derivation can never produce a valid secp signature, so legacy
 *   wallets cannot interact with the new signed-action endpoints
 *   (bridge_burn, dex_swap, etc.). The chain therefore exposes a
 *   `/wallet/migrate-legacy` commit-reveal endpoint pair that lets the
 *   holder of the legacy private key sweep their balance into a brand-
 *   new secp-derived address, where:
 *       secp_addr = RIPEMD160( compressed_secp_pubkey ) _hex_upper [..36]
 *
 *   The migration is RECORDED ON-CHAIN as a normal block event:
 *       "WalletMigration: <legacy> -> <secp> ants=N sessions=M"
 *
 *   Commit-reveal prevents mempool front-running of the revealed
 *   private key: phase 1 binds (legacy, secp) before any privkey is
 *   transmitted; phase 2 reveals the privkey, which the server checks
 *   against the recorded commitment.
 *
 * USAGE:
 *
 *   # The privkey file must contain a single line: 0x-hex (66 chars) or
 *   # bare hex (64 chars). chmod 600 and delete afterwards.
 *
 *   SEED_PHRASE_FILE=/tmp/anet.seed \
 *   node scripts/migrate-legacy-wallet.js
 *
 * Optional flags:
 *   --l1            L1 base URL (default https://anet-private-mainnet.onrender.com)
 *   --legacy        Override the auto-derived legacy address (sanity check only)
 *   --secp          Override the auto-derived secp address (sanity check only)
 *   --commit-only   Submit only the commit phase (debug)
 *   --reveal-only   Submit only the reveal phase, assumes a prior commit
 *   --nonce         Override commit nonce (default: random uint64)
 *   --yes           Skip interactive confirmation prompts
 *
 * SAFETY:
 *   - Private key only lives in process memory.
 *   - Reveal phase transmits the privkey to the L1 node over HTTPS.
 *     Once submitted, the legacy address is swept atomically, so the
 *     revealed key has no remaining funds to steal.
 *   - The commitment in phase 1 locks (legacy, secp): any front-runner
 *     who later observes the reveal cannot redirect the migration to
 *     a different secp address.
 */

import { createHash, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createInterface } from 'node:readline';
import { stdin as input, stdout as output } from 'node:process';

import { SigningKey, hexlify } from 'ethers';

const ANET_CHAIN_ID = 'anet-private-mainnet-1';
const DEFAULT_L1 = 'https://anet-private-mainnet.onrender.com';

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 2; i < argv.length; i += 1) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        args[key] = true;
      } else {
        args[key] = next;
        i += 1;
      }
    } else {
      args._.push(a);
    }
  }
  return args;
}

const ARGS = parseArgs(process.argv);
const L1_BASE = String(ARGS.l1 || DEFAULT_L1).replace(/\/+$/, '');
const COMMIT_ONLY = Boolean(ARGS['commit-only']);
const REVEAL_ONLY = Boolean(ARGS['reveal-only']);
const SKIP_CONFIRM = Boolean(ARGS.yes);

function fatal(msg) {
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest();
}
function ripemd160(bytes) {
  return createHash('ripemd160').update(bytes).digest();
}

function compressPubKey(uncompressed65) {
  if (uncompressed65.length !== 65 || uncompressed65[0] !== 0x04) {
    throw new Error('compressPubKey: expected 65-byte 0x04-prefixed key');
  }
  const x = uncompressed65.subarray(1, 33);
  const y = uncompressed65.subarray(33, 65);
  const prefix = (y[31] & 1) === 0 ? 0x02 : 0x03;
  return Buffer.concat([Buffer.from([prefix]), x]);
}

function deriveSecpAnetAddress(privKey) {
  const uncompressedHex = SigningKey.computePublicKey(hexlify(privKey), false);
  const uncompressed = Buffer.from(uncompressedHex.slice(2), 'hex');
  const compressed = compressPubKey(uncompressed);
  const ripe = ripemd160(compressed);
  return 'ANET' + ripe.toString('hex').toUpperCase().slice(0, 36);
}

function deriveLegacyAnetAddressFromPrivKey(privKey) {
  // Mirrors transaction.rs::derive_legacy_address_from_privkey_bytes:
  //   priv_str = hex_lower(privkey_bytes)
  //   pub_str  = hex_lower(SHA256(priv_str.bytes()))
  //   addr     = "ANET" + hex_upper(RIPEMD160(pub_str.bytes()))[..36]
  const privStr = Buffer.from(privKey).toString('hex'); // lowercase
  const pubStr = sha256(Buffer.from(privStr, 'utf8')).toString('hex');
  const ripe = ripemd160(Buffer.from(pubStr, 'utf8'));
  return 'ANET' + ripe.toString('hex').toUpperCase().slice(0, 36);
}

function bigIntTo32(buf) {
  if (buf.length === 32) return buf;
  if (buf.length > 32) return buf.subarray(buf.length - 32);
  const out = Buffer.alloc(32);
  buf.copy(out, 32 - buf.length);
  return out;
}

function canonicalPayload(payload) {
  const keys = Object.keys(payload).sort();
  const ordered = {};
  for (const k of keys) ordered[k] = payload[k];
  return JSON.stringify(ordered);
}

function signActionAuth({ privKey, wallet, actionType }) {
  const ts = new Date();
  const nonce = ts.getTime();
  const payload = { route: actionType };
  const payloadCanon = canonicalPayload(payload);
  const preimage =
    `action-v1|${actionType}|${wallet.toUpperCase()}|${nonce}|${ts.getTime()}|${ANET_CHAIN_ID}|${payloadCanon}`;
  const hash = sha256(Buffer.from(preimage, 'utf8'));
  const actionHash = hash.toString('hex').toLowerCase();
  const signingKey = new SigningKey(hexlify(privKey));
  const sig = signingKey.sign(hexlify(hash));
  let v = sig.yParity ?? (sig.v === 27 ? 0 : sig.v === 28 ? 1 : sig.v);
  if (v === 27) v = 0;
  if (v === 28) v = 1;
  const r = bigIntTo32(Buffer.from(sig.r.slice(2), 'hex'));
  const s = bigIntTo32(Buffer.from(sig.s.slice(2), 'hex'));
  const sigBytes = Buffer.concat([r, s, Buffer.from([v])]);
  return {
    wallet: wallet.toUpperCase(),
    nonce,
    timestamp: ts.toISOString(),
    chain_id: ANET_CHAIN_ID,
    payload,
    signature: sigBytes.toString('hex').toLowerCase(),
    action_hash: actionHash,
  };
}

async function loadCredential() {
  if (process.env.SEED_PHRASE) return process.env.SEED_PHRASE.trim();
  if (process.env.SEED_PHRASE_FILE) {
    try {
      return readFileSync(process.env.SEED_PHRASE_FILE, 'utf8').trim();
    } catch (e) {
      fatal(`failed to read SEED_PHRASE_FILE: ${e.message}`);
    }
  }
  // Interactive
  return new Promise((resolve) => {
    const rl = createInterface({ input, output, terminal: true });
    rl.question('paste your private key (hex, will not echo): ', (ans) => {
      rl.close();
      resolve(ans.trim());
    });
  });
}

function parseCredential(text) {
  const cleaned = text.trim();
  const m = /^(?:evmkey:)?(0x)?([0-9a-fA-F]{64})$/.exec(cleaned.replace(/\s+/g, ''));
  if (!m) {
    fatal('input must be a 64-hex-char EVM private key (optionally 0x-prefixed)');
  }
  return Buffer.from(m[2], 'hex');
}

async function prompt(text) {
  if (SKIP_CONFIRM) return 'yes';
  return new Promise((resolve) => {
    const rl = createInterface({ input, output });
    rl.question(text, (ans) => {
      rl.close();
      resolve(ans);
    });
  });
}

async function httpPost(path, body) {
  const url = `${L1_BASE}${path}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = { raw: text };
  }
  return { status: res.status, ok: res.ok, body: parsed };
}

async function httpGet(path) {
  const url = `${L1_BASE}${path}`;
  const res = await fetch(url);
  const text = await res.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = { raw: text };
  }
  return { status: res.status, ok: res.ok, body: parsed };
}

async function main() {
  console.log('');
  console.log('anet-wallet-migration  legacy → secp');
  console.log('------------------------------------');
  console.log(`  L1 base URL : ${L1_BASE}`);
  console.log('');

  // Health check.
  const health = await httpGet('/health');
  if (!health.ok) fatal(`L1 not reachable (status=${health.status})`);
  console.log('  ✓ L1 reachable');

  // Load credential.
  const cred = await loadCredential();
  const privKey = parseCredential(cred);

  const legacyDerived = deriveLegacyAnetAddressFromPrivKey(privKey);
  const secpDerived = deriveSecpAnetAddress(privKey);
  const legacy = String(ARGS.legacy || legacyDerived).trim().toUpperCase();
  const secp = String(ARGS.secp || secpDerived).trim().toUpperCase();

  console.log(`  derived legacy : ${legacyDerived}`);
  console.log(`  derived secp   : ${secpDerived}`);
  if (legacy !== legacyDerived) {
    fatal(`--legacy override (${legacy}) does not match derived (${legacyDerived})`);
  }
  if (secp !== secpDerived) {
    fatal(`--secp override (${secp}) does not match derived (${secpDerived})`);
  }

  // Check balance.
  const acctLegacy = await httpGet(`/accounts/${legacy}`);
  if (acctLegacy.ok) {
    console.log(`  legacy balance : ${acctLegacy.body.anet_balance} ANET  (${acctLegacy.body.ants_balance} ants, ${acctLegacy.body.sessions} sessions)`);
  } else {
    console.log(`  legacy balance : (account not found on chain)`);
  }
  const acctSecp = await httpGet(`/accounts/${secp}`);
  if (acctSecp.ok) {
    console.log(`  secp balance   : ${acctSecp.body.anet_balance} ANET  (${acctSecp.body.ants_balance} ants, ${acctSecp.body.sessions} sessions)`);
  } else {
    console.log(`  secp balance   : (account does not exist yet)`);
  }

  // Existing migration check.
  const existing = await httpGet(`/wallet/migrate-legacy/${legacy}`);
  let nonce;
  let commitHash;
  let priorCommitExists = false;
  if (existing.ok) {
    priorCommitExists = true;
    console.log(`  existing       : status=${existing.body.status} secp=${existing.body.secp_address}`);
    if (existing.body.status === 'revealed') {
      console.log('  → already migrated, nothing to do.');
      process.exit(0);
    }
    if (existing.body.secp_address !== secp) {
      fatal(`prior commit was for secp=${existing.body.secp_address}, refusing to continue with secp=${secp}`);
    }
  }

  // ---- Phase 1: COMMIT ----
  if (!REVEAL_ONLY && !priorCommitExists) {
    // Use crypto-strong 48-bit random nonce so it stays within Number.MAX_SAFE_INTEGER
    // (JSON has no native uint64 — server deserializes via serde as u64).
    nonce = BigInt('0x' + randomBytes(6).toString('hex'));
    const privHex = Buffer.from(privKey).toString('hex');
    const preimage = `${privHex}:${secp}:${nonce}`;
    commitHash = sha256(Buffer.from(preimage, 'utf8')).toString('hex');

    console.log('');
    console.log('  PHASE 1 — COMMIT');
    console.log(`    legacy_address : ${legacy}`);
    console.log(`    secp_address   : ${secp}`);
    console.log(`    nonce          : ${nonce}`);
    console.log(`    commit_hash    : ${commitHash}`);
    const yn = await prompt('\n  proceed with commit? type "yes" to continue: ');
    if (yn.trim().toLowerCase() !== 'yes') {
      console.log('  aborted by user.');
      process.exit(0);
    }

    const auth = signActionAuth({ privKey, wallet: secp, actionType: 'migrate_commit' });
    const commitRes = await httpPost('/wallet/migrate-legacy/commit', {
      legacy_address: legacy,
      secp_address: secp,
      commit_hash: commitHash,
      auth,
    });
    if (!commitRes.ok) {
      fatal(`commit failed (HTTP ${commitRes.status}): ${JSON.stringify(commitRes.body)}`);
    }
    console.log(`  ✓ commit accepted at ${commitRes.body.committed_at}`);

    // Persist nonce/secp for the reveal step in case the process dies.
    // We never persist privkey; the user already has it in their secure file.
    console.log('');
    console.log(`  → keep this nonce somewhere safe (you'll need it for the reveal):`);
    console.log(`      MIGRATION_NONCE=${nonce}`);
  } else if (REVEAL_ONLY) {
    if (!ARGS.nonce) {
      fatal('--reveal-only requires --nonce <value> from the prior commit');
    }
    nonce = BigInt(ARGS.nonce);
    const privHex = Buffer.from(privKey).toString('hex');
    commitHash = sha256(Buffer.from(`${privHex}:${secp}:${nonce}`, 'utf8')).toString('hex');
  } else {
    // Prior commit exists — must use its nonce (caller must supply via --nonce).
    if (!ARGS.nonce) {
      fatal('a prior commit exists for this legacy address — supply --nonce to continue, or delete the row from the DB');
    }
    nonce = BigInt(ARGS.nonce);
  }

  if (COMMIT_ONLY) {
    console.log('  --commit-only: stopping here.');
    process.exit(0);
  }

  // ---- Phase 2: REVEAL ----
  console.log('');
  console.log('  PHASE 2 — REVEAL (this submits the privkey hex to L1)');
  console.log(`    legacy_address : ${legacy}`);
  console.log(`    secp_address   : ${secp}`);
  console.log(`    nonce          : ${nonce}`);
  const yn2 = await prompt('\n  proceed with reveal? type "yes" to continue: ');
  if (yn2.trim().toLowerCase() !== 'yes') {
    console.log('  aborted by user.');
    process.exit(0);
  }

  const auth2 = signActionAuth({ privKey, wallet: secp, actionType: 'migrate_reveal' });
  const revealRes = await httpPost('/wallet/migrate-legacy/reveal', {
    legacy_address: legacy,
    secp_address: secp,
    privkey_hex: Buffer.from(privKey).toString('hex'),
    nonce: Number(nonce), // server accepts u64 via serde; nonce fits 53-bit safely for ts-based values
    auth: auth2,
  });
  if (!revealRes.ok) {
    fatal(`reveal failed (HTTP ${revealRes.status}): ${JSON.stringify(revealRes.body)}`);
  }
  console.log('  ✓ migration completed!');
  console.log(`    ants migrated       : ${revealRes.body.ants_migrated}`);
  console.log(`    sessions migrated   : ${revealRes.body.sessions_migrated}`);
  console.log(`    new secp ants bal   : ${revealRes.body.new_secp_ants_balance}`);
  console.log('');
  console.log('  Your balance is now under the secp wallet. You can:');
  console.log(`    • bridge-burn from ${secp}`);
  console.log(`    • use the Flutter wallet (will display ${secp} once the app re-derives)`);
}

main().catch((e) => {
  process.stderr.write(`fatal: ${e?.stack || e}\n`);
  process.exit(1);
});
