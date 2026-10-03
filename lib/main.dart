import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/design_system/app_colors.dart';
import 'data/firebase/firebase_init.dart';
import 'data/local/notification_store.dart';
import 'data/local/payroll_store.dart';
import 'data/local/roster_store.dart';
import 'data/local/runtime_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native-app chrome: draw edge-to-edge behind the system bars and paint a
  // warm, light system UI (dark icons on the warm canvas). Purely presentational
  // — no effect on routing, auth, or the attendance state machine.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000), // transparent — content shows through
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light, // iOS
    systemNavigationBarColor: AppColors.warmSurface,
    systemNavigationBarDividerColor: AppColors.warmLine,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await bootstrapFirebase();

  // Hydrate on-device activity (submitted sessions + supervisor decisions) so
  // the connected loop survives app restarts in the local build. Non-fatal on
  // failure — the store starts clean.
  await RuntimeStore.instance.load();
  await RosterStore.instance.load();
  await NotificationStore.instance.load();
  await PayrollStore.instance.load();

  runApp(const ProviderScope(child: EarnLearnApp()));
}
