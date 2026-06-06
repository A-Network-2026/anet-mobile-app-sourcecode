// Unity Ads service — INTERNAL TESTING ONLY.
//
// This entire module is a no-op stub unless the binary was built with:
//     flutter build appbundle --dart-define=ENABLE_ADS=true
//
// Production builds (no flag) ship the stub. The unity_ads_plugin package is
// still in the AAB, but no SDK init runs, no ads load, no Unity network calls
// are made, no app-ads.txt crawl is triggered. Treat the flag as the single
// source of truth.
//
// DO NOT call any Unity SDK API directly from app code. Always go through
// UnityAdsService — that's where the kill switch lives.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class UnityAdsService {
  UnityAdsService._();
  static final UnityAdsService instance = UnityAdsService._();

  /// Build-time flag. Production builds (no --dart-define) get false.
  static const bool enabled = bool.fromEnvironment(
    'ENABLE_ADS',
    defaultValue: false,
  );

  /// Unity Cloud Monetization Game ID for Android (A-Network project).
  /// Set during onboarding 2026-05-28. Org ID 18968437863421.
  static const String _androidGameId = '800001547';

  /// Unity Cloud Monetization Game ID for iOS.
  /// TODO: replace with the real iOS Game ID once the iOS platform has been
  /// added in the Unity dashboard (Project Settings -> Platforms -> Add iOS).
  /// Until then this stays as the placeholder and init() will skip on iOS
  /// with a debug log -- the TestFlight build still ships safely without ads.
  static const String _iosGameId = 'PENDING_IOS_GAME_ID';

  /// Placement IDs as configured on the Unity dashboard.
  /// Android placement is already provisioned; iOS placement will be created
  /// by Unity automatically once the iOS platform is added.
  static const String _androidInterstitialPlacement = 'Interstitial_Android';
  static const String _iosInterstitialPlacement = 'Interstitial_iOS';

  String get _gameId => Platform.isIOS ? _iosGameId : _androidGameId;

  String get interstitialPlacement => Platform.isIOS
      ? _iosInterstitialPlacement
      : _androidInterstitialPlacement;

  bool get _gameIdConfigured =>
      _gameId.isNotEmpty && !_gameId.startsWith('PENDING_');

  bool _initialized = false;
  DateTime? _lastShown;

  /// Minimum gap between Interstitial impressions. Protects retention on
  /// low-end devices in India/Pakistan/Indonesia (62%+ of our DAU).
  static const Duration _frequencyCap = Duration(minutes: 5);

  Future<void> init() async {
    if (!enabled) return; // no-op in production
    if (_initialized) return;
    if (!_gameIdConfigured) {
      debugPrint(
        '[UnityAds] skip init: Game ID not configured for '
        '${Platform.isIOS ? 'iOS' : 'Android'} '
        '(value=$_gameId). Add the iOS platform in the Unity dashboard and '
        'paste the iOS Game ID into UnityAdsService._iosGameId.',
      );
      return;
    }
    try {
      await UnityAds.init(
        gameId: _gameId,
        testMode:
            true, // safe default; flip to false after first live impression test
        onComplete: () {
          debugPrint('[UnityAds] init complete');
          _initialized = true;
          _preload();
        },
        onFailed: (error, message) {
          debugPrint('[UnityAds] init failed: $error $message');
        },
      );
    } catch (e) {
      debugPrint('[UnityAds] init threw: $e');
    }
  }

  void _preload() {
    if (!enabled || !_initialized) return;
    UnityAds.load(
      placementId: interstitialPlacement,
      onComplete: (id) => debugPrint('[UnityAds] preload complete: $id'),
      onFailed: (id, error, message) =>
          debugPrint('[UnityAds] preload failed: $id $error $message'),
    );
  }

  /// Returns true if we actually showed (or attempted to show) an ad.
  /// Returns false if disabled, not initialized, or frequency-capped.
  Future<bool> maybeShowInterstitial({String trigger = 'manual'}) async {
    if (!enabled) return false;
    if (!_initialized) {
      debugPrint('[UnityAds] skip show ($trigger): not initialized');
      return false;
    }
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < _frequencyCap) {
      debugPrint('[UnityAds] skip show ($trigger): frequency capped');
      return false;
    }
    _lastShown = now;
    debugPrint('[UnityAds] showing interstitial trigger=$trigger');
    UnityAds.showVideoAd(
      placementId: interstitialPlacement,
      onComplete: (id) {
        debugPrint('[UnityAds] show complete: $id');
        _preload(); // queue next
      },
      onFailed: (id, error, message) {
        debugPrint('[UnityAds] show failed: $id $error $message');
        _lastShown = null; // failed = don't count toward cap
      },
      onStart: (id) => debugPrint('[UnityAds] show start: $id'),
      onClick: (id) => debugPrint('[UnityAds] show click: $id'),
      onSkipped: (id) => debugPrint('[UnityAds] show skipped: $id'),
    );
    return true;
  }
}
