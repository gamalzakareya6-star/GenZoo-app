import '../../widgets/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/materials_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/material_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/url_service.dart';
import '../../widgets/custom_widgets.dart';
import 'upload_material_screen.dart';
import 'submit_material_screen.dart';
import '../../models/user_model.dart';
import '../../models/offline_file.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/daily_provider.dart';
import 'downloads_screen.dart';
import 'material_reviews_sheet.dart';
import '../../providers/review_stats_provider.dart';

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MaterialsProvider>(context);
    final auth = Provider.of<UserAuthProvider>(context);
    final isAdmin = auth.isAdmin;
    final theme = Theme.of(context);

    final allDepartments = ['الكل', ...AppConstants.departments];

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  AppRoute.fadeSlide(const UploadMaterialScreen()),
                );
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('إضافة مادة'),
              backgroundColor: AppColors.primary,
            )
          : FloatingActionButton.extended(
              onPressed: () {
                final u = auth.user;
                if (u == null || u.role == UserRole.guest) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سجّل الدخول بحسابك لرفع ملف.')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  AppRoute.fadeSlide(const SubmitMaterialScreen()),
                );
              },
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: const Text('ساهم بملف'),
              backgroundColor: AppColors.secondary,
            ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Search Field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: provider.setSearchQuery,
                        decoration: InputDecoration(
                          hintText: 'ابحث بالمادة أو العنوان أو كلمة...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: theme.cardColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'تحميلاتي (بدون إنترنت)',
                      child: Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            AppRoute.fadeSlide(const DownloadsScreen()),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.download_done_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Department filter chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allDepartments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final d = allDepartments[i];
                      return ChoiceChip(
                        label: Text(
                          d == 'الكل' ? 'كل الأقسام' : d,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: provider.selectedDepartment == d,
                        onSelected: (_) => provider.setDepartmentFilter(d),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Materials Feed
          Expanded(
            child: provider.isLoading
                ? const FeedSkeleton()
                : provider.filteredMaterials.isEmpty
                    ? EmptyStateView(
                        icon: Icons.folder_open_rounded,
                        title: 'لا توجد مواد',
                        subtitle: 'لا توجد ملفات تطابق القسم أو البحث المختار.',
                        action: isAdmin
                            ? ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    AppRoute.fadeSlide(const UploadMaterialScreen()),
                                  );
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('أضف مادة الآن'),
                              )
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: provider.filteredMaterials.length,
                        itemBuilder: (context, index) => FadeSlideIn(index: index, child: Builder(builder: (context) {
                          final material = provider.filteredMaterials[index];
                          return _buildMaterialCard(context, material, isAdmin, provider);
                        })),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(
    BuildContext context,
    StudyMaterial item,
    bool isAdmin,
    MaterialsProvider provider,
  ) {
    final theme = Theme.of(context);
    final ext = item.fileExtension.toLowerCase();
    final dateStr = DateFormat.yMMMd().format(item.uploadedAt);

    Color fileColor = AppColors.primary;
    IconData fileIcon = Icons.insert_drive_file;

    if (ext == 'pdf') {
      fileColor = const Color(0xFFE11D48);
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (ext.contains('doc')) {
      fileColor = const Color(0xFF2563EB);
      fileIcon = Icons.description_rounded;
    } else if (ext.contains('ppt')) {
      fileColor = const Color(0xFFEA580C);
      fileIcon = Icons.slideshow_rounded;
    } else if (ext.contains('zip') || ext.contains('rar')) {
      fileColor = const Color(0xFF7C3AED);
      fileIcon = Icons.folder_zip_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badges & Year
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.subject,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.materialType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.department,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Material Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(fileIcon, size: 28, color: fileColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${item.formattedFileSize} • بواسطة ${item.uploadedBy} • $dateStr',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action Row
            Row(
              children: [
                Icon(Icons.download_done_rounded, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${item.downloadCount} مشاهدة/تحميل',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showMaterialReviews(context, item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Builder(builder: (context) {
                      final st = context.watch<ReviewStatsProvider>().statsFor(item.id);
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          st == null ? 'آراء' : '${st.avg.toStringAsFixed(1)} (${st.count})',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ]);
                    }),
                  ),
                ),
                const Spacer(),
                if (isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    tooltip: 'حذف المادة',
                    onPressed: () => _confirmDelete(context, item, provider),
                  ),
                ],
                _DownloadActions(item: item, provider: provider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, StudyMaterial item, MaterialsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المادة الدراسية؟'),
        content: Text(
          'هل أنت متأكد من حذف "${item.title}"؟ سيتم حذف المادة من التطبيق (ملف Drive لن يُحذف).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteMaterial(item);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

/// Download / open buttons of a material card: downloads it for offline use,
/// shows progress, and opens the saved copy (or the online link).
class _DownloadActions extends StatelessWidget {
  final StudyMaterial item;
  final MaterialsProvider provider;
  const _DownloadActions({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final saved = dl.fileFor(item.id);
    final progress = dl.progress(item.id);

    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 2.5),
            ),
            const SizedBox(width: 8),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 12)),
            IconButton(
              tooltip: 'إلغاء التحميل',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => context.read<DownloadsProvider>().cancelDownload(item.id),
            ),
          ],
        ),
      );
    }

    if (saved != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.offline_pin_rounded, size: 18, color: AppColors.secondary),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: () {
              provider.recordDownload(item.id);
              openOfflineFile(context, saved);
            },
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text('فتح'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'فتح أونلاين',
          icon: const Icon(Icons.open_in_new, size: 20),
          onPressed: () {
            provider.recordDownload(item.id);
            context.read<DailyProvider>().markStudied(context);
            UrlService.launchWebUrl(context, item.fileUrl);
          },
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final dl = context.read<DownloadsProvider>();
            final ok = await dl.download(item);
            provider.recordDownload(item.id);
            messenger.showSnackBar(SnackBar(
              content: Text(ok
                  ? 'بدأ التحميل في الخلفية، يمكنك مغادرة التطبيق.'
                  : (dl.errorFor(item.id) ?? 'تعذّر التحميل.')),
              backgroundColor: ok ? AppColors.secondary : AppColors.error,
            ));
          },
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text(dl.errorFor(item.id) != null ? 'إعادة المحاولة' : 'تحميل'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
