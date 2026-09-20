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
        onFirstConnected: c.pairedRing == null
            ? () => unawaited(openRingOnboarding(navigator.context, c))
            : null,
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
    final profile = ref
        .watch(userProfileProvider)
        .maybeWhen(data: (p) => p, orElse: () => const UserProfile());
    final notify = ref.watch(notificationPrefsProvider);
    final guideState =
        ref.watch(guideModelManagerProvider).stateFor(GuideKind.nova);
    final band = TrainingFrequencyX.fromName(profile.trainingFrequency);
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
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: 'ring',
                iconColor: t.heading,
                label: c.pairedRing == null ? 'Scan & pair' : 'Manage ring',
                subtitle: c.pairedRing == null ? null : 'Pair, rename, unpair',
                trailing: c.pairedRing == null
                    ? null
                    : Text('PAIRED',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                onTap: c.isReady ? () => _manageRing(context, ref, c) : null,
              ),
              if (c.supportsHealthMonitoring)
                _SettingsRow(
                  icon: 'activity',
                  iconColor: t.heading,
                  label: 'Health monitoring',
                  subtitle: 'Ring measures on its own',
                  trailing: Text(
                    c.healthMonitoring.enabled
                        ? 'ON · ${c.healthMonitoring.intervalMinutes} MIN'
                        : 'OFF',
                    style: VyanaType.mono10.copyWith(
                      color: c.healthMonitoring.enabled &&
                              c.healthMonitoring.ringAcknowledged
                          ? t.green
                          : t.textMuted,
                    ),
                  ),
                  onTap: () => openHealthMonitoring(context, c),
                ),
              _SettingsRow(
                icon: 'refresh',
                iconColor: t.heading,
                label: 'Sync',
                subtitle: [
                  if (c.isSyncing)
                    'Syncing now'
                  else if (lastSync != null)
                    'Last synced ${_clockLabel(lastSync)}'
                  else
                    'Not synced yet',
                  if (Platform.isAndroid && c.foregroundServiceEnabled)
                    'background service',
                ].join(' · '),
                trailing: Text(
                  'EVERY ${c.periodicSyncIntervalMinutes} MIN',
                  style: VyanaType.mono10.copyWith(color: t.textMuted),
                ),
                onTap: () => openSyncSettings(context, c),
              ),
              _SettingsRow(
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
                _SettingsRow(
                  icon: 'target',
                  iconColor: t.heading,
                  label: 'Find my ring',
                  onTap: c.isConnected ? c.findRing : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: 'bluetooth',
                iconColor: t.heading,
                label: 'Disconnect',
                onTap: c.isConnected ? c.disconnect : null,
              ),
              _SettingsRow(
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
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: 'ring',
                iconColor: t.heading,
                label: 'Scan & pair',
                onTap: c.isReady ? () => openScanner(context, c) : null,
              ),
              _SettingsRow(
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
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'ring',
              iconColor: t.heading,
              label: 'Buy a PRANA ring',
              subtitle: 'Another size, or one for someone else',
              onTap: () => openRingOrder(context),
            ),
            if (orders.isNotEmpty)
              _SettingsRow(
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
        const _YouHeading('Nova', 'Your private guide'),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'brain',
              iconColor: t.heading,
              label: 'On-device model',
              subtitle: guideState.isReady
                  ? 'Installed · nothing leaves the phone'
                  : 'Not installed · runs entirely on this phone',
              trailing: Text(
                guideState.isReady
                    ? kGuideModelSizeLabel
                    : guideState.statusLabel.toUpperCase(),
                style: VyanaType.mono10.copyWith(color: t.textMuted),
              ),
              onTap: () => openNovaFootprint(context),
            ),
            _SettingsRow(
              icon: 'speaker',
              iconColor: t.heading,
              label: 'Voice cues',
              subtitle: 'Nova speaks during sessions · tap to preview',
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
        // ── About you · baselines ──────────────────────────────────────────
        const _YouHeading('About you', 'Baselines'),
        _SettingsGroup(
          rows: [
            _SettingsRow(
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
          ],
        ),
        // ── Appearance ─────────────────────────────────────────────────────
        const _YouHeading('Appearance', 'Theme'),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'sunDim',
              iconColor: t.heading,
              label: 'Theme',
              chevron: false,
              enabled: true,
              trailing: _ThemePills(mode: mode),
            ),
          ],
        ),
        // ── Your data ──────────────────────────────────────────────────────
        const _YouHeading('Your data', 'Export and sovereignty'),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'download',
              iconColor: t.heading,
              label: 'Export health data',
              subtitle: 'Summary, every reading, sleep nights, ECG',
              trailing: Text('CSV · JSON',
                  style: VyanaType.mono10.copyWith(color: t.textMuted)),
              onTap: () => openExports(context, ref, section: ExportSection.health),
            ),
            _SettingsRow(
              icon: 'download',
              iconColor: t.heading,
              label: 'Export your journal',
              subtitle: 'All entries, or dreams, reflections, ideas, meals separately',
              onTap: () => openExports(context, ref, section: ExportSection.journal),
            ),
            _SettingsRow(
              icon: 'db',
              iconColor: t.heading,
              label: 'Export everything',
              subtitle: 'Machine-readable archive',
              onTap: () => openExports(context, ref, section: ExportSection.archive),
            ),
            _SettingsRow(
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
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'info',
              iconColor: t.heading,
              label: 'About Vyana',
              subtitle: 'Mission, ethos, ring capabilities, version',
              onTap: () => openAbout(context, c),
            ),
            _SettingsRow(
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

  /// Manage ring: pair/scan, rename and unpair in one place — renaming is
  /// device identity, not its own destination.
  Future<void> _manageRing(
    BuildContext context,
    WidgetRef ref,
    RingController c,
  ) {
    final t = context.vyana;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom,
        ),
        child: Panel(
          pad: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsRow(
                icon: 'bluetooth',
                iconColor: t.heading,
                label: c.pairedRing == null ? 'Scan & pair' : 'Pair or reconnect',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  openScanner(context, c);
                },
              ),
              Divider(height: 1, color: t.borderSoft, indent: 14, endIndent: 14),
              _SettingsRow(
                icon: 'feather',
                label: 'Rename ring',
                onTap: c.isConnected
                    ? () {
                        Navigator.of(sheetContext).pop();
                        _renameRing(context, c);
                      }
                    : null,
              ),
              Divider(height: 1, color: t.borderSoft, indent: 14, endIndent: 14),
              _SettingsRow(
                icon: 'x',
                iconColor: t.vit('hr'),
                label: 'Unpair',
                chevron: false,
                onTap: c.pairedRing == null
                    ? null
                    : () async {
                        final ok = await showVyanaConfirmDialog<bool>(
                          context: sheetContext,
                          title: 'Unpair this ring?',
                          message: 'Vyana forgets the ring. Your synced history stays on this phone.',
                          confirmLabel: 'Unpair',
                          destructive: true,
                        );
                        if (ok != true) return;
                        await c.unpairCurrentRing();
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Future<void> _renameRing(BuildContext context, RingController c) async {
    final current = c.selectedDevice == null
        ? ''
        : deviceLabel(c.selectedDevice);
    var edited = current;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename ring'),
        content: TextFormField(
          initialValue: current,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ring name'),
          textInputAction: TextInputAction.done,
          onChanged: (value) => edited = value,
          onFieldSubmitted: (value) =>
              Navigator.of(dialogContext).pop(normalizeRingName(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(normalizeRingName(edited)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return;
    await c.renameRing(name);
  }
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in ThemeMode.values)
            InkWell(
              onTap: () => ref.read(themeModeProvider.notifier).set(m),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
                decoration: BoxDecoration(
                  color: mode == m
                      ? t.heading.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  YouScreen._themeLabel(m),
                  style: VyanaType.caption.copyWith(
                    color: mode == m ? t.text : t.mutedInk,
                    fontWeight: mode == m ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});
  final List<_SettingsRow> rows;

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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.subtitle,
    this.chevron = true,
    this.enabled,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final String? subtitle;
  final bool chevron;

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
          child: Row(
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
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              if (chevron) VyanaIcon('chevR', size: 17, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
