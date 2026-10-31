import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/download_notification_service.dart';

/// An illustrative dialog that guides the user on how to grant the
/// "Install unknown apps" permission on Android with a visual mockup.
class InstallPermissionGuideDialog extends StatelessWidget {
  final String apkPath;
  final VoidCallback onInstallConfirmed;

  const InstallPermissionGuideDialog({
    super.key,
    required this.apkPath,
    required this.onInstallConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required String apkPath,
    required VoidCallback onInstallConfirmed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InstallPermissionGuideDialog(
        apkPath: apkPath,
        onInstallConfirmed: onInstallConfirmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.security_update_good_rounded,
                color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'الموافقة على تثبيت التحديث',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Explanatory message
            Text(
              'اكتمل تنزيل التحديث بنجاح! لتثبيته، يتطلب أندرويد تفعيل إذن تثبيت التطبيقات من هذا المصدر.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 14),

            // Graphic Illustration of the Android Permission Screen
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  // Phone mock header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Settings Header Mock
                  Row(
                    children: [
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'تثبيت تطبيقات غير معروفة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Permission Toggle Item Card Mock
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // App Logo Mock
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.school_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        // Label
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'السماح من هذا المصدر',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'تطبيق GenZoo Student',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Animated Switch Mock (ON state)
                        Container(
                          width: 44,
                          height: 24,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 14, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  // Guide Pointer Arrow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'فعّل المفتاح كما هو موضح بالأعلى',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Step-by-step text
            _buildStepRow('1', 'اضغط «منح الإذن من الإعدادات» لفتح شاشة الإذن.'),
            const SizedBox(height: 6),
            _buildStepRow('2', 'قم بتفعيل زر «السماح من هذا المصدر».'),
            const SizedBox(height: 6),
            _buildStepRow('3', 'ارجع واضغط «تثبيت التحديث الآن» لتحديث التطبيق.'),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await DownloadNotificationService.openInstallPermissionSettings();
              },
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('منح الإذن'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final allowed =
                    await DownloadNotificationService.canRequestPackageInstalls();
                if (!allowed) {
                  // Permission still missing: send the user to the switch
                  // instead of letting Android silently refuse the install.
                  await DownloadNotificationService.openInstallPermissionSettings();
                  return;
                }
                if (context.mounted) Navigator.of(context).pop();
                onInstallConfirmed();
              },
              icon: const Icon(Icons.system_update_rounded, size: 16),
              label: const Text('تثبيت الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, height: 1.3),
          ),
        ),
      ],
    );
  }
}
