import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// A newer build published as a GitHub Release.
class AppUpdate {
  final int build;
  final String notes;
  final String apkUrl;

  const AppUpdate({required this.build, required this.notes, required this.apkUrl});
}

/// Looks for a newer APK. The CI publishes every build as a release tagged
/// `build-<number>` (the number equals the app's Android versionCode).
class UpdateService {
  static const String _latest =
      'https://api.github.com/repos/gamalzakareya6-star/GenZoo-app/releases/latest';

  static Future<AppUpdate?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse(_latest), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '');
      final match = RegExp(r'^build-(\d+)$').firstMatch(tag);
      if (match == null) return null;
      final build = int.parse(match.group(1)!);
      if (build <= current) return null;

      String? url;
      for (final a in (json['assets'] as List<dynamic>? ?? [])) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          url = a['browser_download_url'] as String?;
          break;
        }
      }
      if (url == null) return null;

      return AppUpdate(
        build: build,
        notes: (json['body'] as String? ?? '').trim(),
        apkUrl: url,
      );
    } catch (e) {
      debugPrint('Update check skipped: $e');
      return null;
    }
  }
}
