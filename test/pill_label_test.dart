import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/theme/app_theme.dart';
import 'package:vyana/src/widgets/primitives.dart';

/// Item 55 — a pill with nothing to do must not look like a button.
///
/// Wallet drew two labels as `Pill(..., onTap: () {})`: the currency beside
/// your address, and a row's status badge. Both rippled under a finger and
/// did nothing, which reads as a broken control rather than as text.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: VyanaTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('a pill with no action has nothing to press', (tester) async {
    await tester.pumpWidget(host(const Pill(label: 'USDC', active: true)));

    expect(find.text('USDC'), findsOneWidget);
    // Not merely a disabled InkWell — no InkWell at all, so there is no
    // ripple, no pressed state, and nothing announced as a control.
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a pill that does something stays tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(Pill(label: 'Switch', onTap: () => taps++)),
    );

    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.text('Switch'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the label reads the same either way', (tester) async {
    await tester.pumpWidget(host(const Pill(label: 'PENDING')));
    expect(find.text('PENDING'), findsOneWidget);
  });
}
