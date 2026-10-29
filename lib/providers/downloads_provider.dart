import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/drive_link.dart';
import '../models/material_model.dart';
import '../models/offline_file.dart';

/// Files saved on the device (offline library), their download progress and
/// the last page read in each PDF.
class DownloadsProvider extends ChangeNotifier {
  static const _prefsKey = 'offline_files_v1';

  final Map<String, OfflineFile> _files = {};
  final Map<String, double> _progress = {};
  final Map<String, String> _errors = {};
  Timer? _saveTimer;

  DownloadsProvider() {
    _load();
  }

  List<OfflineFile> get items {
    final list = _files.values.toList();
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  List<OfflineFile> get downloads => items.where((f) => !f.isExport).toList();
  List<OfflineFile> get exports => items.where((f) => f.isExport).toList();

  OfflineFile? fileFor(String id) {
    final f = _files[id];
    if (f == null) return null;
    return File(f.path).existsSync() ? f : null;
  }

  bool isDownloaded(String id) => fileFor(id) != null;
  double? progress(String id) => _progress[id];
  String? errorFor(String id) => _errors[id];

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        for (final e in jsonDecode(raw) as List<dynamic>) {
          final f = OfflineFile.fromJson(Map<String, dynamic>.from(e as Map));
          if (f.id.isNotEmpty && File(f.path).existsSync()) _files[f.id] = f;
        }
      }
    } catch (e) {
      debugPrint('Offline index could not be read: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_files.values.map((f) => f.toJson()).toList()));
    } catch (e) {
      debugPrint('Offline index could not be saved: $e');
    }
  }

  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$name');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Downloads a material for offline use. Returns true on success.
  Future<bool> download(StudyMaterial m) async {
    if (_progress.containsKey(m.id)) return false; // already running
    _errors.remove(m.id);
    _progress[m.id] = 0;
    notifyListeners();

    final client = http.Client();
    File? tmp;
    try {
      final ext = _cleanExt(m.fileExtension);
      final dir = await _dir('materials');
      final target = File('${dir.path}/${m.id}.$ext');
      tmp = File('${target.path}.part');

      final res = await client
          .send(http.Request('GET', Uri.parse(directDownloadUrl(m.fileUrl))))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw 'تعذّر التحميل (رمز ${res.statusCode}).';
      }
      final type = (res.headers['content-type'] ?? '').toLowerCase();
      if (type.contains('text/html')) {
        throw 'هذا الرابط لا يدعم التحميل المباشر. افتحه من المتصفح.';
      }

      final total = res.contentLength ?? 0;
      var received = 0;
      var lastReported = 0.0;
      final sink = tmp.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final p = received / total;
            if (p - lastReported >= 0.02) {
              lastReported = p;
              _progress[m.id] = p;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }

      if (received == 0) throw 'الملف فارغ.';
      if (ext == 'pdf') {
        final head = await tmp.openRead(0, 5).fold<List<int>>([], (a, b) => a..addAll(b));
        if (String.fromCharCodes(head).trim().isEmpty || !String.fromCharCodes(head).startsWith('%PDF')) {
          throw 'الملف المُحمَّل ليس PDF صالحاً. تأكد من مشاركة الرابط للجميع.';
        }
      }
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);

      _files[m.id] = OfflineFile(
        id: m.id,
        title: m.title,
        subject: m.subject,
        department: m.department,
        ext: ext,
        path: target.path,
        size: received,
        savedAt: DateTime.now(),
      );
      await _save();
      return true;
    } catch (e) {
      _errors[m.id] = e is TimeoutException ? 'انتهت مهلة الاتصال.' : '$e';
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return false;
    } finally {
      client.close();
      _progress.remove(m.id);
      notifyListeners();
    }
  }

  String _cleanExt(String ext) {
    final e = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return (e.isEmpty || e == 'other') ? 'bin' : e;
  }

  /// Stores an exported (edited) copy of a PDF in the library.
  Future<void> addExport({required File file, required String title}) async {
    final id = 'export_${DateTime.now().millisecondsSinceEpoch}';
    _files[id] = OfflineFile(
      id: id,
      title: title,
      subject: 'نسخة معدّلة',
      department: '',
      ext: 'pdf',
      path: file.path,
      size: await file.length(),
      savedAt: DateTime.now(),
      isExport: true,
    );
    await _save();
    notifyListeners();
  }

  Future<Directory> exportsDir() => _dir('exports');

  Future<void> remove(String id) async {
    final f = _files.remove(id);
    if (f != null) {
      try {
        final file = File(f.path);
        if (await file.exists()) await file.delete();
        final ann = File('${f.path}.ann.json');
        if (await ann.exists()) await ann.delete();
      } catch (_) {}
    }
    await _save();
    notifyListeners();
  }

  void setLastPage(String id, int page) {
    final f = _files[id];
    if (f == null || f.lastPage == page) return;
    f.lastPage = page;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
