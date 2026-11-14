part of '../../main.dart';

// ── Shared navigation into the retained (reused) screens ────────────────────

Future<void> openScanner(BuildContext context, RingController c) {
  // The caller's context can be gone by the time the ring connects (Home's
  // "Pair now" panel is removed once a ring exists), so onboarding is pushed
  // from the navigator captured now, not from that context later.
  final navigator = Navigator.of(context);
  return navigator.push<void>(
    MaterialPageRoute(
      builder: (_) => DeviceScanScreen(
        repo: c.repo,
        selectedDevice: c.selectedDevice,
        pairedRing: c.pairedRing,
        connected: c.isConnected,
        basicInfo: c.basicInfo,
        vitals: c.vitals,
        onConnect: c.connect,
        onReconnectPaired: () => c.reconnectSavedRing(force: true),
        onUnpair: c.unpairCurrentRing,
        onConnectedDeviceDetected: c.handleScannerDetectedConnection,
        // Bug 37: the app's own last sync, not this screen's.
        lastSyncedAt: c.lastSyncedAt,
        // Bug 26: rename moved onto the ring screen, beside the name.
        onRename: c.renameRing,
        // Setup is remembered per ring, so the decision can only be made
        // once the connection has told us which ring this is. Re-pairing a
        // ring you already set up goes straight back to You; a ring this
        // phone has not seen gets its own setup.
        onFirstConnected: () {
          if (!c.currentRingNeedsOnboarding) return;
          unawaited(openRingOnboarding(navigator.context, c));
        },
      ),
    ),
  );
}

Future<void> openMeasurements(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MeasurementsScreen(
        snapshotListenable: c.measurementSnapshot,
        onMeasure: c.runMeasurement,
        onStartEcg: c.startEcg,
        onStopEcg: c.stopEcg,
        onGetEcgResult: c.getEcgResult,
        onSync: () => syncRingWithFeedback(context, c),
      ),
    ),
  );
}

/// How long a user-driven reconnect is given before it is called a failure.
/// A direct connect, a six-second scan and a connect fit inside this.
const Duration kReconnectTimeout = Duration(seconds: 20);

/// Bug 48: tapping CONNECT used to call `reconnectSavedRing(force: true)`
/// with `unawaited` and nothing else — no change on the pill, no message, and
/// a silent failure when the ring was out of reach. This is the reconnect
/// equivalent of [syncRingWithFeedback], and every Reconnect action uses it.
///
/// The pill, the eyebrow and the banner switch to "connecting" on their own,
/// from [RingController.isUserReconnecting]; this adds the ending — a sync on
/// success, a snackbar with a way forward on failure.
Future<void> reconnectWithFeedback(
  BuildContext context,
  RingController c,
) async {
  // Rule 3: ignore taps while a user-driven attempt is already running.
  // A passive retry is not ignored — the call below joins it, so the pill
  // still answers the tap.
  if (c.isUserReconnecting || c.isConnected) return;

  var connected = false;
  try {
    connected = await c
        .reconnectSavedRing(force: true)
        .timeout(kReconnectTimeout, onTimeout: () => c.isConnected);
  } on Object catch (error) {
    debugPrint('Reconnect with feedback failed: $error');
  }
  if (!context.mounted) return;

  if (connected) {
    // A fresh connection starts its own sync; this makes it the narrated one.
    await syncRingWithFeedback(context, c);
    return;
  }
  showVyanaSnackBar(
    context,
    message: "Couldn't reach your ring. Keep it close and try again.",
    success: false,
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: 'Ring screen',
      onPressed: () => unawaited(openScanner(context, c)),
    ),
  );
}

Future<void> syncRingWithFeedback(
  BuildContext context,
  RingController c,
) async {
  // A sync needs a live link; when the ring dropped, reach for it first so
  // "Sync" from the Home pill or banner is one tap, not two.
  if (!c.isConnected) {
    showVyanaSnackBar(
      context,
      message: 'Reaching your ring…',
      icon: 'bluetooth',
      success: true,
      duration: const Duration(seconds: 2),
    );
    final connected = await c.reconnectSavedRing(force: true);
    if (!context.mounted) return;
    if (!connected) {
      showVyanaSnackBar(
        context,
        message: 'Ring not in reach. Bring it closer and try again.',
        success: false,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => unawaited(syncRingWithFeedback(context, c)),
        ),
      );
      return;
    }
  }
  showVyanaSnackBar(
    context,
    message: 'Updating your health data…',
    icon: 'refresh',
    success: true,
    duration: const Duration(seconds: 2),
  );
  final feedback = await c.syncDeviceData();
  // Null here means a sync was already running (a fresh connection starts
  // one on its own) — the pill shows SYNCING, nothing more to say.
  if (!context.mounted || feedback == null) return;
  showVyanaSnackBar(
    context,
    message: feedback.snackMessage,
    success: feedback.success,
    action: feedback.success
        ? null
        : SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(syncRingWithFeedback(context, c)),
          ),
  );
}

Future<void> openSleep(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => SleepDetailScreen(history: c.history)),
  );
}

Future<void> openHistory(BuildContext context, RingController c) async {
  await c.refreshHistoryLogStatus();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          HistoryLogScreen(history: c.history, status: c.historyLogStatus),
    ),
  );
}

Future<void> openAbout(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => AppAboutScreen(features: c.features)),
  );
}

Future<void> openPrivacy(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const AppPrivacyScreen()));
}

Future<void> openActivityDetail(
  BuildContext context,
  Activity activity, {
  int? minutes,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ActivityDetailScreen(activity: activity, minutes: minutes),
    ),
  );
}

/// You answers "what is mine and where does it go" — device, model
/// footprint, baselines and exports. The ring group is device management
/// only: the three data views that used to live here are Metrics' now.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final c = ref.watch(ringControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final ai = ref.watch(aiBackendProvider);
    final voiceSvc = ref.watch(guideVoiceServiceProvider);
    final displayScale = ref.watch(displayScaleProvider);
    final profile = ref
        .watch(userProfileProvider)
        .maybeWhen(data: (p) => p, orElse: () => const UserProfile());
    final notify = ref.watch(notificationPrefsProvider);
    final guideState =
        ref.watch(guideModelManagerProvider).stateFor(GuideKind.nova);
    final band = TrainingFrequencyX.fromName(profile.trainingFrequency);
    final baselines = ref.watch(personalBaselinesProvider);
    final orders = ref.watch(ringOrdersProvider).valueOrNull ?? const [];
    final lastSync = c.lastSyncedAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 176),
      children: [
        const VAppBar(title: 'You'),
        Panel(
          pad: 16,
          onTap: () => openProfileEditor(context),
          child: Row(
            children: [
              const Seal(size: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.displayName,
                      style: VyanaType.titleSerif.copyWith(
                        color: t.text,
                        fontSize: 20,
                      ),
                    ),
                    if (profile.subtitle != null)
                      Text(
                        profile.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VyanaType.caption.copyWith(color: t.textSec),
                      )
                    else
                      Text(
                        'Tap to add your details',
                        style: VyanaType.caption.copyWith(color: t.textMuted),
                      ),
                    const SizedBox(height: 4),
                    MonoEyebrow(
                      [
                        ringLineFor(c),
                        if (c.isConnected && c.batteryPercent != null)
                          '${c.batteryPercent}%',
                      ].join(' · '),
                      size: 11.5,
                      spacing: 0.8,
                      // Ends in the ring's state and battery, so it shrinks
                      // rather than losing its tail on a narrow screen.
                      shrinkToFit: true,
                    ),
                  ],
                ),
              ),
              VyanaIcon('edit', size: 18, color: t.green),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // ── Your ring · PRANA (design order: manage, monitoring, sync,
        // notifications, find) then the destructive pair on their own ──
        const _YouHeading('Your ring', 'PRANA'),
        if (c.hasRingContext) ...[
          SettingsGroup(
            rows: [
              // Bug 26: the same Sync now sits at the top of You → Ring,
              // shown whether or not the ring is connected — when it is not,
              // reconnecting is the thing the user actually wants.
              SettingsRow(
                icon: 'refresh',
                iconColor: t.heading,
                label: c.isConnected ? 'Sync now' : 'Reconnect',
                subtitle: c.isSyncing
                    ? 'Syncing your ring…'
                    : (lastSync == null
                        ? 'Not synced yet'
                        : 'Last synced ${_clockLabel(lastSync)}'),
                onTap: !c.isReady || c.isSyncing || c.isUserReconnecting
                    ? null
                    : () => c.isConnected
                        ? unawaited(syncRingWithFeedback(context, c))
                        // Bug 48: same feedback path everywhere.
                        : unawaited(reconnectWithFeedback(context, c)),
              ),
              SettingsRow(
                icon: 'ring',
                iconColor: t.heading,
                label: c.pairedRing == null ? 'Scan & pair' : 'Manage ring',
                subtitle: c.pairedRing == null ? null : 'Status, sync, rename',
                trailing: c.pairedRing == null
                    ? null
                    : Text('PAIRED',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                // Bug 26: opens the ring screen directly. The old sheet
                // offered pair / rename / unpair — all of which now live on
                // that screen, beside the ring they act on.
                onTap: c.isReady ? () => openScanner(context, c) : null,
              ),
              // Two screens with near-identical "every N minutes" steppers
              // became one: the ring's own interval and Vyana's collection
              // interval read as a pair, which is the only way either makes
              // sense.
              SettingsRow(
                icon: 'activity',
                iconColor: t.heading,
                label: 'Ring data',
                subtitle: ringDataSubtitle(
                  supportsMonitoring: c.supportsHealthMonitoring,
                  monitoringOn: c.healthMonitoring.enabled,
                  monitoringMinutes: c.healthMonitoring.intervalMinutes,
                  collectMinutes: c.periodicSyncIntervalMinutes,
                  background:
                      Platform.isAndroid && c.foregroundServiceEnabled,
                ),
                onTap: () => openRingData(context, c),
              ),
              SettingsRow(
                icon: 'bell',
                iconColor: t.heading,
                label: 'Notifications',
                subtitle: 'Ring offline, low battery, vitals alerts',
                trailing: Text(
                  '${notify.onCount} OF 3 ON',
                  style: VyanaType.mono10.copyWith(color: t.textMuted),
                ),
                onTap: () => openNotificationSettings(context),
              ),
              if (c.supportsFindRing)
                SettingsRow(
                  icon: 'target',
                  iconColor: t.heading,
                  label: 'Find my ring',
                  onTap: c.isConnected ? c.findRing : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          SettingsGroup(
            rows: [
              SettingsRow(
                icon: 'bluetooth',
                iconColor: t.heading,
                label: 'Disconnect',
                onTap: c.isConnected ? c.disconnect : null,
              ),
              SettingsRow(
                icon: 'alert',
                iconColor: t.vit('hr'),
                label: 'Reset PRANA ring',
                subtitle: 'Erases ring data and unpairs',
                onTap: c.isConnected
                    ? () => _confirmResetRing(context, ref, c)
                    : null,
              ),
            ],
          ),
        ] else
          SettingsGroup(
            rows: [
              SettingsRow(
                icon: 'ring',
                iconColor: t.heading,
                label: 'Scan & pair',
                onTap: c.isReady ? () => openScanner(context, c) : null,
              ),
              SettingsRow(
                icon: 'bell',
                iconColor: t.heading,
                label: 'Notifications',
                subtitle: 'Ring offline, low battery, vitals alerts',
                trailing: Text(
                  '${notify.onCount} OF 3 ON',
                  style: VyanaType.mono10.copyWith(color: t.textMuted),
                ),
                onTap: () => openNotificationSettings(context),
              ),
            ],
          ),
        const SizedBox(height: 10),
        // ── Commerce, unchanged ────────────────────────────────────────────
        SettingsGroup(
          rows: [
            SettingsRow(
              icon: 'ring',
              iconColor: t.heading,
              label: 'Buy a PRANA ring',
              subtitle: 'Another size, or one for someone else',
              onTap: () => openRingOrder(context),
            ),
            if (orders.isNotEmpty)
              SettingsRow(
                icon: 'db',
                iconColor: t.heading,
                label: 'Your orders',
                subtitle: _ordersLine(orders),
                onTap: () => openRingOrders(context),
              ),
          ],
        ),
        const SizedBox(height: 18),
        // ── Nova ──────────────────────────────────────────────────────────
        const _YouHeading('Nova', 'Where she thinks, and how she sounds'),
        SettingsGroup(
          rows: [
            // This row claimed "On-device model · nothing leaves the phone"
            // whatever the user had actually chosen, so someone running
            // their own endpoint was told the opposite of what was
            // happening. It reads the backend now, and says which.
            SettingsRow(
              icon: ai.backend == AiBackend.cloud ? 'cloud' : 'brain',
              iconColor: t.heading,
              label: 'Thinking',
              subtitle: novaThinkingSubtitle(
                backend: ai.backend,
                endpoint: ai.endpoint,
                localReady: guideState.isReady,
              ),
              trailing: Text(
                novaThinkingTrailing(
                  backend: ai.backend,
                  endpoint: ai.endpoint,
                  localReady: guideState.isReady,
                  localStatus: guideState.statusLabel,
                ),
                style: VyanaType.mono10.copyWith(color: t.textMuted),
              ),
              onTap: () => openAiSetup(context),
            ),
            // Nova's voice had no entry in You at all — it was reachable
            // only through Practice, behind the guide store, inside a card
            // named after something else. "Where is the audio model in
            // settings" had no good answer.
            SettingsRow(
              icon: 'speaker',
              iconColor: t.heading,
              label: 'Nova\'s voice',
              subtitle: novaVoiceRowSubtitle(
                installed: voiceSvc.novaVoiceReady,
                available: voiceSvc.novaVoiceAvailableToInstall,
                size: voiceSvc.novaVoiceDownloadSize,
              ),
              trailing: Text(
                voiceSvc.novaVoiceReady
                    ? 'INSTALLED'
                    : (voiceSvc.novaVoiceAvailableToInstall
                        ? voiceSvc.novaVoiceDownloadSize.toUpperCase()
                        : 'UNAVAILABLE'),
                style: VyanaType.mono10.copyWith(color: t.textMuted),
              ),
              onTap: () => openGuideStore(context),
            ),
            SettingsRow(
              icon: 'waveform',
              iconColor: t.heading,
              label: 'Voice cues',
              subtitle: voiceSvc.novaVoiceReady
                  ? 'Nova speaks during sessions · tap to preview'
                  : "Silent until Nova's voice is installed",
              chevron: false,
              trailing: VSwitch(
                on: ref.watch(voiceCuesEnabledProvider),
                color: t.green,
                onTap: () => ref
                    .read(voiceCuesEnabledProvider.notifier)
                    .set(!ref.read(voiceCuesEnabledProvider)),
              ),
              onTap: () => _previewVoiceCue(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // ── Practice · the weekly plan (item 46) ──────────────────────────
        const _YouHeading('Practice', 'My week'),
        SettingsGroup(
          rows: [
            SettingsRow(
              icon: 'calendar',
              iconColor: t.heading,
              label: 'My week',
              subtitle: weeklyPlanSubtitle(ref.watch(weeklyPlanProvider)),
              trailing: Text(
                ref.watch(weeklyPlanProvider).isEmpty ? 'OFF' : 'ON',
                style: VyanaType.mono10.copyWith(color: t.textMuted),
              ),
              onTap: () => openMyWeek(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // ── About you · baselines ──────────────────────────────────────────
        const _YouHeading('About you', 'Baselines'),
        SettingsGroup(
          rows: [
            SettingsRow(
              icon: 'run',
              iconColor: t.heading,
              label: 'How often you train',
              subtitle: 'Sets your resting-HR band · '
                  '${restingHrBand(band).low.round()}–${restingHrBand(band).high.round()} bpm',
              trailing: Text(
                band == null ? 'NOT SET' : band.shortLabel,
                style: VyanaType.mono10.copyWith(color: t.textMuted),
              ),
              onTap: () => showTrainingFrequencySheet(context, ref),
            ),
            // §14: the answers Nova asked for stay visible and editable here,
            // beside the one question we ask up front.
            SettingsRow(
              icon: 'insights',
              iconColor: t.heading,
              label: 'Your normal',
              subtitle: baselineSummaryLine(baselines),
              trailing: Text(
                baselines.isLearning
                    ? 'DAY ${baselines.learningDay}/$kBaselineLearningDays'
                    : 'EDIT',
                style: VyanaType.mono10.copyWith(color: t.textMuted),
              ),
              onTap: () => showBaselineAnswersSheet(context, ref),
            ),
            // §14b: the Cycle row exists only while the profile says female.
            if (profile.gender == UserGender.female)
              SettingsRow(
                icon: 'calendar',
                iconColor: t.heading,
                label: 'Cycle',
                subtitle: cycleSubtitleFor(profile.cycleMode),
                trailing: Text(
                  profile.cycleMode == CycleMode.off ? 'OFF' : 'ON',
                  style: VyanaType.mono10.copyWith(color: t.textMuted),
                ),
                onTap: () => showCycleModeSheet(context, ref),
              ),
          ],
        ),
        // ── Appearance ─────────────────────────────────────────────────────
        const _YouHeading('Appearance', 'Theme and size'),
        SettingsGroup(
          rows: [
            // Both appearance controls are segmented, and three words do
            // not fit beside a label on a narrow row — "Theme" wrapped to
            // "The / me" at the Large display size. They get the row's full
            // width, under the label, and now read as a pair.
            SettingsRow(
              icon: 'sunDim',
              iconColor: t.heading,
              label: 'Theme',
              subtitle: 'Light, dark, or whatever the phone is set to',
              chevron: false,
              enabled: true,
              below: _ThemePills(mode: mode),
            ),
            // The same screen arrives with a third less room on a 360dp
            // phone than on a 411dp one, and Vyana is drawn proportionally
            // larger there. Android's own Display size fixes it system-wide;
            // this is the same lever where people will actually find it.
            SettingsRow(
              icon: 'textSize',
              iconColor: t.heading,
              label: 'Display size',
              subtitle: displayScaleCaption(displayScale),
              chevron: false,
              enabled: true,
              below: DisplayScalePills(scale: displayScale),
            ),
          ],
        ),
        // ── Your data ──────────────────────────────────────────────────────
        const _YouHeading('Your data', 'Export and sovereignty'),
        SettingsGroup(
          rows: [
            SettingsRow(
              icon: 'download',
              iconColor: t.heading,
              label: 'Export health data',
              subtitle: 'Summary, every reading, sleep nights, ECG',
              trailing: Text('CSV · JSON',
                  style: VyanaType.mono10.copyWith(color: t.textMuted)),
              onTap: () => openExports(context, ref, section: ExportSection.health),
            ),
            SettingsRow(
              icon: 'download',
              iconColor: t.heading,
              label: 'Export your journal',
              subtitle: 'All entries, or dreams, reflections, ideas, meals separately',
              onTap: () => openExports(context, ref, section: ExportSection.journal),
            ),
            SettingsRow(
              icon: 'db',
              iconColor: t.heading,
              label: 'Export everything',
              subtitle: 'Machine-readable archive',
              onTap: () => openExports(context, ref, section: ExportSection.archive),
            ),
            SettingsRow(
              icon: 'shield',
              iconColor: t.heading,
              label: 'Cloud sync',
              subtitle: 'Opt-in backup · not yet live, nothing leaves this phone',
              chevron: false,
              trailing: VSwitch(
                on: ref.watch(sessionSyncEnabledProvider),
                color: t.green,
                onTap: () => ref
                    .read(sessionSyncEnabledProvider.notifier)
                    .set(!ref.read(sessionSyncEnabledProvider)),
              ),
              onTap: () => ref
                  .read(sessionSyncEnabledProvider.notifier)
                  .set(!ref.read(sessionSyncEnabledProvider)),
            ),
          ],
        ),
        const _YouHeading('Vyana', 'About & privacy'),
        SettingsGroup(
          rows: [
            SettingsRow(
              icon: 'info',
              iconColor: t.heading,
              label: 'About Vyana',
              subtitle: 'Mission, ethos, ring capabilities, version',
              onTap: () => openAbout(context, c),
            ),
            SettingsRow(
              icon: 'shield',
              iconColor: t.heading,
              label: 'Privacy & sovereignty',
              subtitle: 'What stays on your phone, and what never leaves it',
              onTap: () => openPrivacy(context),
            ),
          ],
        ),
      ],
    );
  }

  static String _clockLabel(DateTime at) {
    final now = DateTime.now();
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return time;
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[at.weekday - 1]} $time';
  }

  /// "1 order · shipped 12 Sep" — the whole question is where the ring is.
  static String _ordersLine(List<RingOrderRow> orders) {
    final latest = orders.first;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final placed = '${latest.createdAt.day} ${months[latest.createdAt.month - 1]}';
    final eta = latest.createdAt.add(Duration(days: latest.shippingEtaDays));
    final etaText = '${eta.day} ${months[eta.month - 1]}';
    final status = switch (latest.status) {
      'paid' => latest.orderType == 'interest'
          ? 'interest noted $placed'
          : 'paid $placed · ships by $etaText',
      'pending' => 'payment pending',
      'failed' => 'payment failed',
      _ => latest.status,
    };
    final n = orders.length;
    return '$n order${n == 1 ? '' : 's'} · $status';
  }

  // _manageRing is gone (bug 26): pair, rename and unpair all live on the
  // ring screen now, beside the ring they act on, so the sheet in between
  // was one tap and one layer with nothing of its own to say.

  static String _themeLabel(ThemeMode m) => switch (m) {
    ThemeMode.dark => 'Dark',
    ThemeMode.light => 'Light',
    ThemeMode.system => 'System',
  };

  Future<void> _previewVoiceCue(BuildContext context, WidgetRef ref) async {
    if (!ref.read(voiceCuesEnabledProvider)) {
      showVyanaSnackBar(
        context,
        message: 'Turn on Voice cues to hear session guidance.',
        icon: 'speaker',
      );
      return;
    }
    try {
      await ref.read(voiceCueServiceProvider).preview();
    } catch (_) {
      if (!context.mounted) return;
      showVyanaSnackBar(
        context,
        message: 'Could not play voice cue preview.',
        icon: 'alert',
      );
    }
  }


  Future<void> _confirmResetRing(
    BuildContext context,
    WidgetRef ref,
    RingController c,
  ) async {
    final ringName = c.pairedRing?.displayName ?? 'your ring';
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Reset PRANA ring?',
      message:
          'Back up anything you want to keep first.\n\n'
          '${c.supportsFactoryReset ? 'This factory-resets $ringName — erasing ring settings and health records.' : 'This erases health records stored on $ringName (sleep, steps, vitals, and related history).'}\n\n'
          'Vyana will also unpair the ring and remove all cached vitals, history, '
          'health monitoring prefs, and the local sync log from this phone. '
          'Practice sessions, journal, and wallet data stay on your phone.\n\n'
          'This cannot be undone. Keep the ring nearby and connected.',
      confirmLabel: 'Reset ring',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    showVyanaSnackBar(
      context,
      message: 'Resetting ring…',
      icon: 'refresh',
      success: true,
      duration: const Duration(seconds: 2),
    );

    final result = await c.resetPranaRingToFactory();
    if (!context.mounted) return;

    showVyanaSnackBar(
      context,
      message: result.message,
      icon: result.success ? 'check' : 'alert',
      success: result.success,
      action: result.success
          ? null
          : SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_confirmResetRing(context, ref, c)),
            ),
    );

    if (result.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(tabIndexProvider.notifier).state = 0;
    }
  }

  // _renameRing moved onto the ring screen (bug 26).
}

/// You's section heading: grey mono eyebrow over a neutral title, on two
/// lines (clearer than the mock's one-line form). Never gold — gold is the
/// Perform intent colour.
class _YouHeading extends StatelessWidget {
  const _YouHeading(this.eyebrow, this.title);
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoEyebrow(eyebrow, size: 11.5, spacing: 1),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 21),
          ),
        ],
      ),
    );
  }
}

/// Dark · Light · System as a compact trailing control on the Theme row.
/// Same shape as [_ThemePills] — one segmented control for each of the two
/// appearance choices, so they read as a pair.
class DisplayScalePills extends ConsumerWidget {
  const DisplayScalePills({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.mutedInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      // Three segments share the row's width equally and each word shrinks
      // inside its own segment, so neither a long label nor a large text
      // scale can push this control past the edge.
      child: Row(
        children: [
          for (final option in kDisplayScales)
            Expanded(
              child: InkWell(
                onTap: () => unawaited(
                  ref.read(displayScaleProvider.notifier).set(option),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
                  decoration: BoxDecoration(
                    color: (scale - option).abs() < 0.005
                        ? t.heading.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      displayScaleLabel(option),
                      maxLines: 1,
                      softWrap: false,
                      style: VyanaType.caption.copyWith(
                        color: (scale - option).abs() < 0.005
                            ? t.text
                            : t.mutedInk,
                        fontWeight: (scale - option).abs() < 0.005
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemePills extends ConsumerWidget {
  const _ThemePills({required this.mode});
  final ThemeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.mutedInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      // Equal shares, each word shrinking inside its own segment — the
      // same shape as DisplayScalePills, so neither control can push the
      // row past the edge at any size or text scale.
      child: Row(
        children: [
          for (final m in ThemeMode.values)
            Expanded(
              child: InkWell(
                onTap: () => ref.read(themeModeProvider.notifier).set(m),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
                  decoration: BoxDecoration(
                    color: mode == m
                        ? t.heading.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      YouScreen._themeLabel(m),
                      maxLines: 1,
                      softWrap: false,
                      style: VyanaType.caption.copyWith(
                        color: mode == m ? t.text : t.mutedInk,
                        fontWeight:
                            mode == m ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.rows});
  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 4,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: t.borderSoft,
                indent: 14,
                endIndent: 14,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One row in a You settings group. Public so the layout cases can render
/// it: this row carries a label, an optional subtitle, an optional trailing
/// control and an optional full-width one, and that combination has broken
/// on a narrow phone twice.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.subtitle,
    this.chevron = true,
    this.enabled,
    this.below,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final String? subtitle;
  final bool chevron;

  /// A control that gets the row's full width, under the label, instead of
  /// being squeezed into [trailing]. A segmented control with three words in
  /// it does not fit beside a label on a 360dp phone — it overflowed the row
  /// and crushed "Display size" into a one-letter column.
  final Widget? below;

  /// Rows whose control lives in [trailing] (a switch, theme pills) have no
  /// row tap but are not disabled; pass true so they are not dimmed.
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final enabled = this.enabled ?? onTap != null;
    final color = iconColor ?? t.textSec;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  VyanaIconBadge(name: icon, color: color),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: VyanaType.bodySm.copyWith(color: t.text),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: VyanaType.caption.copyWith(
                              color: t.textSec,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Deliberately NOT Flexible: in a Row it would take flex
                  // space away from the label's Expanded and split the row
                  // in half, wrapping "Notifications" to "Notification / s".
                  // A control too wide to sit beside the label belongs in
                  // [below] instead.
                  if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
                  if (chevron) VyanaIcon('chevR', size: 17, color: t.textMuted),
                ],
              ),
              if (below != null) ...[
                const SizedBox(height: 10),
                below!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
