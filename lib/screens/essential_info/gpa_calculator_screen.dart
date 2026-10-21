import '../../models/gpa_model.dart';
import '../../models/gpa_model.dart';
import '../../models/gpa_model.dart';
import '../../models/gpa_model.dart';
import '../../models/gpa_model.dart';
class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  final TextEditingController _priorGpaController = TextEditingController();
  final TextEditingController _priorCreditsController = TextEditingController();
  bool _showPriorHistory = false;

  @override
  void dispose() {
    _priorGpaController.dispose();
    _priorCreditsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpa = Provider.of<GpaProvider>(context);
    final result = gpa.calculationResult;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة المعدل الفصلي والتراكمي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'مسح المقررات',
            onPressed: () {
              gpa.resetAll();
              _priorGpaController.clear();
              _priorCreditsController.clear();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Strategy / Grading Scale Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text('النظام: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<GpaScaleStrategy>(
                          value: gpa.currentStrategy,
                          isExpanded: true,
                          items: gpa.availableScales.map((scale) {
                            return DropdownMenuItem(
                              value: scale,
                              child: Text(
                                scale.scaleName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) gpa.setScaleStrategy(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // GPA Summary Scorecard
              _buildGpaScorecard(result, gpa.currentStrategy.maxGpa),
              const SizedBox(height: 16),

              // Prior History Collapsible (for Cumulative CGPA)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.cardBorderLight),
                ),
                child: ExpansionTile(
                  initiallyExpanded: _showPriorHistory,
                  title: const Text(
                    'السجل الأكاديمي السابق (اختياري للتراكمي)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    result.cumulativeGpa != null
                        ? 'المعدل التراكمي مفعّل: ${result.cumulativeGpa}'
                        : 'احسب المعدل التراكمي مع الفصول السابقة',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priorGpaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'المعدل التراكمي السابق',
                                hintText: 'e.g. 3.45',
                              ),
                              onChanged: (val) {
                                final parsedGpa = double.tryParse(val);
                                final parsedCredits = int.tryParse(_priorCreditsController.text);
                                gpa.setPreviousHistory(gpa: parsedGpa, credits: parsedCredits);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _priorCreditsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الساعات المنجزة',
                                hintText: 'e.g. 60',
                              ),
                              onChanged: (val) {
                                final parsedCredits = int.tryParse(val);
                                final parsedGpa = double.tryParse(_priorGpaController.text);
                                gpa.setPreviousHistory(gpa: parsedGpa, credits: parsedCredits);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Courses Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مقررات الفصل الحالي (${gpa.courses.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => gpa.addCourse(name: 'مقرر ${gpa.courses.length + 1}'),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('إضافة مقرر'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Courses List
              ...gpa.courses.asMap().entries.map((entry) {
                final index = entry.key;
                final course = entry.value;
                return _buildCourseCard(context, course, index, gpa);
              }),

              const SizedBox(height: 16),

              // Add Course Button Full Width
              OutlinedButton.icon(
                onPressed: () => gpa.addCourse(name: 'مقرر ${gpa.courses.length + 1}'),
                icon: const Icon(Icons.add),
                label: const Text('إضافة مقرر آخر'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpaScorecard(GpaCalculationResult result, double maxGpa) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Semester GPA
              Column(
                children: [
                  const Text(
                    'المعدل الفصلي',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.semesterGpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'من ${maxGpa.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),

              // Vertical Divider
              Container(width: 1, height: 60, color: Colors.white.withOpacity(0.2)),

              // Cumulative CGPA (or Credit Hours)
              Column(
                children: [
                  Text(
                    result.cumulativeGpa != null ? 'المعدل التراكمي' : 'إجمالي الساعات',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.cumulativeGpa != null
                        ? result.cumulativeGpa!.toStringAsFixed(2)
                        : '${result.totalSemesterCredits} ساعة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    result.cumulativeGpa != null
                        ? 'الإجمالي ${result.totalCumulativeCredits} ساعة'
                        : '${result.totalQualityPoints.toStringAsFixed(1)} نقطة جودة',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Standing Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text(
                  result.academicStanding,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, CourseEntry course, int index, GpaProvider gpa) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Course Number Indicator
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Course Name
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: course.name,
                decoration: const InputDecoration(
                  hintText: 'اسم المقرر',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (val) => gpa.updateCourseName(course.id, val),
              ),
            ),
            const SizedBox(width: 8),

            // Credit Hours Picker
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: course.creditHours,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                items: [1, 2, 3, 4, 5, 6].map((hrs) {
                  return DropdownMenuItem(value: hrs, child: Text('$hrs س'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) gpa.updateCourseCredits(course.id, val);
                },
              ),
            ),
            const SizedBox(width: 8),

            // Letter Grade Picker
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: course.letterGrade,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                items: gpa.currentStrategy.availableGrades.map((grade) {
                  return DropdownMenuItem(value: grade, child: Text(grade));
                }).toList(),
                onChanged: (val) {
                  if (val != null) gpa.updateCourseGrade(course.id, val);
                },
              ),
            ),

            // Remove Button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
              onPressed: () => gpa.removeCourse(course.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
