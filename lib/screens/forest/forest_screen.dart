import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_provider.dart';
import '../../providers/forest_provider.dart';
import '../../widgets/animations.dart';
import '../../widgets/user_avatar.dart';

const _treeEmojis = ['🌳', '🌲', '🌴', '🌳', '🌲', '🌿'];
const _green = Color(0xFF15803D);

String _clock(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String _stage(double p) => p < 0.34 ? '🌱' : p < 0.67 ? '🌿' : '🪴';

String _milestoneMessage(int trees) {
  if (trees >= 100) return '🎉 أكملت تحدي الـ100 شجرة! غابتك كاملة، أنت بطل حقيقي.';
  if (trees >= 75) return '٧٥ شجرة! اقتربت جداً من القمة 🌟';
  if (trees >= 50) return 'نصف الغابة! ٥٠ شجرة من الالتزام 💚';
  if (trees >= 25) return '٢٥ شجرة، ربع الطريق خلفك 🌳';
  if (trees >= 10) return 'عشر أشجار! بدأت غابتك تكبر 🌲';
  return 'شجرة جديدة في غابتك 🌳';
}

/// Small card for the home feed.
class ForestCard extends StatelessWidget {
  const ForestCard({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<ForestProvider>();
    return FadeSlideIn(
      index: 1,
      child: PressableScale(
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, AppRoute.fadeSlide(const ForestScreen())),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Text(f.running ? _stage(f.treeProgress) : '🌳', style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('تحدي الـ100 شجرة', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (f.trees / ForestProvider.goalTrees).clamp(0.0, 1.0),
                        minHeight: 7,
                        color: _green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.running ? 'جلسة جارية ${_clock(f.sessionSecs)}' : '${f.trees} / ${ForestProvider.goalTrees} شجرة • شجرة لكل نصف ساعة',
                      style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor),
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

class ForestScreen extends StatelessWidget {
  const ForestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحدي الـ100 شجرة'),
          bottom: const TabBar(tabs: [Tab(text: 'غابتي'), Tab(text: 'المتصدرون')]),
        ),
        body: const TabBarView(children: [_MyForest(), _Leaderboard()]),
      ),
    );
  }
}

class _MyForest extends StatelessWidget {
  const _MyForest();

  Future<void> _toggle(BuildContext context) async {
    final f = context.read<ForestProvider>();
    if (!f.running) {
      await f.start();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('بدأت جلسة المذاكرة 🌱 يمكنك مغادرة الشاشة وسيستمر العدّ.'),
        ));
      }
      return;
    }
    final user = context.read<UserAuthProvider>().user;
    final signedIn = user != null && user.role != UserRole.guest;
    final daily = context.read<DailyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final before = f.trees;
    final r = await f.stop(uid: signedIn ? user.uid : null, name: user?.displayName, photo: user?.photoUrl);
    if (r.seconds >= 600) daily.markStudied();
    final gained = f.trees - before;
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      content: Text(gained > 0
          ? _milestoneMessage(f.trees)
          : 'ذاكرت ${r.seconds ~/ 60} دقيقة. بقي ${f.secondsToNextTree ~/ 60} دقيقة لشجرتك القادمة 💪'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<ForestProvider>();
    final trees = f.trees;
    final shown = trees.clamp(0, ForestProvider.goalTrees);
    return ListView(padding: const EdgeInsets.all(16), children: [
      FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF166534), Color(0xFF15803D)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: f.treeProgress),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, v, __) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Text(_stage(f.treeProgress), key: ValueKey(_stage(f.treeProgress)), style: const TextStyle(fontSize: 46)),
                  ),
                  Text(
                    f.running ? _clock(f.sessionSecs) : '${f.secondsToNextTree ~/ 60} د',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            Text(
              f.running
                  ? 'الشجرة التالية بعد ${(f.secondsToNextTree / 60).ceil()} دقيقة'
                  : 'ابدأ جلسة مذاكرة لتنمو شجرتك',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: f.running ? Colors.white : const Color(0xFFD4AF37),
                  foregroundColor: f.running ? AppColors.error : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _toggle(context),
                icon: Icon(f.running ? Icons.stop_circle_rounded : Icons.play_arrow_rounded),
                label: Text(f.running ? 'إنهاء الجلسة' : 'ابدأ المذاكرة'),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'كل 30 دقيقة مذاكرة = شجرة. المؤقت يكمل في الخلفية حتى 4 ساعات للجلسة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      FadeSlideIn(
        index: 1,
        child: Row(children: [
          Text('$trees / ${ForestProvider.goalTrees} شجرة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const Spacer(),
          Text('${f.totalMinutes ~/ 60} ساعة و${f.totalMinutes % 60} دقيقة', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 6),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (trees / ForestProvider.goalTrees).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: v, minHeight: 10, color: _green),
        ),
      ),
      if (f.completed)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            color: _green.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_milestoneMessage(trees), style: const TextStyle(fontWeight: FontWeight.bold, height: 1.4)),
            ),
          ),
        ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < ForestProvider.goalTrees; i++)
            i < shown
                ? TweenAnimationBuilder<double>(
                    key: ValueKey('t$i'),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (i % 10) * 40),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
                    child: Text(_treeEmojis[i % _treeEmojis.length], style: const TextStyle(fontSize: 26)),
                  )
                : Opacity(opacity: 0.18, child: const Text('🌱', style: TextStyle(fontSize: 22))),
        ],
      ),
      if (trees > ForestProvider.goalTrees)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: Text('+${trees - ForestProvider.goalTrees} شجرة إضافية 🌟')),
        ),
      const SizedBox(height: 40),
    ]);
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().user;
    final signedIn = user != null && user.role != UserRole.guest;
    if (!signedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('سجّل الدخول بحسابك لتظهر في لوحة المتصدرين.', textAlign: TextAlign.center),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('forest').orderBy('trees', descending: true).limit(30).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('تعذّر تحميل المتصدرين.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('كن أول من يزرع شجرة! 🌱'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final mine = docs[i].id == user.uid;
            final trees = (d['trees'] as num?)?.toInt() ?? 0;
            final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
            return FadeSlideIn(
              index: i,
              child: Card(
                color: mine ? _green.withOpacity(0.12) : null,
                child: ListTile(
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 30, child: Center(child: Text(medal, style: const TextStyle(fontSize: 18)))),
                    const SizedBox(width: 6),
                    UserAvatar(name: d['name'] as String? ?? '', photoUrl: d['photo'] as String?, radius: 17),
                  ]),
                  title: Text(d['name'] as String? ?? 'طالب', style: TextStyle(fontWeight: mine ? FontWeight.bold : null)),
                  trailing: Text('$trees 🌳', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
