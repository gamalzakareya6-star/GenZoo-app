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

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MaterialsProvider>(context);
    final auth = Provider.of<UserAuthProvider>(context);
    final isAdmin = auth.isAdmin;
    final theme = Theme.of(context);

    final allYears = ['الكل', ...AppConstants.academicYears];
    final allSemesters = ['الكل', ...AppConstants.semesters];

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
          : null,
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Search Field
                TextField(
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالمادة أو العنوان أو كلمة...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: theme.cardColor,
                  ),
                ),
                const SizedBox(height: 10),

                // Year & Semester Filter Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: provider.selectedYear,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            items: allYears.map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year == 'الكل' ? 'كل الفرق' : year,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) provider.setYearFilter(val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: provider.selectedSemester,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            items: allSemesters.map((sem) {
                              return DropdownMenuItem(
                                value: sem,
                                child: Text(
                                  sem == 'الكل' ? 'كل الفصول' : sem,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) provider.setSemesterFilter(val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Materials Feed
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.filteredMaterials.isEmpty
                    ? EmptyStateView(
                        icon: Icons.folder_open_rounded,
                        title: 'لا توجد مواد',
                        subtitle: 'لا توجد ملفات تطابق الفرقة أو المادة المختارة.',
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
                  item.academicYear,
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
                const Spacer(),
                if (isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    tooltip: 'حذف المادة',
                    onPressed: () => _confirmDelete(context, item, provider),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    provider.recordDownload(item.id);
                    UrlService.launchWebUrl(context, item.fileUrl);
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('فتح / تحميل'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
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
