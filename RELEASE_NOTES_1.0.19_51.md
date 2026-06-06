# A Network - Version 1.0.19 (Build 51)

## Release Date
May 14, 2026

## What's New

### Bug Fixes
- **Fixed ANR (Application Not Responding) issues** affecting users on Android 12+
  - Resolved notification permission request blocking main thread
  - Fixed delayed response in voice controls (Flutter TTS)
  - Improved ad loading responsiveness

- **Fixed session history display**
  - Session rewards and block height now display correctly
  - Real-time mining session updates restored
  - Proper sorting of completed sessions (newest first)

  - Rewarded ad unit IDs now correctly route to ad rewards
  - Ad token topup flow improved

- **Fixed authentication token corruption**
  - Resolved Bearer token corruption from secure storage decryption failures
  - Added automatic token validation and integrity checking
  - Users experiencing "invalid HTTP header field value" errors will now auto-recover
  - Corrupted tokens are automatically cleared and user is prompted to re-login
### Performance Improvements
- Non-blocking notification permission flow (deferred to 2 seconds after app launch)
- Voice (TTS) plugin now initializes on-demand instead of at page load
- Reduced main thread contention during app lifecycle transitions
- Optimized ad preload sequences to avoid UI freezes

### Mining & Rewards
- Session credit rewards now reflect in real-time on completion
- Improved reliability of 6-hour Ant Work session tracking
- Better handling of offline/poor network conditions during session completion

### Ad Serving
- AdMob limited ad serving status monitored; fallback messages improved
- Ad requests now proceed asynchronously without blocking Ant Work startup
- Better error handling for unavailable ad inventory

## Known Limitations
- Ad serving may be limited due to ongoing AdMob traffic quality review (started May 11, 2026)
- Voice playback depends on device language support availability

## Recommendations
- Update to this version to resolve ANR crashes and improve overall stability
- Ensure app has notification permissions enabled for timely mining session completion alerts
- Check device language settings if voice features are not responding

## Support
For issues or feedback, please contact: info@a-network.net

---
**Build Version:** 1.0.19 (51)  
**Platform:** Android (minimum SDK 24)  
**Size:** ~71 MB (APK) / ~61 MB (Bundle)
