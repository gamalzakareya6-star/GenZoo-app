import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/offline_file.dart';
import '../../providers/downloads_provider.dart';
import '../../screens/materials/pdf_reader_screen.dart';
import '../../widgets/animations.dart';

/// Opens PDFs that come from outside the app: "Open with GenZoo" from a file
/// manager / WhatsApp / browser, and the in-app "open from device" picker.
class ExternalPdf {
  static const _channel = MethodChannel('com.gamal.genzoo/pdf_intent');
  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool _started = false;

  /// Call once after the first frame (from the splash/home screen).
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPdf') {
        await _handle(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    try {
      final initial = await _channel.invokeMethod<Map>('getInitialPdf');
      if (initial != null) await _handle(Map<String, dynamic>.from(initial));
    } catch (_) {}
  }

  static Future<void> _handle(Map<String, dynamic> data) async {
    final ctx = navigatorKey.currentContext;
    final path = data['path'] as String?;
    if (ctx == null || path == null) return;
    final name = (data['name'] as String?) ?? 'document.pdf';
    await _openPath(ctx, path, name);
  }

  static Future<void> _openPath(BuildContext ctx, String path, String name) async {
    try {
      final f = await ctx.read<DownloadsProvider>().addExternal(sourcePath: path, name: name);
      if (!ctx.mounted) return;
      await openExternalFile(ctx, f);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذّر فتح الملف: $e')));
      }
    }
  }

  static Future<void> openExternalFile(BuildContext ctx, OfflineFile f) {
    return Navigator.of(ctx).push(AppRoute.fadeSlide(PdfReaderScreen(file: f)));
  }

  /// In-app picker for a PDF stored on the phone.
  static Future<void> pick(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final p = res?.files.single;
    if (p?.path == null) return;
    if (!context.mounted) return;
    await _openPath(context, p!.path!, p.name);
  }
}
