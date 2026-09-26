import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/app.dart';

void main() {
  testWidgets('app boots to AVCOE splash and transitions to role selection',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EarnLearnApp()));
    await tester.pump();

    expect(find.text('Earn & Learn'), findsOneWidget);
    expect(find.text('Amrutvahini College of Engineering'), findsOneWidget);

    // Fast-forward 2 seconds for splash timer
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Select your role'), findsOneWidget);
  });
}