import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 115 — the two save buttons left unguarded by item 73.
void main() {
  test('the training-frequency sheet saves once', () {
    final source = File('lib/src/screens/you_subscreens.dart').readAsStringSync();
    final sheet = source.indexOf('Future<void> showTrainingFrequencySheet');
    final body = source.substring(sheet, source.indexOf('\n}\n', sheet));
    expect(body, contains('if (saving) return;'));
  });

  test('the cycle-mode sheet resets saving even when the save throws', () {
    final source = File('lib/src/screens/cycle_screens.dart').readAsStringSync();
    expect(source, contains('} finally {\n                            if (sheetContext.mounted) {\n                              setSheetState(() => saving = false);'));
  });
}
