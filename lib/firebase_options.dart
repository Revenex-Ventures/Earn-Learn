import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase configuration for the registered EarnAndLearn app
/// identifiers (Project `earnandlearn-2eeea`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'No web app is registered for earnandlearn-2eeea; Stage 2A targets '
        'Android.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'No iOS app is registered for earnandlearn-2eeea yet. Stage 2A '
          'targets Android; iOS requires a real GoogleService-Info.plist and a '
          're-run of flutterfire configure before it can be enabled.',
        );
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCx8DThgSPf5OhlVqjrnAe9hPN23ZqAEEQ',
    appId: '1:159946200704:android:6992b8669895780e0cf865',
    messagingSenderId: '159946200704',
    projectId: 'earnandlearn-2eeea',
    storageBucket: 'earnandlearn-2eeea.firebasestorage.app',
  );
}