import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level contract: catches deleted UI/API before compile.
/// Pair with scripts/verify-release-apk.sh for stale-release APK detection.
void main() {
  final root = Directory.current;
  final lib = root.uri.resolve('lib/');

  String readLib(String relativePath) {
    final file = File.fromUri(lib.resolve(relativePath));
    expect(file.existsSync(), isTrue, reason: 'Missing $relativePath');
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
    expect(homeScreen, contains('Check vitals'));
    expect(homeScreen, contains('homeMomentAt'));
    expect(homeScreen, contains('Suggested practice'));
    expect(homeScreen, contains('suggestedPracticeId'));

    // The Trends screen became the Metrics tab in v1.1.0.
    final metricsScreen = readLib('src/screens/metrics_screen.dart');
    expect(metricsScreen, contains('openVitalDetail'));
    expect(metricsScreen, contains('openMeasurements'));
    expect(metricsScreen, contains('READINESS TODAY'));

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

  test(
    'v1.0.4 live sessions (map, 10-min splits, terrain cues) + meal polish',
    () {
      final sessionBodies = readLib('src/screens/session_bodies.dart');
      expect(sessionBodies, contains('FlutterMap'));
      expect(sessionBodies, contains('tile.openstreetmap.org'));
      expect(sessionBodies, contains('PolylineLayer'));

      final sessionController = readLib('src/state/session_controller.dart');
      expect(
        sessionController,
        contains('% 600'),
        reason: 'spoken splits every 10 minutes',
      );
      expect(sessionController, contains('Kilometre'));
      expect(sessionController, contains('Steep climb'));
      expect(sessionController, contains('gpsPermissionDenied'));

      final journalScreen = readLib('src/screens/journal_screen.dart');
      expect(journalScreen, contains('deleteMeal'));
      expect(journalScreen, contains('MealPhotoViewer'));

      final journalEditors = readLib('src/screens/journal_editors.dart');
      expect(journalEditors, contains('Add a photo of your plate'));

      // GPS must work on Android 12+: FINE_LOCATION may not carry maxSdkVersion.
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
        ),
      );
    },
  );

  test('v1.0.5 ring onboarding, sync interval, foreground heartbeat', () {
    final onboarding = readLib('src/screens/ring_onboarding_screen.dart');
    expect(onboarding, contains('Name your ring'));
    expect(onboarding, contains('Wipe old ring data'));
    expect(onboarding, contains('Skip — keep existing data'));
    expect(onboarding, contains('Keep Vyana running'));
    expect(onboarding, contains("Let's Go!"));
    expect(onboarding, contains('completeRingOnboarding'));

    final syncSettings = readLib('src/screens/sync_settings_screen.dart');
    expect(syncSettings, contains('Sync interval saved.'));
    expect(syncSettings, contains('applyPeriodicSyncInterval'));
    // The Android foreground toggle folded into the Sync screen in v1.1.0.
    expect(syncSettings, contains('setForegroundServiceEnabled'));

    final youScreen = readLib('src/screens/you_screen.dart');
    expect(youScreen, contains('Health monitoring'));

    final foreground = readLib('src/services/ring_foreground_service.dart');
    expect(foreground, contains('kRingForegroundSyncTick'));
    expect(foreground, contains('Vyana is running'));
    expect(foreground, contains('Keeping your ring connected'));

    final ringController = readLib('src/state/ring_controller.dart');
    expect(ringController, contains('_growReconnectBackoff'));
    expect(ringController, contains('_resetReconnectBackoff'));
    expect(ringController, contains('applyPeriodicSyncInterval'));
    expect(ringController, contains('completeRingOnboarding'));

    // Ring status copy moved into the shared chrome in v1.1.0.
    final chrome = readLib('src/shell/vyana_chrome.dart');
    expect(chrome, contains('RING OUT OF REACH'));
    expect(chrome, contains('SYNCING YOUR RING'));

    final manifest = File('scripts/release-manifest.txt').readAsStringSync();
    expect(manifest, contains('completeRingOnboarding'));
    expect(manifest, contains('ring_foreground_sync_tick'));
    expect(manifest, contains('Checking paired PRANA ring'));
  });

  test('v1.1.0 Vyana 2.0 — five tabs, Nova pill, patterns, exports', () {
    final shell = readLib('src/shell/vyana_shell.dart');
    expect(shell, contains('MetricsScreen()'));
    expect(shell, contains('NovaPill()'));
    expect(shell, isNot(contains('GuidesScreen()')));

    final chrome = readLib('src/shell/vyana_chrome.dart');
    expect(chrome, contains('Install private AI guide'));
    expect(chrome, contains("'Ask Nova'"));
    expect(chrome, contains('class PatternCard'));
    expect(chrome, contains('DashedPillPainter'));

    final home = readLib('src/screens/home_screen.dart');
    expect(home, contains("Today's read"));
    expect(home, contains('IntentRow()'));
    expect(home, contains('homeMetricCards'));

    final metrics = readLib('src/screens/metrics_screen.dart');
    expect(metrics, contains('See all & test'));
    expect(metrics, contains('ecgClassification'));
    expect(metrics, contains('readinessSeries'));

    final practice = readLib('src/screens/practice_screen.dart');
    expect(practice, contains('SUGGESTED TODAY'));
    expect(practice, contains('ReorderableListView'));
    expect(practice, contains('Pin your practices'));

    final journal = readLib('src/screens/journal_screen.dart');
    expect(journal, contains('Search entries'));
    expect(journal, contains('Did you catch it?'));

    final you = readLib('src/screens/you_screen.dart');
    expect(you, contains('Export and sovereignty'));
    expect(you, contains('How often you train'));
    expect(you, contains('openNovaFootprint'));

    final engine = readLib('src/state/pattern_engine.dart');
    expect(engine, contains('journalPatternCandidate'));
    expect(engine, contains('metricsPatternCandidate'));

    final db = readLib('src/data/db.dart');
    expect(db, contains('class Patterns extends Table'));
    expect(db, contains('int get schemaVersion => 8;'));

    final catalog = readLib('src/data/catalog.dart');
    expect(catalog, contains('kLucidDreamingId'));
    expect(catalog, isNot(contains("id: 'ravi'")));

    final manifest = File('scripts/release-manifest.txt').readAsStringSync();
    expect(manifest, contains('NOVA FOUND A PATTERN'));
    expect(manifest, contains('Search entries'));
    expect(manifest, contains('3.1 GB'));
  });
}
