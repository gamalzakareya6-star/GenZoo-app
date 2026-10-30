import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Switches for features that are built but not announced yet. The admin turns
/// them on from the dashboard (document config/features), no new build needed.
class FeatureFlags extends ChangeNotifier {
  static const String studySchedule = 'studySchedule';
  static const String studyCamps = 'studyCamps';

  final Map<String, bool> _values = {};
  StreamSubscription? _sub;

  FeatureFlags() {
    _sub = FirebaseFirestore.instance.collection('config').doc('features').snapshots().listen((s) {
      final d = s.data() ?? {};
      _values
        ..clear()
        ..addAll({for (final e in d.entries) if (e.value is bool) e.key: e.value as bool});
      notifyListeners();
    }, onError: (e) => debugPrint('Feature flags error: $e'));
  }

  bool isOn(String key) => _values[key] ?? false;

  static Future<void> set(String key, bool value) => FirebaseFirestore.instance
      .collection('config')
      .doc('features')
      .set({key: value}, SetOptions(merge: true));

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
