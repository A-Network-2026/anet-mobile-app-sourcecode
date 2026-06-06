/**
 * refund-usdt.js — one-off: pull stuck USDT out of the AnetSwap contract and
 * send it back to the depositor. Run ONCE for the stuck swap.
 *
 * SECURITY: your private key is read from the OWNER_PK environment variable that
 * YOU set in YOUR terminal. It is never written to disk and never printed.
 *
 * Usage (from this folder):
 *   export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
 *   cd /Users/joeldupalco/Downloads/anet-mobile-app/bsc-relayer
 *   OWNER_PK=YOUR_PRIVATE_KEY_HEX node scripts/refund-usdt.js
 *
 * To preview without sending, add DRY=1:
 *   OWNER_PK=... DRY=1 node scripts/refund-usdt.js
 */
import { ethers } from 'ethers';

// ── Fixed parameters for this refund ────────────────────────────────────────
const RPC          = 'https://bsc-dataseed.binance.org';
const SWAP         = '0x1A1AFE5BF1ffDB64aC10958cCe2D06B22Fb47Fb8'; // AnetSwap
const USDT         = '0x55d398326f99059fF775485246999027B3197955'; // BSC USDT (18 dec)
const USER         = '0xDF91a4ee172852e03aA964039Cce5fF718084259'; // refund recipient
const OWNER_EXPECT = '0x4F7219FB43289DFB58CEe363DED15CeD19670A91'; // contract owner
const AMOUNT_WEI   = 9890100000000000000n;                         // 9.8901 USDT

const SWAP_ABI = ['function withdrawToken(address token, uint256 amount) external'];
const ERC20_ABI = [
  'function balanceOf(address) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
];

async function main() {
  const pk = (process.env.OWNER_PK || '').trim();
  if (!pk) { console.error('ERROR: set OWNER_PK=<your private key> in your terminal.'); process.exit(1); }
  const dry = process.env.DRY === '1';

  const provider = new ethers.JsonRpcProvider(RPC);
  const wallet = new ethers.Wallet(pk.startsWith('0x') ? pk : '0x' + pk, provider);

  console.log('Signer address :', wallet.address);
  if (wallet.address.toLowerCase() !== OWNER_EXPECT.toLowerCase()) {
    console.error(`ERROR: this key is NOT the contract owner (${OWNER_EXPECT}). Aborting.`);
    process.exit(1);
  }

  const usdt = new ethers.Contract(USDT, ERC20_ABI, wallet);
  const swap = new ethers.Contract(SWAP, SWAP_ABI, wallet);

  const bnb = await provider.getBalance(wallet.address);
  const contractUsdt = await usdt.balanceOf(SWAP);
  const ownerUsdtBefore = await usdt.balanceOf(wallet.address);
  console.log('Owner BNB (gas):', ethers.formatEther(bnb));
  console.log('Contract USDT  :', ethers.formatUnits(contractUsdt, 18));
  console.log('Owner USDT     :', ethers.formatUnits(ownerUsdtBefore, 18));
  console.log('Refund amount  :', ethers.formatUnits(AMOUNT_WEI, 18), 'USDT  ->', USER);

  if (contractUsdt < AMOUNT_WEI) {
    console.error('ERROR: contract holds less USDT than the refund amount. Aborting.');
    process.exit(1);
  }
  if (dry) { console.log('\nDRY run — nothing sent. Re-run without DRY=1 to execute.'); return; }

  // Step 1 — withdraw stuck USDT from the contract to the owner wallet.
  console.log('\n[1/2] withdrawToken ...');
  const tx1 = await swap.withdrawToken(USDT, AMOUNT_WEI);
  console.log('  tx:', tx1.hash);
  await tx1.wait();
  console.log('  confirmed.');

  // Step 2 — forward the USDT from the owner wallet to the depositor.
  console.log('[2/2] transfer to user ...');
  const tx2 = await usdt.transfer(USER, AMOUNT_WEI);
  console.log('  tx:', tx2.hash);
  await tx2.wait();
  console.log('  confirmed.');

  const ownerUsdtAfter = await usdt.balanceOf(wallet.address);
  const userUsdt = await usdt.balanceOf(USER);
  console.log('\nDONE.');
  console.log('Owner USDT now :', ethers.formatUnits(ownerUsdtAfter, 18));
  console.log('User  USDT now :', ethers.formatUnits(userUsdt, 18));
  console.log('Refund tx (to user):', tx2.hash);
}

main().catch((e) => { console.error('FAILED:', e.message || e); process.exit(1); });
