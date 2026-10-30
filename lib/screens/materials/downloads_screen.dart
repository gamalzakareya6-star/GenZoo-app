import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../models/offline_file.dart';
import '../../providers/downloads_provider.dart';
import '../../widgets/animations.dart';
import 'pdf_reader_screen.dart';

/// Opens a saved file: PDFs in the in-app reader, other types in the
/// matching app on the phone.
Future<void> openOfflineFile(BuildContext context, OfflineFile f) async {
  if (f.isPdf) {
    await Navigator.push(context, AppRoute.fadeSlide(PdfReaderScreen(file: f)));
    return;
  }
  final res = await OpenFilex.open(f.path);
  if (res.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لا يوجد تطبيق على جهازك لفتح هذا النوع (${f.ext}).')),
    );
  }
}

/// "تحميلاتي": everything saved on the device, usable without internet.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final downloads = dl.downloads;
    final exports = dl.exports;

    return Scaffold(
      appBar: AppBar(title: const Text('تحميلاتي')),
      body: (downloads.isEmpty && exports.isEmpty)
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'لا توجد ملفات محفوظة بعد.\nاضغط "تحميل" على أي مادة لتفتحها بدون إنترنت.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (downloads.isNotEmpty) ...[
                  const _Header('ملفات محمّلة'),
                  for (var i = 0; i < downloads.length; i++) FadeSlideIn(index: i, child: _FileTile(file: downloads[i])),
                ],
                if (exports.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _Header('نسخ معدّلة'),
                  for (var i = 0; i < exports.length; i++) FadeSlideIn(index: i, child: _FileTile(file: exports[i])),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

class _FileTile extends StatelessWidget {
  final OfflineFile file;
  const _FileTile({required this.file});

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadsProvider>();
    final pdf = file.isPdf;
    final color = pdf ? const Color(0xFFE11D48) : AppColors.primary;
    final extra = [
      if (file.subject.isNotEmpty) file.subject,
      file.sizeLabel,
      if (pdf && file.lastPage > 1) 'آخر صفحة ${file.lastPage}',
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => openOfflineFile(context, file),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(pdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded, color: color),
        ),
        title: Text(file.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(extra, style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'share') {
              await Share.shareXFiles([XFile(file.path)], text: file.title);
            } else if (v == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف الملف من الجهاز؟'),
                  content: Text('سيُحذف "${file.title}" وتعديلاته من هذا الجهاز فقط.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              if (ok == true) await dl.remove(file.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'share', child: Text('مشاركة')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }
}
