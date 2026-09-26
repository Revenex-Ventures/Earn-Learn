/// Build/run flavor switch for the Firebase backend.
///
/// Stage 2A ships **emulator-first**: the local `@DevOnly` repositories remain
/// the default; the Firestore-backed implementations are opt-in at run time via
/// `--dart-define=FIREBASE=true`. Unit/widget tests never enable this.
///
/// ```sh
/// flutter run --dart-define=FIREBASE=true \
///   --dart-define=FIREBASE_HOST=127.0.0.1
/// ```
class AppFlavor {
  AppFlavor._();

  /// True when the app should bind the Firestore/Auth/Storage repositories.
  static const bool useFirebase =
      bool.fromEnvironment('FIREBASE', defaultValue: false);

  /// Emulator host (use 127.0.0.1 locally; other machines target their IP).
  static const String emulatorHost =
      String.fromEnvironment('FIREBASE_HOST', defaultValue: '127.0.0.1');

  /// Fixed emulator ports from firebase.json.
  static const int authPort = 9099;
  static const int firestorePort = 8080;
  static const int functionsPort = 5001;
  static const int storagePort = 9199;
}