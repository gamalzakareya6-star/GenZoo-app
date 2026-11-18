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

  factory SurahInfo.fromJson(Map<String, dynamic> json) => SurahInfo(
        number: (json['number'] as num).toInt(),
        name: json['name'] as String? ?? '',
        englishName: json['englishName'] as String? ?? '',
        ayahCount: (json['numberOfAyahs'] as num?)?.toInt() ?? 0,
        revelationType: json['revelationType'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'englishName': englishName,
        'numberOfAyahs': ayahCount,
        'revelationType': revelationType,
      };
}

class QuranAyah {
  final int number;
  final String text;

  const QuranAyah({required this.number, required this.text});
}

/// Loads the Uthmani Quran text without rewriting, trimming words from, or
/// otherwise altering any ayah. Cache v2 intentionally invalidates older
/// entries that were stored after the unsafe four-word Basmala removal.
class QuranService {
  static const String _base = 'https://api.alquran.cloud/v1';
  static const String _edition = 'quran-uthmani';
  static const String _surahsKey = 'quran_surahs_v2';
  static String _surahKey(int n) => 'quran_surah_v2_$n';
  static const Duration _timeout = Duration(seconds: 25);

  static const List<int> ayahCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
    111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
    54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
    49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30,
    20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4,
    5, 6,
  ];

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await http.get(Uri.parse('$_base$path')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Quran API HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['code'] != 200) {
      throw Exception('Unexpected Quran API response');
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
        if (_validSurahList(surahs)) return surahs;
      } catch (e) {
        debugPrint('Quran: invalid surah index cache: $e');
      }
    }

    final json = await _getJson('/surah');
    final data = json['data'] as List<dynamic>;
    final surahs = data
        .map((e) => SurahInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    if (!_validSurahList(surahs)) {
      throw Exception('Quran API returned an invalid surah index');
    }
    await prefs.setString(
      _surahsKey,
      jsonEncode(surahs.map((s) => s.toJson()).toList()),
    );
    return surahs;
  }

  bool _validSurahList(List<SurahInfo> surahs) {
    if (surahs.length != 114) return false;
    for (var i = 0; i < 114; i++) {
      if (surahs[i].number != i + 1 ||
          surahs[i].ayahCount != ayahCounts[i] ||
          surahs[i].name.isEmpty) {
        return false;
      }
    }
    return true;
  }

  bool isCached(SharedPreferences prefs, int number) {
    if (number < 1 || number > 114) return false;
    final raw = prefs.getString(_surahKey(number));
    if (raw == null) return false;
    try {
      _decodeAyahs(raw, expectedCount: ayahCounts[number - 1]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<QuranAyah>> getSurah(int number) async {
    if (number < 1 || number > 114) {
      throw RangeError.range(number, 1, 114, 'surah number');
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_surahKey(number));
    if (cached != null) {
      try {
        return _decodeAyahs(cached, expectedCount: ayahCounts[number - 1]);
      } catch (e) {
        debugPrint('Quran: invalid cache for surah $number: $e');
      }
    }

    final json = await _getJson('/surah/$number/$_edition');
    final data = json['data'] as Map<String, dynamic>;
    final responseSurah = (data['number'] as num?)?.toInt();
    final responseCount = (data['numberOfAyahs'] as num?)?.toInt();
    if (responseSurah != number ||
        responseCount != ayahCounts[number - 1]) {
      throw Exception('Quran API returned mismatched surah metadata');
    }

    final ayahsJson = data['ayahs'] as List<dynamic>;
    final ayahs = <QuranAyah>[];
    for (final item in ayahsJson) {
      final map = item as Map<String, dynamic>;
      final ayahNumber = (map['numberInSurah'] as num).toInt();
      final text = (map['text'] as String? ?? '');
      // Preserve the exact text supplied by the Uthmani edition. In
      // particular, never remove a guessed number of words for Basmala:
      // Basmala display is a UI concern, not a text transformation.
      ayahs.add(QuranAyah(number: ayahNumber, text: text));
    }

    _validateAyahs(ayahs, ayahCounts[number - 1]);
    await prefs.setString(
      _surahKey(number),
      jsonEncode(ayahs.map((a) => [a.number, a.text]).toList()),
    );
    return ayahs;
  }

  List<QuranAyah> _decodeAyahs(String raw, {required int expectedCount}) {
    final list = jsonDecode(raw) as List<dynamic>;
    final ayahs = list.map((item) {
      final pair = item as List<dynamic>;
      if (pair.length != 2) throw const FormatException('Invalid ayah cache row');
      return QuranAyah(
        number: (pair[0] as num).toInt(),
        text: pair[1] as String,
      );
    }).toList();
    _validateAyahs(ayahs, expectedCount);
    return ayahs;
  }

  void _validateAyahs(List<QuranAyah> ayahs, int expectedCount) {
    if (ayahs.length != expectedCount) {
      throw FormatException(
        'Expected $expectedCount ayahs, received ${ayahs.length}',
      );
    }
    for (var i = 0; i < ayahs.length; i++) {
      if (ayahs[i].number != i + 1 || ayahs[i].text.trim().isEmpty) {
        throw FormatException('Invalid ayah at position ${i + 1}');
      }
    }
  }

  Future<void> downloadAll({
    required void Function(int done) onProgress,
    required bool Function() isCancelled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var done = 0;
    for (var number = 1; number <= 114; number++) {
      if (isCancelled()) return;
      if (!isCached(prefs, number)) {
        await getSurah(number);
      }
      done++;
      onProgress(done);
    }
  }

  Future<int> cachedCount() async {
    final prefs = await SharedPreferences.getInstance();
    var count = 0;
    for (var number = 1; number <= 114; number++) {
      if (isCached(prefs, number)) count++;
    }
    return count;
  }
}
