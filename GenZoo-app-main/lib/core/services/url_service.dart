import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlService {
  static Future<void> launchWebUrl(BuildContext context, String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) {
      _showErrorSnackBar(context, 'الرابط غير صالح أو فارغ.');
      return;
    }

    final Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null) {
      _showErrorSnackBar(context, 'تعذّر قراءة الرابط.');
      return;
    }

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'تعذّر فتح الرابط: $cleanUrl');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'حدث خطأ أثناء فتح الرابط: $e');
      }
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
