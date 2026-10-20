import '../../models/gpa_model.dart';

/// Strategy Interface for GPA Scales
/// Allows easily swapping or extending grading policies (4.0 scale, 5.0 scale, Egyptian, American, European ECTS, etc.)
abstract class GpaScaleStrategy {
  String get scaleName;
  double get maxGpa;
  List<String> get availableGrades;
  double gradeToPoint(String letterGrade);
  String evaluateStanding(double gpa);
}

/// Standard 4.0 Scale Strategy (Commonly used across American-style credit hour systems)
class Standard4ScaleStrategy implements GpaScaleStrategy {
  @override
  String get scaleName => 'نظام 4.0 (القياسي)';

  @override
  double get maxGpa => 4.0;

  @override
  List<String> get availableGrades => [
        'A+',
        'A',
        'A-',
        'B+',
        'B',
        'B-',
        'C+',
        'C',
        'C-',
        'D+',
        'D',
        'F',
      ];

  @override
  double gradeToPoint(String letterGrade) {
    switch (letterGrade.toUpperCase().trim()) {
      case 'A+':
        return 4.0;
      case 'A':
        return 4.0;
      case 'A-':
        return 3.7;
      case 'B+':
        return 3.3;
      case 'B':
        return 3.0;
      case 'B-':
        return 2.7;
      case 'C+':
        return 2.3;
      case 'C':
        return 2.0;
      case 'C-':
        return 1.7;
      case 'D+':
        return 1.3;
      case 'D':
        return 1.0;
      case 'F':
      default:
        return 0.0;
    }
  }

  @override
  String evaluateStanding(double gpa) {
    if (gpa >= 3.7) return 'ممتاز مع مرتبة الشرف';
    if (gpa >= 3.4) return 'ممتاز';
    if (gpa >= 3.0) return 'جيد جداً';
    if (gpa >= 2.5) return 'جيد';
    if (gpa >= 2.0) return 'مقبول';
    return 'إنذار أكاديمي';
  }
}

/// Standard 5.0 Scale Strategy (Common in Saudi Arabia, Gulf & international universities)
class Standard5ScaleStrategy implements GpaScaleStrategy {
  @override
  String get scaleName => 'نظام 5.0';

  @override
  double get maxGpa => 5.0;

  @override
  List<String> get availableGrades => [
        'A+',
        'A',
        'B+',
        'B',
        'C+',
        'C',
        'D+',
        'D',
        'F',
      ];

  @override
  double gradeToPoint(String letterGrade) {
    switch (letterGrade.toUpperCase().trim()) {
      case 'A+':
        return 5.0;
      case 'A':
        return 4.75;
      case 'B+':
        return 4.5;
      case 'B':
        return 4.0;
      case 'C+':
        return 3.5;
      case 'C':
        return 3.0;
      case 'D+':
        return 2.5;
      case 'D':
        return 2.0;
      case 'F':
      default:
        return 1.0;
    }
  }

  @override
  String evaluateStanding(double gpa) {
    if (gpa >= 4.5) return 'ممتاز مرتفع';
    if (gpa >= 4.0) return 'جيد جداً';
    if (gpa >= 3.25) return 'جيد';
    if (gpa >= 2.75) return 'مقبول';
    return 'إنذار';
  }
}

/// Custom / University Specific Logic Placeholder
/// Easily customize this class with your institution's specific regulations
class CustomUniversityScaleStrategy implements GpaScaleStrategy {
  @override
  String get scaleName => 'نظام الجامعة المخصص';

  @override
  double get maxGpa => 4.0; // Change to match university ceiling

  @override
  List<String> get availableGrades => ['A+', 'A', 'B+', 'B', 'C+', 'C', 'D', 'F'];

  @override
  double gradeToPoint(String letterGrade) {
    // -------------------------------------------------------------------------
    // TODO: [CUSTOMIZATION HOOK]
    // Insert your college's specific grade-to-point mappings here.
    // Example: Some colleges map A+ to 4.3 or have different thresholds for D.
    // -------------------------------------------------------------------------
    switch (letterGrade.toUpperCase()) {
      case 'A+':
        return 4.0;
      case 'A':
        return 3.75;
      case 'B+':
        return 3.25;
      case 'B':
        return 3.0;
      case 'C+':
        return 2.5;
      case 'C':
        return 2.0;
      case 'D':
        return 1.5;
      case 'F':
      default:
        return 0.0;
    }
  }

  @override
  String evaluateStanding(double gpa) {
    // -------------------------------------------------------------------------
    // TODO: [CUSTOMIZATION HOOK]
    // Insert university honors / warning rules based on GPA & credit requirements.
    // -------------------------------------------------------------------------
    if (gpa >= 3.6) return 'امتياز';
    if (gpa >= 3.0) return 'جيد جداً';
    if (gpa >= 2.4) return 'جيد';
    if (gpa >= 2.0) return 'مقبول';
    return 'إنذار أكاديمي';
  }
}

/// Core GPA Calculation Engine
class GpaCalculatorEngine {
  /// Computes semester GPA and optionally combines with previous history for Cumulative GPA (CGPA)
  static GpaCalculationResult calculate({
    required List<CourseEntry> courses,
    required GpaScaleStrategy strategy,
    double? previousCumulativeGpa,
    int? previousCompletedCredits,
  }) {
    if (courses.isEmpty) {
      return GpaCalculationResult(
        semesterGpa: 0.0,
        totalSemesterCredits: 0,
        totalQualityPoints: 0.0,
        cumulativeGpa: previousCumulativeGpa,
        totalCumulativeCredits: previousCompletedCredits ?? 0,
        academicStanding: 'لم تتم إضافة مقررات',
      );
    }

    int semesterCredits = 0;
    double semesterQualityPoints = 0.0;

    for (final course in courses) {
      if (course.creditHours <= 0) continue;
      final point = strategy.gradeToPoint(course.letterGrade);
      final qualityPoints = point * course.creditHours;

      semesterCredits += course.creditHours;
      semesterQualityPoints += qualityPoints;
    }

    final double semesterGpa = semesterCredits > 0
        ? double.parse((semesterQualityPoints / semesterCredits).toStringAsFixed(2))
        : 0.0;

    // Cumulative GPA calculation
    double? finalCgpa;
    int totalCumulativeCredits = semesterCredits;

    if (previousCumulativeGpa != null &&
        previousCompletedCredits != null &&
        previousCompletedCredits > 0) {
      final double previousQualityPoints =
          previousCumulativeGpa * previousCompletedCredits;
      final double totalPoints = previousQualityPoints + semesterQualityPoints;
      totalCumulativeCredits = previousCompletedCredits + semesterCredits;

      finalCgpa = totalCumulativeCredits > 0
          ? double.parse((totalPoints / totalCumulativeCredits).toStringAsFixed(2))
          : semesterGpa;
    }

    final effectiveGpa = finalCgpa ?? semesterGpa;
    final standing = strategy.evaluateStanding(effectiveGpa);

    return GpaCalculationResult(
      semesterGpa: semesterGpa,
      totalSemesterCredits: semesterCredits,
      totalQualityPoints: semesterQualityPoints,
      cumulativeGpa: finalCgpa,
      totalCumulativeCredits: totalCumulativeCredits,
      academicStanding: standing,
    );
  }
}
