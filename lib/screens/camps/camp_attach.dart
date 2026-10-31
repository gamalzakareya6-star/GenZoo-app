import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/drive_upload_service.dart';
import '../../models/material_model.dart';
import '../../providers/materials_provider.dart';

/// Lets the user pick a file (or a picture) from the phone and uploads it to
/// Drive. Shows errors itself; returns null when cancelled or failed.
Future<UploadedFile?> pickAndUpload(BuildContext context, {required bool image}) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.platform.pickFiles(type: image ? FileType.image : FileType.any);
  final path = picked?.files.single.path;
  if (path == null) return null;
  try {
    messenger.showSnackBar(const SnackBar(content: Text('جارٍ الرفع...'), duration: Duration(seconds: 30)));
    final f = await DriveUploadService.upload(path, displayName: picked!.files.single.name);
    messenger.hideCurrentSnackBar();
    return f;
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    return null;
  }
}

/// Bottom sheet to choose one of the app's study materials.
Future<StudyMaterial?> pickAppMaterial(BuildContext context) {
  final all = context.read<MaterialsProvider>().materials;
  return showModalBottomSheet<StudyMaterial>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setS) {
          final list = all
              .where((m) => query.isEmpty || m.title.contains(query) || m.subject.contains(query))
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(children: [
                const Text('اختر من مواد التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => setS(() => query = v.trim()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'بحث', isDense: true),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('لا توجد مواد مطابقة.'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) => ListTile(
                            leading: Icon(Icons.description_rounded, color: AppColors.primary),
                            title: Text(list[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(list[i].subject),
                            onTap: () => Navigator.pop(ctx, list[i]),
                          ),
                        ),
                ),
              ]),
            ),
          );
        },
      );
    },
  );
}

enum AttachChoice { image, device, app }

/// The "attach" menu used by the chat and by the files tab.
Future<AttachChoice?> showAttachMenu(BuildContext context, {bool withImage = true}) {
  return showModalBottomSheet<AttachChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (withImage)
          ListTile(
            leading: Icon(Icons.image_rounded, color: AppColors.secondary),
            title: const Text('صورة'),
            onTap: () => Navigator.pop(ctx, AttachChoice.image),
          ),
        ListTile(
          leading: Icon(Icons.upload_file_rounded, color: AppColors.primary),
          title: const Text('ملف من الجهاز'),
          onTap: () => Navigator.pop(ctx, AttachChoice.device),
        ),
        ListTile(
          leading: Icon(Icons.menu_book_rounded, color: AppColors.accent),
          title: const Text('ملف من مواد التطبيق'),
          onTap: () => Navigator.pop(ctx, AttachChoice.app),
        ),
      ]),
    ),
  );
}
