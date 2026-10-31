import 'dart:math' as math;

enum CalcMethod { egyptian, mwl, ummAlQura, karachi }

extension CalcMethodInfo on CalcMethod {
  String get label => switch (this) {
        CalcMethod.egyptian => 'الهيئة المصرية العامة للمساحة',
        CalcMethod.mwl => 'رابطة العالم الإسلامي',
        CalcMethod.ummAlQura => 'أم القرى (مكة)',
        CalcMethod.karachi => 'جامعة العلوم الإسلامية - كراتشي',
      };
  double get fajrAngle => switch (this) {
        CalcMethod.egyptian => 19.5,
        CalcMethod.mwl => 18,
        CalcMethod.ummAlQura => 18.5,
        CalcMethod.karachi => 18,
      };

  /// Isha angle, or null when it is a fixed interval after Maghrib.
  double? get ishaAngle => switch (this) {
        CalcMethod.egyptian => 17.5,
        CalcMethod.mwl => 17,
        CalcMethod.ummAlQura => null,
        CalcMethod.karachi => 18,
      };
}

class PrayerDay {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  const PrayerDay(this.fajr, this.sunrise, this.dhuhr, this.asr, this.maghrib, this.isha);

  static const names = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  List<DateTime> get all => [fajr, sunrise, dhuhr, asr, maghrib, isha];

  /// The five prayers (without sunrise).
  List<DateTime> get prayers => [fajr, dhuhr, asr, maghrib, isha];
}

/// Offline prayer-time calculation (same astronomical method used by the
/// well-known PrayTimes library). Accuracy is about ±1–2 minutes.
class PrayerCalc {
  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
  static double _fix(double a, double m) {
    a = a - m * (a / m).floorToDouble();
    return a < 0 ? a + m : a;
  }

  static double julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (m + 1)).floorToDouble() + d + b - 1524.5;
  }

  static ({double decl, double eqt}) _sun(double jd) {
    final dd = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * dd, 360);
    final q = _fix(280.459 + 0.98564736 * dd, 360);
    final l = _fix(q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)), 360);
    final e = 23.439 - 0.00000036 * dd;
    final ra = _fix(_deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) / 15, 24);
    final eqt = q / 15 - ra;
    final decl = _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
    return (decl: decl, eqt: eqt);
  }

  static double _angleTime(double angle, double t, double lat, double jd, double mid, {bool ccw = false}) {
    final decl = _sun(jd + t / 24).decl;
    final v = (-math.sin(_rad(angle)) - math.sin(_rad(decl)) * math.sin(_rad(lat))) /
        (math.cos(_rad(decl)) * math.cos(_rad(lat)));
    final h = _deg(math.acos(v.clamp(-1.0, 1.0))) / 15;
    return mid + (ccw ? -h : h);
  }

  static double _asrTime(double factor, double t, double lat, double jd, double mid) {
    final decl = _sun(jd + t / 24).decl;
    final angle = -_deg(math.atan(1 / (factor + math.tan(_rad((lat - decl).abs())))));
    final v = (-math.sin(_rad(angle)) - math.sin(_rad(decl)) * math.sin(_rad(lat))) /
        (math.cos(_rad(decl)) * math.cos(_rad(lat)));
    return mid + _deg(math.acos(v.clamp(-1.0, 1.0))) / 15;
  }

  static PrayerDay compute({
    required DateTime date,
    required double lat,
    required double lng,
    CalcMethod method = CalcMethod.egyptian,
    bool hanafi = false,
  }) {
    final tz = DateTime(date.year, date.month, date.day, 12).timeZoneOffset.inMinutes / 60.0;
    final jd = julian(date.year, date.month, date.day) - lng / (15 * 24);
    var t = [5.0, 6.0, 12.0, 13.0, 18.0, 18.0]; // fajr, sunrise, dhuhr, asr, sunset, isha
    for (var i = 0; i < 2; i++) {
      final mid = 12 - _sun(jd + 0.5).eqt;
      final fajr = _angleTime(method.fajrAngle, t[0], lat, jd, mid, ccw: true);
      final sunrise = _angleTime(0.833, t[1], lat, jd, mid, ccw: true);
      final asr = _asrTime(hanafi ? 2 : 1, t[3], lat, jd, mid);
      final sunset = _angleTime(0.833, t[4], lat, jd, mid);
      final ia = method.ishaAngle;
      final isha = ia == null ? sunset + 1.5 : _angleTime(ia, t[5], lat, jd, mid);
      t = [fajr, sunrise, mid, asr, sunset, isha];
    }
    final adj = tz - lng / 15;
    DateTime at(double h) {
      if (h.isNaN) throw StateError('تعذّر حساب المواقيت لهذا الموقع');
      final base = DateTime(date.year, date.month, date.day);
      return base.add(Duration(seconds: ((h + adj) * 3600).round()));
    }

    return PrayerDay(at(t[0]), at(t[1]), at(t[2]), at(t[3]), at(t[4] + 0.0), at(t[5]));
  }

  // ---- Hijri (arithmetical, can differ by a day from the moon sighting) ----
  static const hijriMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static String hijri(DateTime d) {
    final jdn = (julian(d.year, d.month, d.day) + 0.5).floor();
    var l = jdn - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    l = l - 10631 * n + 354;
    final j = ((10985 - l) / 5316).floor() * ((50 * l) / 17719).floor() +
        (l / 5670).floor() * ((43 * l) / 15238).floor();
    l = l - ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() - (j / 16).floor() * ((15238 * j) / 43).floor() + 29;
    final m = ((24 * l) / 709).floor();
    final day = l - ((709 * m) / 24).floor();
    final y = 30 * n + j - 30;
    return '$day ${hijriMonths[(m - 1).clamp(0, 11)]} $y هـ';
  }
}
