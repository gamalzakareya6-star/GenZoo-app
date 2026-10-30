import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/opinion_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';

/// آراء عن المواد: opinions and advice students wrote about subjects.
class SubjectOpinionsScreen extends StatefulWidget {
  const SubjectOpinionsScreen({super.key});

  @override
  State<SubjectOpinionsScreen> createState() => _SubjectOpinionsScreenState();
}

class _SubjectOpinionsScreenState extends State<SubjectOpinionsScreen> {
  String _query = '';

  Future<void> _write(AppUser user) async {
    final subject = TextEditingController();
    final opinion = TextEditingController();
    final advice = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('اكتب رأيك عن مادة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: subject,
                maxLength: 80,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(labelText: 'اسم المادة'),
              ),
              TextField(
                controller: opinion,
                maxLength: OpinionService.maxOpinion,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(labelText: 'رأيك في المادة'),
              ),
              TextField(
                controller: advice,
                maxLength: OpinionService.maxAdvice,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'نصيحتك لزملائك'),
              ),
              const Text('سيظهر رأيك بعد موافقة المشرف.', style: TextStyle(fontSize: 11.5)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: subject.text.trim().isEmpty || opinion.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await OpinionService.submit(
        uid: user.uid,
        userName: user.displayName,
        subjectName: subject.text,
        opinion: opinion.text,
        advice: advice.text,
      );
      messenger.showSnackBar(const SnackBar(content: Text('تم الإرسال، سيظهر رأيك بعد موافقة المشرف.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر الإرسال. حاول مرة أخرى.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().user;
    final canWrite = user != null && user.role != UserRole.guest;

    return Scaffold(
      appBar: AppBar(title: const Text('آراء عن المواد')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _write(user),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('اكتب رأيك'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث باسم المادة', isDense: true),
          ),
        ),
        if (canWrite) _MyPending(uid: user.uid),
        Expanded(
          child: StreamBuilder<List<SubjectOpinion>>(
            stream: OpinionService.streamApproved(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('تعذّر تحميل الآراء.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!.where((o) => _query.isEmpty || o.subjectName.contains(_query)).toList();
              if (list.isEmpty) {
                return Center(child: Text(_query.isEmpty ? 'لا توجد آراء منشورة بعد.\nكن أول من يشارك رأيه!' : 'لا توجد آراء لهذه المادة.', textAlign: TextAlign.center));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: list.length,
                itemBuilder: (_, i) => FadeSlideIn(index: i, child: OpinionCard(opinion: list[i])),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Shows the student's own opinions that are still waiting or were rejected.
class _MyPending extends StatelessWidget {
  final String uid;
  const _MyPending({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SubjectOpinion>>(
      stream: OpinionService.streamMine(uid),
      builder: (context, snap) {
        final mine = (snap.data ?? const <SubjectOpinion>[]).where((o) => o.status != 'approved').toList();
        if (mine.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(children: [
            for (final o in mine)
              Card(
                color: (o.status == 'pending' ? AppColors.accent : AppColors.error).withOpacity(0.1),
                child: ListTile(
                  dense: true,
                  title: Text(o.subjectName),
                  subtitle: Text(o.status == 'pending' ? 'بانتظار موافقة المشرف' : 'لم تتم الموافقة على هذا الرأي'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => OpinionService.delete(o.id),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class OpinionCard extends StatelessWidget {
  final SubjectOpinion opinion;
  const OpinionCard({super.key, required this.opinion});

  @override
  Widget build(BuildContext context) {
    final o = opinion;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(o.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          ]),
          const SizedBox(height: 2),
          Text(o.userName, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
          const SizedBox(height: 8),
          Text(o.opinion, style: const TextStyle(height: 1.45)),
          if (o.advice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(child: Text(o.advice, style: const TextStyle(height: 1.4, fontSize: 13))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
