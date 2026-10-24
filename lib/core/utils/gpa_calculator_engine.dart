import '../../models/gpa_model.dart';

/// One row of the grading table (Article 13 of the bylaws).
class GradeBand {
  final String key; // A+, A, ...
  final String arabic; // أ+, أ, ...
  final double points;
  final double minScore; // lower bound of the degree range (percent)
  final double estimatedScore; // used when only the letter is known

  const GradeBand(
    this.key,
    this.arabic,
    this.points,
    this.minScore,
    this.estimatedScore,
  );
}

/// Grading rules of the Faculty of Science, Menoufia University
/// (credit-hour bylaws, 2024).
class BylawGrading {
  static const List<GradeBand> bands = [
    GradeBand('A+', 'أ+', 4.0, 90, 95),
    GradeBand('A', 'أ', 3.7, 85, 87.5),
    GradeBand('B+', 'ب+', 3.3, 80, 82.5),
    GradeBand('B', 'ب', 3.0, 75, 77.5),
    GradeBand('C+', 'ج+', 2.7, 70, 72.5),
    GradeBand('C', 'ج', 2.3, 65, 67.5),
    GradeBand('D', 'د', 2.0, 60, 62.5),
    GradeBand('F', 'ر', 0.0, 0, 50),
  ];

  /// Minimum percentage to pass a course and to stay out of probation.
  static const double passPercent = 60;

  static GradeBand forScore(double score) {
    for (final b in bands) {
      if (score >= b.minScore) return b;
    }
    return bands.last;
  }

  static GradeBand forKey(String key) {
    return bands.firstWhere((b) => b.key == key, orElse: () => bands.last);
  }

  /// Overall rating from a percentage.
  static String verbalForPercent(double p) {
    if (p >= 85) return 'ممتاز';
    if (p >= 75) return 'جيد جداً';
    if (p >= 65) return 'جيد';
    if (p >= passPercent) return 'مقبول';
    return 'راسب';
  }

  static const List<List<double>> _anchors = [
    [0, 40],
    [2.0, 60],
    [2.3, 65],
    [2.7, 70],
    [3.0, 75],
    [3.3, 80],
    [3.7, 85],
    [4.0, 90],
  ];

  /// Rough percentage for a GPA, used only when the student did not enter the
  /// previous cumulative percentage. It follows the lower bounds of the table.
  static double approxPercentFromGpa(double gpa) {
    final g = gpa.clamp(0.0, 4.0).toDouble();
    for (var i = 0; i < _anchors.length - 1; i++) {
      final a = _anchors[i];
      final b = _anchors[i + 1];
      if (g <= b[0]) {
        final t = (g - a[0]) / (b[0] - a[0]);
        return a[1] + t * (b[1] - a[1]);
      }
    }
    return _anchors.last[1];
  }

  static double round2(double v) => (v * 100).round() / 100;

  /// At graduation the GPA is rounded to one decimal when that favors the
  /// student (Article 13, item 2).
  static double graduationGpa(double gpa) {
    final r = (gpa * 10).round() / 10;
    return r > gpa ? r : gpa;
  }
}

class GpaCalculatorEngine {
  static GpaCalculationResult calculate({
    required List<CourseEntry> courses,
    double? previousGpa,
    double? previousPercent,
    double? previousCredits,
  }) {
    double semPoints = 0, semScoreSum = 0, semCredits = 0;
    double cumPoints = 0, cumScoreSum = 0, cumCredits = 0;
    double registered = 0, universityCredits = 0;
    var approx = false;

    for (final c in courses) {
      if (c.creditHours <= 0) continue;
      if (c.status == CourseStatus.withdrawn) continue;
      registered += c.creditHours;
      if (c.status != CourseStatus.counted) continue; // incomplete / deferred
      final band = BylawGrading.forKey(c.grade);

      if (c.universityReq) {
        if (band.key != 'F') universityCredits += c.creditHours;
        continue; // not part of the GPA
      }

      final score = c.score ?? band.estimatedScore;
      if (c.score == null) approx = true;

      semCredits += c.creditHours;
      semPoints += band.points * c.creditHours;
      semScoreSum += score * c.creditHours;

      // A repeated failure is counted only once in the cumulative GPA, and
      // that failure is already part of the previous history.
      final repeatedFailure = c.isRetake && band.key == 'F';
      if (!repeatedFailure) {
        cumCredits += c.creditHours;
        cumPoints += band.points * c.creditHours;
        cumScoreSum += score * c.creditHours;
      }
    }

    final semGpa = semCredits > 0 ? semPoints / semCredits : 0.0;
    final semPercent = semCredits > 0 ? semScoreSum / semCredits : 0.0;

    final hasHistory = previousGpa != null &&
        previousCredits != null &&
        previousCredits > 0;

    double cumGpa = semGpa;
    double cumPercent = semPercent;
    double totalCredits = semCredits;
    var percentApprox = approx;
    var priorProbation = false;

    if (hasHistory) {
      final prevCredits = previousCredits!;
      final prevGpa = previousGpa!;
      final prevPercentValue =
          previousPercent ?? BylawGrading.approxPercentFromGpa(prevGpa);
      if (previousPercent == null) percentApprox = true;

      totalCredits = prevCredits + cumCredits;
      cumGpa = (prevGpa * prevCredits + cumPoints) / totalCredits;
      cumPercent = (prevPercentValue * prevCredits + cumScoreSum) / totalCredits;
      priorProbation = prevPercentValue < BylawGrading.passPercent;
    }

    final hasData = hasHistory || semCredits > 0;
    final shownPercent = hasData ? BylawGrading.round2(cumPercent) : 0.0;
    final shownGpa = hasData ? BylawGrading.round2(cumGpa) : 0.0;

    return GpaCalculationResult(
      semesterGpa: BylawGrading.round2(semGpa),
      semesterPercent: BylawGrading.round2(semPercent),
      semesterCredits: semCredits,
      semesterPercentApprox: approx,
      registeredCredits: registered,
      universityCredits: universityCredits,
      hasHistory: hasHistory,
      cumulativeGpa: shownGpa,
      cumulativePercent: shownPercent,
      cumulativeCredits: totalCredits,
      percentApprox: percentApprox,
      hasData: hasData,
      verbal: hasData ? BylawGrading.verbalForPercent(shownPercent) : '-',
      letter: hasData ? BylawGrading.forScore(shownPercent).arabic : '-',
      onProbation: hasData && shownPercent < BylawGrading.passPercent,
      priorProbation: priorProbation,
      graduationGpa:
          hasData ? BylawGrading.round2(BylawGrading.graduationGpa(shownGpa)) : 0.0,
    );
  }
}
