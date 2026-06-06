# A-Network Profile Share Link Format

Date: 2026-05-14

## Canonical Public Web URL
Use this URL format for all profile sharing:

https://a-network.net/profile.html?wallet={WALLET_ADDRESS}

Example:

https://a-network.net/profile.html?wallet=ANET9EXAMPLE1234567890

## App Deep Link URL
Use this deep link format to open directly in the app:

anetwork://profile/{WALLET_ADDRESS}

## Notes
- Do not share placeholder values like {wallet} directly.
- Wallet address should be uppercase and at least 20 characters.
- The web page fetches public profile data from /wallet/nft/public/{wallet}.
- If a profile is locked, web shows locked state instead of 404.
