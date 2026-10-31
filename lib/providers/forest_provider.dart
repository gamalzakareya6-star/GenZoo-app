import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/services/daily_notifications.dart';
import '../core/services/download_notification_service.dart';

/// "تحدي الـ100 شجرة": a tree grows for every 30 minutes of study.
/// Study time is counted with a timer; the start time is stored, so the
/// session keeps counting while the app is in the background or closed.
class ForestProvider extends ChangeNotifier {
  static const _key = 'forest_v1';
  static const int treeSeconds = 30 * 60;
  static const int goalTrees = 100;
  static const int maxSessionSeconds = 4 * 3600; // a forgotten timer stops counting here
  static const _notifBase = 9200;

  int _storedSecs = 0;
  int? _startMs;
  Timer? _ticker;

  ForestProvider() {
    _load();
  }

  bool get running => _startMs != null;

  int get sessionSecs {
    if (_startMs == null) return 0;
    final s = (DateTime.now().millisecondsSinceEpoch - _startMs!) ~/ 1000;
    return math.min(math.max(s, 0), maxSessionSeconds);
  }

  int get totalSecs => _storedSecs + sessionSecs;
  int get trees => totalSecs ~/ treeSeconds;
  double get treeProgress => (totalSecs % treeSeconds) / treeSeconds;
  int get secondsToNextTree => treeSeconds - (totalSecs % treeSeconds);
  bool get completed => trees >= goalTrees;
  int get totalMinutes => totalSecs ~/ 60;

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _storedSecs = p.getInt('${_key}_secs') ?? 0;
      _startMs = p.getInt('${_key}_start');
      // A session left running for too long is closed at the cap.
      if (_startMs != null) {
        final elapsed = (DateTime.now().millisecondsSinceEpoch - _startMs!) ~/ 1000;
        if (elapsed >= maxSessionSeconds) {
          _storedSecs += maxSessionSeconds;
          _startMs = null;
          await _save();
        }
      }
    } catch (_) {}
    if (_startMs != null) _startTicker();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('${_key}_secs', _storedSecs);
      if (_startMs == null) {
        await p.remove('${_key}_start');
      } else {
        await p.setInt('${_key}_start', _startMs!);
      }
    } catch (_) {}
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startMs != null && sessionSecs >= maxSessionSeconds) {
        stop();
        return;
      }
      notifyListeners();
    });
  }

  Future<void> start() async {
    if (running) return;
    _startMs = DateTime.now().millisecondsSinceEpoch;
    _startTicker();
    notifyListeners();
    await _save();
    unawaited(_scheduleTreeAlerts());
  }

  /// Ends the session and returns what it earned: (seconds, trees gained).
  Future<({int seconds, int newTrees})> stop({String? uid, String? name, String? photo}) async {
    if (!running) return (seconds: 0, newTrees: 0);
    final before = trees;
    final secs = sessionSecs;
    _storedSecs += secs;
    _startMs = null;
    _ticker?.cancel();
    notifyListeners();
    await _save();
    unawaited(_cancelTreeAlerts());
    if (uid != null) unawaited(syncRemote(uid, name ?? 'طالب', photo));
    return (seconds: secs, newTrees: trees - before);
  }

  /// Publishes the student's total for the leaderboard.
  Future<void> syncRemote(String uid, String name, [String? photo]) async {
    try {
      await FirebaseFirestore.instance.collection('forest').doc(uid).set({
        'name': name,
        if (photo != null && photo.isNotEmpty) 'photo': photo,
        'seconds': _storedSecs,
        'trees': _storedSecs ~/ treeSeconds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Forest sync failed: $e');
    }
  }

  // ---- "a tree grew" notifications while the session runs ----

  Future<void> _scheduleTreeAlerts() async {
    try {
      final svc = DownloadNotificationService();
      await svc.init();
      DailyNotifications.initTz();
      final plugin = svc.plugin;
      final start = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, _startMs!);
      var secsToNext = treeSeconds - (_storedSecs % treeSeconds);
      var treeNo = _storedSecs ~/ treeSeconds + 1;
      for (var i = 0; i < 8 && secsToNext <= maxSessionSeconds; i++) {
        final at = start.add(Duration(seconds: secsToNext));
        if (at.isAfter(tz.TZDateTime.now(tz.local))) {
          await plugin.zonedSchedule(
            _notifBase + i,
            'GenZoo 🌳',
            'نمت شجرتك رقم $treeNo! أكمل لتجمع غابتك.',
            at,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'genzoo_forest',
                'تحدي الـ100 شجرة',
                channelDescription: 'تنبيه عند نمو شجرة جديدة أثناء المذاكرة',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
        secsToNext += treeSeconds;
        treeNo++;
      }
    } catch (e) {
      debugPrint('Tree alerts could not be scheduled: $e');
    }
  }

  Future<void> _cancelTreeAlerts() async {
    try {
      final plugin = DownloadNotificationService().plugin;
      for (var i = 0; i < 8; i++) {
        await plugin.cancel(_notifBase + i);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
