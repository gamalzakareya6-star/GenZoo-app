import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/services/review_service.dart';

/// Average rating and count of approved reviews per material.
class ReviewStatsProvider extends ChangeNotifier {
  final Map<String, ({double avg, int count})> _stats = {};
  StreamSubscription? _sub;

  ReviewStatsProvider() {
    _sub = ReviewService.streamAllApproved().listen((list) {
      final sum = <String, int>{};
      final n = <String, int>{};
      for (final r in list) {
        sum[r.materialId] = (sum[r.materialId] ?? 0) + r.rating;
        n[r.materialId] = (n[r.materialId] ?? 0) + 1;
      }
      _stats
        ..clear()
        ..addAll({for (final id in n.keys) id: (avg: sum[id]! / n[id]!, count: n[id]!)});
      notifyListeners();
    }, onError: (e) => debugPrint('Review stats error: $e'));
  }

  ({double avg, int count})? statsFor(String materialId) => _stats[materialId];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
