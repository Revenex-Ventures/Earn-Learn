import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../data/app_flavor.dart';
import '../../data/firebase/firebase_auth_controller.dart';

/// Emulator-first authentication gate.
///
/// Renders the app's router ONLY after a Firebase session with a server-issued,
/// linked, non-pending account. Unlinked and pending accounts see an explicit
/// status (they get no attendance authority). When the flavor is off the gate
/// is a pass-through so Stage 1B demo flows are untouched.
class FirebaseAuthGate extends ConsumerWidget {
  const FirebaseAuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppFlavor.useFirebase) return child;

    final authState = ref.watch(firebaseAuthControllerProvider);
    return switch (authState.status) {
      FirebaseAuthStatus.booting => const _GateScaffold(
          child: Center(child: CircularProgressIndicator()),
        ),
      FirebaseAuthStatus.signedOut => _SignedOutPanel(
          onSignIn: () => ref.read(firebaseAuthControllerProvider.notifier)
              .signInWithGoogle(),
        ),
      FirebaseAuthStatus.unlinked => _UnlinkedPanel(
          message: authState.message ??
              'Account awaiting institution approval — no attendance authority.',
          onSignOut: () => ref.read(firebaseAuthControllerProvider.notifier)
              .signOut(),
        ),
      FirebaseAuthStatus.ready => child,
    };
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(child: child),
    );
  }
}

class _SignedOutPanel extends StatelessWidget {
  const _SignedOutPanel({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return _GateScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Earn & Learn', style: AppTextStyles.headlineLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sign in with your college Google account. '
                'Authority is granted server-side only.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Continue with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlinkedPanel extends StatelessWidget {
  const _UnlinkedPanel({required this.message, required this.onSignOut});

  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _GateScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top,
                  size: 40, color: AppColors.marigold),
              const SizedBox(height: AppSpacing.lg),
              Text('Account pending', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              OutlinedButton(
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}