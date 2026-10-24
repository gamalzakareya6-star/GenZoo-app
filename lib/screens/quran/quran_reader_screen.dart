import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/quran_service.dart';

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

  @override
  void initState() {
    super.initState();
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
      _future = _service.getSurah(widget.surah.number);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = widget.surah.number;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.name),
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
            spans.add(TextSpan(text: '${a.text} ', style: textStyle));
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
                      widget.surah.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.surah.isMeccan ? 'مكية' : 'مدنية'} • '
                      '${toArabicDigits(widget.surah.ayahCount)} آية',
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
