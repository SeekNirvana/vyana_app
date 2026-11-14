import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 66 — WalletConnect must not start until the person asks for it.
///
/// Source-level, like release_contract_test.dart, and for the same reason:
/// the property worth protecting is "no code path reaches Reown at launch",
/// which is a fact about call sites. A behavioural test would need a fake
/// modal and a widget harness and would still only prove that the path it
/// drove stayed quiet — not that no other path exists.
///
/// What this guards against is someone adding the launch-time call back,
/// which is an easy and invisible mistake: the app behaves identically
/// except that every launch now talks to Reown's servers.
void main() {
  final lib = Directory.current.uri.resolve('lib/');

  String readLib(String relativePath) {
    final file = File.fromUri(lib.resolve(relativePath));
    expect(file.existsSync(), isTrue, reason: 'Missing $relativePath');
    return file.readAsStringSync();
  }

  group('nothing initialises Reown at launch', () {
    test('the shell does not', () {
      final shell = readLib('src/shell/vyana_shell.dart');
      // The shell is what runs on every launch, so this is the one file
      // where the call must never appear.
      expect(
        shell,
        isNot(contains('initIfNeeded')),
        reason: 'The shell runs at launch; initialising Reown there reaches '
            'Reown before the person has asked for a wallet (item 66).',
      );
    });

    test('only the Wallet screen does', () {
      final callers = <String>[];
      for (final file in Directory.fromUri(lib)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        // The declaration itself lives in the service, so look for calls.
        if (source.contains('.initIfNeeded(')) {
          callers.add(file.uri.pathSegments.last);
        }
      }
      expect(
        callers,
        ['wallet_screen.dart'],
        reason: 'Opening Wallet is the consent. Any other caller — a launch '
            'hook, a background task, a preload — does not have it.',
      );
    });
  });

  group('the Wallet screen still gets a working wallet', () {
    test('it initialises on open and attaches when init finishes', () {
      final wallet = readLib('src/screens/wallet_screen.dart');
      expect(wallet, contains('initIfNeeded(context)'));
      // init is not awaited, so the modal is null when initState returns.
      // Without this listener the screen would miss connect and disconnect
      // events entirely — which the launch-time init used to hide, because
      // the modal was usually ready long before anyone opened Wallet.
      expect(wallet, contains('ref.listen<ReownWalletState>'));
      expect(wallet, contains('_attachReownListeners'));
    });
  });

  group('analytics are off by instruction, not by omission', () {
    test('enableAnalytics is passed false', () {
      final service = readLib('src/state/reown_wallet_service.dart');
      expect(service, contains('enableAnalytics: false'));
    });

    test('the privacy claim on the privacy screen is the one kept', () {
      // "only if you connect" is the promise item 66 found broken. If the
      // wording goes, the promise it describes should be revisited, not
      // quietly dropped.
      final panels = readLib('src/info_panels.dart');
      expect(panels, contains('only if you connect'));
    });
  });
}
