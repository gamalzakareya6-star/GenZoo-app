import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/review_service.dart';
import '../../models/review_model.dart';
import '../materials/material_reviews_sheet.dart';

/// Admin: approve or reject the opinions students wrote about materials.
class ReviewModerationScreen extends StatelessWidget {
  const ReviewModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آراء المواد بانتظار الموافقة')),
      body: StreamBuilder<List<MaterialReview>>(
        stream: ReviewService.streamPending(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد آراء بانتظار المراجعة.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.materialTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(children: [StarRow(value: r.rating.toDouble()), const SizedBox(width: 8), Text(r.userName, style: const TextStyle(fontSize: 12))]),
                      if (r.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(r.text, style: const TextStyle(height: 1.4)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => ReviewService.setStatus(r.id, 'rejected'),
                            icon: const Icon(Icons.close_rounded, color: AppColors.error),
                            label: const Text('رفض', style: TextStyle(color: AppColors.error)),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => ReviewService.setStatus(r.id, 'approved'),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('موافقة ونشر'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
