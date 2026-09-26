import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/features/student/home_screen.dart';

void main() {
  testWidgets(
      'student home composes duty card, hours meter, upcoming shift and weekly attendance without earnings',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: StudentHomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S DUTY"), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.textContaining('Mayur'), findsWidgets);
    expect(find.text('Monthly hours'), findsOneWidget);
    expect(find.textContaining('used'), findsOneWidget);
    expect(find.textContaining('remaining'), findsWidgets);
    expect(find.text('Upcoming shift'), findsOneWidget);
    // Asserts complete absence of student earnings / currency presentation
    expect(find.textContaining('₹'), findsNothing);
  });
}