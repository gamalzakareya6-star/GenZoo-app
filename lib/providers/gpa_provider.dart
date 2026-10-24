import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/data/bylaw_courses.dart';
import '../core/utils/gpa_calculator_engine.dart';
import '../models/gpa_model.dart';

/// GPA calculator state. The data is saved per account: locally on the device
/// (keyed by the user id) and, for signed-in users, in Firestore under
/// users/{uid}/private/gpa so it follows the account to other devices.
class GpaProvider extends ChangeNotifier {
  static const String _guestId = 'guest';

  String _uid = _guestId;
  bool _attached = false;
  int _loadToken = 0;
  int _dataVersion = 0;
  int _updatedAt = 0;
  Timer? _saveTimer;

  final List<CourseEntry> _courses = [];
  bool _summer = false;
  double? _prevGpa;
  double? _prevPercent;
  double? _prevCredits;

  GpaProvider() {
    _resetState();
  }

  List<CourseEntry> get courses => _courses;
  bool get isSummer => _summer;
  double? get previousGpa => _prevGpa;
  double? get previousPercent => _prevPercent;
  double? get previousCredits => _prevCredits;

  /// Increases whenever data is replaced as a whole (login, load, reset), so
  /// the UI can refresh its text fields.
  int get dataVersion => _dataVersion;

  GpaCalculationResult get result => GpaCalculatorEngine.calculate(
        courses: _courses,
        previousGpa: _prevGpa,
        previousPercent: _prevPercent,
        previousCredits: _prevCredits,
      );

  // ---------------------------------------------------------------------------
  // Account handling
  // ---------------------------------------------------------------------------
  void attachUser(String? uid) {
    final id = (uid == null || uid.isEmpty) ? _guestId : uid;
    if (_attached && id == _uid) return;
    _attached = true;
    _uid = id;
    _saveTimer?.cancel();
    _resetState();
    _dataVersion++;
    final token = ++_loadToken;
    Future.microtask(() => _load(token, id));
  }

  void _resetState() {
    _courses
      ..clear()
      ..add(_newCourse());
    _summer = false;
    _prevGpa = null;
    _prevPercent = null;
    _prevCredits = null;
    _updatedAt = 0;
  }

  CourseEntry _newCourse() => CourseEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        grade: 'A',
      );

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------
  String _prefsKey(String uid) => 'gpa_state_v2_$uid';

  DocumentReference<Map<String, dynamic>> _cloudDoc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('gpa');

  Map<String, dynamic> _toJson() => {
        'version': 2,
        'summer': _summer,
        'prevGpa': _prevGpa,
        'prevPercent': _prevPercent,
        'prevCredits': _prevCredits,
        'updatedAt': _updatedAt,
        'courses': _courses.map((c) => c.toJson()).toList(),
      };

  void _apply(Map<String, dynamic> data) {
    final list = (data['courses'] as List<dynamic>? ?? [])
        .map((e) => CourseEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _courses
      ..clear()
      ..addAll(list.isEmpty ? [_newCourse()] : list);
    _summer = data['summer'] as bool? ?? false;
    _prevGpa = (data['prevGpa'] as num?)?.toDouble();
    _prevPercent = (data['prevPercent'] as num?)?.toDouble();
    _prevCredits = (data['prevCredits'] as num?)?.toDouble();
    _updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
  }

  Future<void> _load(int token, String uid) async {
    Map<String, dynamic>? local;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(uid));
      if (raw != null) {
        local = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (e) {
      debugPrint('GPA: could not read local data: $e');
    }
    if (token != _loadToken) return;

    if (local != null) {
      _apply(local);
      _dataVersion++;
      notifyListeners();
    }

    if (uid == _guestId) return;

    try {
      final snap = await _cloudDoc(uid).get();
      if (token != _loadToken) return;
      final cloud = snap.data();
      final cloudUpdated = (cloud?['updatedAt'] as num?)?.toInt() ?? 0;

      if (cloud != null && cloudUpdated > _updatedAt) {
        _apply(cloud);
        _dataVersion++;
        await _writeLocal(uid);
        notifyListeners();
      } else if (local != null && _updatedAt > cloudUpdated) {
        await _cloudDoc(uid).set(_toJson());
      }
    } catch (e) {
      // Offline or the Firestore rules do not allow it yet: local data still
      // works, so this is not an error for the user.
      debugPrint('GPA: cloud sync skipped: $e');
    }
  }

  Future<void> _writeLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(uid), jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('GPA: could not save locally: $e');
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    final uid = _uid;
    _saveTimer = Timer(const Duration(milliseconds: 700), () => _saveNow(uid));
  }

  Future<void> _saveNow(String uid) async {
    if (uid != _uid) return;
    _updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _writeLocal(uid);
    if (uid == _guestId) return;
    try {
      await _cloudDoc(uid).set(_toJson());
    } catch (e) {
      debugPrint('GPA: cloud save skipped: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _scheduleSave();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------
  CourseEntry? _find(String id) {
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  void addCourse() {
    _courses.add(_newCourse());
    _changed();
  }

  void removeCourse(String id) {
    _courses.removeWhere((c) => c.id == id);
    if (_courses.isEmpty) _courses.add(_newCourse());
    _dataVersion++;
    _changed();
  }

  void updateName(String id, String name) {
    final c = _find(id);
    if (c == null) return;
    c.name = name;
    if (c.code.isNotEmpty) {
      // The text was edited by hand, so it no longer refers to a catalog entry.
      c.code = '';
      c.universityReq = false;
    }
    _changed();
  }

  void applyCatalogCourse(String id, BylawCourse course) {
    final c = _find(id);
    if (c == null) return;
    c.name = course.name;
    c.code = course.code;
    c.creditHours = course.credits;
    c.universityReq = course.universityReq;
    _changed();
  }

  void setCredits(String id, double credits) {
    final c = _find(id);
    if (c == null) return;
    c.creditHours = credits;
    _changed();
  }

  void setScore(String id, double? score) {
    final c = _find(id);
    if (c == null) return;
    c.score = score;
    if (score != null) c.grade = BylawGrading.forScore(score).key;
    _changed();
  }

  void setGrade(String id, String grade) {
    final c = _find(id);
    if (c == null) return;
    c.grade = grade;
    c.score = null;
    _changed();
  }

  void setRetake(String id, bool value) {
    final c = _find(id);
    if (c == null) return;
    c.isRetake = value;
    _changed();
  }

  void setUniversityReq(String id, bool value) {
    final c = _find(id);
    if (c == null) return;
    c.universityReq = value;
    _changed();
  }

  void setStatus(String id, CourseStatus status) {
    final c = _find(id);
    if (c == null) return;
    c.status = status;
    _changed();
  }

  void setSummer(bool value) {
    _summer = value;
    _changed();
  }

  void setHistory({double? gpa, double? percent, double? credits}) {
    _prevGpa = gpa;
    _prevPercent = percent;
    _prevCredits = credits;
    _changed();
  }

  void resetAll() {
    _resetState();
    _dataVersion++;
    _changed();
  }
}
