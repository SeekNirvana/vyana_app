import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 85 — nine actions that failed without a word.
///
/// They share one shape: something was awaited, the thing that would have
/// reported the outcome had gone, and the button looked like it had worked.
/// None of them is reachable from a unit test — each needs a BLE stack, a
/// navigator or a platform settings screen — so these read the source, and
/// each assertion names the call that was missing.
void main() {
  String read(String path) {
    final file = File.fromUri(Directory.current.uri.resolve(path));
    if (!file.existsSync()) throw StateError('Missing $path');
    return file.readAsStringSync();
  }

  String codeOnly(String source) => source
      .split('\n')
      .map((l) {
        final at = l.indexOf('//');
        return at < 0 ? l : l.substring(0, at);
      })
      .join('\n');

  final scan = codeOnly(read('lib/src/scan_screen.dart'));
  final you = codeOnly(read('lib/src/screens/you_screen.dart'));
  final home = codeOnly(read('lib/src/screens/home_screen.dart'));
  final practice = codeOnly(read('lib/src/screens/practice_screen.dart'));
  final session = codeOnly(read('lib/src/screens/session_screen.dart'));
  final controller = codeOnly(read('lib/src/state/ring_controller.dart'));

  test('(a) a ring already connected in system Bluetooth still gets setup', () {
    // That branch announced the device but not a first connection, so setup
    // was skipped for anyone who paired in Android's settings first.
    final branch = scan.substring(scan.indexOf('onConnectedDeviceDetected('));
    expect(branch.substring(0, 400), contains('onFirstConnected?.call()'));
  });

  test('(b) a rename is only shown once the ring accepted it', () {
    // renameRing already says whether it worked; the callback threw that
    // away, so the new name appeared even when nothing had been renamed.
    expect(scan, contains('Future<RingNameUpdateResult> Function(String name)?'));
    final rename = scan.substring(scan.indexOf('Future<void> _rename()'));
    final body = rename.substring(0, rename.indexOf('\n  }'));
    expect(body, contains('result.successful'));
    expect(body, contains('showVyanaSnackBar'));
  });

  test('(c) the baseline answer reads the controller before awaiting', () {
    final blocks = codeOnly(read('lib/src/screens/baseline_blocks.dart'));
    final answer = blocks.substring(blocks.indexOf('Future<void> _answer('));
    final body = answer.substring(0, answer.indexOf('\n  }'));
    // The read has to come first: answering dismisses the card, and the ref
    // dies with it, so the sleep target was never updated.
    expect(
      body.indexOf('ref.read(ringControllerProvider)'),
      lessThan(body.indexOf('await controller.answer')),
      reason: 'the controller is still read after the await',
    );
  });

  test('(d) snack-bar retries use a context that outlives the screen', () {
    // A Retry is tapped seconds later, often after the screen has closed.
    final sync = you.substring(you.indexOf('Future<void> syncRingWithFeedback'));
    final body = sync.substring(0, sync.indexOf('\nFuture<void> open'));
    expect(body, contains('Navigator.of(context).context'));
    expect(
      body,
      isNot(contains('syncRingWithFeedback(context, c))')),
      reason: 'a retry still closes over the calling screen',
    );
  });

  test('(e) a recovered session that will not resume says so', () {
    final resume = home.substring(home.indexOf("label: 'Resume'"));
    final body = resume.substring(0, 900);
    expect(body, contains('resumeRecoveredSession()'));
    expect(body, contains('showSnackBar'));
  });

  test('(f) the battery card is dismissed only if settings opened', () {
    final foreground =
        codeOnly(read('lib/src/services/ring_foreground_service.dart'));
    expect(foreground, contains('static Future<bool> requestBatteryExemption()'));
    final allow = home.substring(home.indexOf("label: 'Allow'"));
    final body = allow.substring(0, 900);
    expect(body, contains('if (!opened)'));
  });

  test('(g) beginning another practice asks before ending the running one',
      () {
    // Begin on a Walk silently opened a Run that had been going all morning.
    final begin = practice.substring(practice.indexOf('Future<void> _begin('));
    final body = begin.substring(0, begin.indexOf('\n  }'));
    expect(body, contains('showVyanaConfirmDialog'));
    expect(body, contains('controller.end()'));
  });

  test('(h) the history button returns to an open detail rather than stacking',
      () {
    expect(session, contains('activityDetailRouteName('));
    expect(session, contains('kLiveSessionRouteName'));
    // And the route it looks for is actually named at the push.
    expect(you, contains('activityDetailRouteName(activity.id)'));
  });

  test('(i) an SDK that will not start says so, with a retry', () {
    expect(controller, contains('String? get sdkFailure'));
    expect(controller, contains('Future<void> retrySdkInit()'));
    // And the screen where Pair is greyed out shows it.
    expect(you, contains('c.sdkFailure'));
    expect(you, contains('retrySdkInit()'));
  });
}
