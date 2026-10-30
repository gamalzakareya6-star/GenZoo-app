import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/data/motivation.dart';
import '../core/services/daily_notifications.dart';

class ExamEntry {
  final String name;
  final DateTime date;
  const ExamEntry(this.name, this.date);

  int daysLeft([DateTime? from]) {
    final n = from ?? DateTime.now();
    return DateTime(date.year, date.month, date.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  Map<String, dynamic> toJson() => {'n': name, 'd': date.millisecondsSinceEpoch};
  factory ExamEntry.fromJson(Map<String, dynamic> j) =>
      ExamEntry(j['n'] as String? ?? '', DateTime.fromMillisecondsSinceEpoch(j['d'] as int? ?? 0));
}

/// The "Daily" page data: study streak, exam countdowns and the reminder
/// switch. Everything is stored on the device.
class DailyProvider extends ChangeNotifier {
  static const _key = 'daily_v1';

  int _streak = 0;
  int _best = 0;
  String _lastDay = ''; // yyyy-mm-dd of the last study day
  bool _remind = true;
  final List<ExamEntry> _exams = [];
  bool _loaded = false;

  DailyProvider() {
    _load();
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get studiedToday => _lastDay == _dayKey(DateTime.now());

  /// The streak as shown: it is broken when yesterday was missed.
  int get streak {
    if (_lastDay.isEmpty) return 0;
    if (studiedToday) return _streak;
    final y = DateTime.now().subtract(const Duration(days: 1));
    return _lastDay == _dayKey(y) ? _streak : 0;
  }

  int get best => _best;
  bool get remind => _remind;
  bool get loaded => _loaded;

  List<ExamEntry> get exams {
    final list = _exams.where((e) => e.daysLeft() >= 0).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  ExamEntry? get nextExam => exams.isEmpty ? null : exams.first;

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _streak = (j['s'] as int?) ?? 0;
        _best = (j['b'] as int?) ?? 0;
        _lastDay = (j['l'] as String?) ?? '';
        _remind = (j['r'] as bool?) ?? true;
        _exams
          ..clear()
          ..addAll((j['e'] as List<dynamic>? ?? []).map((e) => ExamEntry.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
    _reschedule();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({'s': _streak, 'b': _best, 'l': _lastDay, 'r': _remind, 'e': _exams.map((e) => e.toJson()).toList()}),
      );
    } catch (_) {}
  }

  void _reschedule() {
    DailyNotifications.reschedule(
      enabled: _remind,
      streak: streak,
      studiedToday: studiedToday,
      exams: exams,
    );
  }

  /// Records a study action. Shows an encouraging message the first time it
  /// happens each day (pass a [context] to show it).
  void markStudied([BuildContext? context]) {
    if (!_loaded || studiedToday) return;
    final now = DateTime.now();
    final y = _dayKey(now.subtract(const Duration(days: 1)));
    _streak = _lastDay == y ? _streak + 1 : 1;
    if (_streak > _best) _best = _streak;
    _lastDay = _dayKey(now);
    notifyListeners();
    _save();
    _reschedule();
    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('🔥 ${Motivation.streakMessage(_streak)}'), duration: const Duration(seconds: 4)),
      );
    }
  }

  void setRemind(bool v) {
    _remind = v;
    notifyListeners();
    _save();
    _reschedule();
  }

  void addExam(String name, DateTime date) {
    _exams.add(ExamEntry(name.trim(), date));
    notifyListeners();
    _save();
    _reschedule();
  }

  void removeExam(ExamEntry e) {
    _exams.removeWhere((x) => x.name == e.name && x.date == e.date);
    notifyListeners();
    _save();
    _reschedule();
  }
}
