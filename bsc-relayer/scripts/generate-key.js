// Generate a cryptographically strong shared secret for the relayer ↔ L1
// admin channel. The same string is pasted into:
//   - L1 server env: ANET_DEX_ADMIN_KEY
//   - Relayer env:   ANET_DEX_ADMIN_KEY
//
// Treat the output like a root password. Never commit it. Rotate by
// re-running this script and updating both env values in lock-step.

import { randomBytes } from 'node:crypto';

const bytes = randomBytes(48);                  // 384 bits of entropy
const key   = bytes.toString('base64url');      // URL-safe, no padding

console.log('');
console.log('═══════════════════════════════════════════════════════════════════');
console.log(' ANET BRIDGE ADMIN KEY — copy this value into BOTH places below.');
console.log('═══════════════════════════════════════════════════════════════════');
console.log('');
console.log(`  ANET_DEX_ADMIN_KEY=${key}`);
console.log('');
console.log('Paste it into:');
console.log('  1. Render env vars for the L1 chain service');
console.log('     (anet-private-mainnet.onrender.com).');
console.log('     Also set ANET_BRIDGE_MINT_ENABLED=true on that service.');
console.log('  2. Render env vars for the bsc-relayer worker service.');
console.log('');
console.log('After both are updated, restart both services so they pick up');
console.log('the new value. Anyone with this key can mint ANET — keep it');
console.log('out of git, logs, screenshots, and chat history.');
console.log('═══════════════════════════════════════════════════════════════════');
console.log('');
