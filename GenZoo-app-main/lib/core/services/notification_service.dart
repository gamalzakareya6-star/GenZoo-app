
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';

/// Handles Firebase Cloud Messaging notifications for GenZoo.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'Background notification received: ${message.messageId}',
  );
}

class NotificationService {
  static final GlobalKey<ScaffoldMessengerState>
      messengerKey = GlobalKey<ScaffoldMessengerState>();

  static const String newsTopic = 'news';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Ask for notification permission.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'Notification permission: ${settings.authorizationStatus}',
      );

      // Subscribe this device to the news topic.
      await messaging.subscribeToTopic(newsTopic);

      // Handle notifications while the app is open.
      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          final notification = message.notification;

          if (notification == null) return;

          messengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 6),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title ?? 'إشعار جديد',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((notification.body ?? '').isNotEmpty)
                      Text(notification.body!),
                  ],
                ),
              ),
            );
        },
      );

      // Handle taps on notifications when the app
      // was in the background.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint(
            'Notification opened: ${message.messageId}',
          );
        },
      );

      // Handle a notification that opened the app
      // from a terminated state.
      final initialMessage =
          await messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint(
          'App opened from notification: '
          '${initialMessage.messageId}',
        );
      }

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('Notification setup failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
