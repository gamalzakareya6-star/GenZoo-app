import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'daily_notifications.dart';
import 'download_notification_service.dart';
import 'prayer_calc.dart';

class PrayerSettings {
  double lat;
  double lng;
  String city;
  CalcMethod method;
  bool hanafi;
  bool notify;
  List<bool> perPrayer; // fajr, dhuhr, asr, maghrib, isha
  int offsetMin; // manual correction applied to every time

  PrayerSettings({
    this.lat = 30.0444,
    this.lng = 31.2357,
    this.city = 'القاهرة',
    this.method = CalcMethod.egyptian,
    this.hanafi = false,
    this.notify = false,
    List<bool>? perPrayer,
    this.offsetMin = 0,
  }) : perPrayer = perPrayer ?? List.filled(5, true);

  PrayerDay day(DateTime d) {
    final r = PrayerCalc.compute(date: d, lat: lat, lng: lng, method: method, hanafi: hanafi);
    if (offsetMin == 0) return r;
    DateTime s(DateTime t) => t.add(Duration(minutes: offsetMin));
    return PrayerDay(s(r.fajr), s(r.sunrise), s(r.dhuhr), s(r.asr), s(r.maghrib), s(r.isha));
  }
}

class PrayerService {
  static const _k = 'prayer_settings_v1';
  static const _baseId = 9300;

  static Future<PrayerSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k);
    if (l == null || l.length < 8) return PrayerSettings();
    return PrayerSettings(
      lat: double.tryParse(l[0]) ?? 30.0444,
      lng: double.tryParse(l[1]) ?? 31.2357,
      city: l[2],
      method: CalcMethod.values[(int.tryParse(l[3]) ?? 0).clamp(0, CalcMethod.values.length - 1)],
      hanafi: l[4] == '1',
      notify: l[5] == '1',
      perPrayer: l[6].split('').map((c) => c == '1').toList(),
      offsetMin: int.tryParse(l[7]) ?? 0,
    );
  }

  static Future<void> save(PrayerSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_k, [
      '${s.lat}',
      '${s.lng}',
      s.city,
      '${s.method.index}',
      s.hanafi ? '1' : '0',
      s.notify ? '1' : '0',
      s.perPrayer.map((b) => b ? '1' : '0').join(),
      '${s.offsetMin}',
    ]);
  }

  /// Rebuilds the next 7 days of prayer notifications (also called whenever
  /// the app opens, so the window keeps rolling forward).
  static Future<void> reschedule(PrayerSettings s) async {
    try {
      final svc = DownloadNotificationService();
      await svc.init();
      final plugin = svc.plugin;
      for (var i = 0; i < 7 * 5; i++) {
        await plugin.cancel(_baseId + i);
      }
      if (!s.notify) return;
      DailyNotifications.initTz();
      final now = DateTime.now();
      const names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      for (var d = 0; d < 7; d++) {
        final day = s.day(now.add(Duration(days: d)));
        final times = day.prayers;
        for (var i = 0; i < 5; i++) {
          if (!s.perPrayer[i] || !times[i].isAfter(now)) continue;
          final at = tz.TZDateTime.from(times[i], tz.local);
          const details = NotificationDetails(
            android: AndroidNotificationDetails(
              'genzoo_prayer',
              'مواقيت الصلاة',
              channelDescription: 'تنبيه عند دخول وقت الصلاة',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          );
          final id = _baseId + d * 5 + i;
          Future<void> schedule(AndroidScheduleMode mode) => plugin.zonedSchedule(
                id,
                'حان الآن موعد صلاة ${names[i]} 🕌',
                'حيّ على الصلاة — ${s.city}',
                at,
                details,
                androidScheduleMode: mode,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              );
          try {
            await schedule(AndroidScheduleMode.exactAllowWhileIdle);
          } catch (_) {
            await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
          }
        }
      }
    } catch (e) {
      debugPrint('Prayer notifications could not be scheduled: $e');
    }
  }
}
