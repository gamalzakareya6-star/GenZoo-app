import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

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
  static const int maxBytes = 30 * 1024 * 1024;

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
    'webp': 'image/webp',
    'gif': 'image/gif',
    'zip': 'application/zip',
    'txt': 'text/plain',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'mp3': 'audio/mpeg',
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

  static Future<UploadedFile> upload(String path, {String? displayName, void Function(int sent, int total)? onProgress}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw UploadException('سجّل الدخول أولاً لرفع الملفات.');

    final endpoint = await getEndpoint();
    if (endpoint == null) {
      throw UploadException('رفع الملفات غير مفعّل بعد. على المسؤول إعداده من لوحة التحكم.');
    }

    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw UploadException('حجم الملف أكبر من 30 ميجابايت.');
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

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 2),
      followRedirects: true,
      maxRedirects: 5,
      responseType: ResponseType.plain,
    ));
    try {
      final response = await dio.post<String>(
        endpoint,
        data: payload,
        options: Options(headers: {
          'Content-Type': 'text/plain;charset=utf-8',
          'Accept': 'application/json',
        }),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent, total);
        },
      );
      if (response.statusCode != 200) {
        throw UploadException('فشل الرفع (رمز ${response.statusCode}).');
      }
      final raw = (response.data ?? '').trim();
      if (raw.isEmpty) {
        throw UploadException('خدمة Google Drive لم تُرجع أي بيانات. تأكد من رابط Apps Script وإعادة نشره.');
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        final looksLikeHtml = raw.startsWith('<') ||
            raw.toLowerCase().contains('<!doctype html');
        if (looksLikeHtml) {
          throw UploadException(
            'وصلت صفحة ويب بدل نتيجة الرفع. غالبًا رابط Google Apps Script قديم أو صلاحية النشر ليست Anyone. أعد نشره كـ Web App ثم حدّث الرابط في لوحة الإدارة.',
          );
        }
        throw UploadException('استجابة Google Drive غير مفهومة. أعد المحاولة، وإذا تكرر الخطأ أرسل رسالة الخطأ للمسؤول.');
      }
      if (decoded is! Map<String, dynamic>) {
        throw UploadException('استجابة Google Drive غير صالحة.');
      }
      final json = decoded;
      if (json['ok'] != true) {
        final err = '${json['error']}';
        if (err.contains('unauthorized')) throw UploadException('تعذر التحقق من حسابك، سجّل الدخول من جديد.');
        if (err.contains('too large')) throw UploadException('حجم الملف أكبر من المسموح.');
        throw UploadException('فشل الرفع: $err');
      }
      onProgress?.call(payload.length, payload.length);
      return UploadedFile(
        name: json['name'] as String? ?? name,
        url: json['url'] as String,
        size: (json['size'] as num?)?.toInt() ?? bytes.length,
      );
    } on UploadException {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 413) {
        throw UploadException('خدمة الرفع رفضت حجم الطلب بعد تحويل الملف. جرّب ملفًا أصغر.');
      }
      if (status == 401 || status == 403) {
        throw UploadException('خدمة Google Drive رفضت الطلب. تأكد أن نشر Apps Script يسمح بالوصول Anyone.');
      }
      if (e.type == DioExceptionType.sendTimeout) {
        throw UploadException('انتهت مهلة رفع الملف. جرّب اتصالًا أسرع أو أعد المحاولة.');
      }
      throw UploadException('تعذر الاتصال بخدمة Google Drive: ${e.message ?? 'خطأ غير معروف'}');
    } catch (e) {
      throw UploadException('تعذر الرفع، تأكد من الاتصال بالإنترنت ($e).');
    }
  }
}
