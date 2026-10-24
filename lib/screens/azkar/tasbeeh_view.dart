import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';

/// Electronic tasbeeh (digital counter). State is saved on the device.
class TasbeehView extends StatefulWidget {
  const TasbeehView({super.key});

  @override
  State<TasbeehView> createState() => _TasbeehViewState();
}

class _TasbeehViewState extends State<TasbeehView> {
  static const List<String> _dhikrs = [
    'سُبْحَانَ اللَّهِ',
    'الْحَمْدُ لِلَّهِ',
    'اللَّهُ أَكْبَرُ',
    'لَا إِلَهَ إِلَّا اللَّهُ',
    'أَسْتَغْفِرُ اللَّهَ',
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
  ];

  // 0 means "open" (no target).
  static const List<int> _targets = [33, 99, 100, 1000, 0];

  static const String _kDhikr = 'tasbeeh_dhikr';
  static const String _kCount = 'tasbeeh_count';
  static const String _kTarget = 'tasbeeh_target';
  static const String _kTotal = 'tasbeeh_total';
  static const String _kRounds = 'tasbeeh_rounds';
  static const String _kVibrate = 'tasbeeh_vibrate';

  SharedPreferences? _prefs;
  int _dhikr = 0;
  int _count = 0;
  int _target = 33;
  int _total = 0;
  int _rounds = 0;
  bool _vibrate = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _dhikr = (prefs.getInt(_kDhikr) ?? 0).clamp(0, _dhikrs.length - 1);
        _count = prefs.getInt(_kCount) ?? 0;
        _target = prefs.getInt(_kTarget) ?? 33;
        _total = prefs.getInt(_kTotal) ?? 0;
        _rounds = prefs.getInt(_kRounds) ?? 0;
        _vibrate = prefs.getBool(_kVibrate) ?? true;
      });
    } catch (e) {
      debugPrint('Tasbeeh: could not load saved state: $e');
    }
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setInt(_kDhikr, _dhikr);
    prefs.setInt(_kCount, _count);
    prefs.setInt(_kTarget, _target);
    prefs.setInt(_kTotal, _total);
    prefs.setInt(_kRounds, _rounds);
    prefs.setBool(_kVibrate, _vibrate);
  }

  void _tap() {
    setState(() {
      _count++;
      _total++;
      if (_target > 0 && _count >= _target) {
        _rounds++;
        _count = 0;
        if (_vibrate) HapticFeedback.heavyImpact();
      } else if (_vibrate) {
        HapticFeedback.lightImpact();
      }
    });
    _save();
  }

  void _resetCurrent() {
    setState(() {
      _count = 0;
      _rounds = 0;
    });
    _save();
  }

  void _selectDhikr(int index) {
    setState(() {
      _dhikr = index;
      _count = 0;
      _rounds = 0;
    });
    _save();
  }

  void _selectTarget(int target) {
    setState(() {
      _target = target;
      _count = 0;
    });
    _save();
  }

  String _targetLabel(int t) => t == 0 ? 'مفتوح' : '$t';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        _target > 0 ? (_count / _target).clamp(0.0, 1.0).toDouble() : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // Dhikr picker
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dhikrs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return ChoiceChip(
                  label: Text(
                    _dhikrs[i],
                    style: const TextStyle(fontSize: 13),
                  ),
                  selected: _dhikr == i,
                  selectedColor: AppColors.secondary.withOpacity(0.2),
                  onSelected: (_) => _selectDhikr(i),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Current dhikr text
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              _dhikrs[_dhikr],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.8,
                fontFamily: 'serif',
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Big counter button with progress ring
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: _target > 0 ? progress : 0,
                    strokeWidth: 8,
                    backgroundColor: AppColors.secondary.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.secondary,
                    ),
                  ),
                ),
                Container(
                  width: 210,
                  height: 210,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: AppColors.azkarCardGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _tap,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _target > 0 ? 'من $_target' : 'اضغط للتسبيح',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats
          Row(
            children: [
              Expanded(child: _statCard(theme, 'الدورات المكتملة', '$_rounds')),
              const SizedBox(width: 12),
              Expanded(child: _statCard(theme, 'إجمالي التسبيحات', '$_total')),
            ],
          ),
          const SizedBox(height: 20),

          // Target picker
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'العدد المطلوب',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _targets.map((t) {
              return ChoiceChip(
                label: Text(_targetLabel(t)),
                selected: _target == t,
                selectedColor: AppColors.secondary.withOpacity(0.2),
                onSelected: (_) => _selectTarget(t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Controls
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الاهتزاز عند كل تسبيحة'),
            value: _vibrate,
            activeColor: AppColors.secondary,
            onChanged: (v) {
              setState(() => _vibrate = v);
              _save();
            },
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _resetCurrent,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تصفير العدّاد'),
          ),
        ],
      ),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
