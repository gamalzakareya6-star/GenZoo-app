import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_service.dart';

/// A reciter available from the free Islamic Network audio CDN
/// (https://alquran.cloud/cdn). Files are one mp3 per ayah.
class Reciter {
  final String name;
  final String edition; // CDN edition id
  final int bitrate;
  final String keyword; // used to find the edition if the id differs

  const Reciter(this.name, this.edition, this.bitrate, this.keyword);
}

const List<Reciter> quranReciters = [
  Reciter('مشاري العفاسي', 'ar.alafasy', 128, 'alafasy'),
  Reciter('عبد الباسط عبد الصمد', 'ar.abdulbasit', 192, 'abdul'),
  Reciter('محمد صديق المنشاوي', 'ar.minshawi', 128, 'minshawi'),
  Reciter('محمود خليل الحصري', 'ar.husary', 128, 'husary'),
  Reciter('ماهر المعيقلي', 'ar.mahermuaiqly', 128, 'muaiqly'),
  Reciter('عبد الرحمن السديس', 'ar.sudais', 192, 'sudais'),
];

const List<int> _ayahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
  54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
  49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30,
  20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4,
  5, 6,
];

/// Plays a surah ayah by ayah, starts from any ayah the user taps, and —
/// once a surah finishes — automatically continues into the next one, like
/// a normal music player playing through an album. Kept as a single
/// app-wide instance (not tied to any one screen) so playback and the
/// music-style notification controls (via just_audio_background) survive
/// navigating away from the Quran reader screen.
class QuranAudioController extends ChangeNotifier {
  static const String _kReciter = 'quran_reciter_index';

  static final QuranAudioController instance = QuranAudioController._();

  final AudioPlayer _player = AudioPlayer();
  final QuranService _service = QuranService();
  int _reciterIndex = 0;
  int? _surah;
  int _firstAyah = 1; // ayah number of playlist item 0
  int? _currentAyah;
  bool _playing = false;
  bool _loading = false;
  String? _error;

  static Map<String, String>? _resolvedEditions;
  static Map<int, String>? _surahNames;
  late final StreamSubscription<int?> _indexSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;
  int _requestId = 0;
  bool _advancing = false;

  QuranAudioController._() {
    _indexSubscription = _player.currentIndexStream.listen((i) {
      if (i == null || _surah == null) return;
      _currentAyah = _firstAyah + i;
      notifyListeners();
    });
    _stateSubscription = _player.playerStateStream.listen((s) {
      _playing = s.playing;
      _loading = s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering;
      if (s.processingState == ProcessingState.completed && !_advancing) {
        _onSurahCompleted();
      }
      notifyListeners();
    });
    _loadReciter();
  }

  Reciter get reciter => quranReciters[_reciterIndex];
  int get reciterIndex => _reciterIndex;
  int? get currentSurah => _surah;
  int? get currentAyah => _currentAyah;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get hasAudio => _surah != null && _currentAyah != null;

  /// Called when the current surah's last ayah finishes playing. Moves on
  /// to the next surah automatically (112 → الناس), matching how a music
  /// app flips to the next track at the end of an album. Playback simply
  /// stops after سورة الناس (114), the last surah.
  Future<void> _onSurahCompleted() async {
    if (_advancing) return;
    _advancing = true;
    final surah = _surah;
    _currentAyah = null;
    _playing = false;
    try {
      if (surah != null && surah < 114) {
        await playFrom(surah + 1, 1);
      }
    } finally {
      _advancing = false;
    }
  }

  Future<String> _surahName(int surah) async {
    try {
      _surahNames ??= {
        for (final s in await _service.getSurahs()) s.number: s.name,
      };
    } catch (_) {
      _surahNames ??= {};
    }
    return _surahNames![surah] ?? 'سورة $surah';
  }

  Future<void> _loadReciter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final i = prefs.getInt(_kReciter);
      if (i != null && i >= 0 && i < quranReciters.length) {
        _reciterIndex = i;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setReciter(int index) async {
    if (index < 0 || index >= quranReciters.length || index == _reciterIndex) return;
    _reciterIndex = index;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kReciter, index);
    } catch (_) {}
    // Continue from the same ayah with the new reciter.
    final s = _surah;
    final a = _currentAyah;
    if (s != null && a != null && _playing) {
      await playFrom(s, a);
    }
  }

  /// The CDN edition ids are checked against the live list once, so a wrong
  /// id above never breaks playback.
  Future<String> _editionFor(Reciter r) async {
    try {
      _resolvedEditions ??= await _fetchEditions();
    } catch (_) {
      _resolvedEditions = <String, String>{};
    }
    final map = _resolvedEditions!;
    if (map.isEmpty || map.containsKey(r.edition)) return r.edition;
    for (final e in map.entries) {
      if (e.value.toLowerCase().contains(r.keyword)) return e.key;
    }
    return r.edition;
  }

  Future<Map<String, String>> _fetchEditions() async {
    final res = await http
        .get(Uri.parse(
            'https://api.alquran.cloud/v1/edition?format=audio&language=ar&type=versebyverse'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Edition API HTTP ${res.statusCode}');
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>;
    final out = <String, String>{};
    for (final e in data) {
      out[e['identifier'] as String] = '${e['englishName']}';
    }
    return out;
  }

  int _globalAyah(int surah, int ayah) {
    var n = 0;
    for (var i = 0; i < surah - 1; i++) {
      n += _ayahCounts[i];
    }
    return n + ayah;
  }

  /// Plays [surah] starting at [ayah] and continues to the end of the
  /// surah — then automatically into the next one (see
  /// [_onSurahCompleted]), exactly like flipping to the next track in a
  /// music player once the current one ends.
  Future<void> playFrom(int surah, int ayah) async {
    if (surah < 1 || surah > _ayahCounts.length) {
      _error = 'رقم السورة غير صحيح.';
      notifyListeners();
      return;
    }
    final total = _ayahCounts[surah - 1];
    if (ayah < 1 || ayah > total) {
      _error = 'رقم الآية غير صحيح.';
      notifyListeners();
      return;
    }
    final requestId = ++_requestId;
    _error = null;
    final start = ayah;
    try {
      final r = reciter;
      final edition = await _editionFor(r);
      if (requestId != _requestId) return;
      final name = await _surahName(surah);
      if (requestId != _requestId) return;
      final sources = <AudioSource>[
        for (var a = start; a <= total; a++)
          AudioSource.uri(
            Uri.parse(
                'https://cdn.islamic.network/quran/audio/${r.bitrate}/$edition/${_globalAyah(surah, a)}.mp3'),
            tag: MediaItem(
              id: '$surah-$a',
              album: 'القرآن الكريم',
              title: name,
              artist: r.name,
            ),
          ),
      ];
      if (requestId != _requestId) return;
      _surah = surah;
      _firstAyah = start;
      _currentAyah = start;
      _loading = true;
      notifyListeners();
      await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
      if (requestId != _requestId) return;
      await _player.play();
    } catch (e) {
      if (requestId != _requestId) return;
      debugPrint('Quran audio error: $e');
      _error = 'تعذّر تشغيل الصوت. تأكد من الاتصال بالإنترنت وحاول مرة أخرى.';
      _loading = false;
      _playing = false;
      notifyListeners();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> resumeOrPlay(int surah) async {
    if (_surah == surah && _currentAyah != null) {
      await _player.play();
    } else {
      await playFrom(surah, 1);
    }
  }

  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> previous() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  Future<void> stop() async {
    ++_requestId;
    await _player.stop();
    _currentAyah = null;
    _playing = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
  }

  @override
  void dispose() {
    ++_requestId;
    _indexSubscription.cancel();
    _stateSubscription.cancel();
    _player.dispose();
    super.dispose();
  }
}
