import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/theme/app_theme.dart';

/// Item 104 — a suggestion with no known length shows none.
void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: VyanaTheme.dark(),
          home: Scaffold(body: Center(child: child)),
        ),
      );

  final activity = activityById('breathwork')!;

  for (final compact in [false, true]) {
    testWidgets('no meta and no minutes: no "MIN" (compact $compact)',
        (tester) async {
      await tester.pumpWidget(host(SuggestedPracticeBlock(
        intent: DayIntent.recover,
        activity: activity,
        reason: 'Settles you',
        compact: compact,
        heading: 'Suggested activity',
      )));
      expect(find.textContaining('MIN'), findsNothing);
      expect(find.text(activity.name), findsOneWidget);
      if (compact) expect(find.text('Settles you'), findsOneWidget);
    });
  }

  testWidgets('a known length is still shown', (tester) async {
    await tester.pumpWidget(host(SuggestedPracticeBlock(
      intent: DayIntent.recover,
      activity: activity,
      reason: 'Settles you',
      minutes: 4,
    )));
    expect(find.textContaining('4 MIN'), findsOneWidget);
  });
}
