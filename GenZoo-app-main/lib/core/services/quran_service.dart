import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SurahInfo {
  final int number;
  final String name;
  final String englishName;
  final int ayahCount;
  final String revelationType;

  const SurahInfo({
    required this.number,
    required this.name,
    required this.englishName,
    required this.ayahCount,
    required this.revelationType,
  });

  bool get isMeccan => revelationType.toLowerCase() == 'meccan';

  factory SurahInfo.fromJson(Map<String, dynamic> json) {
    return SurahInfo(
      number: (json['number'] as num).toInt(),
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      ayahCount: (json['numberOfAyahs'] as num?)?.toInt() ?? 0,
      revelationType: json['revelationType'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'englishName': englishName,
        'numberOfAyahs': ayahCount,
        'revelationType': revelationType,
      };
}

class QuranAyah {
  final int number; // number inside the surah
  final String text;

  const QuranAyah({required this.number, required this.text});
}

/// Loads the Quran text (Uthmani script) from the public alquran.cloud API
/// and caches every surah on the device, so it can be read offline later.
class QuranService {
  static const String _base = 'https://api.alquran.cloud/v1';
  static const String _edition = 'quran-uthmani';
  static const String _surahsKey = 'quran_surahs_v1';
  static String _surahKey(int n) => 'quran_surah_v1_$n';
  static const Duration _timeout = Duration(seconds: 25);

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response =
        await http.get(Uri.parse('$_base$path')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }
    return decoded;
  }

  Future<List<SurahInfo>> getSurahs() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_surahsKey);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        final surahs = list
            .map((e) => SurahInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        if (surahs.length == 114) return surahs;
      } catch (e) {
        debugPrint('Quran: bad surah list cache: $e');
      }
    }

    final json = await _getJson('/surah');
    final data = json['data'] as List<dynamic>;
    final surahs = data
        .map((e) => SurahInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    if (surahs.length != 114) {
      throw Exception('Unexpected surah count: ${surahs.length}');
    }
    await prefs.setString(
      _surahsKey,
      jsonEncode(surahs.map((s) => s.toJson()).toList()),
    );
    return surahs;
  }

  bool isCached(SharedPreferences prefs, int number) =>
      prefs.containsKey(_surahKey(number));

  Future<List<QuranAyah>> getSurah(int number) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_surahKey(number));
    if (cached != null) {
      try {
        return _decodeAyahs(cached);
      } catch (e) {
        debugPrint('Quran: bad cache for surah $number: $e');
      }
    }

    final json = await _getJson('/surah/$number/$_edition');
    final data = json['data'] as Map<String, dynamic>;
    final ayahsJson = data['ayahs'] as List<dynamic>;

    final ayahs = <QuranAyah>[];
    for (final a in ayahsJson) {
      final m = a as Map<String, dynamic>;
      var text = (m['text'] as String? ?? '').trim();
      final n = (m['numberInSurah'] as num).toInt();

      // The API prefixes the first ayah of every surah (except Al-Fatiha and
      // At-Tawbah) with the Basmala. We show the Basmala as a header instead,
      // so drop its four words from the first ayah.
      if (n == 1 && number != 1 && number != 9) {
        final words = text.split(RegExp(r'\s+'));
        if (words.length > 4) {
          text = words.sublist(4).join(' ');
        }
      }
      ayahs.add(QuranAyah(number: n, text: text));
    }

    if (ayahs.isEmpty) throw Exception('Empty surah');

    await prefs.setString(
      _surahKey(number),
      jsonEncode(ayahs.map((a) => [a.number, a.text]).toList()),
    );
    return ayahs;
  }

  List<QuranAyah> _decodeAyahs(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) {
      final pair = e as List<dynamic>;
      return QuranAyah(
        number: (pair[0] as num).toInt(),
        text: pair[1] as String,
      );
    }).toList();
  }

  /// Downloads every surah for offline reading. [onProgress] receives the
  /// number of surahs that are available so far (0..114).
  Future<void> downloadAll({
    required void Function(int done) onProgress,
    required bool Function() isCancelled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var done = 0;
    for (var n = 1; n <= 114; n++) {
      if (isCancelled()) return;
      if (!isCached(prefs, n)) {
        await getSurah(n);
      }
      done++;
      onProgress(done);
    }
  }

  Future<int> cachedCount() async {
    final prefs = await SharedPreferences.getInstance();
    var count = 0;
    for (var n = 1; n <= 114; n++) {
      if (isCached(prefs, n)) count++;
    }
    return count;
  }
}
