import '../../widgets/animations.dart';
import 'package:flutter/material.dart';
import '../../models/azkar_model.dart';
import '../../core/constants/app_colors.dart';

class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<AzkarItem> _allAzkar;
  final Map<String, int> _counts = {};

  final List<Map<String, String>> _categories = [
    {'id': 'study', 'label': 'أدعية المذاكرة', 'sub': 'أدعية المذاكرة'},
    {'id': 'morning', 'label': 'أذكار الصباح', 'sub': 'الصباح'},
    {'id': 'evening', 'label': 'أذكار المساء', 'sub': 'المساء'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _allAzkar = AzkarItem.getDefaultAzkar();
    _resetCounts();
  }

  void _resetCounts() {
    setState(() {
      for (var item in _allAzkar) {
        _counts[item.id] = 0;
      }
    });
  }

  void _incrementCount(AzkarItem item) {
    final current = _counts[item.id] ?? 0;
    if (current < item.targetCount) {
      setState(() {
        _counts[item.id] = current + 1;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.azkarCardGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ذكر الله يمنح السكينة وصفاء الذهن قبل المذاكرة والامتحانات.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: 'تصفير العدّادات',
                      onPressed: _resetCounts,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.secondary,
                labelColor: AppColors.secondary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: _categories.map((c) {
                  return Tab(
                    text: c['label'],
                  );
                }).toList(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((cat) {
            final categoryItems = _allAzkar.where((z) => z.category == cat['id']).toList();
            return _buildAzkarList(categoryItems);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAzkarList(List<AzkarItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد أذكار في هذا القسم.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) => FadeSlideIn(index: index, child: Builder(builder: (context) {
        final item = items[index];
        final currentCount = _counts[item.id] ?? 0;
        final isCompleted = currentCount >= item.targetCount;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isCompleted
                  ? AppColors.success.withOpacity(0.5)
                  : AppColors.cardBorderLight,
              width: isCompleted ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _incrementCount(item),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? AppColors.success : AppColors.secondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isCompleted)
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'تم',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Arabic Supplication Text
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      item.arabicText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 2.0,
                        fontFamily: 'serif',
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),

                  // English / Meaning Translation
                  if (item.translation != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      item.translation!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Virtue / Source
                  if (item.virtue != null) ...[
                    const SizedBox(height: 10),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        '💡 ${item.virtue!}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Interactive Counter Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المطلوب: ${item.targetCount} ${item.targetCount > 1 ? 'مرات' : 'مرة'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.secondary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted ? Icons.check : Icons.touch_app,
                              size: 16,
                              color: isCompleted ? Colors.white : AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$currentCount / ${item.targetCount}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.white : AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      })),
    );
  }
}
