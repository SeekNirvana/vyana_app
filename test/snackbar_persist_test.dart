import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/theme/app_theme.dart';
import 'package:vyana/src/widgets/primitives.dart';

/// Item 129 — "Skipped for today · Undo" goes away on its own.
void main() {
  testWidgets('a snack bar with an action still leaves after its time',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: VyanaTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showVyanaSnackBar(
              context,
              message: 'Skipped for today',
              duration: const Duration(seconds: 6),
              action: SnackBarAction(label: 'Undo', onPressed: () {}),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Skipped for today'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Skipped for today'), findsNothing);
  });

  test('every snack bar with an action is told not to persist', () {
    for (final path in [
      'lib/src/screens/home_screen.dart',
      'lib/src/widgets/primitives.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('persist: false'));
    }
    expect(
      File('lib/src/shell/vyana_shell.dart').readAsStringSync(),
      contains('hideCurrentSnackBar'),
    );
  });
}
