#!/usr/bin/env node
/**
 * check-vault-eip712.js — Standalone digest verifier for AnetBridgeVault.
 *
 * Purpose
 *   Before submitting a real release, prove that the relayer and the on-chain
 *   vault agree on the EIP-712 domain separator and the typed-data digest for
 *   a given Release. If they disagree, every signature this relayer produces
 *   will be rejected by the vault.
 *
 * Usage
 *   node scripts/check-vault-eip712.js \
 *     --vault   0xYourVaultAddress \
 *     --chainId 56 \
 *     --rpc     https://bsc-dataseed1.binance.org/ \
 *     [--burnId 1] [--sender ANET1xxx] [--recipient 0xabc...] \
 *     [--amount 1000] [--deadline <unix>]
 *
 * Exit code 0 ⇔ domain separator + digest match. Non-zero on any mismatch.
 */

import { ethers } from 'ethers';

const VAULT_ABI = [
  'function DOMAIN_SEPARATOR() view returns (bytes32)',
  'function threshold() view returns (uint256)',
  'function signers() view returns (address[])',
];

const RELEASE_TYPES = {
  Release: [
    { name: 'burnId',    type: 'uint256' },
    { name: 'l1Sender',  type: 'string'  },
    { name: 'recipient', type: 'address' },
    { name: 'amount',    type: 'uint256' },
    { name: 'deadline',  type: 'uint256' },
  ],
};

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return fallback;
}

async function main() {
  const vaultAddr = arg('vault');
  const chainId   = Number(arg('chainId', '56'));
  const rpc       = arg('rpc', 'https://bsc-dataseed1.binance.org/');

  if (!vaultAddr) {
    console.error('Missing --vault <address>');
    process.exit(2);
  }

  const provider = new ethers.JsonRpcProvider(rpc);
  const net      = await provider.getNetwork();
  if (Number(net.chainId) !== chainId) {
    console.error(`RPC reports chainId ${net.chainId} but --chainId is ${chainId}`);
    process.exit(2);
  }

  const vault = new ethers.Contract(vaultAddr, VAULT_ABI, provider);

  const domain = {
    name:              'AnetBridgeVault',
    version:           '1',
    chainId,
    verifyingContract: ethers.getAddress(vaultAddr),
  };

  // ── 1) Domain separator ─────────────────────────────────────────────────
  const onchain  = (await vault.DOMAIN_SEPARATOR()).toLowerCase();
  const computed = ethers.TypedDataEncoder.hashDomain(domain).toLowerCase();
  console.log('Vault       :', vaultAddr);
  console.log('Chain id    :', chainId);
  console.log('On-chain DS :', onchain);
  console.log('Computed DS :', computed);
  if (onchain !== computed) {
    console.error('❌ DOMAIN_SEPARATOR mismatch — relayer signatures will be rejected.');
    process.exit(1);
  }
  console.log('✓ domain separator matches');

  // ── 2) Sample digest for a Release ──────────────────────────────────────
  const message = {
    burnId:    BigInt(arg('burnId',    '1')),
    l1Sender:  arg('sender',           'ANET1examplexxxxxxxxxxxxxxxxxxxxxxxxx'),
    recipient: ethers.getAddress(arg('recipient', '0x000000000000000000000000000000000000dEaD')),
    amount:    ethers.parseEther(arg('amount',    '1000')),
    deadline:  BigInt(arg('deadline', String(Math.floor(Date.now() / 1000) + 3600))),
  };
  const digest = ethers.TypedDataEncoder.hash(domain, RELEASE_TYPES, message);
  console.log('\nSample Release message:');
  console.log('  burnId    :', message.burnId.toString());
  console.log('  l1Sender  :', message.l1Sender);
  console.log('  recipient :', message.recipient);
  console.log('  amount    :', message.amount.toString(), 'wei');
  console.log('  deadline  :', message.deadline.toString());
  console.log('Typed-data digest :', digest);

  // ── 3) Vault config snapshot ────────────────────────────────────────────
  const threshold    = await vault.threshold();
  const signers      = await vault.signers();
  console.log('\nVault signer set:');
  console.log('  threshold :', threshold.toString(), 'of', signers.length);
  for (const s of signers) console.log('   ', s);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
