import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Items 75 and 76 — what iPhone is promised and what it is asked.
///
/// Three of these four facts live in Info.plist, which nothing else in the
/// test suite reads: a missing background mode or a purpose string that
/// describes the wrong feature cannot be caught by the analyser, by a
/// build, or by any Dart test. They surface as a recording that stops when
/// the screen locks, or as an App Store reviewer's rejection.
void main() {
  final root = Directory.current.uri;

  String read(String relativePath) {
    final file = File.fromUri(root.resolve(relativePath));
    if (!file.existsSync()) throw StateError('Missing $relativePath');
    return file.readAsStringSync();
  }

  group('iOS can keep recording a route (item 76)', () {
    final plist = read('ios/Runner/Info.plist');

    test('the location background mode is declared', () {
      // location_service.dart passes allowBackgroundLocationUpdates: true.
      // Without this key that setting has nothing behind it and an outdoor
      // session stops the moment the phone locks — the normal case for a
      // walk or a run.
      final modes = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
              dotAll: true)
          .firstMatch(plist)
          ?.group(1);
      expect(modes, isNotNull, reason: 'UIBackgroundModes is missing');
      expect(modes, contains('<string>location</string>'));
      // The ring still needs its own mode; this must not have replaced it.
      expect(modes, contains('<string>bluetooth-central</string>'));
    });

    test('the location purpose string describes recording routes', () {
      // It used to say location "can be required by the platform while
      // scanning nearby Bluetooth devices", which is not what it is for.
      // A purpose string is what the person reads before agreeing, so it
      // has to name the real use.
      final match = RegExp(
        r'<key>NSLocationWhenInUseUsageDescription</key>\s*'
        r'(?:<!--.*?-->\s*)?<string>(.*?)</string>',
        dotAll: true,
      ).firstMatch(plist);
      expect(match, isNotNull);
      final text = match!.group(1)!;
      expect(text, contains('route'));
      expect(
        text.toLowerCase(),
        isNot(contains('bluetooth')),
        reason: 'the string still explains Bluetooth scanning',
      );
    });

    test('the Bluetooth strings still explain Bluetooth', () {
      // Guards against fixing the above by editing the wrong key.
      expect(plist, contains('NSBluetoothAlwaysUsageDescription'));
      expect(plist, contains('<key>NSBluetoothPeripheralUsageDescription</key>'));
    });
  });

  group('iOS is asked for notification permission at pairing (item 76)', () {
    test('finishing setup requests it when there is no Android service', () {
      // The alert switches default to on, on every platform. iOS was only
      // ever asked on a toggle or a Monitor-all run, so until someone
      // happened to do one, every alert the app had been told to send was
      // dropped in silence.
      final controller = read('lib/src/state/ring_controller.dart');
      final completion = controller.substring(
        controller.indexOf('Future<void> completeRingOnboarding'),
      );
      final body = completion.substring(0, completion.indexOf('\n  Future<'));
      expect(body, contains('requestPermissions()'));
      expect(body, contains('ensureNotificationPermission()'));
    });
  });

  group('iPhone is not promised a background service (item 75)', () {
    final onboarding = read('lib/src/screens/ring_onboarding_screen.dart');

    test('the step is behind a platform check', () {
      expect(onboarding, contains('_hasForegroundStep'));
      expect(onboarding, contains('Platform.isAndroid'));
      expect(onboarding, contains('if (_hasForegroundStep) _buildForegroundStep'));
    });

    test('the dots count the steps rather than assuming four', () {
      // A hard-coded 4 would show an unreachable dot on iPhone.
      expect(onboarding, contains('_dots(_pageCount'));
      expect(onboarding, isNot(contains('_dots(4,')));
    });

    test('nothing still jumps to a page that may not exist', () {
      // Four separate calls used to mean "past the wipe step" by number.
      final body = onboarding.replaceAll(
        RegExp(r'//.*'),
        '',
      );
      expect(
        body,
        isNot(contains('_goTo(3)\n')),
        reason: 'a bare jump to page 3 is out of range without the step',
      );
      expect(body, contains('_afterWipe'));
    });
  });
}
