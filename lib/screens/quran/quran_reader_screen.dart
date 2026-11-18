import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/quran_service.dart';
import '../../core/services/quran_audio.dart';

const String _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

String toArabicDigits(int n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}

class QuranReaderScreen extends StatefulWidget {
  final SurahInfo surah;

  const QuranReaderScreen({super.key, required this.surah});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  static const String _kFontSize = 'quran_font_size';
  static const String _kLastSurah = 'quran_last_surah';

  final QuranService _service = QuranService();
  late Future<List<QuranAyah>> _future;
  double _fontSize = 26;
  final QuranAudioController _audio = QuranAudioController.instance;
  final Map<int, TapGestureRecognizer> _tapRecognizers = {};
  late SurahInfo _displayedSurahInfo;
  bool _followingAudio = false;

  TapGestureRecognizer _recognizerFor(int ayah) {
    return _tapRecognizers.putIfAbsent(
      ayah,
      () => TapGestureRecognizer()
        ..onTap = () => _audio.playFrom(_displayedSurahInfo.number, ayah),
    );
  }

  @override
  void dispose() {
    for (final r in _tapRecognizers.values) {
      r.dispose();
    }
    // The audio controller is a single app-wide instance (see
    // QuranAudioController.instance) so playback and the notification
    // controls keep going after leaving this screen — it is never
    // disposed here.
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _displayedSurahInfo = widget.surah;
    _future = _service.getSurah(widget.surah.number);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSurah, widget.surah.number);
      final size = prefs.getDouble(_kFontSize);
      if (size != null && mounted) {
        setState(() => _fontSize = size.clamp(18.0, 44.0).toDouble());
      }
    } catch (e) {
      debugPrint('Quran reader prefs error: $e');
    }
  }

  Future<void> _changeFont(double delta) async {
    final next = (_fontSize + delta).clamp(18.0, 44.0).toDouble();
    setState(() => _fontSize = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kFontSize, next);
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _future = _service.getSurah(_displayedSurahInfo.number);
    });
  }

  /// Once the audio controller auto-advances into the next surah (see
  /// QuranAudioController._onSurahCompleted), this brings the text view
  /// along with it — just like a music player showing the next track's
  /// info once it starts playing.
  void _followAudioAdvance() {
    final target = _audio.currentSurah;
    if (target == null ||
        target == _displayedSurahInfo.number ||
        _followingAudio) {
      return;
    }
    _followingAudio = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final surahs = await _service.getSurahs();
        SurahInfo? info;
        for (final s in surahs) {
          if (s.number == target) {
            info = s;
            break;
          }
        }
        if (!mounted || info == null) return;
        setState(() {
          _displayedSurahInfo = info!;
          _future = _service.getSurah(target);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kLastSurah, target);
      } catch (_) {
        // Audio keeps playing regardless of whether the text view could
        // follow along — nothing to show the student for this failure.
      } finally {
        _followingAudio = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _audio,
      builder: (context, _) {
        _followAudioAdvance();
        return _buildScaffold(context, theme, _displayedSurahInfo.number);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, ThemeData theme, int number) {
    return Scaffold(
      bottomNavigationBar: _AudioBar(audio: _audio, surah: _displayedSurahInfo),
      appBar: AppBar(
        title: Text(_displayedSurahInfo.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded),
            tooltip: 'تصغير الخط',
            onPressed: () => _changeFont(-2),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded),
            tooltip: 'تكبير الخط',
            onPressed: () => _changeFont(2),
          ),
        ],
      ),
      body: FutureBuilder<List<QuranAyah>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorView(onRetry: _retry);
          }

          final ayahs = snapshot.data!;
          final textStyle = GoogleFonts.getFont(
            'Amiri',
            fontSize: _fontSize,
            height: 2.1,
            color: theme.colorScheme.onSurface,
          );
          final markerStyle = textStyle.copyWith(
            color: AppColors.secondary,
            fontSize: _fontSize * 0.8,
          );

          final spans = <InlineSpan>[];
          for (final a in ayahs) {
            final isCurrent = _audio.currentAyah == a.number &&
                (_audio.isPlaying || _audio.isLoading);
            spans.add(
              TextSpan(
                text: '${a.text} ',
                style: isCurrent
                    ? textStyle.copyWith(
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                      )
                    : textStyle,
                recognizer: _recognizerFor(a.number),
              ),
            );
            spans.add(
              TextSpan(
                text: '﴿${toArabicDigits(a.number)}﴾ ',
                style: markerStyle,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
            children: [
              // Surah header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.azkarCardGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _displayedSurahInfo.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_displayedSurahInfo.isMeccan ? 'مكية' : 'مدنية'} • '
                      '${toArabicDigits(_displayedSurahInfo.ayahCount)} آية',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Basmala (not shown for Al-Fatiha, where it is ayah 1,
              // nor for At-Tawbah).
              if (number != 1 && number != 9)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _basmala,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: textStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),

              Directionality(
                textDirection: TextDirection.rtl,
                child: Text.rich(
                  TextSpan(children: spans),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'تعذّر تحميل السورة. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.\n'
              'بعد التحميل الأول تُقرأ السورة بدون إنترنت.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom player: reciter, previous / play / next, current ayah.
class _AudioBar extends StatelessWidget {
  final QuranAudioController audio;
  final SurahInfo surah;

  const _AudioBar({required this.audio, required this.surah});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final err = audio.error;
    if (err != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        audio.clearError();
      });
    }

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              PopupMenuButton<int>(
                tooltip: 'اختر القارئ',
                initialValue: audio.reciterIndex,
                onSelected: audio.setReciter,
                itemBuilder: (_) => [
                  for (var i = 0; i < quranReciters.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      child: Text(quranReciters[i].name),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.record_voice_over_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          audio.reciter.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (audio.currentAyah != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'آية ${toArabicDigits(audio.currentAyah!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: audio.hasAudio ? audio.previous : null,
              ),
              audio.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : IconButton.filled(
                      icon: Icon(audio.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      tooltip: audio.isPlaying ? 'إيقاف مؤقت' : 'تشغيل السورة',
                      onPressed: () => audio.isPlaying
                          ? audio.pause()
                          : audio.resumeOrPlay(surah.number),
                    ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: audio.hasAudio ? audio.next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
