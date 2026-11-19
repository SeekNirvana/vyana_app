import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 96 — About and Privacy must describe the release they ship in.
///
/// The rule from the handover: the text must match the release. Several
/// lines had stopped being true — Nova "runs entirely on your phone" (not
/// with your own server), "only if you connect" a wallet (WalletConnect
/// started at launch), a USDC payment signed in the app (ordering moved to
/// the website), a Cloud sync switch that no longer exists.
///
/// These tests pin the two halves of that rule: nothing claims what the
/// app no longer does, and nothing that reaches outward is left out. Both
/// kinds of error read as honest text, which is why they need a test
/// rather than a reading.
void main() {
  final panels = File.fromUri(
    Directory.current.uri.resolve('lib/src/info_panels.dart'),
  ).readAsStringSync();

  /// The panel text as a reader sees it, not as Dart stores it.
  ///
  /// Two things get in the way of searching the source for a sentence. Long
  /// strings are split across adjacent literals, so "Never a platform-owned
  /// dataset" is `'Never a platform-owned '` then `'dataset'` with a line
  /// break between them. And an apostrophe is escaped, so "Nova's" is
  /// `Nova\'s`. A test that does not undo both searches for phrases that
  /// are not there in that form and passes or fails for the wrong reason —
  /// which is how the first draft of this file failed.
  String readable(String source) {
    var out = source
        .split('\n')
        .map((l) {
          final at = l.indexOf('//');
          return at < 0 ? l : l.substring(0, at);
        })
        .join('\n');
    // Join adjacent string literals: `'…' \n '…'` becomes one run.
    out = out.replaceAll(RegExp(r"'\s*\n\s*'"), '');
    return out.replaceAll(r"\'", "'");
  }

  final code = readable(panels);

  group('nothing claims what the app no longer does', () {
    test('Nova does not "run entirely on your phone"', () {
      // Untrue for anyone on their own AI server — which is also the route
      // offered to phones with under 6 GB, so not a rare case.
      expect(code, isNot(contains('runs entirely on your phone')));
    });

    test('the wallet is not described as connecting only on your say-so '
        'without that being true', () {
      // Item 66 made it true, so the line may stay — but it must describe
      // opening Wallet, not merely "connecting".
      expect(code, contains('only when you open Wallet'));
    });

    test('no in-app USDC payment is promised', () {
      // Item 61 moved ordering to the website.
      expect(code, isNot(contains('a USDC payment you sign')));
      expect(code, contains('seeknirvana.com'));
    });

    test('no Cloud sync switch is described', () {
      expect(code, isNot(contains('Cloud sync')));
    });

    test('the voice is named, and not by its old name', () {
      expect(code, isNot(contains('Vani voice model')));
      expect(code, contains('Kokoro'));
    });
  });

  group('everything that reaches outward is listed', () {
    test('each outward connection has a line', () {
      for (final subject in [
        'Your own AI server',
        'Backups',
        'Exports',
        'Wallet',
        'Ordering a ring',
        'Session map',
        'Downloads',
      ]) {
        expect(
          code,
          contains(subject),
          reason: '$subject is not in the outward list',
        );
      }
    });

    test('the backup exclusion is stated where it matters', () {
      // The one line somebody needs before they uninstall: this is the
      // only copy, and no platform backup has it.
      expect(code, contains('Google or iCloud backups'));
      expect(code, contains('a saved passphrase may stay in the Keychain'));
      // Item 121: one backup line, and no claim it is never sent anywhere.
      expect(code, contains('Backups go only where you save them'));
      expect(code, isNot(contains('never sends it anywhere')));
    });

    test("Nova's conversations are listed as kept", () {
      // New in v1.1.6 and absent from the panel.
      expect(code, contains("Nova's conversations"));
    });
  });

  group('the positioning is unchanged', () {
    test('the no-collect claims still stand', () {
      expect(code, contains('We do not upload'));
      expect(code, contains('No sale of personal or health data'));
      expect(code, contains('No advertising identifiers'));
      expect(code.toLowerCase(), contains('never a platform-owned dataset'));
    });

    test('the date says this release', () {
      expect(code, contains('Last updated November 2026'));
      expect(code, isNot(contains('Last updated September 2026')));
    });
  });
}
