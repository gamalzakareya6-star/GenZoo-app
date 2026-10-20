import 'package:flutter/foundation.dart';
import '../models/gpa_model.dart';
import '../core/utils/gpa_calculator_engine.dart';

class GpaProvider extends ChangeNotifier {
  final List<GpaScaleStrategy> _availableScales = [
    Standard4ScaleStrategy(),
    Standard5ScaleStrategy(),
    CustomUniversityScaleStrategy(),
  ];

  late GpaScaleStrategy _currentStrategy;
  final List<CourseEntry> _courses = [];

  double? _previousCgpa;
  int? _previousCredits;

  List<GpaScaleStrategy> get availableScales => _availableScales;
  GpaScaleStrategy get currentStrategy => _currentStrategy;
  List<CourseEntry> get courses => _courses;
  double? get previousCgpa => _previousCgpa;
  int? get previousCredits => _previousCredits;

  GpaCalculationResult get calculationResult {
    return GpaCalculatorEngine.calculate(
      courses: _courses,
      strategy: _currentStrategy,
      previousCumulativeGpa: _previousCgpa,
      previousCompletedCredits: _previousCredits,
    );
  }

  GpaProvider() {
    _currentStrategy = _availableScales.first;
    _populateInitialCourses();
  }

  void _populateInitialCourses() {
    _courses.addAll([
      CourseEntry(id: '1', name: 'علم الحيوان العام', creditHours: 3, letterGrade: 'A'),
      CourseEntry(id: '2', name: 'الكيمياء الحيوية', creditHours: 3, letterGrade: 'B+'),
      CourseEntry(id: '3', name: 'علم الأنسجة', creditHours: 3, letterGrade: 'A-'),
      CourseEntry(id: '4', name: 'الإحصاء الحيوي', creditHours: 3, letterGrade: 'B'),
    ]);
  }

  void setScaleStrategy(GpaScaleStrategy strategy) {
    _currentStrategy = strategy;
    // Normalize existing course grades if not found in new strategy
    for (var c in _courses) {
      if (!_currentStrategy.availableGrades.contains(c.letterGrade)) {
        c.letterGrade = _currentStrategy.availableGrades.first;
      }
    }
    notifyListeners();
  }

  void addCourse({String name = '', int creditHours = 3, String? defaultGrade}) {
    final grade = defaultGrade ?? _currentStrategy.availableGrades.first;
    _courses.add(CourseEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      creditHours: creditHours,
      letterGrade: grade,
    ));
    notifyListeners();
  }

  void removeCourse(String id) {
    _courses.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void updateCourseName(String id, String name) {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index != -1) {
      _courses[index].name = name;
      notifyListeners();
    }
  }

  void updateCourseCredits(String id, int credits) {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index != -1) {
      _courses[index].creditHours = credits;
      notifyListeners();
    }
  }

  void updateCourseGrade(String id, String grade) {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index != -1) {
      _courses[index].letterGrade = grade;
      notifyListeners();
    }
  }

  void setPreviousHistory({double? gpa, int? credits}) {
    _previousCgpa = gpa;
    _previousCredits = credits;
    notifyListeners();
  }

  void resetAll() {
    _courses.clear();
    _previousCgpa = null;
    _previousCredits = null;
    _populateInitialCourses();
    notifyListeners();
  }
}
