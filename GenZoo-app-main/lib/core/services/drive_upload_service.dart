import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// A file saved in Google Drive.
class UploadedFile {
  final String name;
  final String url;
  final int size;

  const UploadedFile({required this.name, required this.url, required this.size});

  Map<String, dynamic> toMap() => {'name': name, 'url': url, 'size': size};

  factory UploadedFile.fromMap(Map<String, dynamic> m) => UploadedFile(
        name: m['name'] as String? ?? 'ملف',
        url: m['url'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
      );
}

class UploadException implements Exception {
  final String message;
  UploadException(this.message);
  @override
  String toString() => message;
}

/// Uploads files to Google Drive through the Apps Script web app in
/// scripts/drive_upload.gs. The web app URL is stored in Firestore
/// (config/upload) so the admin can set or change it without a new build.
class DriveUploadService {
  static const int maxBytes = 15 * 1024 * 1024;

  static const Map<String, String> _mime = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'zip': 'application/zip',
    'txt': 'text/plain',
  };

  static Future<String?> getEndpoint() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('upload').get();
      final url = (doc.data()?['url'] as String? ?? '').trim();
      return url.isEmpty ? null : url;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveEndpoint(String url) {
    return FirebaseFirestore.instance
        .collection('config')
        .doc('upload')
        .set({'url': url.trim(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<UploadedFile> upload(String path, {String? displayName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw UploadException('سجّل الدخول أولاً لرفع الملفات.');

    final endpoint = await getEndpoint();
    if (endpoint == null) {
      throw UploadException('رفع الملفات غير مفعّل بعد. على المسؤول إعداده من لوحة التحكم.');
    }

    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw UploadException('حجم الملف أكبر من 15 ميجابايت.');
    }

    final name = displayName ?? path.split(Platform.pathSeparator).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final token = await user.getIdToken();

    final payload = jsonEncode({
      'idToken': token,
      'name': name,
      'mimeType': _mime[ext] ?? 'application/octet-stream',
      'data': base64Encode(bytes),
    });

    final client = http.Client();
    try {
      var res = await client
          .post(Uri.parse(endpoint),
              headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: payload)
          .timeout(const Duration(minutes: 3));

      // Apps Script answers a POST with a redirect to the result.
      var hops = 0;
      while ((res.statusCode == 301 ||
              res.statusCode == 302 ||
              res.statusCode == 303 ||
              res.statusCode == 307) &&
          hops < 5) {
        final location = res.headers['location'];
        if (location == null) break;
        res = await client.get(Uri.parse(location)).timeout(const Duration(minutes: 1));
        hops++;
      }

      if (res.statusCode != 200) {
        throw UploadException('فشل الرفع (رمز ${res.statusCode}).');
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (json['ok'] != true) {
        final err = '${json['error']}';
        if (err.contains('unauthorized')) throw UploadException('تعذر التحقق من حسابك، سجّل الدخول من جديد.');
        if (err.contains('too large')) throw UploadException('حجم الملف أكبر من المسموح.');
        throw UploadException('فشل الرفع: $err');
      }
      return UploadedFile(
        name: json['name'] as String? ?? name,
        url: json['url'] as String,
        size: (json['size'] as num?)?.toInt() ?? bytes.length,
      );
    } on UploadException {
      rethrow;
    } catch (e) {
      throw UploadException('تعذر الرفع، تأكد من الاتصال بالإنترنت ($e).');
    } finally {
      client.close();
    }
  }
}
