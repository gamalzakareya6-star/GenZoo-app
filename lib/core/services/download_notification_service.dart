import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

/// Service for showing download progress notifications in the Android notification bar
/// and managing unknown app install permissions.
class DownloadNotificationService {
  static final DownloadNotificationService _instance =
      DownloadNotificationService._internal();
  factory DownloadNotificationService() => _instance;
  DownloadNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _installerChannel =
      MethodChannel('com.gamal.genzoo/installer');

  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;

  bool _initialized = false;
  final Map<int, DateTime> _lastShown = {};
  final Map<int, int> _lastPercent = {};

  static const String channelId = 'genzoo_downloads';
  static const String channelName = 'تحميلات وتحديثات GenZoo';

  Future<void> init() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            final file = File(payload);
            if (await file.exists()) {
              if (payload.endsWith('.apk')) {
                await installApk(payload);
              } else {
                await OpenFilex.open(payload);
              }
            }
          }
        },
      );

      _initialized = true;

      // Android 13+: notifications need a runtime permission.
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  /// Show or update a download progress notification in the notification bar
  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required int progress,
    int max = 100,
    String? subText,
  }) async {
    if (!_initialized) await init();

    // Notification updates are expensive: at most ~2 per second, and only
    // when the percentage actually changed (the final 100% always goes out).
    final now = DateTime.now();
    final last = _lastShown[id];
    if (progress < max &&
        (_lastPercent[id] == progress ||
            (last != null && now.difference(last).inMilliseconds < 500))) {
      return;
    }
    _lastShown[id] = now;
    _lastPercent[id] = progress;

    try {
      final safeProgress = progress.clamp(0, max);
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'إشعارات تقدم تحميل التحديثات والملفات',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: max,
        progress: safeProgress,
        ongoing: true,
        onlyAlertOnce: true,
        autoCancel: false,
        subText: subText,
      );

      final NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id,
        title,
        'جارٍ التحميل: $safeProgress%',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error updating download notification: $e');
    }
  }

  /// Show download completed notification
  Future<void> showDownloadCompleted({
    required int id,
    required String title,
    required String body,
    String? filePath,
  }) async {
    if (!_initialized) await init();
    _lastShown.remove(id);
    _lastPercent.remove(id);

    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'إشعارات تقدم تحميل التحديثات والملفات',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showProgress: false,
        ongoing: false,
        autoCancel: true,
      );

      final NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: filePath,
      );
    } catch (e) {
      debugPrint('Error showing download complete notification: $e');
    }
  }

  /// Cancel notification by id
  Future<void> cancel(int id) async {
    _lastShown.remove(id);
    _lastPercent.remove(id);
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  /// Check if the app can install unknown APKs (Android 8.0+)
  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _installerChannel
          .invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } catch (e) {
      debugPrint('Error checking package install permission: $e');
      return true;
    }
  }

  /// Open Android settings to allow installing apps from this source
  static Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _installerChannel
          .invokeMethod<bool>('openInstallSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening install settings: $e');
      return false;
    }
  }

  /// Install an APK file using OpenFilex
  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('APK install open result: ${result.type} - ${result.message}');
    } catch (e) {
      debugPrint('Error installing APK: $e');
    }
  }
}
