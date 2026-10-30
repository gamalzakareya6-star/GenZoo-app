import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/data/motivation.dart';
import '../../core/services/camp_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_provider.dart';
import '../../providers/feature_flags.dart';
import '../../widgets/animations.dart';
import '../camps/camp_detail_screen.dart';

String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Compact card at the top of the home feed: streak + today's line + next exam.
class DailyCard extends StatelessWidget {
  const DailyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DailyProvider>();
    final exam = d.nextExam;
    final now = DateTime.now();
    return FadeSlideIn(
      child: PressableScale(
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, AppRoute.fadeSlide(const DailyScreen())),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                _StreakBadge(days: d.streak, done: d.studiedToday),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Motivation.greeting(now), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      exam != null && exam.daysLeft() <= 14
                          ? Motivation.examMessage(exam.name, exam.daysLeft())
                          : Motivation.phraseFor(now),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor, height: 1.35),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_left_rounded),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int days;
  final bool done;
  const _StreakBadge({required this.days, required this.done});

  @override
  Widget build(BuildContext context) {
    final active = days > 0;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: (active ? Colors.orange : Colors.grey).withOpacity(0.14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(active ? '🔥' : '🌱', style: const TextStyle(fontSize: 22)),
        Text('$days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: active ? Colors.orange.shade800 : Colors.grey)),
        Text(done ? 'تمّ اليوم' : 'يوم', style: const TextStyle(fontSize: 10)),
      ]),
    );
  }
}

/// "يومي": streak, today's line, exam countdowns and pending camp tasks.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  Future<void> _addExam(BuildContext context) async {
    final name = TextEditingController();
    DateTime? date;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة امتحان'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(date == null ? 'تاريخ الامتحان' : _fmt(date!)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now().add(const Duration(days: 14)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 400)),
                );
                if (d != null) setS(() => date = d);
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
    if (ok == true && name.text.trim().isNotEmpty && date != null && context.mounted) {
      context.read<DailyProvider>().addExam(name.text, date!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DailyProvider>();
    final flags = context.watch<FeatureFlags>();
    final user = context.watch<UserAuthProvider>().user;
    final signedIn = user != null && user.role != UserRole.guest;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('يومي')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(d.streak > 0 ? '🔥' : '🌱', style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: d.streak),
                      duration: const Duration(milliseconds: 800),
                      builder: (_, v, __) => Text('$v يوم متتالي',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    Text('أفضل سلسلة: ${d.best} يوم', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                d.streak > 0 ? Motivation.streakMessage(d.streak) : 'ابدأ سلسلتك اليوم، أول يوم هو الأصعب وأجمل ما فيه.',
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.orange.shade900),
                  onPressed: d.studiedToday ? null : () => context.read<DailyProvider>().markStudied(context),
                  icon: Icon(d.studiedToday ? Icons.check_circle_rounded : Icons.local_fire_department_rounded),
                  label: Text(d.studiedToday ? 'أحسنت! سجّلت مذاكرة اليوم' : 'ذاكرت اليوم'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'تُحتسب المذاكرة تلقائياً عند فتح ملف أو إنجاز مهمة.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.format_quote_rounded, color: AppColors.accent, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text(Motivation.phraseFor(now), style: const TextStyle(height: 1.5, fontSize: 14.5))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 2,
          child: Row(children: [
            const Expanded(child: Text('امتحاناتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            TextButton.icon(onPressed: () => _addExam(context), icon: const Icon(Icons.add_rounded), label: const Text('إضافة')),
          ]),
        ),
        if (d.exams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('أضف مواعيد امتحاناتك لتظهر لك العدّادات والتذكيرات.'),
          ),
        for (var i = 0; i < d.exams.length; i++)
          FadeSlideIn(
            index: i + 3,
            child: Card(
              child: ListTile(
                leading: _DaysLeft(days: d.exams[i].daysLeft()),
                title: Text(d.exams[i].name),
                subtitle: Text(_fmt(d.exams[i].date)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => context.read<DailyProvider>().removeExam(d.exams[i]),
                ),
              ),
            ),
          ),
        if (signedIn && flags.isOn(FeatureFlags.studyCamps)) ...[
          const SizedBox(height: 12),
          const Text('مهام معسكراتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          FutureBuilder<List<PendingTask>>(
            future: CampService.pendingTasks(user.uid),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
              }
              final tasks = snap.data!;
              if (tasks.isEmpty) return const Text('لا توجد مهام متبقية 🎉');
              return Column(children: [
                for (var i = 0; i < tasks.length && i < 10; i++)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.checklist_rounded, color: AppColors.secondary),
                      title: Text(tasks[i].task.title),
                      subtitle: Text([
                        tasks[i].camp.name,
                        if (tasks[i].task.deadline != null) 'التسليم ${_fmt(tasks[i].task.deadline!)}',
                      ].join(' • ')),
                      onTap: () => Navigator.push(context, AppRoute.fadeSlide(CampDetailScreen(campId: tasks[i].camp.id))),
                    ),
                  ),
              ]);
            },
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: d.remind,
          onChanged: (v) => context.read<DailyProvider>().setRemind(v),
          title: const Text('تذكير يومي بالمذاكرة'),
          subtitle: const Text('إشعار الساعة 7:30 مساءً بعبارة تحفيزية أو عدّاد امتحانك'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _DaysLeft extends StatelessWidget {
  final int days;
  const _DaysLeft({required this.days});

  @override
  Widget build(BuildContext context) {
    final color = days <= 3 ? AppColors.error : days <= 7 ? AppColors.warning : AppColors.secondary;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$days', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text('يوم', style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }
}
