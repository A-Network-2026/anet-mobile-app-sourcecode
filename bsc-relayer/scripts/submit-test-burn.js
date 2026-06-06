#!/usr/bin/env node
/**
 * submit-test-burn.js
 *
 * End-to-end test of the AnetBridgeVault decentralized bridge pipeline:
 *
 *   1. Locally derive the ANET native wallet key from your seed phrase
 *      (NEVER sent over the network; never logged)
 *   2. Build a SignedActionAuthorization for `action_type = "bridge_burn"`
 *      using the exact canonical encoding used by the Flutter wallet
 *      (`lib/main.dart` → _buildSignedActionAuth)
 *   3. POST /bridge/burn to the L1 chain → server queues the burn,
 *      assigns an id, computes the canonical EIP-712 digest
 *   4. Poll /bridge/burns/:id until status moves through
 *      pending → signed → released (or failed)
 *
 * USAGE (do not put the seed on the command line!):
 *
 *   # Option 1 — env var
 *   SEED_PHRASE="word1 word2 ... word12" \
 *   node scripts/submit-test-burn.js \
 *     --bsc-recipient 0xa0C26B4C802d3C0682ee4BB2bDC3d7989256b8ce \
 *     --amount 1
 *
 *   # Option 2 — local file (recommended: chmod 600, delete after)
 *   echo "word1 word2 ... word12" > /tmp/anet.seed && chmod 600 /tmp/anet.seed
 *   SEED_PHRASE_FILE=/tmp/anet.seed \
 *   node scripts/submit-test-burn.js \
 *     --bsc-recipient 0xa0C26B4C802d3C0682ee4BB2bDC3d7989256b8ce \
 *     --amount 1
 *   shred -u /tmp/anet.seed   # or: rm -P /tmp/anet.seed
 *
 *   # Option 3 — interactive (typed, not echoed)
 *   node scripts/submit-test-burn.js --bsc-recipient 0x... --amount 1
 *
 * Optional flags:
 *   --l1            L1 base URL (default https://anet-private-mainnet.onrender.com)
 *   --token         Token symbol on BSC (default ANET = wANET)
 *   --no-poll       Submit only, do not poll for status
 *   --poll-interval Seconds between status polls (default 15)
 *   --poll-max      Maximum poll attempts before giving up (default 40 → 10 min)
 *
 * SAFETY:
 *   - The seed phrase only lives in process memory long enough to derive
 *     the private key, then is overwritten.
 *   - The script will NOT proceed without explicit confirmation typed
 *     by the user (you).
 *   - This script never writes the seed to disk or logs.
 */

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createInterface } from 'node:readline';
import { stdin as input, stdout as output } from 'node:process';

import { SigningKey, hexlify } from 'ethers';

// ── Constants (must match anet-chain + Flutter wallet) ──────────────────────
const ANET_CHAIN_ID = 'anet-private-mainnet-1';
const ANTS_PER_ANET = 100_000_000n; // 1 ANET = 10^8 ants (BTC-like)
const DEFAULT_L1 = 'https://anet-private-mainnet.onrender.com';
const DEFAULT_TOKEN = 'ANET';
const TERMINAL_STATUSES = new Set(['released', 'failed', 'cancelled']);

// ── CLI parsing ─────────────────────────────────────────────────────────────

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

if (ARGS.help || ARGS.h) {
  console.log(
    'usage: node scripts/submit-test-burn.js --bsc-recipient 0x... --amount <ANET>'
  );
  process.exit(0);
}

const BSC_RECIPIENT = String(ARGS['bsc-recipient'] || '').trim();
const AMOUNT_ANET_RAW = String(ARGS.amount || '').trim();
const L1_BASE = String(ARGS.l1 || DEFAULT_L1).replace(/\/+$/, '');
const TOKEN = String(ARGS.token || DEFAULT_TOKEN).toUpperCase();
const NO_POLL = Boolean(ARGS['no-poll']);
const POLL_INTERVAL_SEC = Number(ARGS['poll-interval'] || 15);
const POLL_MAX = Number(ARGS['poll-max'] || 40);

if (!/^0x[0-9a-fA-F]{40}$/.test(BSC_RECIPIENT)) {
  fatal(`--bsc-recipient is required and must be a valid 0x-address (got ${JSON.stringify(BSC_RECIPIENT)})`);
}

const AMOUNT_ANTS = parseAnetToAnts(AMOUNT_ANET_RAW);
if (AMOUNT_ANTS === null || AMOUNT_ANTS <= 0n) {
  fatal(`--amount must be a positive ANET value with at most 8 decimal places (got ${JSON.stringify(AMOUNT_ANET_RAW)})`);
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function fatal(msg) {
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}

function parseAnetToAnts(text) {
  const m = /^(\d+)(?:\.(\d{1,8}))?$/.exec(text);
  if (!m) return null;
  const whole = BigInt(m[1]);
  const fracRaw = m[2] || '';
  const frac = fracRaw === '' ? 0n : BigInt(fracRaw.padEnd(8, '0'));
  return whole * ANTS_PER_ANET + frac;
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest();
}

function ripemd160(bytes) {
  return createHash('ripemd160').update(bytes).digest();
}

function bigIntTo32(buf) {
  // Already a Buffer — pad/trim to 32 bytes left-padded.
  if (buf.length === 32) return buf;
  if (buf.length > 32) return buf.subarray(buf.length - 32);
  const out = Buffer.alloc(32);
  buf.copy(out, 32 - buf.length);
  return out;
}

function compressPubKey(uncompressed65) {
  // uncompressed65 = [0x04, X(32), Y(32)]
  if (uncompressed65.length !== 65 || uncompressed65[0] !== 0x04) {
    throw new Error('compressPubKey: expected 65-byte 0x04-prefixed key');
  }
  const x = uncompressed65.subarray(1, 33);
  const y = uncompressed65.subarray(33, 65);
  const prefix = (y[31] & 1) === 0 ? 0x02 : 0x03;
  return Buffer.concat([Buffer.from([prefix]), x]);
}

function deriveAnetWalletFromPrivKey(privKey) {
  // ANET native (secp) wallet:
  //   compressed_pubkey → ripemd160 → hex_upper → first 36 chars → ANET + hash
  const pubKeyUncompressed = Buffer.from(
    SigningKey.computePublicKey(hexlify(privKey), false).slice(2),
    'hex'
  );
  const compressed = compressPubKey(pubKeyUncompressed);
  const ripe = ripemd160(compressed);
  const hashHex = ripe.toString('hex').toUpperCase();
  return `ANET${hashHex.slice(0, 36)}`;
}

function deriveLegacyAnetWalletFromSeed(seed) {
  // Legacy variant (matches Flutter _deriveLegacyAnetWalletFromSeed)
  const privHex = sha256(Buffer.from(seed.trim(), 'utf8')).toString('hex');
  const pubHex = sha256(Buffer.from(privHex, 'utf8')).toString('hex');
  const ripe = ripemd160(Buffer.from(pubHex, 'utf8'));
  const hashHex = ripe.toString('hex').toUpperCase();
  return `ANET${hashHex.slice(0, 36)}`;
}

function canonicalPayload(payload) {
  const keys = Object.keys(payload).sort();
  const ordered = {};
  for (const k of keys) ordered[k] = payload[k];
  return JSON.stringify(ordered);
}

function recoverAnetWallet(hash, sigHex) {
  // Recover the ANET wallet from a 65-byte signature over the given hash,
  // mirroring what the L1 chain does (transaction.rs::recover_address_from_signature).
  const sigBytes = Buffer.from(sigHex, 'hex');
  if (sigBytes.length !== 65) throw new Error('signature must be 65 bytes');
  const r = sigBytes.subarray(0, 32);
  const s = sigBytes.subarray(32, 64);
  let v = sigBytes[64];
  if (v === 27 || v === 28) v = v - 27;
  // ethers Signature.from accepts yParity 0/1 in v field via { v: 27 + yParity }
  const ethersSig = {
    r: '0x' + r.toString('hex'),
    s: '0x' + s.toString('hex'),
    v: 27 + (v & 1),
  };
  const compressedPubHex = SigningKey.recoverPublicKey(hexlify(hash), ethersSig);
  // recoverPublicKey returns UNCOMPRESSED ('0x04...'); strip prefix and compress.
  const uncompressed = Buffer.from(compressedPubHex.slice(2), 'hex');
  const compressed = compressPubKey(uncompressed);
  const ripe = ripemd160(compressed);
  return 'ANET' + ripe.toString('hex').toUpperCase().slice(0, 36);
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
  // ethers v6 returns r/s as 0x-hex; v as recovery byte (27/28 or 0/1).
  // The L1 expects v as 0/1 (a "compact" recovery id).
  let v = sig.yParity ?? (sig.v === 27 ? 0 : sig.v === 28 ? 1 : sig.v);
  if (v === 27) v = 0;
  if (v === 28) v = 1;
  const r = bigIntTo32(Buffer.from(sig.r.slice(2), 'hex'));
  const s = bigIntTo32(Buffer.from(sig.s.slice(2), 'hex'));
  const sigBytes = Buffer.concat([r, s, Buffer.from([v])]);
  const signatureHex = sigBytes.toString('hex').toLowerCase();

  // ---- LOCAL SELF-VERIFICATION ----
  // Recover the ANET wallet from our own signature; if it doesn't match
  // `wallet`, we abort BEFORE hitting L1 (saves the burn).
  const recovered = recoverAnetWallet(hash, signatureHex);
  if (recovered !== wallet.toUpperCase()) {
    throw new Error(
      `local sig self-check FAILED: recovered=${recovered} expected=${wallet.toUpperCase()}\n` +
      `  preimage = ${preimage}\n` +
      `  hash     = ${actionHash}\n` +
      `  sig      = ${signatureHex}`
    );
  }

  return {
    wallet: wallet.toUpperCase(),
    nonce,
    timestamp: ts.toISOString(),
    chain_id: ANET_CHAIN_ID,
    payload,
    signature: signatureHex,
    action_hash: actionHash,
  };
}

// ── Seed phrase loading (zero leakage) ──────────────────────────────────────

async function loadSeedPhrase() {
  if (process.env.SEED_PHRASE) {
    return process.env.SEED_PHRASE.trim();
  }
  if (process.env.SEED_PHRASE_FILE) {
    const path = process.env.SEED_PHRASE_FILE;
    try {
      return readFileSync(path, 'utf8').trim();
    } catch (e) {
      fatal(`failed to read SEED_PHRASE_FILE=${path}: ${e.message}`);
    }
  }
  // Interactive — read from stdin, echo off.
  return new Promise((resolve) => {
    const rl = createInterface({ input, output, terminal: true });
    // Disable echo while typing.
    if (output.isTTY) {
      const onData = (char) => {
        const c = char.toString();
        if (c === '\u0003') process.exit(130); // Ctrl-C
        if (c === '\r' || c === '\n') {
          input.setRawMode(false);
          input.removeListener('data', onData);
          output.write('\n');
        } else if (c === '\u007f' || c === '\b') {
          // backspace — silently drop one char from the line buffer.
        }
      };
      input.setRawMode(true);
      input.on('data', onData);
    }
    output.write('seed phrase: ');
    rl.question('', (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// ── HTTP ───────────────────────────────────────────────────────────────────

async function httpJson(method, url, body) {
  const opts = {
    method,
    headers: { 'content-type': 'application/json' },
  };
  if (body !== undefined) opts.body = JSON.stringify(body);
  const res = await fetch(url, opts);
  const text = await res.text();
  let parsed;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }
  if (!res.ok) {
    const detail = typeof parsed === 'string' ? parsed : JSON.stringify(parsed);
    throw new Error(`${method} ${url} → ${res.status} ${detail}`);
  }
  return parsed;
}

// ── Main ───────────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('anet-bridge-burn  test submission');
  console.log('---------------------------------');
  console.log(`  L1 base URL    : ${L1_BASE}`);
  console.log(`  BSC recipient  : ${BSC_RECIPIENT}`);
  console.log(`  Amount         : ${AMOUNT_ANET_RAW} ANET  (${AMOUNT_ANTS} ants)`);
  console.log(`  Token symbol   : ${TOKEN}`);
  console.log(`  Chain ID       : ${ANET_CHAIN_ID}`);
  console.log('');

  // L1 health probe first — fail fast if backend is down.
  try {
    await httpJson('GET', `${L1_BASE}/health`);
  } catch (e) {
    fatal(`L1 health check failed: ${e.message}`);
  }
  console.log('  ✓ L1 reachable');

  const secret = await loadSeedPhrase();
  if (!secret) {
    fatal('no seed phrase / private key provided');
  }

  // Detect input mode:
  //   - "evmkey:0xHEX" or "evmkey:HEX"  → raw EVM private key (32 bytes)
  //   - "0xHEX..." (64-66 chars)        → raw EVM private key
  //   - else                            → BIP-39-style seed phrase (words)
  let privKey;
  let walletLegacy = null;
  let inputMode;
  const cleaned = secret.trim();
  const evmKeyMatch = /^(?:evmkey:)?(0x)?([0-9a-fA-F]{64})$/.exec(cleaned.replace(/\s+/g, ''));
  if (evmKeyMatch) {
    inputMode = 'evmkey';
    privKey = Buffer.from(evmKeyMatch[2], 'hex');
  } else {
    if (cleaned.split(/\s+/).length < 8) {
      fatal('input looks invalid (expected ≥8 seed words OR a 64-hex-char EVM private key)');
    }
    inputMode = 'seed';
    privKey = sha256(Buffer.from(cleaned, 'utf8'));
    walletLegacy = deriveLegacyAnetWalletFromSeed(cleaned);
  }

  const walletSecp = deriveAnetWalletFromPrivKey(privKey);
  console.log(`  input mode       : ${inputMode}`);
  console.log(`  derived (secp)   : ${walletSecp}`);
  if (walletLegacy) console.log(`  derived (legacy) : ${walletLegacy}`);

  // Ask user which wallet to use (must match what they hold ANET in).
  const wallet = await prompt(
    `\n  paste your L1 wallet address to confirm sender (must equal one of the above)\n  > `
  );
  const senderUpper = wallet.trim().toUpperCase();
  const candidates = [walletSecp.toUpperCase()];
  if (walletLegacy) candidates.push(walletLegacy.toUpperCase());
  if (!candidates.includes(senderUpper)) {
    fatal(`sender ${senderUpper} does not match any derivation (${candidates.join(', ')}). Wrong key?`);
  }
  if (walletLegacy && senderUpper === walletLegacy.toUpperCase()) {
    fatal(
      `sender matches legacy derivation, but the L1 chain only accepts secp signatures.\n` +
      `Your wallet ${senderUpper} cannot sign actions. Use the secp wallet ${walletSecp} instead, ` +
      `or transfer the balance via an admin endpoint.`
    );
  }
  console.log(`  ✓ sender confirmed: ${senderUpper}`);

  // Final dry-run confirmation.
  console.log('');
  console.log('  ABOUT TO BURN ON L1 (irreversible):');
  console.log(`    sender         ${senderUpper}`);
  console.log(`    amount_ants    ${AMOUNT_ANTS}  (${AMOUNT_ANET_RAW} ANET)`);
  console.log(`    bsc_recipient  ${BSC_RECIPIENT}`);
  console.log(`    token          ${TOKEN}`);
  const yn = await prompt('\n  proceed? type "yes" to continue: ');
  if (yn.trim().toLowerCase() !== 'yes') {
    console.log('  aborted by user.');
    process.exit(0);
  }

  // Build the action_auth.
  const auth = signActionAuth({
    privKey,
    wallet: senderUpper,
    actionType: 'bridge_burn',
  });

  // Zero out the seed in memory (best-effort, V8 may have copies).
  privKey.fill(0);

  // Submit the burn.
  const burnReq = {
    sender: senderUpper,
    bsc_recipient: BSC_RECIPIENT,
    amount_ants: Number(AMOUNT_ANTS), // u64 in Rust; fits in 53-bit safe int for small test
    token_symbol: TOKEN,
    auth,
  };
  console.log('\n  submitting burn …');
  let resp;
  try {
    resp = await httpJson('POST', `${L1_BASE}/bridge/burn`, burnReq);
  } catch (e) {
    fatal(`POST /bridge/burn failed: ${e.message}`);
  }
  console.log('  ✓ burn accepted by L1:');
  console.log(`    burn_id          : ${resp.burn_id}`);
  console.log(`    status           : ${resp.status}`);
  console.log(`    new ANET balance : ${resp.new_l1_anet_balance}`);
  console.log(`    created_at       : ${resp.created_at}`);

  if (NO_POLL) {
    console.log('\n  --no-poll set; exiting.');
    return;
  }

  // Poll status.
  console.log(`\n  polling /bridge/burns/${resp.burn_id} every ${POLL_INTERVAL_SEC}s (max ${POLL_MAX} times)…`);
  for (let i = 1; i <= POLL_MAX; i += 1) {
    await sleep(POLL_INTERVAL_SEC * 1000);
    let row;
    try {
      row = await httpJson('GET', `${L1_BASE}/bridge/burns/${resp.burn_id}`);
    } catch (e) {
      console.log(`    [#${i}] poll error: ${e.message}`);
      continue;
    }
    const sigsCount = Array.isArray(row.signatures) ? row.signatures.length : (row.sig_count ?? '?');
    console.log(`    [#${i}] status=${row.status}  sigs=${sigsCount}  bsc_tx=${row.bsc_tx_hash || '-'}`);
    if (TERMINAL_STATUSES.has(row.status)) {
      console.log('');
      if (row.status === 'released') {
        console.log('  🎉 BURN RELEASED ON BSC');
        console.log(`     bsc_tx_hash : ${row.bsc_tx_hash}`);
        console.log(`     view on bscscan: https://bscscan.com/tx/${row.bsc_tx_hash}`);
      } else {
        console.log(`  burn ended in terminal state: ${row.status}`);
        if (row.failure_reason) console.log(`  reason: ${row.failure_reason}`);
      }
      return;
    }
  }
  console.log('\n  poll budget exhausted; burn is still in-flight. Check manually with:');
  console.log(`    curl ${L1_BASE}/bridge/burns/${resp.burn_id}`);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function prompt(label) {
  return new Promise((resolve) => {
    const rl = createInterface({ input, output });
    rl.question(label, (a) => {
      rl.close();
      resolve(a);
    });
  });
}

main().catch((e) => fatal(e.stack || e.message || String(e)));
