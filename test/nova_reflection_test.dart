import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 77 — only Nova's own words appear under Nova's name.
///
/// "Ask Nova" wrote a fixed sentence whenever she was unavailable, under a
/// NOVA label, which anyone would read as hers. Worse, "Ask Nova again"
/// wrote that same sentence on *any* error — so a reflection someone
/// valued could be replaced by stock text and the original was gone.
///
/// Source-level, because the claims are about which code paths can write a
/// reflection at all. Driving the editors would need a database, a model
/// manager and a navigator, and would still only exercise the paths the
/// test happened to choose; the fault was a path nobody chose.
void main() {
  final root = Directory.current.uri;

  String read(String relativePath) {
    final file = File.fromUri(root.resolve(relativePath));
    if (!file.existsSync()) throw StateError('Missing $relativePath');
    return file.readAsStringSync();
  }

  /// Source with comments removed, so an explanation of the old behaviour
  /// is not mistaken for the old behaviour.
  String codeOnly(String source) => source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .map((line) {
        final at = line.indexOf('//');
        return at < 0 ? line : line.substring(0, at);
      })
      .join('\n');

  final editors = codeOnly(read('lib/src/screens/journal_editors.dart'));

  group('the canned reflection is gone', () {
    test('the sentence itself appears nowhere', () {
      // The exact text that was being presented as Nova's.
      expect(editors, isNot(contains('Notice the feeling')));
      expect(editors, isNot(contains('carries that same texture')));
    });

    test('and so is the constant that held it', () {
      expect(editors, isNot(contains('_novaFallbackReflection')));
    });
  });

  group('a failure never overwrites what is there', () {
    test('no catch block writes a reflection', () {
      // The data-loss half of the item: on any error the entry was
      // rewritten with stock text, so the reflection it had was lost.
      for (final match
          in RegExp(r'catch \([^)]*\) \{([\s\S]*?)\n  \}').allMatches(editors)) {
        expect(
          match.group(1),
          isNot(contains('setJournalReflection')),
          reason: 'a catch block still writes a reflection',
        );
      }
    });

    test('a reflection is only ever written from a reply', () {
      // Every write should be of something stripGuideMarkdown has been
      // through, which is to say: something Nova said.
      for (final match
          in RegExp(r'setJournalReflection\(([^;]*)\);').allMatches(editors)) {
        expect(
          match.group(1),
          contains('stripGuideMarkdown'),
          reason: 'a reflection is written from something Nova did not say: '
              '${match.group(1)}',
        );
      }
    });
  });

  group('Nova is judged on the backend in use', () {
    test('both paths use the backend-aware check, not modelReady alone', () {
      // Item 69's check. With an endpoint set up and tested, modelReady is
      // false and Nova can still answer — so reading it alone sent those
      // users down the "not installed" branch.
      expect(editors, contains('novaCanAnswer('));
      final checks = RegExp('novaCanAnswer\\(').allMatches(editors).length;
      expect(
        checks,
        greaterThanOrEqualTo(2),
        reason: 'the dream editor and Ask Nova again each need one',
      );
    });

    test('and offer a way to set her up', () {
      expect(editors, contains("Nova isn't set up"));
      expect(editors, contains('openAiSetup'));
    });
  });
}
