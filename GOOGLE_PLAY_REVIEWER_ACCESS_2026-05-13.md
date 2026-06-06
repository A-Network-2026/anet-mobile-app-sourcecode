# Google Play Reviewer Access (Production)

Date: 2026-05-13
App: A-Network
Build: Fill before submission (versionName/versionCode)

## 1) Reviewer Login

- Login URL: In-app login screen
- Reviewer email: <ADD_REVIEWER_EMAIL>
- Reviewer password: <ADD_REVIEWER_PASSWORD>
- OTP delivery: <EMAIL/IN-APP>
- OTP fallback: <BACKUP CODE OR SUPPORT CONTACT>

## 2) Core Reviewer Test Paths

### Path A: Wallet + Send

1. Open Wallet tab.
2. Confirm wallet status badge and balance.
3. Tap Send/Withdraw.
4. Expected behavior:
   - Upgraded wallet (`walletScheme=secp256k1_v2`): transfer intent validates and signed submit flow proceeds.
   - Legacy wallet (`walletScheme=legacy_hash_v1`): clear migration warning is shown (no silent failure).

### Path B: NFT Studio

1. Open Wallet tab.
2. Tap NFT action.
3. Fill Title + Description (+ optional Image URL).
4. Tap Mint.
5. Expected behavior:
   - Mint request accepted.
   - NFT appears in user NFT list.
   - Backend records on-chain activity (`onchain_status=accepted` when L1 call succeeds).

### Path C: Claim Gate

1. Open Wallet tab.
2. Tap Claim.
3. Expected behavior:
   - User with <1000 sessions receives progress gate message.
   - Eligible user can claim and balance refreshes.

## 3) Environment / Endpoint Notes

- API base URL: https://api.a-network.net
- L1 base URL: https://anet-private-mainnet.onrender.com
- Required backend env: `ANET_L1_URL=https://anet-private-mainnet.onrender.com`
- Required app build define: `--dart-define=L1_BASE_URL=https://anet-private-mainnet.onrender.com`

## 4) Known Reviewer Notes

- Some legacy wallets are intentionally blocked from direct L1 signed send until migration path is completed. This is a safety behavior to prevent failing transactions.
- NFT minting is native in-app and also records activity to L1 via backend route.

## 5) Support During Review

- Reviewer support email: info@a-network.net
- Escalation contact: <ADD_ESCALATION_CONTACT>
- SLA: <ADD_RESPONSE_WINDOW>
