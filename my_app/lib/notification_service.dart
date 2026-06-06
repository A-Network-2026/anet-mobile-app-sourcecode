import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _timeZoneInitialized = false;
  static bool _appIsForegrounded = false;
  static bool _permissionRequestScheduled = false;

  static const int miningDoneId = 1001;
  static const Duration _minimumScheduleLead = Duration(seconds: 1);

  static Future<void> initialize() async {
    if (_initialized) return;

    await _initializeLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;

    // Never block startup/UI focus on the Android permission bridge.
    unawaited(_schedulePermissionRequest());
  }

  static Future<void> _schedulePermissionRequest() async {
    if (_permissionRequestScheduled) {
      return;
    }
    _permissionRequestScheduled = true;
    // Never block on permission request; defer 3+ seconds off main thread.
    // Play Console ANR: FlutterLocalNotificationsPlugin.requestNotificationsPermission
    // -> Slow Binder call. We keep this fully off the cold-start path and bound
    // each individual Binder hop with a short timeout so a slow system server
    // never stalls the Flutter UI thread.
    await Future.delayed(const Duration(seconds: 3));
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl == null) {
        return;
      }
      // Yield once more so the call lands on a quiet frame.
      await Future<void>.delayed(Duration.zero);
      await androidImpl.requestNotificationsPermission().timeout(
        const Duration(milliseconds: 800),
        onTimeout: () {
          // Silently continue; notifications remain best-effort
          return null;
        },
      );
    } catch (_) {
      // Keep notifications best-effort; avoid surfacing bridge errors.
      // ANR prevention: never propagate permission errors.
    }
  }

  static Future<void> _initializeLocalTimeZone() async {
    if (_timeZoneInitialized) return;

    tz.initializeTimeZones();

    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _timeZoneInitialized = true;
  }

  static Future<void> scheduleMiningCompleteNotificationAt(
    DateTime scheduledEnd,
  ) async {
    await initialize();

    // Cancel any existing mining notification first
    await cancelMiningNotification();

    final now = DateTime.now();
    final effectiveEnd = scheduledEnd.isAfter(now)
        ? scheduledEnd
        : now.add(_minimumScheduleLead);
    final scheduledTime = tz.TZDateTime.from(effectiveEnd, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'mining_done_channel',
      'Ant Work Complete',
      channelDescription:
          'Notifies when your 6-hour ant work session is complete',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      miningDoneId,
      '🐜 Ant Work Complete!',
      'Your 6-hour ant work session is done. Open the app to claim your ANET reward.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule a notification relative to now.
  static Future<void> scheduleMiningCompleteNotification({
    Duration duration = const Duration(hours: 6),
  }) async {
    await scheduleMiningCompleteNotificationAt(DateTime.now().add(duration));
  }

  /// Cancel the scheduled mining notification (e.g. if session is reset)
  static Future<void> cancelMiningNotification() async {
    await initialize();
    await _plugin.cancel(miningDoneId);
  }

  /// Show immediate notification when mining reward is credited
  static Future<void> showMiningRewardNotification(double reward) async {
    await initialize();

    // Cancel the scheduled one since we're completing now
    await cancelMiningNotification();

    const androidDetails = AndroidNotificationDetails(
      'mining_reward_channel',
      'Ant Work Reward',
      channelDescription: 'Shows your earned ANET reward',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      miningDoneId,
      '✅ Ant Work Session Complete!',
      reward >= 0.0001
          ? 'You earned ${reward.toStringAsFixed(4)} ANET for your colony work.'
          : 'Your session has been recorded. Rewards accumulate with every session — keep working!',
      details,
    );
  }

  /// Called when app enters foreground - resumes notification scheduling
  /// (Privacy Policy Compliance: Ensures notifications only while app is active)
  static Future<void> onAppForegrounded() async {
    _appIsForegrounded = true;
  }

  /// Called when app enters background - pauses notification scheduling
  /// (Privacy Policy Compliance: Ensures notifications only while app is active)
  static Future<void> onAppBackgrounded() async {
    _appIsForegrounded = false;
    // Cancel in background without blocking lifecycle transition.
    unawaited(cancelMiningNotification());
  }

  /// Check if app is currently in foreground
  static bool get isAppForegrounded => _appIsForegrounded;
}
