enum CourseStatus { counted, withdrawn, incomplete, deferred }

class CourseEntry {
  final String id;
  String name;
  String code;
  double creditHours;

  /// Grade key: A+, A, B+, B, C+, C, D or F.
  String grade;

  /// Degree the student typed, out of (creditHours x 100) as in the university
  /// platform; null means the grade was picked directly and the percentage is
  /// estimated.
  double? score;

  /// Course re-registered after failing it. A repeated failure is counted
  /// only once in the cumulative GPA (Article 13, item 6).
  bool isRetake;

  /// University requirement: pass/fail, not counted in the GPA
  /// (Article 14, item 4).
  bool universityReq;

  CourseStatus status;

  CourseEntry({
    required this.id,
    this.name = '',
    this.code = '',
    this.creditHours = 3,
    this.grade = 'A',
    this.score,
    this.isRetake = false,
    this.universityReq = false,
    this.status = CourseStatus.counted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'credits': creditHours,
        'grade': grade,
        'score': score,
        'retake': isRetake,
        'uni': universityReq,
        'status': status.name,
      };

  factory CourseEntry.fromJson(Map<String, dynamic> json) {
    return CourseEntry(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      creditHours: (json['credits'] as num?)?.toDouble() ?? 3,
      grade: json['grade'] as String? ?? 'A',
      score: (json['score'] as num?)?.toDouble(),
      isRetake: json['retake'] as bool? ?? false,
      universityReq: json['uni'] as bool? ?? false,
      status: CourseStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CourseStatus.counted,
      ),
    );
  }
}

class GpaCalculationResult {
  // Current semester
  final double semesterGpa;
  final double semesterPercent;
  final double semesterCredits; // credits counted in the GPA
  final bool semesterPercentApprox;
  final double registeredCredits; // all registered hours (study load)
  final double universityCredits; // university requirements (not in GPA)

  // Cumulative (equals the semester values when no history was entered)
  final bool hasHistory;
  final double cumulativeGpa;
  final double cumulativePercent;
  final double cumulativeCredits;
  final bool percentApprox;

  // Derived from the values above
  final bool hasData;
  final String verbal; // ممتاز / جيد جداً / ...
  final String letter; // أ+ / أ / ب+ ...
  final bool onProbation; // cumulative percentage below 60%
  final bool priorProbation; // was on probation before this semester
  final double graduationGpa;

  const GpaCalculationResult({
    required this.semesterGpa,
    required this.semesterPercent,
    required this.semesterCredits,
    required this.semesterPercentApprox,
    required this.registeredCredits,
    required this.universityCredits,
    required this.hasHistory,
    required this.cumulativeGpa,
    required this.cumulativePercent,
    required this.cumulativeCredits,
    required this.percentApprox,
    required this.hasData,
    required this.verbal,
    required this.letter,
    required this.onProbation,
    required this.priorProbation,
    required this.graduationGpa,
  });
}
