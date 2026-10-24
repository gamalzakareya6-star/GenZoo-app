import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/data/bylaw_courses.dart';
import '../../core/data/course_search.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/utils/gpa_calculator_engine.dart';
import '../../models/gpa_model.dart';
import '../../providers/gpa_provider.dart';

class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  final TextEditingController _prevGpaCtl = TextEditingController();
  final TextEditingController _prevPercentCtl = TextEditingController();
  final TextEditingController _prevCreditsCtl = TextEditingController();
  int _syncedVersion = -1;

  @override
  void dispose() {
    _prevGpaCtl.dispose();
    _prevPercentCtl.dispose();
    _prevCreditsCtl.dispose();
    super.dispose();
  }

  void _syncHistoryFields(GpaProvider gpa) {
    if (_syncedVersion == gpa.dataVersion) return;
    _syncedVersion = gpa.dataVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prevGpaCtl.text =
          gpa.previousGpa == null ? '' : formatNumber(gpa.previousGpa!);
      _prevPercentCtl.text =
          gpa.previousPercent == null ? '' : formatNumber(gpa.previousPercent!);
      _prevCreditsCtl.text =
          gpa.previousCredits == null ? '' : formatNumber(gpa.previousCredits!);
    });
  }

  void _historyChanged(GpaProvider gpa) {
    double? inRange(String text, double min, double max) {
      final v = parseNumber(text);
      if (v == null || v < min || v > max) return null;
      return v;
    }

    gpa.setHistory(
      gpa: inRange(_prevGpaCtl.text, 0, 4),
      percent: inRange(_prevPercentCtl.text, 0, 100),
      credits: inRange(_prevCreditsCtl.text, 0, 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gpa = context.watch<GpaProvider>();
    final result = gpa.result;
    final theme = Theme.of(context);
    _syncHistoryFields(gpa);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة المعدل (حسب اللائحة)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'مسح كل البيانات',
            onPressed: () => _confirmReset(context, gpa),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResultCard(result: result),
                const SizedBox(height: 10),
                _StatusSection(result: result, isSummer: gpa.isSummer),
                const SizedBox(height: 14),
                _buildSemesterType(gpa),
                const SizedBox(height: 10),
                _buildHistory(theme, gpa),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'مقررات الفصل (${gpa.courses.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: gpa.addCourse,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('إضافة مقرر'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final course in gpa.courses)
                  _CourseCard(
                    key: ValueKey('${course.id}-${gpa.dataVersion}'),
                    course: course,
                  ),
                const SizedBox(height: 8),
                _buildGradingTable(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, GpaProvider gpa) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح كل البيانات؟'),
        content: const Text('سيتم حذف المقررات والمعدل السابق المحفوظ في حسابك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (ok == true) gpa.resetAll();
  }

  Widget _buildSemesterType(GpaProvider gpa) {
    return Row(
      children: [
        const Text('نوع الفصل:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text('رئيسي'),
          selected: !gpa.isSummer,
          onSelected: (_) => gpa.setSummer(false),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('صيفي'),
          selected: gpa.isSummer,
          onSelected: (_) => gpa.setSummer(true),
        ),
      ],
    );
  }

  Widget _buildHistory(ThemeData theme, GpaProvider gpa) {
    InputDecoration deco(String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? AppColors.cardBorderDark
              : AppColors.cardBorderLight,
        ),
      ),
      child: ExpansionTile(
        key: ValueKey('history-${gpa.dataVersion}'),
        initiallyExpanded: gpa.previousCredits != null,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.history_rounded, color: AppColors.primary),
        title: const Text(
          'نتيجتي السابقة (للمعدل التراكمي)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: const Text(
          'انقلها من المنصة: المعدل والنسبة والساعات حتى الفصل السابق',
          style: TextStyle(fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prevCreditsCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: deco('الساعات المحسوبة', 'مثال: 60'),
                  onChanged: (_) => _historyChanged(gpa),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _prevGpaCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: deco('GPA (من 4)', 'مثال: 3.12'),
                  onChanged: (_) => _historyChanged(gpa),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _prevPercentCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: deco('النسبة %', 'مثال: 78.4'),
                  onChanged: (_) => _historyChanged(gpa),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'لو تركت النسبة فارغة تُقدَّر من الـ GPA بشكل تقريبي.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingTable(ThemeData theme) {
    const verbal = {
      'A+': 'ممتاز',
      'A': 'ممتاز',
      'B+': 'جيد جداً',
      'B': 'جيد جداً',
      'C+': 'جيد',
      'C': 'جيد',
      'D': 'مقبول',
      'F': 'راسب',
    };

    String range(int i) {
      final b = BylawGrading.bands[i];
      if (i == 0) return 'من ${formatNumber(b.minScore)}% فأكثر';
      final upper = BylawGrading.bands[i - 1].minScore;
      if (i == BylawGrading.bands.length - 1) {
        return 'أقل من ${formatNumber(upper)}%';
      }
      return 'من ${formatNumber(b.minScore)} إلى أقل من ${formatNumber(upper)}%';
    }

    TableRow row(List<String> cells, {bool header = false}) {
      return TableRow(
        decoration: header
            ? BoxDecoration(color: AppColors.primary.withOpacity(0.08))
            : null,
        children: cells
            .map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: header ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? AppColors.cardBorderDark
              : AppColors.cardBorderLight,
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.table_chart_outlined, color: AppColors.primary),
        title: const Text(
          'جدول التقديرات في اللائحة',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        children: [
          Table(
            border: TableBorder.all(color: Colors.grey.withOpacity(0.35)),
            children: [
              row(['التقدير', 'الرمز', 'النقاط', 'الدرجة'], header: true),
              for (var i = 0; i < BylawGrading.bands.length; i++)
                row([
                  verbal[BylawGrading.bands[i].key]!,
                  BylawGrading.bands[i].arabic,
                  formatNumber(BylawGrading.bands[i].points),
                  range(i),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'التقدير العام: ممتاز من 85% • جيد جداً من 75% • جيد من 65% • '
            'مقبول من 60%. الحد الأدنى للنجاح والتخرج 60%.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Result card
// -----------------------------------------------------------------------------
class _ResultCard extends StatelessWidget {
  final GpaCalculationResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final has = r.hasData;

    Widget tile(String label, String value, {String? sub}) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (sub != null)
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            r.hasHistory ? 'النتيجة التراكمية' : 'نتيجة الفصل',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(
                'النسبة المئوية',
                has ? '${r.cumulativePercent.toStringAsFixed(2)}%' : '--',
                sub: has && r.percentApprox ? 'تقريبية' : null,
              ),
              tile(
                'التقدير العام',
                has ? r.verbal : '--',
                sub: has ? 'الرمز: ${r.letter}' : null,
              ),
              tile(
                'GPA',
                has ? r.cumulativeGpa.toStringAsFixed(2) : '--',
                sub: has ? 'من 4.00' : null,
              ),
            ],
          ),
          if (r.hasHistory && r.semesterCredits > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            Text(
              'هذا الفصل: GPA ${r.semesterGpa.toStringAsFixed(2)} • '
              '${r.semesterPercent.toStringAsFixed(2)}% • '
              '${formatNumber(r.semesterCredits)} ساعة',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
          if (has && r.graduationGpa > r.cumulativeGpa) ...[
            const SizedBox(height: 8),
            Text(
              'المعدل عند التخرج بعد التقريب لصالحك: '
              '${r.graduationGpa.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Academic status, study load and notes
// -----------------------------------------------------------------------------
class _StatusSection extends StatelessWidget {
  final GpaCalculationResult result;
  final bool isSummer;

  const _StatusSection({required this.result, required this.isSummer});

  Widget _banner(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final widgets = <Widget>[];

    if (r.hasData) {
      if (r.onProbation) {
        widgets.add(_banner(
          Icons.warning_amber_rounded,
          AppColors.error,
          'مراقب علمياً: نسبتك التراكمية ${r.cumulativePercent.toStringAsFixed(2)}% '
          'وهي أقل من 60%. يُوجَّه لك الإنذار الأول، وتسجّل من 9 إلى 12 ساعة في '
          'الفصل الرئيسي (المادة 7-ز). يُلغى القيد إذا استنفدت 4 فصول رئيسية '
          'متتالية في المراقبة (المادة 16).',
        ));
      } else {
        widgets.add(_banner(
          Icons.check_circle_outline_rounded,
          AppColors.success,
          'وضعك الأكاديمي سليم: النسبة التراكمية '
          '${r.cumulativePercent.toStringAsFixed(2)}% (الحد الأدنى 60%).',
        ));
      }
    }

    // Study load (Article 7).
    final load = r.registeredCredits;
    if (load > 0) {
      double min;
      double max;
      String limitText;
      if (isSummer) {
        min = 6;
        max = 10;
        limitText = 'الفصل الصيفي من 6 إلى 10 ساعات';
      } else if (r.priorProbation) {
        min = 9;
        max = 12;
        limitText = 'الطالب المراقب علمياً من 9 إلى 12 ساعة';
      } else {
        min = 12;
        max = 18;
        limitText = 'الفصل الرئيسي من 12 إلى 18 ساعة';
      }
      final loadText = 'العبء الدراسي: ${formatNumber(load)} ساعة ($limitText)';
      if (load > max) {
        widgets.add(_banner(
          Icons.info_outline_rounded,
          AppColors.warning,
          '$loadText. تجاوزت الحد الأقصى؛ تُسمح زيادة ساعتين، وساعة إضافية '
          'بموافقة العميد للضرورة القصوى (المادة 7-ح).',
        ));
      } else if (load < min) {
        widgets.add(_banner(
          Icons.info_outline_rounded,
          AppColors.warning,
          '$loadText. أقل من الحد الأدنى؛ يُسمح بذلك فقط في آخر فصل لإتمام '
          'متطلبات التخرج (المادة 7-ح).',
        ));
      } else {
        widgets.add(_banner(
          Icons.event_available_outlined,
          AppColors.primary,
          '$loadText: ضمن الحد المسموح.',
        ));
      }
    }

    if (r.universityCredits > 0) {
      widgets.add(_banner(
        Icons.school_outlined,
        AppColors.primary,
        'ساعات متطلبات الجامعة: ${formatNumber(r.universityCredits)} '
        '(نجاح/رسوب، لا تدخل في المعدل الفصلي أو التراكمي).',
      ));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < widgets.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          widgets[i],
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// One course
// -----------------------------------------------------------------------------
class _CourseCard extends StatefulWidget {
  final CourseEntry course;

  const _CourseCard({super.key, required this.course});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  late final TextEditingController _creditsCtl;
  late final TextEditingController _scoreCtl;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _creditsCtl = TextEditingController(text: formatNumber(c.creditHours));
    _scoreCtl = TextEditingController(
      text: c.score == null ? '' : formatNumber(c.score!),
    );
  }

  @override
  void dispose() {
    _creditsCtl.dispose();
    _scoreCtl.dispose();
    super.dispose();
  }

  static String _statusLabel(CourseStatus s) {
    switch (s) {
      case CourseStatus.counted:
        return 'محسوب';
      case CourseStatus.withdrawn:
        return 'منسحب';
      case CourseStatus.incomplete:
        return 'غير مكتمل';
      case CourseStatus.deferred:
        return 'مؤجل';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpa = context.read<GpaProvider>();
    final c = widget.course;
    final theme = Theme.of(context);
    final excluded = c.status != CourseStatus.counted || c.universityReq;

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? AppColors.cardBorderDark
              : AppColors.cardBorderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildNameField(gpa, c, deco)),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  tooltip: 'حذف المقرر',
                  onPressed: () => gpa.removeCourse(c.id),
                ),
              ],
            ),
            if (c.code.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                child: Text(
                  'الرمز: ${c.code}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 82,
                  child: TextField(
                    controller: _creditsCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('الساعات'),
                    onChanged: (t) {
                      final v = parseNumber(t);
                      if (v != null && v >= 0 && v <= 12) {
                        gpa.setCredits(c.id, v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 82,
                  child: TextField(
                    controller: _scoreCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('الدرجة /100'),
                    onChanged: (t) {
                      final v = parseNumber(t);
                      if (t.trim().isEmpty) {
                        gpa.setScore(c.id, null);
                      } else if (v != null && v >= 0 && v <= 100) {
                        gpa.setScore(c.id, v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: c.grade,
                    isExpanded: true,
                    decoration: deco('التقدير'),
                    items: BylawGrading.bands
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b.key,
                            child: Text(
                              '${b.arabic}  •  ${formatNumber(b.points)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      _scoreCtl.clear();
                      gpa.setGrade(c.id, v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('إعادة بعد رسوب', style: TextStyle(fontSize: 12)),
                  selected: c.isRetake,
                  onSelected: (v) => gpa.setRetake(c.id, v),
                ),
                FilterChip(
                  label: const Text('متطلب جامعة', style: TextStyle(fontSize: 12)),
                  selected: c.universityReq,
                  onSelected: (v) => gpa.setUniversityReq(c.id, v),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<CourseStatus>(
                    value: c.status,
                    isDense: true,
                    items: CourseStatus.values
                        .map(
                          (s) => DropdownMenuItem<CourseStatus>(
                            value: s,
                            child: Text(
                              _statusLabel(s),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) gpa.setStatus(c.id, v);
                    },
                  ),
                ),
              ],
            ),
            if (excluded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  c.universityReq
                      ? 'متطلب جامعة: لا يدخل في المعدل.'
                      : 'لا يدخل هذا المقرر في حساب المعدل حالياً.',
                  style: const TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(
    GpaProvider gpa,
    CourseEntry c,
    InputDecoration Function(String) deco,
  ) {
    return Autocomplete<BylawCourse>(
      initialValue: TextEditingValue(text: c.name),
      displayStringForOption: (o) => o.name,
      optionsBuilder: (TextEditingValue value) =>
          CourseSearch.search(value.text),
      onSelected: (option) {
        gpa.applyCatalogCourse(c.id, option);
        _creditsCtl.text = formatNumber(option.credits);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: deco('اسم المقرر أو رمزه').copyWith(
            hintText: 'اكتب مثلاً: فسيولوجيا',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
          ),
          onChanged: (t) => gpa.updateName(c.id, t),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final width = MediaQuery.of(context).size.width - 64;
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 280, maxWidth: width),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final o = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(o.name),
                    subtitle: Text(
                      '${o.code} • ${formatNumber(o.credits)} ساعة'
                      '${o.universityReq ? ' • متطلب جامعة' : ''}',
                    ),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
