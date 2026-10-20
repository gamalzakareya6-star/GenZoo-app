import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Free push notifications via Firebase Cloud Messaging topics.
/// Admins send a message from Firebase Console -> Messaging to the topic "news".
class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static const String newsTopic = 'news';

  static Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.subscribeToTopic(newsTopic);

      // App is open: show the notification as an in-app banner
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final n = message.notification;
        if (n == null) return;
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title ?? 'إشعار جديد', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if ((n.body ?? '').isNotEmpty) Text(n.body!),
                ],
              ),
            ),
          );
      });
    } catch (e) {
      debugPrint('Notification setup skipped: $e');
    }
  }
}
