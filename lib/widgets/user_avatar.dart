import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/drive_link.dart';

/// Profile picture, or the first letter of the name when there is none.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  const UserAvatar({super.key, required this.name, this.photoUrl, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      child: Text(initial, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: radius * 0.9)),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    final size = (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round().clamp(80, 600);
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          driveImageUrl(url, width: size),
          fit: BoxFit.cover,
          loadingBuilder: (_, child, p) => p == null ? child : fallback,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
