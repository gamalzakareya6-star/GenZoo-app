
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

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register the background notification handler
    // before the application starts.
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // Configure notification permission and topic subscription.
    await NotificationService.init();
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization notice: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const GenZooStudentPortalApp());
}

class GenZooStudentPortalApp extends StatelessWidget {
  const GenZooStudentPortalApp({super.key});

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
