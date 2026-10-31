import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/avatar_service.dart';
import '../core/utils/drive_link.dart';

/// Profile picture, or the first letter of the name when there is none.
/// Pass [uid] to load the student's saved picture; [bytes] shows a local preview.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? uid;
  final Uint8List? bytes;
  final String name;
  final double radius;
  const UserAvatar({super.key, required this.name, this.photoUrl, this.uid, this.bytes, this.radius = 20});

  Widget _circle(Widget child) => ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: child));

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      child: Text(initial, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: radius * 0.9)),
    );

    Widget legacy() {
      final url = photoUrl;
      if (url == null || !url.startsWith('http')) return fallback;
      final size = (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round().clamp(80, 600);
      return _circle(Image.network(
        driveImageUrl(url, width: size),
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) => p == null ? child : fallback,
        errorBuilder: (_, __, ___) => fallback,
      ));
    }

    if (bytes != null) return _circle(Image.memory(bytes!, fit: BoxFit.cover));
    final id = uid;
    if (id == null || id.isEmpty) return legacy();
    return ValueListenableBuilder<int>(
      valueListenable: AvatarService.changes,
      builder: (_, __, ___) => FutureBuilder<Uint8List?>(
        future: AvatarService.get(id),
        builder: (_, snap) {
          final b = snap.data;
          if (b != null) return _circle(Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true));
          if (snap.connectionState != ConnectionState.done) return fallback;
          return legacy();
        },
      ),
    );
  }
}
