import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:background_downloader/background_downloader.dart';
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
    _initDownloader();
  }

  List<OfflineFile> get items {
    final list = _files.values.toList();
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  List<OfflineFile> get downloads => items.where((f) => !f.isExport && !f.isExternal).toList();
  List<OfflineFile> get externals => items.where((f) => f.isExternal).toList();
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

  // ---- Background downloads (survive leaving the app or closing it) ----

  static const _group = 'materials';
  bool _downloaderReady = false;

  Future<void> _initDownloader() async {
    if (_downloaderReady) return;
    _downloaderReady = true;
    try {
      final d = FileDownloader();
      d.configureNotificationForGroup(
        _group,
        running: const TaskNotification('جارٍ التحميل', '{displayName}'),
        complete: const TaskNotification('تم التحميل', '{displayName} جاهز للقراءة بدون إنترنت'),
        error: const TaskNotification('تعذّر التحميل', '{displayName}'),
        paused: const TaskNotification('التحميل متوقف مؤقتاً', '{displayName}'),
        progressBar: true,
      );
      d.updates.listen(_onUpdate);
      await d.trackTasks();
      // Delivers updates that happened while the app was closed.
      await d.resumeFromBackground();
    } catch (e) {
      debugPrint('Background downloader could not start: $e');
    }
  }

  static String _taskId(String materialId) => 'dl_$materialId';

  Future<void> _onUpdate(TaskUpdate update) async {
    final task = update.task;
    if (task.group != _group) return;
    Map<String, dynamic> meta;
    try {
      meta = Map<String, dynamic>.from(jsonDecode(task.metaData) as Map);
    } catch (_) {
      return;
    }
    final id = meta['id'] as String? ?? '';
    if (id.isEmpty) return;

    if (update is TaskProgressUpdate) {
      if (update.progress >= 0 && update.progress < 1) {
        _progress[id] = update.progress;
        notifyListeners();
      }
      return;
    }
    if (update is! TaskStatusUpdate) return;

    switch (update.status) {
      case TaskStatus.complete:
        try {
          await _finalize(task, meta);
          _errors.remove(id);
        } catch (e) {
          _errors[id] = '$e';
        }
        _progress.remove(id);
      case TaskStatus.failed:
      case TaskStatus.notFound:
        _errors[id] = update.status == TaskStatus.notFound
            ? 'الملف غير موجود على الرابط.'
            : (update.exception?.description ?? 'تعذّر التحميل.');
        _progress.remove(id);
        await _deletePartial(task);
      case TaskStatus.canceled:
        _progress.remove(id);
        await _deletePartial(task);
      default:
        break; // enqueued / running / paused / waitingToRetry
    }
    notifyListeners();
  }

  Future<void> _deletePartial(Task task) async {
    try {
      final f = File(await task.filePath());
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Validates the downloaded file and adds it to the offline library.
  Future<void> _finalize(Task task, Map<String, dynamic> meta) async {
    final path = await task.filePath();
    final file = File(path);
    if (!await file.exists()) throw 'تعذّر حفظ الملف.';
    final size = await file.length();
    if (size == 0) {
      await file.delete();
      throw 'الملف فارغ.';
    }
    final ext = meta['ext'] as String? ?? 'bin';
    final head = await file.openRead(0, 5).fold<List<int>>([], (a, b) => a..addAll(b));
    final headStr = String.fromCharCodes(head);
    if (ext == 'pdf' && !headStr.startsWith('%PDF')) {
      await file.delete();
      throw 'الملف المُحمَّل ليس PDF صالحاً. تأكد من مشاركة الرابط للجميع.';
    }
    if (ext != 'pdf' && headStr.toLowerCase().contains('<')) {
      // An HTML page (Drive sign-in / virus-scan page) instead of the file.
      final text = await file.openRead(0, 300).transform(utf8.decoder).join().catchError((_) => '');
      if (text.toLowerCase().contains('<html') || text.toLowerCase().contains('<!doctype')) {
        await file.delete();
        throw 'هذا الرابط لا يدعم التحميل المباشر. افتحه من المتصفح.';
      }
    }
    final id = meta['id'] as String;
    _files[id] = OfflineFile(
      id: id,
      title: meta['title'] as String? ?? '',
      subject: meta['subject'] as String? ?? '',
      department: meta['department'] as String? ?? '',
      ext: ext,
      path: path,
      size: size,
      savedAt: DateTime.now(),
    );
    await _save();
  }

  /// Starts a download that keeps running in the background. Returns true
  /// when it was queued; the result arrives through [progress], [fileFor]
  /// and [errorFor], and as a notification.
  Future<bool> download(StudyMaterial m) async {
    if (_progress.containsKey(m.id)) return false; // already running
    _errors.remove(m.id);
    await _initDownloader();
    try {
      final ext = _cleanExt(m.fileExtension);
      final dir = await _dir('materials');
      final target = File('${dir.path}/${m.id}.$ext');
      if (await target.exists()) await target.delete();

      final task = DownloadTask(
        taskId: _taskId(m.id),
        url: directDownloadUrl(m.fileUrl),
        filename: '${m.id}.$ext',
        baseDirectory: BaseDirectory.applicationDocuments,
        directory: 'materials',
        group: _group,
        updates: Updates.statusAndProgress,
        retries: 3,
        allowPause: true,
        displayName: m.title,
        metaData: jsonEncode({
          'id': m.id,
          'title': m.title,
          'subject': m.subject,
          'department': m.department,
          'ext': ext,
        }),
      );
      _progress[m.id] = 0;
      notifyListeners();
      final ok = await FileDownloader().enqueue(task);
      if (!ok) {
        _progress.remove(m.id);
        _errors[m.id] = 'تعذّر بدء التحميل.';
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _progress.remove(m.id);
      _errors[m.id] = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelDownload(String materialId) async {
    await FileDownloader().cancelTaskWithId(_taskId(materialId));
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

  /// Imports a PDF opened from another app (or picked from the device) so it
  /// can be read, edited and found again in "تحميلاتي".
  Future<OfflineFile> addExternal({required String sourcePath, required String name}) async {
    final dir = await _dir('external');
    var clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!clean.toLowerCase().endsWith('.pdf')) clean = '$clean.pdf';
    final src = File(sourcePath);
    final size = await src.length();
    // Same name + same size already imported → reuse it (keeps edits and last page).
    for (final f in _files.values) {
      if (f.isExternal && f.title == clean && f.size == size && File(f.path).existsSync()) {
        f.lastPage = f.lastPage;
        return f;
      }
    }
    final id = 'ext_${DateTime.now().millisecondsSinceEpoch}';
    final target = File('${dir.path}/$id.pdf');
    await src.copy(target.path);
    if (sourcePath.contains('external_pdf')) {
      try { await src.delete(); } catch (_) {}
    }
    final f = OfflineFile(
      id: id,
      title: clean,
      subject: 'ملف من خارج التطبيق',
      department: '',
      ext: 'pdf',
      path: target.path,
      size: size,
      savedAt: DateTime.now(),
    );
    _files[id] = f;
    await _save();
    notifyListeners();
    return f;
  }

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
