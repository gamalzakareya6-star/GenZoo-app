import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/material_model.dart';
import 'download_notification_service.dart';

/// Represents a locally saved material available offline.
class OfflineMaterialItem {
  final String id;
  final String title;
  final String subject;
  final String materialType;
  final String department;
  final String localPath;
  final int fileSizeBytes;
  final String fileExtension;
  final DateTime downloadedAt;
  final int lastReadPage;
  final bool isEditedCopy;

  const OfflineMaterialItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.materialType,
    required this.department,
    required this.localPath,
    required this.fileSizeBytes,
    required this.fileExtension,
    required this.downloadedAt,
    this.lastReadPage = 1,
    this.isEditedCopy = false,
  });

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'materialType': materialType,
        'department': department,
        'localPath': localPath,
        'fileSizeBytes': fileSizeBytes,
        'fileExtension': fileExtension,
        'downloadedAt': downloadedAt.toIso8601String(),
        'lastReadPage': lastReadPage,
        'isEditedCopy': isEditedCopy,
      };

  factory OfflineMaterialItem.fromJson(Map<String, dynamic> json) =>
      OfflineMaterialItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        materialType: json['materialType'] as String? ?? '',
        department: json['department'] as String? ?? '',
        localPath: json['localPath'] as String? ?? '',
        fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
        fileExtension: json['fileExtension'] as String? ?? 'pdf',
        downloadedAt: json['downloadedAt'] != null
            ? DateTime.tryParse(json['downloadedAt'] as String) ??
                DateTime.now()
            : DateTime.now(),
        lastReadPage: json['lastReadPage'] as int? ?? 1,
        isEditedCopy: json['isEditedCopy'] as bool? ?? false,
      );

  OfflineMaterialItem copyWith({
    int? lastReadPage,
    String? title,
  }) =>
      OfflineMaterialItem(
        id: id,
        title: title ?? this.title,
        subject: subject,
        materialType: materialType,
        department: department,
        localPath: localPath,
        fileSizeBytes: fileSizeBytes,
        fileExtension: fileExtension,
        downloadedAt: downloadedAt,
        lastReadPage: lastReadPage ?? this.lastReadPage,
        isEditedCopy: isEditedCopy,
      );
}

/// Service managing offline file downloads, storage, annotations, and reading progress.
class FileStorageService {
  static const String _offlineKey = 'genzoo_offline_materials_v1';
  static const String _lastPagePrefix = 'genzoo_pdf_page_';

  static Directory? _cachedFilesDir;

  /// Get or create the local GenZoo directory for downloaded files
  static Future<Directory> getFilesDirectory() async {
    if (_cachedFilesDir != null && await _cachedFilesDir!.exists()) {
      return _cachedFilesDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final filesDir = Directory('${appDir.path}/GenZoo_Files');
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }
    _cachedFilesDir = filesDir;
    return filesDir;
  }

  /// Convert a Google Drive share link into a direct download link if applicable
  static String convertToDirectUrl(String url) {
    final driveMatch =
        RegExp(r'drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (driveMatch != null) {
      final fileId = driveMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    final driveOpenMatch =
        RegExp(r'drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (driveOpenMatch != null) {
      final fileId = driveOpenMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    return url;
  }

  /// Sanitize filename for local storage
  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Download a study material and save it locally for offline use
  static Future<File> downloadMaterial(
    StudyMaterial material, {
    void Function(int received, int total, double percent)? onProgress,
  }) async {
    final filesDir = await getFilesDirectory();
    final ext = material.fileExtension.isNotEmpty ? material.fileExtension : 'pdf';
    final safeTitle = _sanitizeFilename(material.title);
    final targetPath = '${filesDir.path}/${material.id}_$safeTitle.$ext';
    final targetFile = File(targetPath);

    // If file already exists locally and is in index, return it
    if (await targetFile.exists() && await targetFile.length() > 0) {
      await _recordOfflineItem(
        OfflineMaterialItem(
          id: material.id,
          title: material.title,
          subject: material.subject,
          materialType: material.materialType,
          department: material.department,
          localPath: targetPath,
          fileSizeBytes: await targetFile.length(),
          fileExtension: ext,
          downloadedAt: DateTime.now(),
        ),
      );
      return targetFile;
    }

    final directUrl = convertToDirectUrl(material.fileUrl);
    final notificationService = DownloadNotificationService();
    final notifId = material.id.hashCode & 0x7FFFFFFF;

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(directUrl));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final double percent = totalBytes > 0
            ? (receivedBytes / totalBytes)
            : 0.0;

        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes, percent);
        }

        // Update notification bar every ~5% or periodic
        final int percentInt = (percent * 100).toInt();
        await notificationService.showDownloadProgress(
          id: notifId,
          title: 'تحميل: ${material.title}',
          progress: percentInt,
          subText: material.subject,
        );
      }

      await sink.flush();
      await sink.close();

      final finalSize = await targetFile.length();

      // Show notification completed
      await notificationService.showDownloadCompleted(
        id: notifId,
        title: 'تم اكتمال التنزيل',
        body: 'تم حفظ "${material.title}" في مكتبتك أوفلاين',
        filePath: targetPath,
      );

      // Save to local offline catalog
      await _recordOfflineItem(
        OfflineMaterialItem(
          id: material.id,
          title: material.title,
          subject: material.subject,
          materialType: material.materialType,
          department: material.department,
          localPath: targetPath,
          fileSizeBytes: finalSize,
          fileExtension: ext,
          downloadedAt: DateTime.now(),
        ),
      );

      return targetFile;
    } catch (e) {
      await notificationService.cancel(notifId);
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Record or update an item in the offline materials index
  static Future<void> _recordOfflineItem(OfflineMaterialItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getOfflineMaterials();

    final existingIndex = items.indexWhere((i) => i.id == item.id);
    if (existingIndex >= 0) {
      items[existingIndex] = item;
    } else {
      items.insert(0, item);
    }

    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_offlineKey, encoded);
  }

  /// Get all materials saved locally for offline reading
  static Future<List<OfflineMaterialItem>> getOfflineMaterials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_offlineKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      final items = <OfflineMaterialItem>[];

      for (final obj in list) {
        final item = OfflineMaterialItem.fromJson(obj as Map<String, dynamic>);
        // Ensure file still exists on disk
        if (File(item.localPath).existsSync()) {
          items.add(item);
        }
      }
      return items;
    } catch (e) {
      debugPrint('Error loading offline materials: $e');
      return [];
    }
  }

  /// Check if a specific material is saved locally
  static Future<bool> isMaterialDownloaded(String materialId) async {
    final items = await getOfflineMaterials();
    return items.any((i) => i.id == materialId && File(i.localPath).existsSync());
  }

  /// Get the local file path for a material if already downloaded
  static Future<String?> getLocalFilePath(String materialId) async {
    final items = await getOfflineMaterials();
    final item = items.cast<OfflineMaterialItem?>().firstWhere(
          (i) => i?.id == materialId,
          orElse: () => null,
        );
    if (item != null && File(item.localPath).existsSync()) {
      return item.localPath;
    }
    return null;
  }

  /// Delete a downloaded material and its local file
  static Future<void> deleteOfflineMaterial(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getOfflineMaterials();
    final target = items.cast<OfflineMaterialItem?>().firstWhere(
          (i) => i?.id == materialId,
          orElse: () => null,
        );

    if (target != null) {
      final file = File(target.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      // Also delete annotations file if exists
      final annotFile = File('${target.localPath}.annotations.json');
      if (await annotFile.exists()) {
        try {
          await annotFile.delete();
        } catch (_) {}
      }

      items.removeWhere((i) => i.id == materialId);
      final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_offlineKey, encoded);
    }
  }

  /// Save last read page for a document (saved by file path or id)
  static Future<void> saveLastReadPage(String key, int page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final safeKey = '$_lastPagePrefix${key.hashCode}';
      await prefs.setInt(safeKey, page);

      // Also update in offline catalog if matching
      final items = await getOfflineMaterials();
      final index = items.indexWhere((i) => i.id == key || i.localPath == key);
      if (index >= 0) {
        items[index] = items[index].copyWith(lastReadPage: page);
        await prefs.setString(
          _offlineKey,
          jsonEncode(items.map((i) => i.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('Error saving last read page: $e');
    }
  }

  /// Retrieve last read page for a document (defaults to 1)
  static Future<int> getLastReadPage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final safeKey = '$_lastPagePrefix${key.hashCode}';
      return prefs.getInt(safeKey) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  /// Save drawing annotations and text notes for a document
  static Future<void> saveAnnotations(
    String filePath,
    Map<String, dynamic> annotationsData,
  ) async {
    try {
      final file = File('$filePath.annotations.json');
      await file.writeAsString(jsonEncode(annotationsData));
    } catch (e) {
      debugPrint('Error saving annotations: $e');
    }
  }

  /// Load drawing annotations and text notes for a document
  static Future<Map<String, dynamic>?> loadAnnotations(String filePath) async {
    try {
      final file = File('$filePath.annotations.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading annotations: $e');
    }
    return null;
  }

  /// Save a new edited copy of the file with annotations
  static Future<String> saveEditedCopy({
    required String originalPath,
    required String originalTitle,
    required String subject,
    required String department,
    required Map<String, dynamic> annotationsData,
  }) async {
    final originalFile = File(originalPath);
    if (!await originalFile.exists()) {
      throw Exception('Original file not found');
    }

    final filesDir = await getFilesDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = originalPath.split('.').last;
    final newTitle = 'نسخة معدلة - $originalTitle';
    final safeName = _sanitizeFilename(newTitle);
    final newPath = '${filesDir.path}/edited_${timestamp}_$safeName.$ext';

    // Copy original PDF
    await originalFile.copy(newPath);

    // Save annotations alongside the new copy
    final newAnnotFile = File('$newPath.annotations.json');
    await newAnnotFile.writeAsString(jsonEncode(annotationsData));

    final newSize = await File(newPath).length();
    final newId = 'edited_$timestamp';

    // Register into offline catalog
    await _recordOfflineItem(
      OfflineMaterialItem(
        id: newId,
        title: newTitle,
        subject: subject,
        materialType: 'ملف معدل',
        department: department,
        localPath: newPath,
        fileSizeBytes: newSize,
        fileExtension: ext,
        downloadedAt: DateTime.now(),
        isEditedCopy: true,
      ),
    );

    return newPath;
  }
}
