import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';

class _Subject {
  String name;
  DateTime? exam;
  int difficulty; // 1..3
  _Subject(this.name, this.exam, this.difficulty);

  Map<String, dynamic> toJson() => {'n': name, 'e': exam?.millisecondsSinceEpoch, 'd': difficulty};
  factory _Subject.fromJson(Map<String, dynamic> j) => _Subject(
        j['n'] as String? ?? '',
        j['e'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['e'] as int),
        (j['d'] as int?) ?? 2,
      );
}

class _Slot {
  final DateTime start;
  final int minutes;
  final String subject;
  _Slot(this.start, this.minutes, this.subject);
}

/// اقتراح الجدول الدراسي: builds a 7-day plan from subjects, difficulty and
/// exam dates. Everything stays on the device.
class StudyScheduleScreen extends StatefulWidget {
  const StudyScheduleScreen({super.key});

  @override
  State<StudyScheduleScreen> createState() => _StudyScheduleScreenState();
}

class _StudyScheduleScreenState extends State<StudyScheduleScreen> {
  static const _key = 'study_schedule_v1';
  static const _dayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  final List<_Subject> _subjects = [];
  double _hours = 3;
  int _sessionMin = 50;
  TimeOfDay _start = const TimeOfDay(hour: 17, minute: 0);
  final Set<int> _days = {1, 2, 3, 4, 5, 6, 7}; // DateTime.weekday
  List<_Slot> _plan = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _subjects
          ..clear()
          ..addAll((j['s'] as List<dynamic>? ?? []).map((e) => _Subject.fromJson(e as Map<String, dynamic>)));
        _hours = (j['h'] as num?)?.toDouble() ?? 3;
        _sessionMin = (j['m'] as int?) ?? 50;
        _start = TimeOfDay(hour: (j['th'] as int?) ?? 17, minute: (j['tm'] as int?) ?? 0);
        _days
          ..clear()
          ..addAll((j['days'] as List<dynamic>? ?? [1, 2, 3, 4, 5, 6, 7]).cast<int>());
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({
          's': _subjects.map((e) => e.toJson()).toList(),
          'h': _hours,
          'm': _sessionMin,
          'th': _start.hour,
          'tm': _start.minute,
          'days': _days.toList(),
        }),
      );
    } catch (_) {}
  }

  /// Weight grows with difficulty and as the exam gets closer.
  double _weight(_Subject s, DateTime day) {
    var w = s.difficulty.toDouble();
    if (s.exam != null) {
      final left = s.exam!.difference(day).inDays;
      if (left < 0) return 0;
      w *= left <= 3 ? 3 : left <= 7 ? 2 : left <= 14 ? 1.5 : 1;
    }
    return w;
  }

  void _generate() {
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف مادة واحدة على الأقل.')));
      return;
    }
    final today = DateTime.now();
    final plan = <_Slot>[];
    final credit = <_Subject, double>{for (final s in _subjects) s: 0};
    final perDay = (_hours * 60 / _sessionMin).floor().clamp(1, 12);

    for (var i = 0; i < 7; i++) {
      final day = DateTime(today.year, today.month, today.day).add(Duration(days: i));
      if (!_days.contains(day.weekday)) continue;
      var t = DateTime(day.year, day.month, day.day, _start.hour, _start.minute);
      for (var k = 0; k < perDay; k++) {
        // Smooth weighted round-robin: the subject with the most accumulated credit goes next.
        final active = _subjects.where((s) => _weight(s, day) > 0).toList();
        if (active.isEmpty) break;
        final total = active.fold<double>(0, (a, s) => a + _weight(s, day));
        for (final s in active) {
          credit[s] = credit[s]! + _weight(s, day);
        }
        active.sort((a, b) => credit[b]!.compareTo(credit[a]!));
        final pick = active.first;
        credit[pick] = credit[pick]! - total;
        plan.add(_Slot(t, _sessionMin, pick.name));
        t = t.add(Duration(minutes: _sessionMin + 10));
      }
    }
    setState(() => _plan = plan);
    _save();
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dayLabel(DateTime d) => '${_dayNames[d.weekday - 1]} ${d.day}/${d.month}';

  String _asText() {
    final b = StringBuffer('جدولي الدراسي (GenZoo)\n');
    String? last;
    for (final s in _plan) {
      final l = _dayLabel(s.start);
      if (l != last) {
        b.writeln('\n$l');
        last = l;
      }
      b.writeln('• ${_hm(s.start)} - ${s.subject} (${s.minutes} د)');
    }
    return b.toString();
  }

  Future<void> _addSubject() async {
    final name = TextEditingController();
    DateTime? exam;
    var diff = 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('مادة جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('سهلة')),
                ButtonSegment(value: 2, label: Text('متوسطة')),
                ButtonSegment(value: 3, label: Text('صعبة')),
              ],
              selected: {diff},
              onSelectionChanged: (v) => setS(() => diff = v.first),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(exam == null ? 'موعد الامتحان (اختياري)' : '${exam!.day}/${exam!.month}/${exam!.year}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now().add(const Duration(days: 14)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setS(() => exam = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      setState(() => _subjects.add(_Subject(name.text.trim(), exam, diff)));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اقتراح الجدول الدراسي'),
        actions: [
          if (_plan.isNotEmpty)
            IconButton(icon: const Icon(Icons.share_rounded), onPressed: () => Share.share(_asText())),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('موادك', style: TextStyle(fontWeight: FontWeight.bold))),
          TextButton.icon(onPressed: _addSubject, icon: const Icon(Icons.add_rounded), label: const Text('إضافة')),
        ]),
        if (_subjects.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('لم تضف مواد بعد.')),
        for (var i = 0; i < _subjects.length; i++)
          Card(
            child: ListTile(
              title: Text(_subjects[i].name),
              subtitle: Text([
                ['سهلة', 'متوسطة', 'صعبة'][_subjects[i].difficulty - 1],
                if (_subjects[i].exam != null)
                  'امتحان ${_subjects[i].exam!.day}/${_subjects[i].exam!.month}',
              ].join(' • ')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () {
                  setState(() => _subjects.removeAt(i));
                  _save();
                },
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('ساعات المذاكرة يومياً: ${_hours.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: _hours, min: 1, max: 8, divisions: 14, onChanged: (v) => setState(() => _hours = v), onChangeEnd: (_) => _save()),
        Row(children: [
          const Text('مدة الجلسة: '),
          DropdownButton<int>(
            value: _sessionMin,
            items: const [30, 45, 50, 60, 90].map((m) => DropdownMenuItem(value: m, child: Text('$m د'))).toList(),
            onChanged: (v) {
              setState(() => _sessionMin = v ?? 50);
              _save();
            },
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule_rounded),
            label: Text('البداية ${_start.format(context)}'),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _start);
              if (t != null) {
                setState(() => _start = t);
                _save();
              }
            },
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(_dayNames[d - 1]),
              selected: _days.contains(d),
              onSelected: (v) {
                setState(() => v ? _days.add(d) : _days.remove(d));
                _save();
              },
            ),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('اقترح جدول الأسبوع')),
        const SizedBox(height: 16),
        ..._planWidgets(),
      ]),
    );
  }

  List<Widget> _planWidgets() {
    final out = <Widget>[];
    String? last;
    for (final s in _plan) {
      final l = _dayLabel(s.start);
      if (l != last) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(l, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ));
        last = l;
      }
      out.add(Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: Text(_hm(s.start), style: const TextStyle(fontWeight: FontWeight.bold)),
          title: Text(s.subject),
          trailing: Text('${s.minutes} د'),
        ),
      ));
    }
    return out;
  }
}
