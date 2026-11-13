// File generated and configured for GenZoo Student Portal
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Firebase Web app configuration supplied for project: genzoo-app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDFspg2KIKMShMzMAufq2zxhxsdLFHOpds',
    appId: '1:971349959914:web:ef26a0f3fee148037be393',
    messagingSenderId: '971349959914',
    projectId: 'genzoo-app',
    authDomain: 'genzoo-app.firebaseapp.com',
    storageBucket: 'genzoo-app.firebasestorage.app',
  );

  // Values taken from android/app/google-services.json (project: genzoo-app)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCyItoPA7NaBYck4-tdTMWvIvj6TIe8eG0',
    appId: '1:971349959914:android:dba3251ab594cf447be393',
    messagingSenderId: '971349959914',
    projectId: 'genzoo-app',
    storageBucket: 'genzoo-app.firebasestorage.app',
  );

  // iOS Firebase app has not yet been configured for this project.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyIosPlaceholderApiKeyForGenZoo12345',
    appId: '1:123456789012:ios:abcdef123456789',
    messagingSenderId: '123456789012',
    projectId: 'genzoo-student-portal',
    storageBucket: 'genzoo-student-portal.appspot.com',
    iosBundleId: 'com.genzoo.portal',
  );
}
