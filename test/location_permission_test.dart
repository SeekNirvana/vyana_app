import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 67 — Vyana asks for "while using this app" and nothing more.
///
/// Android used to be asked for ACCESS_BACKGROUND_LOCATION too, which
/// produces the separate "Allow all the time" dialog on every session. It
/// was never needed: an outdoor session records under a location-typed
/// foreground service started while the app is open, and that keeps
/// delivering fixes with the screen locked on "while using" alone.
///
/// The two facts are tested together on purpose. Dropping the permission is
/// only safe *because* the foreground service is there, so a change that
/// removes the service config while leaving this permission out would turn
/// a fixed prompt into a broken recording — and would otherwise pass.
void main() {
  final root = Directory.current.uri;
  final lib = root.resolve('lib/');

  // Deliberately no expect() in here: these are read while the groups are
  // being declared, where expect() is not yet allowed. A missing file
  // throws, which fails the load just as loudly.
  String read(String relativePath) {
    final file = File.fromUri(root.resolve(relativePath));
    if (!file.existsSync()) {
      throw StateError('Missing $relativePath');
    }
    return file.readAsStringSync();
  }

  String readLib(String relativePath) =>
      read('lib/${Uri.parse(relativePath)}');

  /// Source with its comments taken out.
  ///
  /// These assertions are about what the code does, and the first draft of
  /// this test failed against itself: the manifest comment explaining why
  /// ACCESS_BACKGROUND_LOCATION is absent contains the words
  /// "ACCESS_BACKGROUND_LOCATION", and so does the doc comment where the
  /// two Dart methods used to be. A substring search over a whole file
  /// cannot tell an explanation from a declaration, so strip the prose and
  /// ask the code.
  String codeOnly(String source, {required bool xml}) {
    var out = source;
    if (xml) {
      out = out.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    } else {
      out = out.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      out = out
          .split('\n')
          .map((line) {
            final at = line.indexOf('//');
            return at < 0 ? line : line.substring(0, at);
          })
          .join('\n');
    }
    return out;
  }

  group('the manifest asks for no more than it needs', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    test('background location is not declared', () {
      expect(
        codeOnly(manifest, xml: true),
        isNot(contains('ACCESS_BACKGROUND_LOCATION')),
        reason: 'Declaring it brings back the "Allow all the time" prompt '
            'and the Play Store rejection it causes (item 67).',
      );
    });

    test('the foreground-service permissions it does need are declared', () {
      // FOREGROUND_SERVICE_LOCATION is what makes the removal workable: on
      // API 34+ a location-typed service cannot start without it.
      expect(manifest, contains('FOREGROUND_SERVICE_LOCATION'));
      expect(manifest, contains('ACCESS_FINE_LOCATION'));
      expect(manifest, contains('ACCESS_COARSE_LOCATION'));
    });

    test('fine location is not capped to old Android', () {
      // A maxSdkVersion on fine location would break every run on 12+, the
      // mistake the comment above the block warns about.
      final fineLine = manifest
          .split('\n')
          .firstWhere((l) => l.contains('ACCESS_FINE_LOCATION'));
      expect(fineLine, isNot(contains('maxSdkVersion')));
    });
  });

  group('what replaces it is still in place', () {
    final location = readLib('src/state/location_service.dart');

    test('the Android position stream runs as a foreground service', () {
      // Without this, "while using" genuinely is not enough and the stream
      // dies with the screen — which is what the extra permission was
      // wrongly papering over.
      expect(location, contains('foregroundNotificationConfig'));
      expect(location, contains('ForegroundNotificationConfig'));
      expect(location, contains('enableWakeLock: true'));
    });

    test('while-in-use is accepted as sufficient', () {
      expect(location, contains('LocationPermission.whileInUse'));
    });
  });

  group('nothing asks for "Allow all the time" any more', () {
    test('the request and its check are gone, not merely unused', () {
      for (final file in Directory.fromUri(lib)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = codeOnly(file.readAsStringSync(), xml: false);
        final name = file.uri.pathSegments.last;
        expect(source, isNot(contains('requestBackgroundPermission')),
            reason: '$name still reaches for background location');
        expect(source, isNot(contains('hasBackgroundPermission')),
            reason: '$name still reads background location');
      }
    });

    test('LocationPermission.always is never required of anyone', () {
      final location =
          codeOnly(readLib('src/state/location_service.dart'), xml: false);
      // ensurePermission must not demand `always`; it accepts it, which is
      // different — someone who granted it on an older build keeps working.
      expect(
        location,
        isNot(contains('== LocationPermission.always;')),
        reason: 'A check that returns only on `always` is a background '
            'requirement wearing a different name.',
      );
    });
  });
}
