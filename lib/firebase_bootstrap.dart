import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;

import 'firebase_options.dart';

/// Initializes Firebase once. Call before [FirebaseAuth] or other Firebase APIs.
///
/// On Android, the native Google Services plugin may already create the default
/// app before Dart runs; a second [Firebase.initializeApp] then throws
/// [FirebaseException] with code `duplicate-app`.
Future<void> ensureFirebaseInitialized() async {
  if (_hasUsableDefaultApp()) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  } on UnsupportedError {
    rethrow;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app' && _hasUsableDefaultApp()) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Firebase.initializeApp();
        if (_hasUsableDefaultApp()) return;
      } on FirebaseException catch (e2) {
        if (e2.code == 'duplicate-app' && _hasUsableDefaultApp()) return;
      }
    }

    rethrow;
  }
}

bool _hasUsableDefaultApp() {
  if (Firebase.apps.isEmpty) return false;
  try {
    Firebase.app();
    return true;
  } catch (_) {
    return false;
  }
}

/// User-facing message when [ensureFirebaseInitialized] or auth setup fails.
String firebaseBootstrapErrorMessage(Object error) {
  if (error is UnsupportedError) {
    if (kIsWeb) {
      return 'Web Firebase is not configured. Run: flutterfire configure '
          '(or set real keys in lib/firebase_options.dart).';
    }
    return 'Firebase is only set up for Android in this project. '
        'Run on your phone: flutter run -d android';
  }

  if (error is FirebaseException) {
    final detail = error.message?.trim();
    if (detail != null && detail.isNotEmpty) {
      return 'Firebase error (${error.code}): $detail';
    }
    return 'Firebase error: ${error.code}';
  }

  if (kDebugMode) {
    return 'Could not start Firebase: $error';
  }

  return 'Firebase could not start. Confirm android/app/google-services.json '
      'matches lib/firebase_options.dart, then stop the app and run it again '
      '(not hot reload).';
}
