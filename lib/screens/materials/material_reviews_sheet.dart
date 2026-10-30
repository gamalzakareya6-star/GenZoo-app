import 'package:flutter/material.dart';
import '../../widgets/animations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/review_service.dart';
import '../../models/material_model.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

Future<void> showMaterialReviews(BuildContext context, StudyMaterial material) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewsSheet(material: material),
  );
}

class StarRow extends StatelessWidget {
  final double value;
  final double size;
  const StarRow({super.key, required this.value, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i - 0.25
                ? Icons.star_rounded
                : (value >= i - 0.75 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: const Color(0xFFF59E0B),
          ),
      ],
    );
  }
}

class _ReviewsSheet extends StatelessWidget {
  final StudyMaterial material;
  const _ReviewsSheet({required this.material});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<UserAuthProvider>();
    final user = auth.user;
    final canWrite = user != null && user.role != UserRole.guest;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => StreamBuilder<List<MaterialReview>>(
        stream: ReviewService.streamApprovedFor(material.id),
        builder: (context, snap) {
          final list = snap.data ?? const <MaterialReview>[];
          final avg = list.isEmpty ? 0.0 : list.fold<int>(0, (a, r) => a + r.rating) / list.length;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text('آراء الطلاب', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(material.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(list.isEmpty ? '—' : avg.toStringAsFixed(1), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StarRow(value: avg, size: 20),
                      Text('${list.length} رأي', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (canWrite)
                _MyReview(material: material, user: user)
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
                  child: const Text('سجّل الدخول بحسابك لتكتب رأيك في هذه المادة.', style: TextStyle(fontSize: 12.5)),
                ),
              const SizedBox(height: 12),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد آراء منشورة بعد.'))
              else
                for (var i = 0; i < list.length; i++) FadeSlideIn(index: i, child: _ReviewTile(review: list[i])),
            ],
          );
        },
      ),
    );
  }
}

class _MyReview extends StatelessWidget {
  final StudyMaterial material;
  final AppUser user;
  const _MyReview({required this.material, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MaterialReview?>(
      stream: ReviewService.streamMine(material.id, user.uid),
      builder: (context, snap) {
        final mine = snap.data;
        final (label, color) = switch (mine?.status) {
          'approved' => ('تم نشر رأيك', AppColors.secondary),
          'rejected' => ('لم تتم الموافقة على رأيك', AppColors.error),
          'pending' => ('رأيك بانتظار موافقة المشرف', const Color(0xFFF59E0B)),
          _ => ('', Colors.grey),
        };
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: mine == null
                    ? const Text('شاركنا رأيك لتفيد زملاءك.', style: TextStyle(fontSize: 13))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StarRow(value: mine.rating.toDouble()),
                          const SizedBox(height: 2),
                          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openForm(context, mine),
                icon: Icon(mine == null ? Icons.rate_review_rounded : Icons.edit_rounded, size: 18),
                label: Text(mine == null ? 'اكتب رأيك' : 'تعديل'),
              ),
              if (mine != null)
                IconButton(
                  tooltip: 'حذف رأيي',
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: () => ReviewService.delete(mine.id),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openForm(BuildContext context, MaterialReview? existing) async {
    final text = TextEditingController(text: existing?.text ?? '');
    final exam = TextEditingController(text: existing?.exam ?? '');
    final tips = TextEditingController(text: existing?.tips ?? '');
    var rating = existing?.rating ?? 0;
    var difficulty = existing?.difficulty ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('تقييمك للمادة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setS(() => rating = i),
                        icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: const Color(0xFFF59E0B)),
                      ),
                  ],
                ),
                const Text('مستوى الصعوبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                SegmentedButton<int>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('سهلة')),
                    ButtonSegment(value: 2, label: Text('متوسطة')),
                    ButtonSegment(value: 3, label: Text('صعبة')),
                  ],
                  selected: difficulty == 0 ? <int>{} : {difficulty},
                  onSelectionChanged: (v) => setS(() => difficulty = v.isEmpty ? 0 : v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  maxLength: ReviewService.maxLength,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'رأيك في المادة',
                    hintText: 'الشرح، جودة الملف، الدكتور، أي شيء يفيد زملاءك...',
                  ),
                ),
                TextField(
                  controller: exam,
                  maxLength: ReviewService.maxDetail,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'شكل الامتحان (اختياري)'),
                ),
                TextField(
                  controller: tips,
                  maxLength: ReviewService.maxDetail,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'نصائح للمذاكرة (اختياري)'),
                ),
                const Text('سيظهر تقييمك بعد موافقة المشرف.', style: TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: rating == 0 ? null : () => Navigator.pop(ctx, true),
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ReviewService.submit(
        materialId: material.id,
        materialTitle: material.title,
        uid: user.uid,
        userName: user.displayName,
        rating: rating,
        text: text.text,
        exam: exam.text,
        tips: tips.text,
        difficulty: difficulty,
      );
      messenger.showSnackBar(const SnackBar(content: Text('تم إرسال تقييمك، سيظهر بعد موافقة المشرف.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر الإرسال. حاول مرة أخرى.')));
    }
  }
}

/// Details of a review (text, exam, tips, difficulty), shared by the public
/// list and the admin moderation screen.
class ReviewBody extends StatelessWidget {
  final MaterialReview review;
  const ReviewBody({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    Widget section(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ]),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (review.difficulty > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Chip(
            visualDensity: VisualDensity.compact,
            label: Text('الصعوبة: ${['سهلة', 'متوسطة', 'صعبة'][review.difficulty - 1]}', style: const TextStyle(fontSize: 12)),
          ),
        ),
      if (review.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review.text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
      if (review.exam.isNotEmpty) section(Icons.quiz_rounded, 'شكل الامتحان', review.exam),
      if (review.tips.isNotEmpty) section(Icons.lightbulb_rounded, 'نصائح', review.tips),
    ]);
  }
}

class _ReviewTile extends StatelessWidget {
  final MaterialReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StarRow(value: review.rating.toDouble(), size: 15),
              const Spacer(),
              Text(DateFormat.yMMMd().format(review.createdAt), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ]),
            const SizedBox(height: 4),
            Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ReviewBody(review: review),
          ],
        ),
      ),
    );
  }
}
