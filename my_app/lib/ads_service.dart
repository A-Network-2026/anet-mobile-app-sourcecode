// Google AdMob has been fully removed (Google AdSense/AdMob account was banned).
//
// This file is now a permanent no-op stub that preserves the original
// `AdsService` API surface so existing call sites (main.dart, ai_support_page,
// dex_page, referral_chat_page, etc.) continue to compile and run without
// crashing.  When the new ad network (Axon / ads.axon) is integrated, all of
// the methods below should be re-implemented to drive that SDK instead.  No
// Google AdMob code, no `google_mobile_ads` import, and no AdMob unit IDs are
// allowed to come back into this file.

import 'dart:async';

class AdsService {
  AdsService._();

  /// Ads are permanently disabled until the new Axon SDK is wired in.
  static bool get adsEnabled => false;

  /// Empty placeholder kept for API compatibility — never used now.
  static String get bannerAdUnitId => '';

  /// Surfaced to the UI when a rewarded ad load failed.  No-op stub.
  static String? get lastAiTokenRewardedLoadError => null;

  /// Initialize the (future) ad SDK.  Currently a no-op.
  static Future<void> initialize() async {}

  /// Enable ads at runtime.  Currently a no-op — ads stay disabled.
  static Future<void> enableRuntime() async {}

  /// Schedule a delayed foreground warm-up of the (future) ad SDK.
  /// No-op stub.
  static void scheduleForegroundWarmup({
    Duration delay = const Duration(seconds: 12),
  }) {}

  /// Track app foreground/background state for the (future) ad SDK.
  /// No-op stub.
  static void setAppVisibility(bool isForeground) {}

  /// Pre-load a banner.  Returns null — caller treats this as "no ad".
  static Future<Object?> loadBannerAd() async => null;

  /// Pre-load an interstitial.  No-op stub.
  static Future<void> loadInterstitialAd() async {}

  /// Pre-load the AI-token rewarded ad.  No-op stub.
  static Future<void> loadAiTokenRewardedAd() async {}

  /// Show an interstitial and wait for it to dismiss.  Always returns false
  /// (no ad was actually shown) so the caller proceeds as if the ad was
  /// dismissed normally.
  static Future<bool> showInterstitialAndWait() async => false;

  /// Fire-and-forget interstitial show.  No-op stub.
  static Future<void> showInterstitialBestEffort() async {}

  /// Best-effort AI-login interstitial.  Returns false — never shown.
  static Future<bool> showAiLoginInterstitialBestEffort() async => false;

  /// Best-effort AI-token rewarded ad.  Returns false — no reward earned.
  ///
  /// Existing callers gate AI-token grants on this return value; returning
  /// false ensures we don't accidentally hand out tokens for an ad that was
  /// never displayed.  When Axon is wired in, replace this with a real reward
  /// callback.
  static Future<bool> showAiTokenRewardedBestEffort({
    required Object? userId,
  }) async => false;
}
