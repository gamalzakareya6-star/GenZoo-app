import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Profile pictures. Each one is shrunk on the phone to a small JPEG and kept
/// in Firestore (`avatars/{uid}`), so it needs no file hosting and appears
/// everywhere the student's uid is known (drawer, comments, chat, leaderboard).
class AvatarService {
  static final Map<String, Future<Uint8List?>> _cache = {};

  /// Bumped whenever somebody's picture changes so visible avatars reload.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static Uint8List _shrink(String path) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) throw 'تعذّر قراءة الصورة';
    final oriented = img.bakeOrientation(decoded);
    final side = oriented.width < oriented.height ? oriented.width : oriented.height;
    final square = img.copyCrop(
      oriented,
      x: (oriented.width - side) ~/ 2,
      y: (oriented.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final small = img.copyResize(square, width: 192, height: 192, interpolation: img.Interpolation.average);
    return Uint8List.fromList(img.encodeJpg(small, quality: 78));
  }

  /// Crops to a square and shrinks the picked file (about 8–15 KB).
  static Future<Uint8List> prepare(String path) => compute(_shrink, path);

  static Future<void> save(String uid, Uint8List bytes) async {
    await FirebaseFirestore.instance.collection('avatars').doc(uid).set({
      'b64': base64Encode(bytes),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _cache[uid] = Future.value(bytes);
    changes.value++;
  }

  static Future<void> remove(String uid) async {
    await FirebaseFirestore.instance.collection('avatars').doc(uid).delete();
    _cache[uid] = Future.value(null);
    changes.value++;
  }

  static Future<Uint8List?> get(String uid) {
    return _cache.putIfAbsent(uid, () async {
      try {
        final d = await FirebaseFirestore.instance.collection('avatars').doc(uid).get();
        final b64 = d.data()?['b64'] as String?;
        if (b64 == null || b64.isEmpty) return null;
        return base64Decode(b64);
      } catch (_) {
        _cache.remove(uid); // retry next time (offline / rules not published yet)
        return null;
      }
    });
  }
}
