// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../app_flavor.dart';
import '../firebase/firebase_repositories.dart';
import 'firestore_mappers.dart';

class FirebaseAuthState {
  const FirebaseAuthState({
    required this.status,
    this.user,
    this.link,
    this.message,
  });

  final FirebaseAuthStatus status;
  final UserProfile? user;
  final AccountLink? link;
  final String? message;

  static const booting = FirebaseAuthState(status: FirebaseAuthStatus.booting);
  static const signedOut =
      FirebaseAuthState(status: FirebaseAuthStatus.signedOut);
}

enum FirebaseAuthStatus {
  booting,
  signedOut,

  /// Signed in but the server has no directory link yet (account pending or
  /// awaiting college approval) — no attendance authority.
  unlinked,
  ready,
}

/// Bridges Authentication ↔ the account directory.
///
/// Thin by design: role/status/link come from the server-owned
/// `users/{uid}` document, and Google Sign-In is the only identity provider
/// (college email policy is enforced server-side — not invented here).
class FirebaseAuthController extends StateNotifier<FirebaseAuthState> {
  FirebaseAuthController({
    auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? functions,
    String? host,
    ValueChanged<String?>? onUidChange,
  })  : _auth = firebaseAuth ?? auth.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _onUidChange = onUidChange,
        super(FirebaseAuthState.booting) {
    if (host != null) {
      _auth.useAuthEmulator(host, AppFlavor.authPort);
    }
    _subscription = _auth.authStateChanges().listen(_handleAuthChange);
  }

  final auth.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;
  final ValueChanged<String?>? _onUidChange;

  late final StreamSubscription<auth.User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(auth.User? user) async {
    if (user == null) {
      _onUidChange?.call(null);
      state = FirebaseAuthState.signedOut;
      return;
    }
    _onUidChange?.call(user.uid);
    state = await _loadProfile(user);
  }

  Future<FirebaseAuthState> _loadProfile(auth.User user) async {
    final data = await _readProfile(user.uid);
    if (data == null) {
      return FirebaseAuthState(
        status: FirebaseAuthStatus.unlinked,
        message:
            'Account exists but no directory profile has been created for it.',
      );
    }
    final profile = mapUserProfileFromDoc(uid: user.uid, data: data);
    final link = mapAccountLinkFromDoc(uid: user.uid, data: data);
    if (profile.status == AccountStatus.pending || link?.entityId == null) {
      return FirebaseAuthState(
        status: FirebaseAuthStatus.unlinked,
        user: profile,
        link: link,
        message:
            'Account created — awaiting institution approval for a directory '
            'link. You have no attendance authority yet.',
      );
    }
    return FirebaseAuthState(
      status: FirebaseAuthStatus.ready,
      user: profile,
      link: link,
    );
  }

  /// Google Sign-In; then one-time account completion callable
  /// (`completeSignIn`) is invoked so a `users/{uid}` document is created for
  /// brand-new sign-ins.
  Future<void> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final GoogleSignInAccount account;
      try {
        account = await _googleSignIn.authenticate();
      } on GoogleSignInException {
        state = const FirebaseAuthState(
          status: FirebaseAuthStatus.signedOut,
          message: 'Sign-in window dismissed.',
        );
        return;
      }
      final credential = auth.GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final current = result.user;
      if (current == null) {
        state = FirebaseAuthState.signedOut;
        return;
      }
      await _functions
          .httpsCallable('completeSignIn')
          .call(<String, Object?>{
        'displayName': current.displayName ?? account.displayName ?? '',
        'email': current.email ?? account.email,
      });
      _onUidChange?.call(current.uid);
      state = await _loadProfile(current);
    } on Exception {
      state = const FirebaseAuthState(
        status: FirebaseAuthStatus.unlinked,
        message: 'Google Sign-In failed. Check the auth emulator and retry.',
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _onUidChange?.call(null);
    state = FirebaseAuthState.signedOut;
  }

  static Future<Map<String, Object?>?> _readProfile(String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return snap.exists ? snap.data()?.cast<String, Object?>() : null;
  }
}

final firebaseAuthControllerProvider =
    StateNotifierProvider<FirebaseAuthController, FirebaseAuthState>(
  (ref) => FirebaseAuthController(
    host: AppFlavor.emulatorHost,
    onUidChange: (uid) =>
        ref.read(firebaseAuthUidProvider.notifier).state = uid,
  ),
);