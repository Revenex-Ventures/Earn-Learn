import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../app_flavor.dart';
import 'firebase_repositories.dart';

/// Idempotent one-time Firebase bootstrapping bound to the flavor switch.
///
/// Safe to call repeatedly; [Firebase.initializeApp] is a no-op once done.
/// Auth state is the single source of truth for the UID provider
/// (`firebaseAuthUidProvider`), so no manual state reset is needed here.
Future<void> bootstrapFirebase() async {
  if (!AppFlavor.useFirebase) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseRepositories.attachEmulators(host: AppFlavor.emulatorHost);
}