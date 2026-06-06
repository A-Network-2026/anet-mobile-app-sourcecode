#!/usr/bin/env node
// Generates a fresh BSC escrow wallet for the L1 → BSC bridge.
//
//   node scripts/generate-escrow-wallet.js
//
// PRINT-ONLY (never written to disk). Copy the privateKey into Render's
// BSC_ESCROW_PRIVATE_KEY env var, then fund the printed address with wANET
// (and a small amount of BNB for gas) before flipping BRIDGE_BURN_ENABLED=true.

import { ethers } from 'ethers';

const wallet = ethers.Wallet.createRandom();

console.log('───────────────────────────────────────────────────────────────');
console.log(' ANET bridge — new BSC escrow wallet');
console.log('───────────────────────────────────────────────────────────────');
console.log(`  address:      ${wallet.address}`);
console.log(`  privateKey:   ${wallet.privateKey}`);
console.log(`  mnemonic:     ${wallet.mnemonic?.phrase ?? '(none — random key)'}`);
console.log('───────────────────────────────────────────────────────────────');
console.log(' Next steps:');
console.log('  1. Set BSC_ESCROW_PRIVATE_KEY on the relayer service (Render).');
console.log('  2. Send wANET (BEP-20 ANET, contract 0x791055A7...E46A) to the');
console.log('     address above — this is the inventory the bridge releases.');
console.log('  3. Send a small amount of BNB (~0.05) to the address for gas.');
console.log('  4. Set BRIDGE_BURN_ENABLED=true and redeploy.');
console.log('───────────────────────────────────────────────────────────────');
console.log(' WARNING: this private key controls bridge funds. Do NOT commit');
console.log(' it to git, do NOT paste it in chat, do NOT email it. Only enter');
console.log(' it into Render env vars (sync=false) or a hardware vault.');
console.log('───────────────────────────────────────────────────────────────');
