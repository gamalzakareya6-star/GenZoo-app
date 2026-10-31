import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/quran_service.dart';
import '../../widgets/animations.dart';
import 'quran_reader_screen.dart';
import '../qibla/qibla_screen.dart';
import '../prayer/prayer_screen.dart';

/// Removes Arabic diacritics and unifies alef forms so search ignores them.
String _normalize(String input) {
  return input
      .replaceAll(RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
      .replaceAll(RegExp(r'[ٱآأإ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase()
      .trim();
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranService _service = QuranService();
  late Future<List<SurahInfo>> _future;
  String _query = '';
  int? _lastSurah;

  @override
  void initState() {
    super.initState();
    _future = _service.getSurahs();
    _loadLastSurah();
  }

  Future<void> _loadLastSurah() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _lastSurah = prefs.getInt('quran_last_surah'));
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _future = _service.getSurahs();
    });
  }

  Future<void> _openSurah(SurahInfo surah) async {
    await Navigator.push(
      context,
      AppRoute.fadeSlide(QuranReaderScreen(surah: surah)),
    );
    _loadLastSurah();
  }

  Future<void> _downloadAll() async {
    final cached = await _service.cachedCount();
    if (!mounted) return;
    if (cached >= 114) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المصحف كامل محمّل على جهازك بالفعل.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحميل المصحف للقراءة بدون إنترنت'),
        content: Text(
          'سيتم تحميل ${114 - cached} سورة (نص فقط، حجمه صغير). يُفضّل الاتصال بشبكة Wi-Fi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحميل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final progress = ValueNotifier<int>(cached);
    var cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('جارٍ التحميل...'),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: done / 114),
              const SizedBox(height: 12),
              Text('$done من 114 سورة'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.pop(ctx);
            },
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );

    String? errorMessage;
    try {
      await _service.downloadAll(
        onProgress: (done) => progress.value = done,
        isCancelled: () => cancelled,
      );
    } catch (e) {
      errorMessage = 'توقف التحميل بسبب مشكلة في الاتصال. يمكنك المتابعة لاحقاً.';
    }

    if (!mounted) return;
    if (!cancelled) {
      Navigator.of(context, rootNavigator: true).pop(); // close progress dialog
    }

    final total = await _service.cachedCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ??
              (total >= 114
                  ? 'تم تحميل المصحف كاملاً.'
                  : 'تم تحميل $total من 114 سورة.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<List<SurahInfo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'تعذّر تحميل فهرس السور. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final all = snapshot.data!;
          final q = _normalize(_query);
          final surahs = q.isEmpty
              ? all
              : all.where((s) {
                  return _normalize(s.name).contains(q) ||
                      s.englishName.toLowerCase().contains(q) ||
                      s.number.toString() == q;
                }).toList();

          SurahInfo? last;
          if (_lastSurah != null) {
            for (final s in all) {
              if (s.number == _lastSurah) last = s;
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن سورة بالاسم أو الرقم',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.push(
                        context,
                        AppRoute.fadeSlide(const PrayerScreen()),
                      ),
                      icon: const Icon(Icons.access_time_filled_rounded),
                      tooltip: 'مواقيت الصلاة',
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.push(
                        context,
                        AppRoute.fadeSlide(const QiblaScreen()),
                      ),
                      icon: const Icon(Icons.explore_rounded),
                      tooltip: 'اتجاه القبلة',
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: _downloadAll,
                      icon: const Icon(Icons.download_for_offline_rounded),
                      tooltip: 'تحميل المصحف للقراءة بدون إنترنت',
                    ),
                  ],
                ),
              ),
              if (last != null && q.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    color: AppColors.secondary.withOpacity(0.1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.bookmark_rounded,
                          color: AppColors.secondary),
                      title: const Text('متابعة القراءة'),
                      subtitle: Text(last.name),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => _openSurah(last!),
                    ),
                  ),
                ),
              Expanded(
                child: surahs.isEmpty
                    ? const Center(child: Text('لا توجد نتائج.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: surahs.length,
                        itemBuilder: (context, index) {
                          final s = surahs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.cardBorderDark
                                    : AppColors.cardBorderLight,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.secondary.withOpacity(0.12),
                                child: Text(
                                  toArabicDigits(s.number),
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              subtitle: Text(
                                '${s.isMeccan ? 'مكية' : 'مدنية'} • '
                                '${toArabicDigits(s.ayahCount)} آية',
                              ),
                              onTap: () => _openSurah(s),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
