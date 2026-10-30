import 'package:flutter/material.dart';
import '../../widgets/animations.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/submission_service.dart';
import '../../core/services/url_service.dart';
import '../../models/submission_model.dart';
import '../../providers/auth_provider.dart';

/// Admin: review the files students sent.
class ReviewSubmissionsScreen extends StatelessWidget {
  const ReviewSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<UserAuthProvider>().user?.displayName ?? 'الإدارة';
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات رفع الملفات')),
      body: StreamBuilder<List<MaterialSubmission>>(
        stream: SubmissionService.streamPending(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('تعذر تحميل الطلبات: ${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('لا توجد طلبات بانتظار المراجعة.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => FadeSlideIn(index: i, child: _SubmissionCard(s: list[i], admin: admin)),
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final MaterialSubmission s;
  final String admin;
  const _SubmissionCard({required this.s, required this.admin});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await SubmissionService.approve(widget.s, widget.admin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم القبول ونشر الملف في المواد'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر القبول: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _reject() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الملف'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'سبب الرفض (يظهر للطالب)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await SubmissionService.reject(widget.s, widget.admin, text);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الرفض: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${s.subject} • ${s.department} • ${s.materialType}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('من: ${s.submitterName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (s.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s.description, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => UrlService.launchWebUrl(context, s.fileUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(s.fileName, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _approve,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('قبول ونشر'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _reject,
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                    label: const Text('رفض', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
