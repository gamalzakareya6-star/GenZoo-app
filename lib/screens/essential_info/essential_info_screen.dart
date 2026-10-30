import '../../widgets/animations.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/url_service.dart';
import '../../models/quick_link_model.dart';
import 'package:provider/provider.dart';
import '../../providers/feature_flags.dart';
import '../camps/camps_screen.dart';
import '../materials/subject_opinions_screen.dart';
import '../study/study_schedule_screen.dart';
import 'gpa_calculator_screen.dart';

class EssentialInfoScreen extends StatefulWidget {
  const EssentialInfoScreen({super.key});

  @override
  State<EssentialInfoScreen> createState() => _EssentialInfoScreenState();
}

class _EssentialInfoScreenState extends State<EssentialInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _mapIcon(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school_rounded;
      case 'laptop_chromebook':
        return Icons.laptop_chromebook_rounded;
      case 'calendar_month':
      case 'calendar_today':
        return Icons.calendar_month_rounded;
      case 'how_to_reg':
        return Icons.how_to_reg_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(icon: Icon(Icons.public_rounded), text: 'الروابط الرسمية'),
                  Tab(icon: Icon(Icons.calculate_rounded), text: 'حاسبة المعدل'),
                  Tab(icon: Icon(Icons.auto_stories_rounded), text: 'أدوات المذاكرة'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Official Links & Portals
            StreamBuilder<List<QuickLink>>(
              stream: _firestoreService.streamQuickLinks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final links = snapshot.data ?? QuickLink.getDefaultLinks();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: links.length,
                  itemBuilder: (context, index) => FadeSlideIn(index: index, child: Builder(builder: (context) {
                    final link = links[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.cardBorderLight),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => UrlService.launchWebUrl(context, link.url),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _mapIcon(link.iconName),
                                  color: AppColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            link.category.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      link.title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      link.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  })),
                );
              },
            ),

            // Tab 2: Embedded GPA Calculator
            const GpaCalculatorScreen(),
            const _StudyToolsTab(),
          ],
        ),
      ),
    );
  }
}


/// Study tools. Each tool shows "قريباً" until the admin switches it on.
class _StudyToolsTab extends StatelessWidget {
  const _StudyToolsTab();

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlags>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ToolCard(
          icon: Icons.forum_rounded,
          color: const Color(0xFF0F766E),
          title: 'آراء عن المواد',
          subtitle: 'رأي ونصيحة زملائك في كل مادة',
          enabled: true,
          onOpen: () => Navigator.push(context, AppRoute.fadeSlide(const SubjectOpinionsScreen())),
        ),
        _ToolCard(
          icon: Icons.event_note_rounded,
          color: AppColors.primary,
          title: 'اقتراح الجدول الدراسي',
          subtitle: 'جدول أسبوعي ذكي حسب موادك وامتحاناتك',
          enabled: flags.isOn(FeatureFlags.studySchedule),
          onOpen: () => Navigator.push(context, AppRoute.fadeSlide(const StudyScheduleScreen())),
        ),
        _ToolCard(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.secondary,
          title: 'معسكرات المذاكرة',
          subtitle: 'ذاكر مع زملائك: مهام ومواعيد وتقدّم الجميع',
          enabled: flags.isOn(FeatureFlags.studyCamps),
          onOpen: () => Navigator.push(context, AppRoute.fadeSlide(const CampsScreen())),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onOpen;
  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          onTap: enabled ? onOpen : null,
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: enabled
              ? const Icon(Icons.chevron_left_rounded)
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Text('قريباً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
        ),
      ),
    );
  }
}
