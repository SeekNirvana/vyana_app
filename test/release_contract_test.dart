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

    // v1.1.5: Sync and Health monitoring merged into one "Ring data"
    // screen — two intervals, two batteries, one place.
    final ringData = readLib('src/screens/ring_data_screen.dart');
    expect(ringData, contains('applyPeriodicSyncInterval'));
    expect(ringData, contains('applyHealthMonitoring'));
    // The Android foreground toggle folded into the Sync screen in v1.1.0.
    expect(ringData, contains('setForegroundServiceEnabled'));
    expect(ringData, contains('How often the ring measures you'));
    expect(ringData, contains('How often Vyana collects it'));

    final youScreen = readLib('src/screens/you_screen.dart');
    expect(youScreen, contains('Ring data'));
    expect(youScreen, contains('openRingData'));

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
    // v1.1.5: the pill offers the choice, not one of the answers —
    // someone running their own endpoint needs no download.
    expect(chrome, contains('Configure your AI'));
    final aiSetup = readLib('src/screens/ai_setup_screen.dart');
    expect(aiSetup, contains('Which model?'));
    expect(aiSetup, contains('Her voice'));
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
    // The footprint moved to Your AI, beside the choice whose cost it
    // reports; You now opens that screen instead.
    expect(you, contains('openAiSetup'));

    final engine = readLib('src/state/pattern_engine.dart');
    expect(engine, contains('journalPatternCandidate'));
    expect(engine, contains('metricsPatternCandidate'));

    final db = readLib('src/data/db.dart');
    expect(db, contains('class Patterns extends Table'));
    // Was pinned to `=> 12`, which made every new table a failing release
    // check — the same shape as the pubspec version this file used to pin.
    // What matters is that the schema is at or past the one Patterns and
    // PracticeTargets arrived in, not that it stopped there.
    final schema = RegExp(r'int get schemaVersion => (\d+);').firstMatch(db);
    expect(schema, isNotNull, reason: 'the schema version must be readable');
    expect(int.parse(schema!.group(1)!), greaterThanOrEqualTo(12));
    expect(db, contains('class PracticeTargets extends Table'));

    final catalog = readLib('src/data/catalog.dart');
    expect(catalog, contains('kLucidDreamingId'));
    expect(catalog, isNot(contains("id: 'ravi'")));

    final manifest = File('scripts/release-manifest.txt').readAsStringSync();
    expect(manifest, contains('NOVA FOUND A PATTERN'));
    expect(manifest, contains('Search entries'));
    // The size is derived from a byte count now, precisely because a typed
    // string drifted from the file it described — it read 3.1 GB against a
    // 2.59 GB download. Assert the derivation exists and the old literal is
    // gone, rather than pinning a new string that can drift the same way.
    // The size follows the chosen model now, so the byte count lives in the
    // catalogue rather than as one constant tied to Gemma. What matters is
    // that it is a measured number and not a typed string: the label read
    // "3.1 GB" against a 2.59 GB download before this.
    //
    // Pinning each model's literal made every catalogue change a failing
    // release check, so what is asserted is the property instead: every
    // model carries a byte count that was measured rather than typed. A
    // figure somebody rounded by hand lands on an exact multiple of a
    // million; a Content-Length never does.
    final models = readLib('src/services/on_device_models.dart');
    final counts = RegExp(r'bytes: (\d+),')
        .allMatches(models)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    expect(counts, isNotEmpty, reason: 'Nova needs something to think with');
    for (final bytes in counts) {
      expect(bytes, greaterThan(100 * 1000 * 1000),
          reason: 'a usable model is not under 100 MB');
      expect(bytes % (1000 * 1000), isNot(0),
          reason: '$bytes looks rounded by hand, not read off the server');
    }
    // And none of them is the 4B that would not fit the phones this runs on.
    expect(counts.every((b) => b < 2_700_000_000), isTrue);

    // No Qwen3 while the prompt does not reach it. On .litertlm the native
    // LiteRT-LM applies the chat template, and under flutter_gemma 0.13.6
    // the Qwen3 one renders an empty user turn: 378 characters in, nothing
    // out. "What is 2 plus 2" came back "Sure! I'm here to help with
    // anything you need". Re-test against the RunPrefillAsync log before
    // putting one back.
    expect(models, isNot(contains('ModelType.qwen3')),
        reason: 'a model that is handed an empty prompt is not a choice');
    final modelManager = readLib('src/services/guide_model_manager.dart');
    expect(modelManager, contains('activeOnDeviceModel.bytes'));
    expect(manifest, isNot(contains('3.1 GB')));
  });

  test('v1.1.1 ring state you can act on', () {
    final prefs = readLib('src/state/notification_prefs.dart');
    expect(prefs, contains('return c.pairedRing != null;'));
    expect(prefs, contains('c.reconnectFailedThisLaunch || ringIsStale(c)'));
    expect(prefs, contains('vyana.ring.alert.offlineSince'));
    expect(prefs, contains('vyana.ring.alert.lowBatteryFiredAt'));

    final ring = readLib('src/state/ring_controller.dart');
    expect(ring, contains('bool get reconnectFailedThisLaunch'));

    final you = readLib('src/screens/you_screen.dart');
    expect(you, contains('Reaching your ring…'));
    expect(you, contains('Ring not in reach'));

    final intent = readLib('src/state/day_intent.dart');
    expect(intent, contains('if (!state.confirmed) await _preset();'));

    final home = readLib('src/screens/home_screen.dart');
    expect(home, contains('HomeDashboard.from(c).readinessScore'));

    final manifest = File('scripts/release-manifest.txt').readAsStringSync();
    expect(manifest, contains('Reaching your ring…'));
    expect(manifest, contains('vyana.ring.alert.lowBatteryFiredAt'));
  });

  test('v1.1.2 baselines, cycle tracking, honest daily vitals', () {
    final quality = readLib('src/vitals_quality.dart');
    expect(quality, contains('int? restingHrForDay('));
    expect(quality, contains('int? hrvForDay('));
    expect(quality, contains('enum SleepNightStatus'));
    expect(quality, contains('VitalReferenceRange? personalRange'));

    final baselines = readLib('src/state/personal_baselines.dart');
    expect(baselines, contains('enum BaselineVital'));
    expect(baselines, contains('kBaselineLearningDays = 14'));
    expect(baselines, contains('bool breachesSafetyFloor('));
    expect(baselines, contains('Duration sleepDurationTarget('));

    final cycle = readLib('src/state/cycle_tracking.dart');
    expect(cycle, contains('enum CyclePhase'));
    expect(cycle, contains('CycleStatus cycleStatusFrom('));
    expect(cycle, contains('double? phaseBaseFor('));
    expect(cycle, contains('PregnancyStatus? pregnancyStatusFor('));

    final dashboard = readLib('src/state/home_dashboard.dart');
    expect(dashboard, contains('sleepStatus'));
    expect(dashboard, contains('overnightHrv'));
    expect(dashboard, isNot(contains("vitals.heartRate == null ? '—'")));

    final session = readLib('src/state/session_controller.dart');
    expect(session, contains('int? get plannedMinutes'));
    expect(session, contains('bool get timeUp'));
    expect(session, contains('Future<void> endAtSettled()'));
    expect(session, contains('Future<void> findRecoverableSession()'));

    final sessionScreen = readLib('src/screens/session_screen.dart');
    expect(sessionScreen, isNot(contains('_readinessImpact')));
    expect(sessionScreen, contains('class MorningAfterBlock'));
    expect(sessionScreen, contains('class PastSessionScreen'));

    // Chakra is gone for good (bug 9).
    expect(readLib('src/data/catalog.dart'), isNot(contains('chakraBalance')));
    expect(sessionScreen, isNot(contains('Chakra')));
    expect(readLib('src/screens/wallet_screen.dart'),
        isNot(contains('Rewards & quests')));

    final catalog = readLib('src/data/catalog.dart');
    expect(catalog, contains("name: 'Treadmill Walk / Run'"));
    expect(catalog, contains("name: 'Gym'"));
    expect(catalog, contains("id: 'saunaCold'"));
    expect(catalog, contains('List<Activity> searchActivities('));
    expect(catalog, contains('bool get isTimed'));

    final db = readLib('src/data/db.dart');
    expect(db, contains('class CycleDays extends Table'));
    expect(db, contains('class UserActivities extends Table'));
    expect(db, contains('Future<void> updateJournalEntry('));
    expect(db, contains('Future<SessionRow?> unfinishedSession()'));

    final notify = readLib('src/services/vitals_notification_service.dart');
    expect(notify, contains('schedulePracticeEnd'));
    expect(notify, contains('scheduleStaleRingAlert'));
    expect(notify, contains('scheduleRingOfflineAlert'));

    // Bug 5: the Android 12+ splash uses its own padded asset.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/splash_logo_android12.png'));
    // Not a hard-coded version — that one breaks on every release and
    // teaches people to update the assertion without reading it. What
    // matters is that the version shipping has an entry saying what is in
    // it, which is also what the release workflow refuses to publish
    // without.
    final version = RegExp(r'^version:\s*([0-9.]+)\+(\d+)', multiLine: true)
        .firstMatch(pubspec);
    expect(version, isNotNull, reason: 'pubspec has no version line');
    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(
      changelog,
      contains('## v${version!.group(1)}'),
      reason: 'CHANGELOG.md has no entry for ${version.group(1)}',
    );

    final manifest = File('scripts/release-manifest.txt').readAsStringSync();
    expect(manifest, contains('judged against typical ranges'));
    expect(manifest, contains('Period started'));
  });

  test('v1.1.3 background alerts, honest ranges, targets, your week', () {
    // Bug 21 (1): scheduled alerts need both receivers declared, or they
    // never fire. This is the whole reason the alerts were silent.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('ScheduledNotificationReceiver'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));

    // Bug 21 (2): the service must survive a disconnect — that is when it
    // is needed. Bug 21 (3): the old saved `false` is migrated once.
    final ring = readLib('src/state/ring_controller.dart');
    expect(ring, contains('_pairedRing != null'));
    expect(ring, contains('Reconnecting to your ring'));
    expect(ring, contains('_foregroundDefaultMigratedKey'));
    // Bug 19: overnight syncs no longer ask the ring for sleep.
    expect(ring, contains('isLikelyAsleep'));
    final repo = readLib('src/repository.dart');
    expect(repo, contains('includeSleep'));

    // Bugs 22 and 23.
    final quality = readLib('src/vitals_quality.dart');
    expect(quality, contains('isNightForDay'));
    expect(quality, contains('kDayTurnoverHour'));
    expect(quality, contains('RangeDirection'));
    expect(quality, contains('vitalVerdict'));
    expect(quality, contains('kRestingHrFloor'));
    expect(quality, contains('sleptOnAfter'));
    expect(quality, contains('sessionLengthLabel'));

    // Bug 29: nothing may fall back to seed content again.
    final catalog = readLib('src/data/catalog.dart');
    expect(catalog, isNot(contains('class WeeklySeed')));
    expect(catalog, isNot(contains('class HomeSeed')));
    expect(catalog, contains('howStepsFor'));
    expect(catalog, contains('offersOnMyOwn'));
    expect(catalog, contains('offersTarget'));
    expect(
      File('lib/src/screens/weekly_screen.dart').existsSync(),
      isFalse,
      reason: 'Weekly Insights is replaced by Your week / month',
    );
    final week = readLib('src/screens/your_week_screen.dart');
    expect(week, contains('class PeriodSummary'));
    // Bug 50: the card's window is the last seven days, not a calendar week.
    expect(week, contains('LAST 7 DAYS'));

    // §11: Perform is orange, and gold stays a brand colour.
    final colors = readLib('src/theme/app_colors.dart');
    expect(colors, contains('0xFFF5923A'));
    expect(colors, contains('0xFFF9B97E'));

    // Bug 5 with the new mark, and the generator that keeps it inside the
    // Android mask.
    final pubspec2 = File('pubspec.yaml').readAsStringSync();
    expect(pubspec2, contains('assets/logo_adaptive_foreground.png'));
    expect(
      File('scripts/build-brand-assets.py').existsSync(),
      isTrue,
    );

    final fingerprints =
        File('scripts/release-manifest.txt').readAsStringSync();
    for (final line in const [
      'Discard this session?',
      'Set a target',
      'On my own',
      'FOR TODAY',
      'PRANA RINGS NEAR ME',
      'counts as light sleep',
    ]) {
      expect(fingerprints, contains(line));
    }
  });

  test('v1.1.4 brand sources and the ring photo', () {
    // Mock 16a's floating ring: the layout shipped in v1.1.3 with nothing
    // to draw, because this file was never added to the repo.
    expect(
      File('assets/ring_images/ring_inside.png').existsSync(),
      isTrue,
      reason: 'the ring screen renders no photo without it',
    );

    // The launcher wants the opaque tile and the app draws the transparent
    // mark. One file served both before, which is how the icon's dark
    // square ended up on the splash.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('image_path: assets/app_icon.png'));
    expect(pubspec, contains('image: assets/splash_logo.png'));
    expect(
      File('assets/logo.png').readAsBytesSync(),
      isNot(File('assets/app_icon.png').readAsBytesSync()),
      reason: 'the in-app mark and the launcher tile are different images',
    );
  });

  test('v1.1.6 conversations are stored, and the model is told when one ends',
      () {
    final db = readLib('src/data/db.dart');
    expect(db, contains('class ChatSessions extends Table'));
    expect(db, contains('class ChatMessages extends Table'));
    // The cascade is the whole reason deleting a conversation does not leave
    // turns behind, and it only works with foreign keys on.
    expect(db, contains('onDelete: KeyAction.cascade'));
    expect(db, contains('PRAGMA foreign_keys = ON'));

    final state = readLib('src/state/chat_sessions.dart');
    expect(state, contains('class ChatHistoryController'));
    expect(state, contains('chatTitleFrom'));
    expect(state, contains('Future<int> addUserTurn'));

    // The screen's list and the model's own history were two records of one
    // conversation and only one of them was ever cleared. Starting fresh now
    // ends both; without this call the old bug is back.
    expect(state, contains('runtime.forgetConversation()'));
    final runtime = readLib('src/services/guide_runtime_service.dart');
    expect(runtime, contains('Future<void> forgetConversation()'));
    expect(runtime, contains('chat.clearHistory()'));

    final screen = readLib('src/screens/chat_history_screen.dart');
    expect(screen, contains('openChatHistory'));
    expect(screen, contains('class ChatTranscriptScreen'));
    expect(screen, contains("label: 'New conversation'"));

    // The chat reads the stored conversation rather than its own State, so
    // leaving the screen no longer drops what was said.
    final chat = readLib('src/screens/guides_screen.dart');
    expect(chat, contains('chatHistoryProvider'));
    expect(chat, isNot(contains('final List<GuideMessage> _messages')));
    expect(chat, contains("IconBtn(icon: 'chats'"));

    final fingerprints =
        File('scripts/release-manifest.txt').readAsStringSync();
    for (final line in const [
      'Conversations',
      'New conversation',
      'ChatHistoryController',
      'forgetConversation',
    ]) {
      expect(fingerprints, contains(line));
    }
  });

  test('v1.1.6 an endpoint user can actually reach the chat', () {
    // The pill decided readiness one way and the chat decided it another:
    // with an endpoint set up and tested the pill said "Ask Nova" and the
    // screen behind it offered a download instead of a conversation. One
    // function now answers for both, so they cannot drift apart again.
    final helpers = readLib('src/screens/ai_setup_screen.dart');
    expect(helpers, contains('bool novaCanAnswer('));
    expect(helpers, contains('String novaChatSubtitle('));

    final pill = readLib('src/shell/vyana_chrome.dart');
    expect(pill, contains('novaCanAnswer('));

    final chat = readLib('src/screens/guides_screen.dart');
    expect(chat, contains('novaCanAnswer('));
    expect(chat, contains('novaChatSubtitle('));
    // The app bar claimed on-device whatever the backend was.
    expect(chat, isNot(contains("sub: 'on-device")));
    // And the gate offered a 2.6 GB download to someone whose endpoint was
    // only half set up.
    expect(chat, contains("'Finish setting up your endpoint'"));
    expect(chat, contains("label: 'Set up the endpoint'"));
  });

  test('v1.1.6 saving the profile keeps the fields it does not show', () {
    final editor = readLib('src/screens/profile_screen.dart');
    // The whole-object rebuild is what dropped trainingFrequency when that
    // field arrived after this screen was written.
    expect(editor, isNot(contains('UserProfile(\n')));
    expect(editor, contains('.copyWith('));
    expect(editor, contains('clearHeightCm:'));
    expect(editor, contains('clearWeightKg:'));
    expect(editor, contains('clearGender:'));
    // And an implausible height is refused at the gate rather than stored
    // and shown on the You row as though it were a measurement.
    expect(editor, contains('_minHeightCm'));
    expect(editor, contains('_fieldOk('));
  });

  test('v1.1.6 the model picker actually changes what is downloaded', () {
    // The picker wrote to onDeviceModelProvider; the downloader, validator
    // and loader all read activeOnDeviceModel; nothing connected the two.
    // Choosing Qwen3 1.7B put "Install Qwen3 1.7B · 977 MB" on the button
    // and fetched gemma-4-E2B-it.litertlm.
    final manager = readLib('src/services/guide_model_manager.dart');
    expect(manager, contains('setActiveOnDeviceModel(ref.read('));
    expect(manager, contains('ref.listen<OnDeviceModel>(onDeviceModelProvider'));
    expect(manager, contains('Future<void> onActiveModelChanged()'));
    // Re-registration matters as much as the re-check: the spec carries the
    // file name and type of whichever model is active.
    expect(manager, contains('ensureGuideModelRegistered(guidePersonaDefinitions[kind]!)'));

    // And the backend card stops quoting one flat size beside a picker.
    final setup = readLib('src/screens/ai_setup_screen.dart');
    expect(setup, isNot(contains(r"A $kGuideModelSizeLabel download")));
    expect(setup, contains('ref.watch(onDeviceModelProvider).bytes'));
    // "Which model?" over a single row is a question with one answer.
    expect(setup, contains('kOnDeviceModels.length > 1'));
  });
}
