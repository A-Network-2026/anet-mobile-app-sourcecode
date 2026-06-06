# A-Network Flutter App

This folder contains the Flutter client for A-Network.

Current app features:

- authentication flow
- off-chain 6-hour mining session UI
- leaderboard and network stats integration
- Web3 wallet connection and ANET on-chain balance lookup
- Web4 concept slide
- in-app whitepaper, privacy, and terms links

Main entry points:

- `lib/main.dart`
- `lib/api.dart`

Install dependencies:

```bash
flutter pub get
```

Run locally:

```bash
flutter run
```

Build internal test APK with ads disabled:

```bash
flutter build apk --release --no-obfuscate
```

Build developer-only ad test APK if you ever need to verify AdMob wiring privately:

```bash
flutter build apk --release --no-obfuscate --dart-define=ADS_ENABLED=true
```

Build release APK with production ads only after Play Store, App Store, and AdMob approval:

```bash
flutter build apk --release --no-obfuscate --dart-define=ADS_ENABLED=true --dart-define=USE_PRODUCTION_ADS=true --dart-define=AI_BASE_URL=https://anetwork-ai-backend.onrender.com --dart-define=AI_SUPPORT_TOKEN=anet-app-2026-support-key
```

Build release AAB for Play Store with AI support token configured:

```bash
flutter build appbundle --release --no-obfuscate --dart-define=ADS_ENABLED=true --dart-define=USE_PRODUCTION_ADS=true --dart-define=AI_BASE_URL=https://anetwork-ai-backend.onrender.com --dart-define=AI_SUPPORT_TOKEN=anet-app-2026-support-key
```

For full project details, mining formulas, backend rules, and legal links, see the root README:

- `../README.md`
