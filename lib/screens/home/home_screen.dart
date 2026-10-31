import '../../widgets/animations.dart';
import 'package:flutter/material.dart';
import '../daily/daily_screen.dart';
import '../forest/forest_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/news_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/news_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/url_service.dart';
import '../../widgets/custom_widgets.dart';
import 'add_edit_news_dialog.dart';
import '../../widgets/linkified_text.dart';
import '../../widgets/news_images.dart';
import '../../widgets/comments_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final authProvider = Provider.of<UserAuthProvider>(context);
    final isAdmin = authProvider.isAdmin;
    final theme = Theme.of(context);

    final categories = ['الكل', 'عاجل', 'أكاديمي', 'امتحانات', 'أنشطة', 'عام'];

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AddEditNewsDialog(),
                );
              },
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('نشر خبر'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          // Stream automatically updates, slight delay for haptic feedback
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
            // Branded welcome banner
            SliverToBoxAdapter(
              child: FadeSlideIn(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A1B3D), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const AppLogo(size: 72, glow: true),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'أسرة GenZoo الطلابية',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'قسم علم الحيوان - كلية العلوم - جامعة المنوفية',
                              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'خطوات صغيرة .. أثر كبير',
                              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: DailyCard()),
            const SliverToBoxAdapter(child: ForestCard()),
            // Category Filter Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = newsProvider.selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (_) => newsProvider.setCategory(cat),
                    );
                  },
                ),
              ),
            ),

            // Content Feed
            if (newsProvider.isLoading)
              const SliverFillRemaining(
                hasScrollBody: true,
                child: FeedSkeleton(),
              )
            else if (newsProvider.filteredNews.isEmpty)
              SliverFillRemaining(
                child: EmptyStateView(
                  icon: Icons.newspaper_rounded,
                  title: 'لا توجد إعلانات',
                  subtitle: newsProvider.selectedCategory == 'الكل'
                      ? 'تابعنا! ستظهر هنا إعلانات الكلية المهمة.'
                      : 'لا توجد إعلانات في تصنيف "${newsProvider.selectedCategory}".',
                  action: isAdmin
                      ? ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const AddEditNewsDialog(),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('انشر أول إعلان'),
                        )
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => FadeSlideIn(index: index, child: Builder(builder: (context) {
                      final item = newsProvider.filteredNews[index];
                      return _buildNewsCard(context, item, isAdmin, newsProvider);
                    })),
                    childCount: newsProvider.filteredNews.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(
    BuildContext context,
    NewsItem item,
    bool isAdmin,
    NewsProvider newsProvider,
  ) {
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().format(item.publishedAt);
    final isUrgent = item.category.toLowerCase() == 'urgent' || item.category == 'عاجل';
    final isDark = theme.brightness == Brightness.dark;
    final stripe = item.isPinned
        ? AppColors.accent
        : isUrgent
            ? AppColors.error
            : AppColors.primaryLight;

    return PressableScale(
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isPinned
              ? AppColors.accent.withOpacity(0.6)
              : isUrgent
                  ? AppColors.error.withOpacity(0.4)
                  : (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight),
          width: item.isPinned || isUrgent ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showNewsDetailsModal(context, item),
        child: Stack(children: [
          // Colored edge that tells the type of the post at a glance.
          Positioned.directional(
            textDirection: Directionality.of(context),
            start: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: stripe.withOpacity(0.85)),
          ),
          Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrls.isNotEmpty) ...[
                NewsImageBanner(urls: item.imageUrls),
                const SizedBox(height: 12),
              ],
              // Header Tags (Pinned, Category, Date)
              Row(
                children: [
                  if (item.isPinned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.push_pin, size: 12, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text(
                            'مثبّت',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),

              // Snippet
              Text(
                item.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),

              // Footer: Author & Actions
              Row(
                children: [
                  Icon(Icons.person_pin, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${item.authorName}${item.source == 'telegram' ? ' • تليجرام' : ''}${item.edited ? ' • معدّل' : ''}${item.attachments.isNotEmpty ? ' • 📎${item.attachments.length}' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showNewsDetailsModal(context, item),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                    label: const Text('تعليقات', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  if (item.externalUrl != null && item.externalUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => UrlService.launchWebUrl(context, item.externalUrl!),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('فتح الرابط', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  if (isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      tooltip: 'تعديل الإعلان',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddEditNewsDialog(item: item),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      tooltip: 'حذف الإعلان',
                      onPressed: () => _confirmDelete(context, item, newsProvider),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        ]),
      ),
    ),
    );
  }

  void _showNewsDetailsModal(BuildContext context, NewsItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Chip(label: Text(item.category)),
                      const Spacer(),
                      Text(DateFormat.yMMMd().format(item.publishedAt)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('نشره ${item.authorName}', style: TextStyle(color: Colors.grey.shade600)),
                  const Divider(height: 24),
                  if (item.imageUrls.isNotEmpty) ...[
                    NewsImageStrip(urls: item.imageUrls),
                    const SizedBox(height: 14),
                  ],
                  LinkifiedText(
                    item.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CopyTextButton(text: item.content),
                  ),
                  if (item.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('الملفات المرفقة',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    for (final f in item.attachments)
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(f.name, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => UrlService.launchWebUrl(context, f.url),
                        ),
                      ),
                  ],
                  if (item.externalUrl != null && item.externalUrl!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => UrlService.launchWebUrl(context, item.externalUrl!),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('فتح المرفق / الرابط الرسمي'),
                    ),
                  ],
                  CommentsSection(newsId: item.id),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, NewsItem item, NewsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content: Text('هل أنت متأكد من حذف "${item.title}"؟ لا يمكن التراجع عن ذلك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteNews(item.id);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
