import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../providers/daily_provider.dart';
import '../data/motivation.dart';
import 'download_notification_service.dart';

/// One reminder a day (19:30) for the next week, rebuilt every time the app
/// opens or the student's data changes. The text is chosen per day: exam
/// countdown, a streak warning, or a motivational line.
class DailyNotifications {
  static const _baseId = 9100;
  static const _days = 7;
  static bool _tzReady = false;

  static void _initTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    _tzReady = true;
  }

  static Future<void> reschedule({
    required bool enabled,
    required int streak,
    required bool studiedToday,
    required List<ExamEntry> exams,
  }) async {
    try {
      final svc = DownloadNotificationService();
      await svc.init();
      final plugin = svc.plugin;
      for (var i = 0; i < _days; i++) {
        await plugin.cancel(_baseId + i);
      }
      if (!enabled) return;

      _initTz();
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < _days; i++) {
        final day = now.add(Duration(days: i));
        var at = tz.TZDateTime(tz.local, day.year, day.month, day.day, 19, 30);
        if (!at.isAfter(now)) continue;
        if (i == 0 && studiedToday) continue;

        String body;
        final upcoming = exams.where((e) => e.daysLeft(at) >= 0 && e.daysLeft(at) <= 21).toList();
        if (upcoming.isNotEmpty) {
          final e = upcoming.first;
          body = Motivation.examMessage(e.name, e.daysLeft(at));
        } else if (i == 0 && streak > 0) {
          body = 'سلسلتك $streak يوم 🔥 ذاكر اليوم ولا تكسرها!';
        } else {
          body = Motivation.phraseFor(at);
        }

        await plugin.zonedSchedule(
          _baseId + i,
          'GenZoo 📚',
          body,
          at,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'genzoo_daily',
              'تذكيرات المذاكرة',
              channelDescription: 'تذكير يومي بالمذاكرة والامتحانات',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Daily reminders could not be scheduled: $e');
    }
  }
}
