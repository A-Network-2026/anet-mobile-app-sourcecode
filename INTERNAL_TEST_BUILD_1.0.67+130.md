# Internal Test Build — v1.0.67+130

**Date:** 2026-05-28
**Tracks:**
- Google Play Internal Testing (Android AAB)
- Apple TestFlight Internal Testing (iOS IPA)

**Scope:** Wallet seed-reveal fix + Unity Ads SDK integration (build-flag gated)

---

## What's in this build

1. **Seed-reveal fix** (originally 1.0.64+127)
   - Imported wallets (`evmkey:` prefix) now show their private key correctly
   - Clearer empty-state message when no backup exists

2. **Unity Ads SDK** — Interstitial only, gated by `--dart-define=ENABLE_ADS=true`
   - Production builds (no flag): SDK is dead code, no init, no ads
   - Internal-test builds:
     - "Test Ad" button in Settings → Wallet Management
     - Orange "INTERNAL TEST · ADS" ribbon top-right on every screen
   - Frequency cap: 5 minutes between impressions
   - **Android Game ID**: `800001547` (configured)
   - **iOS Game ID**: `PENDING_IOS_GAME_ID` (placeholder)

   > **iOS note**: Unity dashboard currently has only the Android platform.
   > The iOS build still ships safely (orange ribbon shows, Test Ad button shows),
   > but tapping Test Ad will skip with snackbar "Ad skipped" and log:
   > `[UnityAds] skip init: Game ID not configured for iOS`.
   >
   > To enable iOS ads: Unity dashboard → Project Settings → Platforms → Add iOS.
   > Then replace `PENDING_IOS_GAME_ID` in
   > [my_app/lib/ads/unity_ads_service.dart](my_app/lib/ads/unity_ads_service.dart),
   > rebuild and re-upload.

---

# ═══════════════════════════════════════════════════════════
# ANDROID — Google Play Internal Testing
# ═══════════════════════════════════════════════════════════

## Build (already done — 2026-05-28)

```bash
cd /Users/joeldupalco/Downloads/anet-mobile-app/my_app

flutter build appbundle \
  --release \
  --dart-define=ENABLE_ADS=true \
  --build-name=1.0.67 \
  --build-number=130
```

**Output:** `build/app/outputs/bundle/release/app-release.aab` (64.4 MB)

## Upload (Play Console)

1. https://play.google.com/console → **A Network**
2. Sidebar → **Test and release → Testing → Internal testing**
3. **Create new release** → drag in `app-release.aab`
4. Release name: `1.0.67 internal-ads-test`
5. Release notes (paste):

   ```
   Internal testing build — DO NOT promote to production.

   - Fix: seed-phrase reveal handles imported (private-key) wallets correctly
   - Fix: clearer empty-state message when no backup exists
   - NEW (internal only): Unity Ads SDK
     - "Test Ad" button in Settings → Wallet Management
     - Orange "INTERNAL TEST · ADS" ribbon on every screen
   ```

6. **Save → Review → Start rollout to Internal testing**

## Testers (Play Console)

- Internal testing → **Testers** tab → **Create email list**
- Add up to 100 emails
- Copy opt-in URL → send to testers
- Testers click → "Become a tester" → install update
- 5–15 min wait after upload before install is available

---

# ═══════════════════════════════════════════════════════════
# iOS — TestFlight Internal Testing
# ═══════════════════════════════════════════════════════════

## Build (already done — 2026-05-28)

```bash
cd /Users/joeldupalco/Downloads/anet-mobile-app/my_app

cd ios && pod install && cd ..

flutter build ipa \
  --release \
  --dart-define=ENABLE_ADS=true \
  --build-name=1.0.67 \
  --build-number=130
```

**Outputs:**
- `build/ios/ipa/A Network.ipa` — signed IPA for TestFlight
- `build/ios/archive/Runner.xcarchive` — archive (Xcode Organizer entry point)

If `flutter build ipa` fails on signing:

```bash
open ios/Runner.xcworkspace
```

Then in Xcode: **Runner target → Signing & Capabilities** → Team = `khurram zahid` → Automatically manage signing **ON**. Close Xcode, re-run the build.

## Upload (TestFlight — pick ONE method)

### Method A — Transporter app (simplest)

1. Open **Transporter.app** (Mac App Store if missing)
2. Sign in with your App Store Connect Apple ID
3. Drag `build/ios/ipa/A Network.ipa` into Transporter
4. Click **Deliver** → wait for "Delivered" (1–5 min)
5. https://appstoreconnect.apple.com → **A Network** → **TestFlight**
6. Wait for build status to flip from "Processing" → ✓ **Complete** (5–30 min, you'll get an email)

### Method B — Xcode Organizer

```bash
open build/ios/archive/Runner.xcarchive
```

In Organizer: **Distribute App → App Store Connect → Upload** → follow prompts.

## Add to internal testers (TestFlight)

1. App Store Connect → A Network → **TestFlight**
2. Wait until build `1.0.67 (130)` status = ✓ **Complete**
3. Click the build → answer **Export Compliance**:
   - "Does your app use encryption?" → Yes
   - "Only standard / exempt encryption (HTTPS, etc.)?" → Yes
   - Submit. Auto-approved in minutes.
4. Sidebar → **Internal Testing → A Network Testers**
5. Click **+** next to Builds → select `1.0.67 (130)` → **Add**
6. Testers receive TestFlight email + push, install via TestFlight app
7. Up to 100 internal testers, NO Apple review needed

## iOS-specific tester experience

- First launch with ads flag on triggers the iOS **App Tracking Transparency** dialog:
  > "Allow tracking so we can show test ads during internal testing. Personal data is not shared."
- Either choice is fine — Unity will still serve ads (less precise targeting without)
- Orange "INTERNAL TEST · ADS" ribbon top-right on every screen
- Test Ad button:
  - **Until iOS Game ID is filled in**: tapping shows "Ad skipped" snackbar (expected)
  - **After iOS Game ID is set**: Unity Interstitial appears

---

## Cross-platform QA checklist

- [ ] Orange "INTERNAL TEST · ADS" ribbon visible top-right on every screen
- [ ] Sign in works normally (no regression)
- [ ] Settings/More → Wallet Management → "Test Ad" button present
- [ ] Tap Test Ad:
  - Android: Unity Interstitial within 5–10s
  - iOS (pending iOS Game ID): "Ad skipped" snackbar
- [ ] Tap again within 5 min → "frequency capped" snackbar
- [ ] Wait > 5 min, tap again → another ad (Android)
- [ ] Settings → Seed Phrase → enter PIN:
  - Seed wallet: 12 words display correctly
  - Imported wallet: shows private key with imported-wallet warning
  - No backup: shows helpful empty-state, not bare "No seed phrase found"
- [ ] No crashes when closing/dismissing ads
- [ ] No UI overflow on small devices (test on iPhone SE / 5" Android)

---

## Rollback

Production (Play Store v1.0.18 → 45K users; App Store v1.0.65 live) stays untouched.

- **Play Console**: Internal testing → Releases overview → **Halt rollout**
- **TestFlight**: TestFlight tab → expire build (set expiration date to today)

Blast radius: ≤100 testers per platform.

---

## Promoting fixes to production

Build separately **WITHOUT** the ads flag (bump build number):

```bash
flutter build appbundle --release --build-name=1.0.67 --build-number=131
flutter build ipa --release --build-name=1.0.67 --build-number=131
```

Upload Android to Play **Production**; upload iOS to App Store Connect, submit for review. The Unity SDK is tree-shaken out of these builds at compile time.

---

## Files changed

- [my_app/pubspec.yaml](my_app/pubspec.yaml) — `unity_ads_plugin: ^0.3.16`, version `1.0.67+130`
- [my_app/lib/ads/unity_ads_service.dart](my_app/lib/ads/unity_ads_service.dart) — NEW, platform-aware gated wrapper
- [my_app/lib/main.dart](my_app/lib/main.dart) — import + init + Test Ad button + ribbon
- [my_app/ios/Runner/Info.plist](my_app/ios/Runner/Info.plist) — ATT description + Unity SKAdNetworkItems

---

## Decision log

| Decision | Rationale |
|---|---|
| Build-time flag (not runtime) | Tree-shakes Unity SDK from production binaries; scanners see no ad code |
| `testMode = true` initially | Confirm wire-up before real eCPM payouts |
| Test Ad button only (no swap-success hook) | Prove SDK works first; wire real triggers next iteration |
| Orange banner on every screen | Cannot mistake test build for production |
| Interstitial only (no Banner/Rewarded) | Banner kills trust on finance app; Rewarded has no wallet use case yet |
| iOS Game ID placeholder + graceful skip | Ship TestFlight build without blocking on Unity iOS-platform setup |
| ATT copy is honest | "Test ads during internal testing" matches the visible banner |
| SKAdNetwork = Unity IDs only | AdMob/AdSense IDs would re-trigger fingerprint match — keep clean |
