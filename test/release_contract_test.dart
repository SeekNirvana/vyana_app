import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level contract: catches deleted UI/API before compile.
/// Pair with scripts/verify-release-apk.sh for stale-release APK detection.
void main() {
  final root = Directory.current;
  final lib = root.uri.resolve('lib/');

  String readLib(String relativePath) {
    final file = File.fromUri(lib.resolve(relativePath));
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Missing $relativePath',
    );
    return file.readAsStringSync();
  }

  test('v1.0.2 reset ring feature present in source', () {
    final youScreen = readLib('src/screens/you_screen.dart');
    expect(youScreen, contains("label: 'Reset PRANA ring'"));
    expect(youScreen, contains('_confirmResetRing'));

    final ringController = readLib('src/state/ring_controller.dart');
    expect(ringController, contains('resetPranaRingToFactory'));

    final repository = readLib('src/repository.dart');
    expect(repository, contains('restoreFactorySettings'));
    expect(repository, contains('deleteDeviceHealthData'));

    final models = readLib('src/models.dart');
    expect(models, contains('class RingResetResult'));
    expect(models, contains('ringHealthDeleteTargets'));
  });

  test('v1.0.2 exit confirmation present in source', () {
    final shell = readLib('src/shell/vyana_shell.dart');
    expect(shell, contains('confirmExitVyanaApp'));

    final primitives = readLib('src/widgets/primitives.dart');
    expect(primitives, contains("title: 'Exit Vyana?'"));
  });

  test('release manifest documents shipped fingerprints', () {
    final manifest = File('scripts/release-manifest.txt');
    expect(manifest.existsSync(), isTrue);

    final text = manifest.readAsStringSync();
    expect(text, contains('resetPranaRingToFactory'));
    expect(text, contains('Exit Vyana?'));
  });

  test('v1.0.3 monitor-all vitals + state-of-being present in source', () {
    final homeScreen = readLib('src/screens/home_screen.dart');
    expect(homeScreen, contains('runAllVitals'));
    expect(homeScreen, contains('Check in with your body'));
    expect(homeScreen, contains('HOW YOU'));
    expect(homeScreen, contains('reads each vital in turn'));

    // Calm redesign: Home stays number-free; numbers live on TrendsScreen.
    final trendsScreen = readLib('src/screens/trends_screen.dart');
    expect(trendsScreen, contains('openVitalDetail'));
    expect(trendsScreen, contains('openMeasurements'));
    expect(trendsScreen, contains('READINESS'));

    final ringController = readLib('src/state/ring_controller.dart');
    expect(ringController, contains('runAllVitals'));
    expect(ringController, contains('keep the ring snug'));
    expect(ringController, contains("Couldn't get a clean reading"));

    final vitalsQuality = readLib('src/vitals_quality.dart');
    expect(vitalsQuality, contains('isNoContactRecord'));
    expect(vitalsQuality, contains('scrubRecordFields'));

    final homeWidget = readLib('src/services/home_widget_service.dart');
    expect(homeWidget, contains('STATE OF BEING'));
  });

  test('v1.0.4 live sessions (map, 10-min splits, terrain cues) + meal polish',
      () {
    final sessionBodies = readLib('src/screens/session_bodies.dart');
    expect(sessionBodies, contains('FlutterMap'));
    expect(sessionBodies, contains('tile.openstreetmap.org'));
    expect(sessionBodies, contains('PolylineLayer'));

    final sessionController = readLib('src/state/session_controller.dart');
    expect(sessionController, contains('% 600'),
        reason: 'spoken splits every 10 minutes');
    expect(sessionController, contains('Kilometre'));
    expect(sessionController, contains('Steep climb'));
    expect(sessionController, contains('gpsPermissionDenied'));

    final journalScreen = readLib('src/screens/journal_screen.dart');
    expect(journalScreen, contains('deleteMeal'));
    expect(journalScreen, contains('MealPhotoViewer'));

    final journalEditors = readLib('src/screens/journal_editors.dart');
    expect(journalEditors, contains('Add a photo of your plate'));

    // GPS must work on Android 12+: FINE_LOCATION may not carry maxSdkVersion.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      contains(
          '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />'),
    );
  });
}