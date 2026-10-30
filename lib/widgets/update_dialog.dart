import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/download_notification_service.dart';
import '../core/services/update_service.dart';
import 'install_permission_dialog.dart';

/// Checks for an update once and, if there is one, offers to download and
/// install it from inside the app with notification progress and permission guide.
Future<void> checkForAppUpdate(BuildContext context) async {
  final update = await UpdateService.check();
  if (update == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;

  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double? _progress;
  String? _message;
  final DownloadNotificationService _notifService = DownloadNotificationService();
  static const int _updateNotifId = 889911;

  @override
  void initState() {
    super.initState();
    _notifService.init();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _progress = null;
      _message = 'جارٍ بدء تحميل التحديث...';
    });

    http.Client? client;
    IOSink? sink;
    File? part;

    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/genzoo_update_b${widget.update.build}.apk');
      part = File('${apkFile.path}.part');

      // A finished download of this same build can be reused; a partial one
      // only ever exists as ".part" and is never mistaken for a full APK.
      if (await apkFile.exists() && await apkFile.length() > 5 * 1024 * 1024) {
        _onDownloadFinished(apkFile.path);
        return;
      }
      if (await part.exists()) await part.delete();

      client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(widget.update.apkUrl)));
      if (response.statusCode != 200) {
        throw 'رمز الاستجابة ${response.statusCode}';
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      int lastPercent = -1;
      sink = part.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes <= 0) continue;

        final percentInt = (receivedBytes * 100 ~/ totalBytes).clamp(0, 100);
        if (percentInt == lastPercent) continue; // update only when it changes
        lastPercent = percentInt;

        if (mounted) {
          setState(() {
            _progress = percentInt / 100;
            final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            _message = 'جارٍ التحميل $percentInt% ($mbReceived / $mbTotal ميغابايت)';
          });
        }
        await _notifService.showDownloadProgress(
          id: _updateNotifId,
          title: 'تحديث تطبيق GenZoo',
          progress: percentInt,
          subText: '$percentInt%',
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (receivedBytes < 1024 * 1024 || (totalBytes > 0 && receivedBytes != totalBytes)) {
        throw 'الملف لم يكتمل تحميله';
      }
      await part.rename(apkFile.path);

      await _notifService.showDownloadCompleted(
        id: _updateNotifId,
        title: 'اكتمل تحميل التحديث',
        body: 'اضغط هنا لتثبيت التحديث الجديد',
        filePath: apkFile.path,
      );

      _onDownloadFinished(apkFile.path);
    } catch (e) {
      try {
        await sink?.close();
        if (part != null && await part.exists()) await part.delete();
      } catch (_) {}
      await _notifService.cancel(_updateNotifId);
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _message = 'تعذر تحميل التحديث ($e). تأكد من اتصالك بالإنترنت وحاول مرة أخرى.';
        });
      }
    } finally {
      client?.close();
    }
  }

  void _onDownloadFinished(String apkPath) {
    if (!mounted) return;

    Navigator.of(context).pop(); // Close current download dialog

    // Show the Illustrative Permission Guide Dialog
    InstallPermissionGuideDialog.show(
      context,
      apkPath: apkPath,
      onInstallConfirmed: () async {
        await DownloadNotificationService.installApk(apkPath);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.update.notes;
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.system_update_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'يتوفر تحديث جديد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تم إصدار نسخة أحدث من GenZoo. يتم تحميل التحديث الآن مع إشعار بالتقدم في شريط الإشعارات.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ما الجديد في هذا التحديث:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notes,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
            if (_busy || _message != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined,
                          size: 14, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('لاحقاً'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('تحديث الآن'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
