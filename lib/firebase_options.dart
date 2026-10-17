// Generated from android/app/google-services.json (project: madebymaa-633ee).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Android, iOS & Web.
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
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: '1:367368154263:web:REPLACE_ME',
    messagingSenderId: '367368154263',
    projectId: 'madebymaa-633ee',
    authDomain: 'madebymaa-633ee.firebaseapp.com',
    storageBucket: 'madebymaa-633ee.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA93w58EdNdL5Eo3Ifgk1a1i9dE_LXtWpQ',
    appId: '1:367368154263:android:0fe8b60dc9d6ec6b658dd2',
    messagingSenderId: '367368154263',
    projectId: 'madebymaa-633ee',
    storageBucket: 'madebymaa-633ee.firebasestorage.app',
  );

  // Still points at the previous Firebase iOS app until a new GoogleService-Info.plist is added.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCVva9MzHg11R6wah1qg2V6hU30Vhr-uYg',
    appId: '1:780271006039:ios:c6fb79faf29e6c9c0bce12',
    messagingSenderId: '780271006039',
    projectId: 'madebymaa-d820e',
    storageBucket: 'madebymaa-d820e.firebasestorage.app',
    iosBundleId: 'com.madebymaa.seller',
  );
}
