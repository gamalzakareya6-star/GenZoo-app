class CourseEntry {
  final String id;
  String name;
  int creditHours;
  String letterGrade;

  CourseEntry({
    required this.id,
    this.name = '',
    this.creditHours = 3,
    this.letterGrade = 'A',
  });

  CourseEntry copyWith({
    String? id,
    String? name,
    int? creditHours,
    String? letterGrade,
  }) {
    return CourseEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      creditHours: creditHours ?? this.creditHours,
      letterGrade: letterGrade ?? this.letterGrade,
    );
  }
}

class GpaCalculationResult {
  final double semesterGpa;
  final int totalSemesterCredits;
  final double totalQualityPoints;
  final double? cumulativeGpa;
  final int totalCumulativeCredits;
  final String academicStanding;

  GpaCalculationResult({
    required this.semesterGpa,
    required this.totalSemesterCredits,
    required this.totalQualityPoints,
    this.cumulativeGpa,
    required this.totalCumulativeCredits,
    required this.academicStanding,
  });
}
