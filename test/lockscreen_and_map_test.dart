import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Items 81 and 82 — what leaves the phone, and what the lock screen says.
///
/// Both are facts about defaults that no screen shows and no other test
/// reads: a notification's lock-screen visibility, and whether a tile
/// request goes out before anyone asked. Each is one missing argument away
/// from being wrong again, and neither failure is visible from inside the
/// app — the first shows on a locked phone on a table, the second in
/// someone else's server log.
void main() {
  final root = Directory.current.uri;

  String read(String relativePath) {
    final file = File.fromUri(root.resolve(relativePath));
    if (!file.existsSync()) throw StateError('Missing $relativePath');
    return file.readAsStringSync();
  }

  String codeOnly(String source) => source
      .split('\n')
      .map((line) {
        final at = line.indexOf('//');
        return at < 0 ? line : line.substring(0, at);
      })
      .join('\n');

  group('health values stay off the lock screen (item 81)', () {
    test('the ongoing service notification is private', () {
      // It carries HR, SpO2 and HRV, and flutter_foreground_task defaults
      // to VISIBILITY_PUBLIC — so a locked phone on a table showed
      // someone's heart rate to whoever walked past.
      final service = codeOnly(read('lib/src/services/ring_foreground_service.dart'));
      expect(service, contains('NotificationVisibility.VISIBILITY_PRIVATE'));
      expect(
        service,
        isNot(contains('VISIBILITY_PUBLIC')),
        reason: 'the default is public; it must be set, not left',
      );
    });

    test('every alert is private too', () {
      // Alerts name values: a battery percentage, a resting heart rate, a
      // readiness score. Each AndroidNotificationDetails needs its own
      // visibility — there is no file-wide default to inherit.
      final notifications =
          codeOnly(read('lib/src/services/vitals_notification_service.dart'));
      final blocks =
          RegExp('AndroidNotificationDetails\\(').allMatches(notifications).length;
      final privates =
          RegExp('NotificationVisibility.private').allMatches(notifications).length;
      expect(blocks, greaterThan(0));
      expect(
        privates,
        blocks,
        reason: '$blocks notification blocks but only $privates are private',
      );
    });
  });

  group('the map waits to be asked (item 82)', () {
    final bodies = codeOnly(read('lib/src/screens/session_bodies.dart'));

    test('tiles are behind a tap', () {
      // Zoom-16 tiles of the live route were fetched automatically from the
      // moment a session started, which tells a third party where someone
      // is every few seconds as they move.
      expect(bodies, contains('_showMap'));
      expect(bodies, contains('_MapOffPanel'));
      expect(bodies, contains('bool _showMap = false'));
    });

    test('the panel says where the tiles come from', () {
      expect(bodies, contains('OpenStreetMap'));
      expect(bodies, contains('Show map'));
    });

    test('the tile layer is still the only thing reaching out', () {
      // Guards against someone "fixing" this by adding a second tile source
      // that is not behind the gate.
      final tileLayers = RegExp('TileLayer\\(').allMatches(bodies).length;
      expect(tileLayers, 1);
    });
  });

  group('the privacy panel says so (item 82)', () {
    test('the session map is listed among outward connections', () {
      // It was happening and was not written down. A panel that lists what
      // reaches outward is wrong by omission, which is the harder kind to
      // notice.
      final panels = read('lib/src/info_panels.dart');
      final section = panels.substring(
        panels.indexOf('Optional connections you control'),
      );
      final bullets = section.substring(0, section.indexOf('_PrivacySection('));
      expect(bullets, contains('OpenStreetMap'));
      expect(bullets, contains('Show map'));
    });

    test('and the positioning is not weakened', () {
      final panels = read('lib/src/info_panels.dart');
      expect(panels, contains('What stays on your phone'));
      // The claims this release is not allowed to soften. An earlier
      // version of this test pinned the exports bullet's "never uploaded",
      // which item 96 replaced for a good reason: item 65 made exports
      // shareable, so Vyana does not upload them but the person may, and a
      // panel saying otherwise would be the untruth.
      expect(panels, contains('We do not upload'));
      expect(panels, contains('No sale of personal or health data'));
      expect(panels, contains('does not require an account'));
    });
  });
}
