import '../../widgets/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/materials_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/drive_upload_service.dart';
import '../../models/quick_link_model.dart';
import '../home/add_edit_news_dialog.dart';
import '../materials/upload_material_screen.dart';
import 'review_submissions_screen.dart';
import '../../core/services/submission_service.dart';
import '../../models/submission_model.dart';
import '../../models/review_model.dart';
import '../../core/services/review_service.dart';
import '../../providers/feature_flags.dart';
import 'review_moderation_screen.dart';
import 'opinions_moderation_screen.dart';
import '../../core/services/opinion_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<UserAuthProvider>(context);
    final news = Provider.of<NewsProvider>(context);
    final materials = Provider.of<MaterialsProvider>(context);
    final theme = Theme.of(context);

    // Security Gatekeeper
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('الدخول مرفوض')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'الدخول مقصور على المسؤولين',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'حسابك الحالي (${auth.user?.email ?? "زائر"}) ليس له صلاحيات المسؤول.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('العودة للبوابة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المسؤول'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Admin Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تم الدخول باسم ${auth.user?.displayName ?? "المسؤول"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.user?.email ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Overview Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'الإعلانات',
                    value: news.allNews.length.toString(),
                    icon: Icons.newspaper,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'المواد الدراسية',
                    value: materials.materials.length.toString(),
                    icon: Icons.folder_shared,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Administrative Actions Section
            Text(
              'النشر وإدارة المحتوى',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildActionTile(
              context,
              title: 'نشر إعلان جديد',
              subtitle: 'انشر تحديثات وتنبيهات وجداول امتحانات وإعلانات الفعاليات',
              icon: Icons.campaign_rounded,
              color: Colors.blue.shade700,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const AddEditNewsDialog(),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context,
              title: 'إضافة مادة دراسية',
              subtitle: 'أضف روابط المحاضرات والامتحانات السابقة والملخصات',
              icon: Icons.cloud_upload_rounded,
              color: AppColors.secondary,
              onTap: () {
                Navigator.push(
                  context,
                  AppRoute.fadeSlide(const UploadMaterialScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<MaterialSubmission>>(
              stream: SubmissionService.streamPending(),
              builder: (context, snap) {
                final n = snap.data?.length ?? 0;
                return _buildActionTile(
                  context,
                  title: 'طلبات رفع الملفات من الطلاب',
                  subtitle: n == 0 ? 'لا توجد طلبات الآن' : 'عدد الطلبات بانتظار المراجعة: $n',
                  icon: Icons.fact_check_rounded,
                  color: n == 0 ? Colors.grey.shade600 : Colors.orange.shade700,
                  onTap: () => Navigator.push(
                    context,
                    AppRoute.fadeSlide(const ReviewSubmissionsScreen()),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<SubjectOpinion>>(
              stream: OpinionService.streamPending(),
              builder: (context, snap) {
                final n = snap.data?.length ?? 0;
                return _buildActionTile(
                  context,
                  title: 'آراء عن المواد (نصائح الطلاب)',
                  subtitle: n == 0 ? 'لا توجد آراء بانتظار الموافقة' : 'بانتظار المراجعة: $n',
                  icon: Icons.forum_rounded,
                  color: n == 0 ? Colors.grey.shade600 : Colors.teal.shade700,
                  onTap: () => Navigator.push(
                    context,
                    AppRoute.fadeSlide(const OpinionsModerationScreen()),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<MaterialReview>>(
              stream: ReviewService.streamPending(),
              builder: (context, snap) {
                final n = snap.data?.length ?? 0;
                return _buildActionTile(
                  context,
                  title: 'آراء الطلاب عن المواد',
                  subtitle: n == 0 ? 'لا توجد آراء بانتظار الموافقة' : 'بانتظار المراجعة: $n',
                  icon: Icons.rate_review_rounded,
                  color: n == 0 ? Colors.grey.shade600 : Colors.amber.shade800,
                  onTap: () => Navigator.push(
                    context,
                    AppRoute.fadeSlide(const ReviewModerationScreen()),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            Card(
              child: Consumer<FeatureFlags>(
                builder: (context, flags, _) => Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.rocket_launch_rounded),
                      title: Text('الميزات القادمة'),
                      subtitle: Text('جاهزة للعمل، مكتوب عليها "قريباً" للطلاب حتى تفعّلها'),
                    ),
                    SwitchListTile(
                      title: const Text('اقتراح الجدول الدراسي'),
                      value: flags.isOn(FeatureFlags.studySchedule),
                      onChanged: (v) => FeatureFlags.set(FeatureFlags.studySchedule, v),
                    ),
                    SwitchListTile(
                      title: const Text('معسكرات المذاكرة'),
                      value: flags.isOn(FeatureFlags.studyCamps),
                      onChanged: (v) => FeatureFlags.set(FeatureFlags.studyCamps, v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context,
              title: 'إضافة رابط سريع',
              subtitle: 'أضف روابط بوابات التسجيل والمنصات والجداول',
              icon: Icons.add_link_rounded,
              color: Colors.indigo.shade600,
              onTap: () => _showAddLinkDialog(context),
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context,
              title: 'إعداد رفع الملفات',
              subtitle: 'اربط رفع الملفات بحساب Google Drive (رابط Web app)',
              icon: Icons.cloud_sync_rounded,
              color: Colors.teal.shade600,
              onTap: () => _showUploadSetupDialog(context),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showUploadSetupDialog(BuildContext context) async {
    final controller = TextEditingController(text: await DriveUploadService.getEndpoint() ?? '');
    if (!context.mounted) return;
    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إعداد رفع الملفات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الصق رابط Web app الخاص بسكربت Google Drive (الخطوات في أعلى ملف '
                'scripts/drive_upload.gs في المستودع).',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://script.google.com/macros/s/.../exec',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final url = controller.text.trim();
                      if (url.isNotEmpty && !url.startsWith('https://script.google.com/')) {
                        setState(() => error = 'الرابط يجب أن يبدأ بـ https://script.google.com/');
                        return;
                      }
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await DriveUploadService.saveEndpoint(url)
                            .timeout(const Duration(seconds: 15));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        final msg = e.toString();
                        setState(() {
                          saving = false;
                          error = msg.contains('permission-denied')
                              ? 'تم رفض الحفظ: انشر قواعد Firestore الجديدة (ملف firestore.rules) '
                                  'من Firebase Console ثم أعد المحاولة، وتأكد أنك مسجّل بحساب أدمن.'
                              : 'تعذر الحفظ: $msg';
                        });
                      }
                    },
              child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _showAddLinkDialog(BuildContext context) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final descController = TextEditingController();
    String category = 'Portal';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة رابط منصة رسمية'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'اسم المنصة (مثال: Moodle)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'الرابط (https://...)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'الوصف / الغرض'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty && urlController.text.trim().isNotEmpty) {
                final firestoreService = FirestoreService();
                await firestoreService.addQuickLink(
                  QuickLink(
                    id: '',
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    url: urlController.text.trim(),
                    category: category,
                    order: 10,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ الرابط'),
          ),
        ],
      ),
    );
  }
}
