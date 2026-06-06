import { ethers } from 'ethers';
const RPC = 'https://bsc-dataseed1.binance.org/';
const VAULT = '0x31438362a7667ce5559500023D025c7c14168B49';
const provider = new ethers.JsonRpcProvider(RPC);

async function tryCall(label, sig, args = []) {
  try {
    const c = new ethers.Contract(VAULT, [`function ${sig}`], provider);
    const fn = sig.split('(')[0].trim();
    const r = await c[fn](...args);
    console.log(`  ${label.padEnd(22)} ✓ ${r}`);
    return r;
  } catch (e) {
    console.log(`  ${label.padEnd(22)} ✗ ${e.shortMessage || e.message}`);
    return null;
  }
}

console.log('probing', VAULT);
const code = await provider.getCode(VAULT);
console.log('  bytecode size       :', (code.length - 2) / 2, 'bytes');
await tryCall('DOMAIN_SEPARATOR', 'DOMAIN_SEPARATOR() view returns (bytes32)');
await tryCall('threshold', 'threshold() view returns (uint256)');
await tryCall('signers', 'signers() view returns (address[])');
await tryCall('paused', 'paused() view returns (bool)');
await tryCall('token', 'token() view returns (address)');
await tryCall('wAnetToken', 'wAnetToken() view returns (address)');
await tryCall('anetToken', 'anetToken() view returns (address)');
await tryCall('maxPerTx', 'maxPerTx() view returns (uint256)');
await tryCall('vaultBalance', 'vaultBalance() view returns (uint256)');
await tryCall('burnIdConsumed(1)', 'burnIdConsumed(uint256) view returns (bool)', [1n]);
await tryCall('owner', 'owner() view returns (address)');
