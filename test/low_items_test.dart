import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/wellness/wellness_state.dart';

/// Items 86–91 — the low-priority set.
///
/// Three of them are config or copy that nothing else reads: an iOS display
/// name, an app group, a permission list. Those cannot be caught by the
/// analyser or a build, only by shipping them.
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

  group('the iPhone app is called Vyana (item 86)', () {
    test('the display name is not a test build', () {
      final plist = read('ios/Runner/Info.plist');
      final match = RegExp(
        r'<key>CFBundleDisplayName</key>\s*(?:<!--.*?-->\s*)?<string>(.*?)</string>',
        dotAll: true,
      ).firstMatch(plist);
      expect(match, isNotNull);
      expect(match!.group(1), 'Vyana');
    });

    test('the app group is Vyana\'s own, in both places', () {
      // It was group.com.erebrus.keys — a different app's — so the widget's
      // data was written into a container Vyana does not own.
      final entitlements = read('ios/Runner/Runner.entitlements');
      final service = read('lib/src/services/home_widget_service.dart');
      expect(entitlements, contains('group.com.seeknirvana.vyana'));
      expect(entitlements, isNot(contains('erebrus')));
      expect(service, contains("'group.com.seeknirvana.vyana'"));
      expect(codeOnly(service), isNot(contains('erebrus')));
    });
  });

  group('unused permissions are not asked for (item 87)', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    String manifestCode(String xml) =>
        xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    test('this app declares neither', () {
      final code = manifestCode(manifest);
      // Item 120: the one mention left is the removal of the SDK's own.
      expect(
        code,
        contains(RegExp(
          r'android:name="android.permission.SCHEDULE_EXACT_ALARM"\s*tools:node="remove"',
        )),
      );
      expect(
        RegExp('SCHEDULE_EXACT_ALARM').allMatches(code).length,
        1,
      );
      expect(code, isNot(contains('FOREGROUND_SERVICE_DATA_SYNC')));
    });

    test('and the service the data-sync one was for is removed', () {
      // The permission and the service go together: on API 34+ a typed
      // service without its permission throws the moment it starts.
      expect(manifest, contains('background_downloader.UIDTJobService'));
      expect(manifest, contains('tools:node="remove"'));
    });
  });

  group('the Cloud sync switch is gone (item 88)', () {
    test('no row, no provider, no file', () {
      final you = codeOnly(read('lib/src/screens/you_screen.dart'));
      expect(you, isNot(contains('sessionSyncEnabledProvider')));
      expect(
        File.fromUri(
          Directory.current.uri.resolve('lib/src/state/session_sync.dart'),
        ).existsSync(),
        isFalse,
      );
      final controller =
          codeOnly(read('lib/src/state/session_controller.dart'));
      expect(controller, isNot(contains('sessionSyncServiceProvider')));
    });

    test('and the privacy panel no longer promises it', () {
      // A panel listing a feature that does not exist is as wrong as one
      // leaving out a feature that does.
      // Comments stripped: the line explaining the removal names the thing
      // it removed, which a plain substring search cannot tell apart.
      final panels = codeOnly(read('lib/src/info_panels.dart'));
      expect(panels, isNot(contains('Cloud sync')));
    });
  });

  group('one guide, one vocabulary (item 89)', () {
    test('nothing says "your guide" or calls the voice the app\'s', () {
      expect(
        codeOnly(read('lib/src/screens/guides_screen.dart')),
        isNot(contains('Ask your guide')),
      );
      expect(
        codeOnly(read('lib/src/screens/practice_screen.dart')),
        isNot(contains("Vyana's voice")),
      );
    });

    test('the HRV chip does not borrow readiness\'s middle word', () {
      // "Depleted" in the ring with "Balanced" underneath it, about the
      // same body, with nothing to say which was meant.
      final home = codeOnly(read('lib/src/screens/home_screen.dart'));
      expect(home, contains("('Recovered', 'Steady', 'Take it easy')"));
      expect(readinessStateWord(60), 'Balanced');
    });
  });

  group('the sync log is bounded (item 90)', () {
    final panels = codeOnly(read('lib/src/info_panels.dart'));

    test('it keeps a week and prunes', () {
      expect(panels, contains('kHistoryLogKeepFor'));
      expect(panels, contains('_pruneOlderThan'));
    });

    test('the ring MAC is not written into it', () {
      expect(panels, contains("device_.remove('address')"));
    });

    test('the directory is asked for, not hard-coded', () {
      expect(panels, isNot(contains('/data/user/0/')));
      expect(panels, contains('getApplicationSupportDirectory()'));
    });

    test('and the screen says what it is showing', () {
      expect(read('lib/src/info_panels.dart'), contains('last 7 days of syncs'));
    });
  });

  group('copy and recovery gaps (item 91)', () {
    test('a long gap is counted in days', () {
      // "Today is missing 50 hours" is a true number that reads as a fault
      // in the app rather than a ring nobody has worn.
      expect(staleGapLabel(const Duration(hours: 50)), '2 days');
      expect(staleGapLabel(const Duration(hours: 24)), 'a day');
      expect(staleGapLabel(const Duration(hours: 23)), '23 hours');
      expect(staleGapLabel(const Duration(minutes: 30)), 'an hour');
      expect(staleGapLabel(const Duration(days: 9)), '9 days');
    });

    test('the storage screen can try again', () {
      final main = codeOnly(read('lib/main.dart'));
      expect(main, contains('onRetry'));
      // ensureReady caches its attempt, so a retry needs the cache cleared
      // or it returns the same refusal.
      final storage =
          codeOnly(read('lib/src/services/vyana_storage_service.dart'));
      expect(storage, contains('Future<void> retry()'));
      expect(storage, contains('_initFuture = null'));
    });

    test('the profile editor has a way back while loading or broken', () {
      final profile = codeOnly(read('lib/src/screens/profile_screen.dart'));
      final when = profile.substring(profile.indexOf('profileAsync.when('));
      final branches = when.substring(0, when.indexOf('data: (profile)'));
      expect(RegExp('IconBtn').allMatches(branches).length, 2);
    });
  });
}
