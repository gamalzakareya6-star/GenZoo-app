
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/news_provider.dart';
import 'providers/materials_provider.dart';
import 'providers/gpa_provider.dart';
import 'screens/splash_screen.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'ar';

  await initializeDateFormatting('ar');

  bool firebaseReady = false;

  // Initialize Firebase before creating providers that depend on it.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    firebaseReady = true;
    debugPrint('GenZoo: Firebase initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('GenZoo: Firebase initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Start the application without waiting for notification
  // permissions, topic subscriptions, or network requests.
  runApp(
    GenZooStudentPortalApp(
      firebaseReady: firebaseReady,
    ),
  );

  // Configure notifications after the first frame.
  // A notification setup failure must not block the UI.
  if (firebaseReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeNotifications());
    });
  }
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.init().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint(
          'GenZoo: Notification initialization timed out.',
        );
      },
    );
  } catch (e, stackTrace) {
    debugPrint('GenZoo: Notification setup failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class GenZooStudentPortalApp extends StatelessWidget {
  final bool firebaseReady;

  const GenZooStudentPortalApp({
    super.key,
    this.firebaseReady = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserAuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NewsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MaterialsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => GpaProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        scaffoldMessengerKey:
            NotificationService.messengerKey,
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}
