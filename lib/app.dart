import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design_system/app_theme.dart';
import 'core/routing/app_router.dart';
import 'features/auth/firebase_auth_gate.dart';

class EarnLearnApp extends ConsumerWidget {
  const EarnLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return FirebaseAuthGate(
      child: MaterialApp.router(
        title: 'Earn & Learn',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}