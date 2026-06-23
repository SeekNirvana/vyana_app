part of '../../main.dart';

// ── Shared navigation into the retained (reused) screens ────────────────────

Future<void> openScanner(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
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

Future<void> syncRingWithFeedback(BuildContext context, RingController c) async {
  showVyanaSnackBar(
    context,
    message: 'Syncing vitals and data from your ring…',
    icon: 'refresh',
    success: true,
    duration: const Duration(seconds: 2),
  );
  final feedback = await c.syncDeviceData();
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
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const AppPrivacyScreen()),
  );
}

Future<void> openActivityDetail(BuildContext context, Activity activity) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: activity)),
  );
}

/// The "You" tab: profile, ring management (reusing the retained screens),
/// appearance, and links to Chakra/rewards and About.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final c = ref.watch(ringControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final profile = ref.watch(userProfileProvider).maybeWhen(
          data: (p) => p,
          orElse: () => const UserProfile(),
        );
    final wallet = ref.watch(walletControllerProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        const VAppBar(title: 'You', sub: 'Settings'),
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
                    Text(profile.displayName,
                        style: VyanaType.titleSerif.copyWith(
                            color: t.text, fontSize: 20)),
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
                    Text(
                      c.isConnected
                          ? '${c.pairedRing?.displayName ?? 'PRANA ring'} · connected'
                          : c.hasRingContext
                              ? c.status
                              : 'No ring yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.caption.copyWith(color: t.textSec),
                    ),
                  ],
                ),
              ),
              VyanaIcon('chevR', size: 17, color: t.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHead(eyebrow: 'You', title: 'Profile'),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'user',
              label: 'Edit profile',
              onTap: () => openProfileEditor(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHead(eyebrow: 'Your ring', title: 'PRANA'),
        if (c.hasRingContext)
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: 'ring',
                label: c.pairedRing == null ? 'Scan & pair' : 'Manage ring',
                onTap: c.isReady ? () => openScanner(context, c) : null,
              ),
              _SettingsRow(
                icon: 'refresh',
                label: 'Sync vitals & data',
                trailing: c.isSyncing
                    ? Text('Syncing…',
                        style: VyanaType.label.copyWith(color: t.green))
                    : null,
                onTap: c.isConnected && !c.isSyncing
                    ? () => syncRingWithFeedback(context, c)
                    : null,
              ),
              _SettingsRow(
                icon: 'heart',
                label: 'Measurements (HR, SpO₂, ECG…)',
                onTap: () => openMeasurements(context, c),
              ),
              _SettingsRow(
                icon: 'moon',
                label: 'Sleep detail',
                onTap: () => openSleep(context, c),
              ),
              _SettingsRow(
                icon: 'db',
                label: 'Data log',
                onTap: () => openHistory(context, c),
              ),
              if (c.supportsHealthMonitoring)
                _SettingsRow(
                  icon: 'activity',
                  label: 'Health monitoring',
                  trailing: Text(
                    c.healthMonitoring.enabled
                        ? c.healthMonitoring.summaryLabel
                        : 'Off',
                    style: VyanaType.label.copyWith(
                      color: c.healthMonitoring.enabled &&
                              c.healthMonitoring.ringAcknowledged
                          ? t.green
                          : t.textMuted,
                    ),
                  ),
                  onTap: () => openHealthMonitoring(context, c),
                ),
              if (c.supportsFindRing)
                _SettingsRow(
                  icon: 'bell',
                  label: 'Find my ring',
                  onTap: c.isConnected ? c.findRing : null,
                ),
              _SettingsRow(
                icon: 'feather',
                label: 'Rename ring',
                onTap: c.isConnected ? () => _renameRing(context, c) : null,
              ),
              _SettingsRow(
                icon: 'bluetooth',
                label: 'Disconnect',
                onTap: c.isConnected ? c.disconnect : null,
              ),
              _SettingsRow(
                icon: 'refresh',
                label: 'Reset PRANA ring',
                onTap: c.isConnected && c.supportsFactoryReset
                    ? () => _confirmResetRing(context, c)
                    : null,
              ),
            ],
          )
        else
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: 'bluetooth',
                label: 'Scan & pair',
                onTap: c.isReady ? () => openScanner(context, c) : null,
              ),
            ],
          ),
        const SizedBox(height: 10),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'ring',
              label: 'Buy PRANA ring',
              onTap: () => openRingOrder(context),
            ),
            if (ref.watch(hasRingOrdersProvider).valueOrNull ?? false)
              _SettingsRow(
                icon: 'db',
                label: 'Your orders',
                onTap: () => openRingOrders(context),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHead(eyebrow: 'Chakra', title: 'Rewards'),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'award',
              label: 'Chakra & rewards',
              trailing: Text('${HomeSeed.chakraBalance}',
                  style: VyanaType.label.copyWith(color: t.gold)),
              onTap: () => _comingSoon(context, 'Chakra & rewards'),
            ),
            _SettingsRow(
              icon: 'wallet',
              label: 'Wallet',
              trailing: wallet.isConnected
                  ? Text(
                      '${wallet.shortAddress()} · ${wallet.activeChain.currency}',
                      style: VyanaType.mono10.copyWith(color: t.gold),
                    )
                  : null,
              onTap: () => openWallet(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHead(eyebrow: 'Appearance', title: 'Theme'),
        Panel(
          pad: 14,
          child: Row(
            children: [
              for (final m in ThemeMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill(
                    label: _themeLabel(m),
                    active: mode == m,
                    onTap: () => ref.read(themeModeProvider.notifier).set(m),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHead(eyebrow: 'Sovereignty', title: 'Your data'),
        Panel(
          pad: 14,
          child: Row(
            children: [
              VyanaIcon('shield', size: 19, color: t.green),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Cloud sync', style: VyanaType.label.copyWith(color: t.text)),
                    Text(
                      'Opt-in backup of sessions & routes. Off keeps everything on-device.',
                      style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              VSwitch(
                on: ref.watch(sessionSyncEnabledProvider),
                onTap: () => ref
                    .read(sessionSyncEnabledProvider.notifier)
                    .set(!ref.read(sessionSyncEnabledProvider)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          pad: 14,
          child: Row(
            children: [
              VyanaIcon('speaker', size: 19, color: t.green),
              const SizedBox(width: 13),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _previewVoiceCue(context, ref),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Voice cues',
                          style: VyanaType.label.copyWith(color: t.text)),
                      Text(
                        'Spoken guidance during sessions (splits, rest, breath). Tap to preview.',
                        style:
                            VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              VSwitch(
                on: ref.watch(voiceCuesEnabledProvider),
                onTap: () => ref
                    .read(voiceCuesEnabledProvider.notifier)
                    .set(!ref.read(voiceCuesEnabledProvider)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SettingsGroup(
          rows: [
            _SettingsRow(
              icon: 'info',
              label: 'About Vyana',
              onTap: () => openAbout(context, c),
            ),
            _SettingsRow(
              icon: 'shield',
              label: 'Privacy & sovereignty',
              onTap: () => openPrivacy(context),
            ),
          ],
        ),
      ],
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

  void _comingSoon(BuildContext context, String label) {
    showVyanaSnackBar(
      context,
      message: '$label is coming soon.',
      icon: 'info',
      success: true,
    );
  }

  Future<void> _confirmResetRing(BuildContext context, RingController c) async {
    final ringName = c.pairedRing?.displayName ?? 'your ring';
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Reset PRANA ring?',
      message:
          'This factory-resets $ringName — erasing settings and health records '
          'stored on the ring.\n\n'
          'Vyana will also remove pairing, cached vitals and history, health '
          'monitoring prefs, and the local sync log. Practice sessions, journal, '
          'and wallet data stay on your phone.\n\n'
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
              onPressed: () => unawaited(_confirmResetRing(context, c)),
            ),
    );

    if (result.success) {
      await openScanner(context, c);
    }
  }

  Future<void> _renameRing(BuildContext context, RingController c) async {
    final current = c.selectedDevice == null ? '' : deviceLabel(c.selectedDevice);
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
              Divider(height: 1, color: t.borderSoft, indent: 14, endIndent: 14),
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
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              VyanaIcon(icon, size: 19, color: t.textSec),
              const SizedBox(width: 13),
              Expanded(
                child: Text(label,
                    style: VyanaType.bodySm.copyWith(color: t.text)),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              VyanaIcon('chevR', size: 17, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
