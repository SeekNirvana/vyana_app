import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 83 — an overnight sync must not blank the nights already stored.
///
/// Overnight syncs deliberately do not ask the ring for sleep (bug 19),
/// because a sleep request mid-night closes the ring's open sleep record.
/// So `result.history` has no sleep in it, and the cache was saved from
/// `result.history`. Close the app before morning, open it before the
/// morning sync, and past nights were missing; any night older than the
/// ring itself still keeps was gone for good.
///
/// Source-level: the controller needs an SDK, a device and a database to
/// stand up, and the fault is one identifier — which history the cache is
/// handed. That is exactly what this reads.
void main() {
  test('the cache is saved from the merged history, not the sync', () {
    final source =
        File.fromUri(Directory.current.uri.resolve(
          'lib/src/state/ring_controller.dart',
        )).readAsStringSync();

    final start = source.indexOf('Future<void> _persistHistoryToCache');
    expect(start, greaterThan(-1), reason: 'the cache writer is gone');
    final body = source.substring(start, source.indexOf('\n  }', start));
    final code = body
        .split('\n')
        .map((line) {
          final at = line.indexOf('//');
          return at < 0 ? line : line.substring(0, at);
        })
        .join('\n');

    expect(code, contains('history: _history'));
    expect(
      code,
      isNot(contains('history: result.history')),
      reason: 'an overnight result has no sleep in it',
    );
  });

  test('the merged history is the one that retains sleep', () {
    // The other half of the pair: _history keeps the nights when a sync did
    // not ask for them. If that ever stops being true, saving _history is
    // no better than saving the result.
    final source =
        File.fromUri(Directory.current.uri.resolve(
          'lib/src/state/ring_controller.dart',
        )).readAsStringSync();
    expect(source, contains('withSleep(retainedSleep)'));
  });
}
