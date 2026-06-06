import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class SecurityException implements Exception {
  SecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SecurityAssessment {
  const SecurityAssessment({
    required this.platform,
    required this.deviceFingerprint,
    required this.flags,
    required this.isPhysicalDevice,
    required this.isDebugRuntime,
    required this.allowInsecureDeviceForTesting,
  });

  final String platform;
  final String deviceFingerprint;
  final List<String> flags;
  final bool isPhysicalDevice;
  final bool isDebugRuntime;
  final bool allowInsecureDeviceForTesting;

  bool get isMobilePlatform => platform == 'android' || platform == 'ios';

  bool get hasElevatedRisk =>
      flags.contains('emulator_detected') ||
      flags.contains('non_physical_device') ||
      flags.contains('root_detected') ||
      flags.contains('jailbreak_detected') ||
      flags.contains('unsupported_platform');

  bool get shouldBlockSensitiveActions =>
      isMobilePlatform &&
      !allowInsecureDeviceForTesting &&
      !isDebugRuntime &&
      hasElevatedRisk;

  String get runtimeLabel => isDebugRuntime ? 'debug' : 'release';
}

class SecurityService {
  static const bool _allowInsecureDevice = bool.fromEnvironment(
    'ALLOW_INSECURE_DEVICE',
    defaultValue: false,
  );

  static bool _initialized = false;
  static SecurityAssessment _assessment = const SecurityAssessment(
    platform: 'unknown',
    deviceFingerprint: 'uninitialized',
    flags: <String>['uninitialized'],
    isPhysicalDevice: false,
    isDebugRuntime: kDebugMode,
    allowInsecureDeviceForTesting: _allowInsecureDevice,
  );

  static SecurityAssessment get assessment => _assessment;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _assessment = await _buildAssessment();
    _initialized = true;
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  static void ensureSensitiveOperationAllowed([
    String operation = 'sensitive action',
  ]) {
    if (_assessment.shouldBlockSensitiveActions) {
      throw SecurityException(
        'Security policy blocked $operation on this device. Please use an official build on a physical device.',
      );
    }
  }

  static Map<String, String> buildSecurityHeaders() {
    return {
      'x-device-fingerprint': _assessment.deviceFingerprint,
      'x-app-runtime': _assessment.runtimeLabel,
      'x-app-security-flags': _assessment.flags.join(','),
    };
  }

  static Future<SecurityAssessment> _buildAssessment() async {
    final flags = <String>[];
    final info = DeviceInfoPlugin();

    if (kDebugMode) {
      flags.add('debug_runtime');
    }

    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final fingerprint = [
        android.brand,
        android.model,
        android.device,
        android.product,
        android.hardware,
        android.fingerprint,
        android.id,
      ].join('|');

      final emulator =
          !android.isPhysicalDevice || _looksLikeAndroidEmulator(android);
      final hasRootArtifacts = await _hasAnyAccessiblePath(const [
        '/system/bin/su',
        '/system/xbin/su',
        '/sbin/su',
        '/su/bin/su',
        '/system/app/Superuser.apk',
        '/system/xbin/daemonsu',
        '/system/bin/magisk',
        '/sbin/magisk',
        '/init.magisk.rc',
      ]);
      final rooted = hasRootArtifacts;
      if (!android.isPhysicalDevice) {
        flags.add('non_physical_device');
      }
      if (emulator) {
        flags.add('emulator_detected');
      }
      if (rooted) {
        flags.add('root_detected');
      }
      if (_looksLikeAndroidRootBuild(android)) {
        flags.add('developer_build');
      }

      return SecurityAssessment(
        platform: 'android',
        deviceFingerprint: _encodeFingerprint(fingerprint),
        flags: _dedupe(flags),
        isPhysicalDevice: android.isPhysicalDevice,
        isDebugRuntime: kDebugMode,
        allowInsecureDeviceForTesting: _allowInsecureDevice,
      );
    }

    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      final fingerprint = [
        ios.model,
        ios.name,
        ios.systemVersion,
        ios.identifierForVendor ?? 'no-vendor-id',
      ].join('|');

      final emulator = !ios.isPhysicalDevice || _looksLikeIosSimulator(ios);
      final jailbroken = await _hasAnyAccessiblePath(const [
        '/Applications/Cydia.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
        '/etc/apt',
        '/private/var/lib/apt/',
        '/private/var/stash',
      ]);
      if (!ios.isPhysicalDevice) {
        flags.add('non_physical_device');
      }
      if (emulator) {
        flags.add('emulator_detected');
      }
      if (jailbroken) {
        flags.add('jailbreak_detected');
      }

      return SecurityAssessment(
        platform: 'ios',
        deviceFingerprint: _encodeFingerprint(fingerprint),
        flags: _dedupe(flags),
        isPhysicalDevice: ios.isPhysicalDevice,
        isDebugRuntime: kDebugMode,
        allowInsecureDeviceForTesting: _allowInsecureDevice,
      );
    }

    flags.add('unsupported_platform');
    return SecurityAssessment(
      platform: Platform.operatingSystem,
      deviceFingerprint: _encodeFingerprint(Platform.operatingSystem),
      flags: _dedupe(flags),
      isPhysicalDevice: false,
      isDebugRuntime: kDebugMode,
      allowInsecureDeviceForTesting: _allowInsecureDevice,
    );
  }

  static bool _looksLikeAndroidEmulator(AndroidDeviceInfo info) {
    final values = [
      info.brand,
      info.device,
      info.fingerprint,
      info.hardware,
      info.manufacturer,
      info.model,
      info.product,
    ].map((value) => value.toLowerCase()).join(' ');

    const emulatorHints = [
      'generic',
      'unknown',
      'emulator',
      'sdk',
      'google_sdk',
      'genymotion',
      'goldfish',
      'ranchu',
      'vbox',
      'simulator',
      'x86',
    ];

    return emulatorHints.any(values.contains);
  }

  static bool _looksLikeAndroidRootBuild(AndroidDeviceInfo info) {
    final values = [
      info.tags,
      info.fingerprint,
      info.hardware,
      info.product,
    ].map((value) => value.toLowerCase()).join(' ');

    const rootHints = [
      'test-keys',
      'magisk',
      'superuser',
      'lineage',
      'userdebug',
      'eng',
    ];

    return rootHints.any(values.contains);
  }

  static bool _looksLikeIosSimulator(IosDeviceInfo info) {
    final values = [
      info.model,
      info.name,
      info.localizedModel,
      info.systemName,
    ].map((value) => value.toLowerCase()).join(' ');

    return values.contains('simulator') || values.contains('x86_64');
  }

  static Future<bool> _hasAnyAccessiblePath(List<String> paths) async {
    for (final path in paths) {
      try {
        if (await File(path).exists() || await Directory(path).exists()) {
          return true;
        }
      } catch (_) {
        // Ignore inaccessible system paths and continue probing.
      }
    }
    return false;
  }

  static String _encodeFingerprint(String raw) {
    final encoded = base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    final end = encoded.length > 96 ? 96 : encoded.length;
    return encoded.substring(0, end);
  }

  static List<String> _dedupe(List<String> flags) {
    return flags.toSet().toList()..sort();
  }
}
