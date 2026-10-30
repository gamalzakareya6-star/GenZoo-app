import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/opinion_service.dart';
import '../../widgets/animations.dart';
import '../materials/subject_opinions_screen.dart';

/// Admin: approve or reject the subject opinions students wrote.
class OpinionsModerationScreen extends StatelessWidget {
  const OpinionsModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آراء المواد بانتظار الموافقة')),
      body: StreamBuilder<List<SubjectOpinion>>(
        stream: OpinionService.streamPending(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد آراء بانتظار المراجعة.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => FadeSlideIn(
              index: i,
              child: Column(children: [
                OpinionCard(opinion: list[i]),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(
                      onPressed: () => OpinionService.setStatus(list[i].id, 'rejected'),
                      icon: const Icon(Icons.close_rounded, color: AppColors.error),
                      label: const Text('رفض', style: TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => OpinionService.setStatus(list[i].id, 'approved'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('موافقة ونشر'),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      ),
    );
  }
}
