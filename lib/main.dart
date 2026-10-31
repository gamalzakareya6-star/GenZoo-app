
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
import 'providers/downloads_provider.dart';
import 'providers/review_stats_provider.dart';
import 'providers/feature_flags.dart';
import 'providers/daily_provider.dart';
import 'providers/appearance_provider.dart';
import 'core/constants/app_colors.dart';
import 'providers/forest_provider.dart';
import 'core/services/download_notification_service.dart';
import 'screens/splash_screen.dart';
import 'core/services/notification_service.dart';
import 'core/services/external_pdf.dart';

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
    await DownloadNotificationService().init();
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
          create: (_) => AppearanceProvider(),
        ),
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
          create: (_) => DownloadsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ForestProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewStatsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FeatureFlags(),
        ),
        // Keeps the GPA calculator data separate for every account.
        ChangeNotifierProxyProvider<UserAuthProvider, GpaProvider>(
          create: (_) => GpaProvider(),
          update: (_, auth, gpa) {
            final provider = gpa ?? GpaProvider();
            provider.attachUser(auth.user?.uid);
            return provider;
          },
        ),
      ],
      child: Consumer<AppearanceProvider>(
        builder: (context, ap, _) => MaterialApp(
        title: AppConstants.appName,
        navigatorKey: ExternalPdf.navigatorKey,
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
        theme: AppTheme.build(Brightness.light, ap),
        darkTheme: AppTheme.build(Brightness.dark, ap),
        themeMode: ap.mode,
        builder: (context, child) {
          AppColors.dark = Theme.of(context).brightness == Brightness.dark;
          final mq = MediaQuery.of(context);
          final system = mq.textScaler.scale(14) / 14;
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(system * ap.fontScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
        ),
      ),
    );
  }
}
