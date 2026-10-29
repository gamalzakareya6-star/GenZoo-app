import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/services/url_service.dart';
import '../../models/material_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/materials_provider.dart';
import '../../widgets/animations.dart';
import '../../widgets/custom_widgets.dart';
import 'pdf_viewer_screen.dart';
import 'submit_material_screen.dart';
import 'upload_material_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  bool _showOfflineOnly = false;
  List<OfflineMaterialItem> _offlineList = [];
  bool _loadingOffline = false;

  // Track downloading materials: materialId -> progress (0.0 to 1.0)
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _refreshOfflineList();
  }

  Future<void> _refreshOfflineList() async {
    setState(() => _loadingOffline = true);
    final items = await FileStorageService.getOfflineMaterials();
    if (mounted) {
      setState(() {
        _offlineList = items;
        _loadingOffline = false;
      });
    }
  }

  Future<void> _startDownload(StudyMaterial item) async {
    final id = item.id;
    setState(() {
      _downloadProgress[id] = 0.01;
    });

    try {
      await FileStorageService.downloadMaterial(
        item,
        onProgress: (received, total, percent) {
          if (mounted) {
            setState(() {
              _downloadProgress[id] = percent;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadProgress.remove(id);
        });
        await _refreshOfflineList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text('✓ تم تحميل "${item.title}" وحفظها للأوفلاين'),
            action: SnackBarAction(
              label: 'فتح الآن',
              textColor: Colors.white,
              onPressed: () => _openDownloadedMaterial(item.id, item.title, item.subject, item.department),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل الملف: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openDownloadedMaterial(
    String id,
    String title,
    String subject,
    String department,
  ) async {
    final path = await FileStorageService.getLocalFilePath(id);
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف غير موجود على الجهاز.')),
        );
      }
      return;
    }
    _openFilePath(path, title, subject, department);
  }

  void _openFilePath(
    String path,
    String title,
    String subject,
    String department,
  ) {
    if (path.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        AppRoute.fadeSlide(
          PdfViewerScreen(
            filePath: path,
            title: title,
            subject: subject,
            department: department,
          ),
        ),
      ).then((_) => _refreshOfflineList());
    } else {
      OpenFilex.open(path);
    }
  }

  Future<void> _shareFile(String path, String title) async {
    try {
      await Share.shareXFiles([XFile(path)], text: 'مشاركة: $title');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر مشاركة الملف: $e')),
        );
      }
    }
  }

  Future<void> _deleteDownloaded(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف من الجهاز؟'),
        content: Text('هل تريد حذف "$title" من مساحة التخزين؟ يمكنك إعادة تنزيله لاحقاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FileStorageService.deleteOfflineMaterial(id);
      await _refreshOfflineList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الملف من التخزين المحلي.')),
        );
      }
    }
  }

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
          // Mode Switch Bar: [📚 جميع المواد أونلاين]  [📥 المحفوظة أوفلاين]
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      const ButtonSegment(
                        value: false,
                        icon: Icon(Icons.cloud_outlined, size: 18),
                        label: Text('المواد أونلاين', style: TextStyle(fontSize: 12.5)),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.download_done_rounded, size: 18),
                        label: Text(
                          _offlineList.isEmpty
                              ? 'المحفوظات أوفلاين'
                              : 'المحفوظات (${_offlineList.length})',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                    selected: {_showOfflineOnly},
                    onSelectionChanged: (set) {
                      setState(() {
                        _showOfflineOnly = set.first;
                      });
                      if (_showOfflineOnly) {
                        _refreshOfflineList();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search & Filters Header
          if (!_showOfflineOnly) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              color: theme.scaffoldBackgroundColor,
              child: Column(
                children: [
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
          ],

          // Body: Either Offline List or Online Materials List
          Expanded(
            child: _showOfflineOnly
                ? _buildOfflineView(theme)
                : _buildOnlineView(provider, isAdmin, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineView(ThemeData theme) {
    if (_loadingOffline) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_offlineList.isEmpty) {
      return EmptyStateView(
        icon: Icons.cloud_download_outlined,
        title: 'لا توجد ملفات محفوظة أوفلاين',
        subtitle: 'يمكنك تنزيل أي مادة من تبويب "المواد أونلاين" لتتمكن من فتحها وتعديلها بدون إنترنت في أي وقت.',
        action: ElevatedButton.icon(
          onPressed: () => setState(() => _showOfflineOnly = false),
          icon: const Icon(Icons.cloud_outlined),
          label: const Text('استعراض المواد الآن'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _offlineList.length,
      itemBuilder: (context, index) {
        final item = _offlineList[index];
        final isPdf = item.fileExtension.toLowerCase() == 'pdf';
        final dateStr = DateFormat.yMMMd().format(item.downloadedAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
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
                    if (item.isEditedCopy) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'نسخة معدلة ✏️',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.materialType,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isPdf ? const Color(0xFFE11D48) : AppColors.primary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                        size: 28,
                        color: isPdf ? const Color(0xFFE11D48) : AppColors.primary,
                      ),
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
                          const SizedBox(height: 6),
                          Text(
                            '${item.formattedFileSize} • حُفظ بتاريخ $dateStr',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          if (isPdf && item.lastReadPage > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              '📍 آخر ما وقفت عنده: صفحة ${item.lastReadPage}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      tooltip: 'مشاركة الملف',
                      onPressed: () => _shareFile(item.localPath, item.title),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                      tooltip: 'حذف من الجهاز',
                      onPressed: () => _deleteDownloaded(item.id, item.title),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _openFilePath(
                        item.localPath,
                        item.title,
                        item.subject,
                        item.department,
                      ),
                      icon: Icon(
                        isPdf ? Icons.menu_book_rounded : Icons.open_in_new,
                        size: 16,
                      ),
                      label: Text(isPdf ? 'فتح وتعديل' : 'فتح الملف'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnlineView(
    MaterialsProvider provider,
    bool isAdmin,
    ThemeData theme,
  ) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.filteredMaterials.isEmpty) {
      return EmptyStateView(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.filteredMaterials.length,
      itemBuilder: (context, index) {
        final item = provider.filteredMaterials[index];
        final isDownloaded = _offlineList.any((o) => o.id == item.id);
        final downloadProgress = _downloadProgress[item.id];

        return FadeSlideIn(
          index: index,
          child: _buildOnlineMaterialCard(
            context,
            item,
            isAdmin,
            provider,
            isDownloaded,
            downloadProgress,
          ),
        );
      },
    );
  }

  Widget _buildOnlineMaterialCard(
    BuildContext context,
    StudyMaterial item,
    bool isAdmin,
    MaterialsProvider provider,
    bool isDownloaded,
    double? downloadProgress,
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
                if (isDownloaded) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'محفوظ أوفلاين',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  item.department,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
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

            // Live Download Progress Bar (if active)
            if (downloadProgress != null) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'جارٍ التنزيل للأوفلاين...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: downloadProgress > 0 ? downloadProgress : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

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

                // If already downloaded: "فتح في التطبيق"
                if (isDownloaded) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      provider.recordDownload(item.id);
                      UrlService.launchWebUrl(context, item.fileUrl);
                    },
                    icon: const Icon(Icons.open_in_browser, size: 15),
                    label: const Text('درايف'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _openDownloadedMaterial(
                        item.id,
                        item.title,
                        item.subject,
                        item.department,
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('فتح ومطالعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  // Not downloaded yet: "تنزيل أوفلاين" and fallback "رابط خارجي"
                  OutlinedButton.icon(
                    onPressed: () {
                      provider.recordDownload(item.id);
                      UrlService.launchWebUrl(context, item.fileUrl);
                    },
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text('المتصفح'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: downloadProgress != null
                        ? null
                        : () {
                            provider.recordDownload(item.id);
                            _startDownload(item);
                          },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('تنزيل للأوفلاين'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
