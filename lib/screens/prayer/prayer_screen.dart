import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/constants/app_colors.dart';
import '../../core/services/download_notification_service.dart';
import '../../core/services/prayer_calc.dart';
import '../../core/services/prayer_service.dart';

/// مواقيت الصلاة — calculated on the device (works offline), with optional
/// notifications at each prayer time.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _City {
  final String name;
  final double lat;
  final double lng;
  const _City(this.name, this.lat, this.lng);
}

const _cities = [
  _City('القاهرة', 30.0444, 31.2357),
  _City('الجيزة', 30.0131, 31.2089),
  _City('الإسكندرية', 31.2001, 29.9187),
  _City('شبين الكوم (المنوفية)', 30.5972, 30.9876),
  _City('طنطا', 30.7865, 31.0004),
  _City('المنصورة', 31.0409, 31.3785),
  _City('الزقازيق', 30.5877, 31.5020),
  _City('بورسعيد', 31.2653, 32.3019),
  _City('السويس', 29.9668, 32.5498),
  _City('الفيوم', 29.3084, 30.8428),
  _City('بني سويف', 29.0661, 31.0994),
  _City('المنيا', 28.1099, 30.7503),
  _City('أسيوط', 27.1783, 31.1859),
  _City('سوهاج', 26.5591, 31.6948),
  _City('الأقصر', 25.6872, 32.6396),
  _City('أسوان', 24.0889, 32.8998),
  _City('الغردقة', 27.2579, 33.8116),
  _City('شرم الشيخ', 27.9158, 34.3300),
  _City('مكة المكرمة', 21.3891, 39.8579),
  _City('المدينة المنورة', 24.5247, 39.5692),
];

class _PrayerScreenState extends State<PrayerScreen> {
  PrayerSettings? _s;
  Timer? _tick;
  DateTime _now = DateTime.now();
  String? _error;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await PrayerService.load();
    if (!mounted) return;
    setState(() => _s = s);
  }

  Future<void> _commit() async {
    final s = _s!;
    setState(() {});
    await PrayerService.save(s);
    await PrayerService.reschedule(s);
  }

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'خدمة الموقع مغلقة. فعّلها أو اختر مدينتك يدوياً.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'إذن الموقع مرفوض. اختر مدينتك يدوياً.';
      }
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 15),
          );
      _s!
        ..lat = pos.latitude
        ..lng = pos.longitude
        ..city = 'موقعي الحالي';
      await _commit();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickCity() async {
    final c = await showModalBottomSheet<_City>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location_rounded),
              title: const Text('تحديد موقعي تلقائياً (GPS)'),
              onTap: () {
                Navigator.pop(ctx);
                _useGps();
              },
            ),
            const Divider(),
            for (final c in _cities)
              ListTile(
                leading: const Icon(Icons.location_city_rounded),
                title: Text(c.name),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (c == null) return;
    _s!
      ..lat = c.lat
      ..lng = c.lng
      ..city = c.name;
    await _commit();
  }

  Future<void> _setNotify(bool v) async {
    if (v) {
      final svc = DownloadNotificationService();
      await svc.init();
      await svc.plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _s!.notify = v;
    await _commit();
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        final s = _s!;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('طريقة الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                for (final m in CalcMethod.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.method == m ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: s.method == m ? AppColors.primary : null,
                    ),
                    title: Text(m.label),
                    onTap: () async {
                      s.method = m;
                      setM(() {});
                      await _commit();
                    },
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('العصر بالمذهب الحنفي'),
                  subtitle: const Text('الافتراضي: الجمهور (ظل المثل)'),
                  value: s.hanafi,
                  onChanged: (v) async {
                    s.hanafi = v;
                    setM(() {});
                    await _commit();
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(child: Text('تعديل يدوي لكل المواقيت (دقائق)')),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: s.offsetMin <= -15
                          ? null
                          : () async {
                              s.offsetMin--;
                              setM(() {});
                              await _commit();
                            },
                    ),
                    Text('${s.offsetMin > 0 ? '+' : ''}${s.offsetMin}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: s.offsetMin >= 15
                          ? null
                          : () async {
                              s.offsetMin++;
                              setM(() {});
                              await _commit();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'المواقيت محسوبة فلكياً على جهازك وقد تختلف دقيقة أو دقيقتين عن التقويم الرسمي. استخدم التعديل اليدوي لمطابقتها مع مسجدك.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) {
      return Scaffold(appBar: AppBar(title: const Text('مواقيت الصلاة')), body: const Center(child: CircularProgressIndicator()));
    }
    PrayerDay today;
    PrayerDay tomorrow;
    try {
      today = s.day(_now);
      tomorrow = s.day(_now.add(const Duration(days: 1)));
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('مواقيت الصلاة')),
        body: Center(child: Text('$e')),
      );
    }

    // Next prayer among the five (sunrise is shown but not a prayer).
    final fiveToday = today.prayers;
    int next = fiveToday.indexWhere((t) => t.isAfter(_now));
    DateTime nextAt;
    if (next == -1) {
      next = 0;
      nextAt = tomorrow.fajr;
    } else {
      nextAt = fiveToday[next];
    }
    const five = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final left = nextAt.difference(_now);
    String two(int n) => n.toString().padLeft(2, '0');
    final countdown = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final timeFmt = DateFormat('h:mm a', 'ar');

    final rows = <(String, DateTime, int?)>[
      ('الفجر', today.fajr, 0),
      ('الشروق', today.sunrise, null),
      ('الظهر', today.dhuhr, 1),
      ('العصر', today.asr, 2),
      ('المغرب', today.maghrib, 3),
      ('العشاء', today.isha, 4),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(tooltip: 'الموقع', icon: const Icon(Icons.location_on_rounded), onPressed: _pickCity),
          IconButton(tooltip: 'الإعدادات', icon: const Icon(Icons.tune_rounded), onPressed: _settings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(PrayerCalc.hijri(_now), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(DateFormat('EEEE d MMMM yyyy', 'ar').format(_now), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 14),
                Text('الصلاة القادمة: ${five[next]}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(countdown, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 2)),
                ),
                const SizedBox(height: 6),
                Text('${timeFmt.format(nextAt)} • ${s.city}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: TextStyle(color: AppColors.error)),
            ),
          if (_locating) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          const SizedBox(height: 14),
          for (final r in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: r.$3 != null && r.$3 == next ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  r.$3 == null ? Icons.wb_twilight_rounded : Icons.mosque_rounded,
                  color: r.$3 != null && r.$3 == next ? AppColors.primary : null,
                ),
                title: Text(r.$1, style: TextStyle(fontWeight: r.$3 == next ? FontWeight.bold : FontWeight.w500)),
                subtitle: r.$3 != null && r.$3 == next ? const Text('الصلاة القادمة') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeFmt.format(r.$2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (r.$3 != null)
                      IconButton(
                        tooltip: 'تنبيه',
                        icon: Icon(
                          s.notify && s.perPrayer[r.$3!] ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                          color: s.notify && s.perPrayer[r.$3!] ? AppColors.primary : null,
                        ),
                        onPressed: () async {
                          if (!s.notify) {
                            s.perPrayer = List.filled(5, false);
                            await _setNotify(true);
                          }
                          s.perPrayer[r.$3!] = !s.perPrayer[r.$3!];
                          if (!s.perPrayer.contains(true)) s.notify = false;
                          await _commit();
                        },
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: const Text('تنبيه عند كل صلاة'),
            subtitle: const Text('إشعار في وقت الأذان للأيام السبعة القادمة، ويتجدد كلما فتحت التطبيق'),
            value: s.notify,
            onChanged: (v) async {
              if (v) s.perPrayer = List.filled(5, true);
              await _setNotify(v);
            },
          ),
          const SizedBox(height: 6),
          Text(
            'المواقيت تُحسب على جهازك بدون إنترنت حسب: ${s.method.label}. إن لم يصلك تنبيه في وقته، استثنِ التطبيق من توفير البطارية.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}
