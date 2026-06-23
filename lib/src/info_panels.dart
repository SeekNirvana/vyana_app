part of '../main.dart';

const _kSeekNirvanaUrl = 'https://seeknirvana.com';

Future<void> _openSeekNirvanaSite(BuildContext context) async {
  final uri = Uri.parse(_kSeekNirvanaUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    showVyanaSnackBar(
      context,
      message: 'Could not open seeknirvana.com',
      icon: 'alert',
    );
  }
}

class _InfoScreenHeader extends StatelessWidget {
  const _InfoScreenHeader({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow.toUpperCase(),
                  style: VyanaType.eyebrow.copyWith(color: t.gold)),
              Text(title,
                  style: VyanaType.appBarSerif.copyWith(color: t.text)),
            ],
          ),
        ),
      ],
    );
  }
}

class AppAboutScreen extends StatefulWidget {
  const AppAboutScreen({required this.features, super.key});

  final DeviceFeatureSnapshot? features;

  @override
  State<AppAboutScreen> createState() => _AppAboutScreenState();
}

class _AppAboutScreenState extends State<AppAboutScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              const _InfoScreenHeader(eyebrow: 'SeekNirvana', title: 'About Vyana'),
              const SizedBox(height: 14),
              Panel(
                grad: true,
                pad: 22,
                child: Column(
                  children: [
                    const Seal(size: 72, glow: true),
                    const SizedBox(height: 16),
                    Text('Vyana App',
                        style: VyanaType.titleSerif.copyWith(
                            color: t.text, fontSize: 28)),
                    const SizedBox(height: 6),
                    Text('Your wellness operating system',
                        style: VyanaType.bodySm.copyWith(color: t.textSec)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join the mission',
                        style: VyanaType.label.copyWith(
                            color: t.text, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(
                      'Most wearables lock your biometrics in someone else\'s cloud. '
                      'Vyana is different — your signals, your AI, your guidance, '
                      'all under your rules. We built this for people who want to '
                      'feel better without giving away the story their body tells.',
                      style: VyanaType.bodySm
                          .copyWith(color: t.textSec, height: 1.55),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sense your rhythm. Understand the pattern. Practice with '
                      'intention — one breath, one session, one kinder day at a time.',
                      style: VyanaType.bodySm
                          .copyWith(color: t.textSec, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionHead(eyebrow: 'Our ethos', title: 'Own your wellness'),
              Panel(
                child: Column(
                  children: [
                    _EthosPillar(
                      step: '01',
                      title: 'Your data',
                      body:
                          'Ring biometrics and practice history stay on your device. '
                          'Exportable when you need them — never a platform-owned dataset.',
                      icon: 'shield',
                      accent: t.vit('hr'),
                    ),
                    const SizedBox(height: 12),
                    _EthosPillar(
                      step: '02',
                      title: 'Private AI',
                      body:
                          'Guides and interpretation run on your phone. Nothing is sent '
                          'to surveillance analytics in someone else\'s cloud.',
                      icon: 'sparkles',
                      accent: t.vit('breath'),
                    ),
                    const SizedBox(height: 12),
                    _EthosPillar(
                      step: '03',
                      title: 'Human guidance',
                      body:
                          'Experts and programs you choose, connected to the daily '
                          'context from your own signals — not an algorithm deciding for you.',
                      icon: 'lotus',
                      accent: t.vit('sleep'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Cta(
                label: 'Explore SeekNirvana',
                icon: 'arrowR',
                onTap: () => _openSeekNirvanaSite(context),
              ),
              const SizedBox(height: 22),
              const SectionHead(eyebrow: 'Hardware', title: 'Ring capabilities'),
              FeaturePanel(features: widget.features),
              const SizedBox(height: 18),
              FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final versionText = snapshot.hasData
                      ? 'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : null;
                  if (versionText == null) return const SizedBox.shrink();
                  return Center(
                    child: Text(versionText,
                        style: VyanaType.caption.copyWith(color: t.textMuted)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EthosPillar extends StatelessWidget {
  const _EthosPillar({
    required this.step,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String step;
  final String title;
  final String body;
  final String icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withValues(alpha: t.isDark ? 0.18 : 0.12),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Center(child: VyanaIcon(icon, size: 18, color: accent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$step · $title',
                  style: VyanaType.label.copyWith(
                      color: t.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(body,
                  style: VyanaType.bodySm
                      .copyWith(color: t.textSec, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}

class AppPrivacyScreen extends StatelessWidget {
  const AppPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              const _InfoScreenHeader(
                eyebrow: 'Sovereignty',
                title: 'Privacy & sovereignty',
              ),
              const SizedBox(height: 14),
              Panel(
                grad: true,
                pad: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: t.green.withValues(alpha: t.isDark ? 0.2 : 0.13),
                          ),
                          child: Center(
                              child: VyanaIcon('shield', size: 20, color: t.green)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Your body, your rules',
                              style: VyanaType.titleSerif.copyWith(
                                  color: t.text, fontSize: 22)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vyana is built on data sovereignty. We do not collect, sell, '
                      'or profile you. This is a plain-language summary of how your '
                      'information is handled.',
                      style: VyanaType.bodySm
                          .copyWith(color: t.textSec, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _PrivacySection(
                title: 'What we do not collect',
                body:
                    'Vyana does not require an account for core use. We do not upload '
                    'your ring biometrics, journal entries, session recordings, or '
                    'on-device AI conversations to SeekNirvana servers. There is no '
                    'hidden analytics pipeline watching how you practice.',
                bullets: const [
                  'No sale of personal or health data',
                  'No advertising identifiers or cross-app tracking',
                  'No cloud account needed to breathe, move, or sync your ring',
                ],
              ),
              _PrivacySection(
                title: 'What stays on your phone',
                body:
                    'Your wellness story lives locally — in the vault on your device.',
                bullets: const [
                  'Practice sessions, routes, and journal notes',
                  'Ring history pulled from your PRANA device',
                  'On-device AI guides and voice models you choose to download',
                  'Theme, profile, and app preferences',
                ],
              ),
              _PrivacySection(
                title: 'Optional connections you control',
                body:
                    'Some features reach outward only when you turn them on:',
                bullets: const [
                  'Wallet linking — only if you connect Solana or Reown; keys stay with your wallet app',
                  'Weather on ring — only if you enable weather push to the device',
                  'Android notification forwarding — local listener access; not sent to our servers',
                  'Ring firmware updates — uses the manufacturer SDK path you initiate',
                ],
              ),
              _PrivacySection(
                title: 'Your rights',
                body: 'You remain in charge at every step.',
                bullets: const [
                  'Uninstalling removes local Vyana data from your phone',
                  'Disconnect or unpair your ring at any time',
                  'Wallet connections can be revoked in the wallet app',
                  'Future cloud sync, if offered, will be opt-in with clear export and delete controls',
                ],
              ),
              const SizedBox(height: 6),
              Panel(
                onTap: () => _openSeekNirvanaSite(context),
                child: Row(
                  children: [
                    VyanaIcon('arrowR', size: 18, color: t.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Questions or feedback',
                              style: VyanaType.label.copyWith(
                                  color: t.text, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('seeknirvana.com',
                              style: VyanaType.caption.copyWith(color: t.green)),
                        ],
                      ),
                    ),
                    VyanaIcon('chevR', size: 16, color: t.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Last updated June 2026',
                  style: VyanaType.caption.copyWith(color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.title,
    required this.body,
    required this.bullets,
  });

  final String title;
  final String body;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: VyanaType.label
                    .copyWith(color: t.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body,
                style: VyanaType.bodySm
                    .copyWith(color: t.textSec, height: 1.45)),
            const SizedBox(height: 10),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: t.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(bullet,
                        style: VyanaType.bodySm
                            .copyWith(color: t.textSec, height: 1.45)),
                  ),
                ],
              ),
              if (bullet != bullets.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class FeaturePanel extends StatelessWidget {
  const FeaturePanel({required this.features, super.key});

  final DeviceFeatureSnapshot? features;

  @override
  Widget build(BuildContext context) {
    final feature = features;
    final capabilities = feature == null
        ? const <_RingCapability>[]
        : _ringCapabilities(feature);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feature == null)
            const EmptyState(
              icon: Icons.fact_check,
              text: 'Connect and sync your ring to see supported sensors.',
            )
          else if (capabilities.isEmpty)
            const EmptyState(
              icon: Icons.fact_check,
              text: 'No supported feature flags were reported by this ring.',
            )
          else
            _CapabilityGrid(capabilities: capabilities),
        ],
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid({required this.capabilities});

  final List<_RingCapability> capabilities;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: capabilities
              .map(
                (capability) => SizedBox(
                  width: width,
                  child: _CapabilityCard(capability: capability),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final _RingCapability capability;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      height: 88,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.card,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: t.green.withValues(alpha: t.isDark ? 0.2 : 0.13),
            ),
            child: Icon(
              capability.icon,
              size: 20,
              color: t.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capability.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  capability.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingCapability {
  const _RingCapability({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

List<_RingCapability> _ringCapabilities(DeviceFeatureSnapshot feature) {
  final items = <_RingCapability>[];

  void addIf(bool supported, String title, String subtitle, IconData icon) {
    if (!supported) return;
    items.add(_RingCapability(title: title, subtitle: subtitle, icon: icon));
  }

  addIf(
    feature.supportsAny(const [
      'isSupportHeartRate',
      'isSupportStartHeartRateMeasurement',
    ]),
    'Heart rate',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportHeartRate',
      testKey: 'isSupportStartHeartRateMeasurement',
    ),
    Icons.favorite,
  );
  addIf(
    feature.supportsAny(const [
      'isSupportBloodOxygen',
      'isSupportStartBloodOxygenMeasurement',
    ]),
    'SpO2',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportBloodOxygen',
      testKey: 'isSupportStartBloodOxygenMeasurement',
    ),
    Icons.bloodtype,
  );
  addIf(
    feature.supportsAny(const [
      'isSupportBloodPressure',
      'isSupportStartBloodPressureMeasurement',
    ]),
    'Blood pressure',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportBloodPressure',
      testKey: 'isSupportStartBloodPressureMeasurement',
    ),
    Icons.speed,
  );
  addIf(
    feature.supportsAny(const [
      'isSupportTemperature',
      'isSupportStartBodyTemperatureMeasurement',
    ]),
    'Temperature',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportTemperature',
      testKey: 'isSupportStartBodyTemperatureMeasurement',
    ),
    Icons.thermostat,
  );
  addIf(
    feature.supportsAny(const ['isSupportHRV', 'isSupportStartHRVMeasurement']),
    'HRV',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportHRV',
      testKey: 'isSupportStartHRVMeasurement',
    ),
    Icons.timeline,
  );
  addIf(
    feature.supportsAny(const [
      'isSupportPressure',
      'isSupportStartPressureMeasurement',
    ]),
    'Stress',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportPressure',
      testKey: 'isSupportStartPressureMeasurement',
    ),
    Icons.psychology,
  );
  addIf(
    feature.supportsAny(const [
      'isSupportBloodGlucose',
      'isSupportStartBloodGlucoseMeasurement',
    ]),
    'Glucose',
    _historyTestSubtitle(
      feature,
      historyKey: 'isSupportBloodGlucose',
      testKey: 'isSupportStartBloodGlucoseMeasurement',
    ),
    Icons.water_drop,
  );
  addIf(
    feature.supports('isSupportSleep'),
    'Sleep stages',
    'Deep, light, REM, awake',
    Icons.bedtime,
  );
  addIf(
    feature.supports('isSupportStep'),
    'Steps',
    'Daily activity history',
    Icons.directions_walk,
  );
  addIf(
    feature.supports('isSupportSport'),
    'Sport sessions',
    'Workout history',
    Icons.fitness_center,
  );
  addIf(
    feature.supports('isSupportUricAcid'),
    'Uric acid',
    'Biomarker history',
    Icons.science,
  );
  addIf(
    feature.supports('isSupportBloodKetone'),
    'Blood ketone',
    'Biomarker history',
    Icons.opacity,
  );
  addIf(
    feature.supports('isSupportBloodFat'),
    'Blood lipids',
    'Cholesterol panel history',
    Icons.biotech,
  );
  addIf(
    feature.supportsAny(const [
      'isSupportRealTimeECG',
      'isSupportHistoricalECG',
      'isSupportECGDiagnosis',
    ]),
    'ECG',
    _ecgSubtitle(feature),
    Icons.monitor_heart,
  );
  addIf(
    feature.supports('isSupportRealTimeDataUpload'),
    'Live stream',
    'Realtime SDK upload',
    Icons.sensors,
  );
  addIf(
    feature.supports('isSupportHeartRateAlarm'),
    'Health alarms',
    'Heart-rate alerts',
    Icons.notifications_active,
  );
  addIf(
    feature.supports('isSupportFindDevice'),
    'Find ring',
    'Ring locator command',
    Icons.ring_volume,
  );
  addIf(
    feature.supports('isSupportAntiLostReminder'),
    'Anti-lost',
    'Disconnect reminder',
    Icons.link,
  );
  addIf(
    feature.supports('isSupportOta'),
    'Firmware update',
    'OTA capable',
    Icons.system_update_alt,
  );
  addIf(
    feature.supports('isSupportVo2max'),
    'VO2 max',
    'Fitness estimate',
    Icons.show_chart,
  );

  return items;
}

String _historyTestSubtitle(
  DeviceFeatureSnapshot feature, {
  required String historyKey,
  required String testKey,
}) {
  final history = feature.supports(historyKey);
  final test = feature.supports(testKey);
  if (history && test) return 'History + on-demand test';
  if (test) return 'On-demand test';
  return 'History records';
}

String _ecgSubtitle(DeviceFeatureSnapshot feature) {
  final modes = <String>[
    if (feature.supports('isSupportRealTimeECG')) 'live',
    if (feature.supports('isSupportHistoricalECG')) 'history',
    if (feature.supports('isSupportECGDiagnosis')) 'analysis',
  ];
  if (modes.isEmpty) return 'Supported';
  return modes.join(' + ');
}

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({required this.history, super.key});

  final RingHistory history;

  @override
  Widget build(BuildContext context) {
    final rows = [
      HistoryRow(
        'Step history',
        history.steps.length,
        latestByTimestamp(history.steps),
      ),
      HistoryRow(
        'Sleep sessions',
        history.sleep.length,
        latestByTimestamp(history.sleep),
      ),
      HistoryRow(
        'Heart rate',
        history.heartRate.length,
        latestByTimestamp(history.heartRate),
      ),
      HistoryRow(
        'Blood pressure',
        history.bloodPressure.length,
        latestByTimestamp(history.bloodPressure),
      ),
      HistoryRow(
        'Combined vitals',
        history.combined.length,
        latestByTimestamp(history.combined),
      ),
      HistoryRow(
        'Biomarkers',
        history.invasive.length,
        latestByTimestamp(history.invasive),
      ),
      HistoryRow(
        'Sport sessions',
        history.sport.length,
        latestByTimestamp(history.sport),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'History Pull',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The SDK returns historical records from the ring. Sleep is derived from ring-provided stages and durations here, without a cloud call.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...rows.map((row) => HistoryListTile(row: row)),
          ],
        ),
      ),
    );
  }
}

class HistoryRow {
  const HistoryRow(this.label, this.count, this.latest);

  final String label;
  final int count;
  final dynamic latest;
}

class HistoryListTile extends StatelessWidget {
  const HistoryListTile({required this.row, super.key});

  final HistoryRow row;

  @override
  Widget build(BuildContext context) {
    final ts = timestampOf(row.latest);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(row.label),
      subtitle: Text(
        ts == null
            ? 'No records'
            : 'Latest ${timeLabel(DateTime.fromMillisecondsSinceEpoch(ts * 1000))}',
      ),
      trailing: Text('${row.count}'),
    );
  }
}

class ExternalServicesPanel extends StatelessWidget {
  const ExternalServicesPanel({super.key});

  final List<String> items = const [
    'No third-party server is required for detection, connection, vitals sync, or sleep summaries in this app.',
    'Weather push needs an external weather feed only if you choose to send today/tomorrow weather to the ring.',
    'Android notification forwarding requires local notification-listener access; it does not need a vendor server.',
    'OTA/DFU uses the SDK service path; firmware package hosting should be self-hosted before production.',
    'Sleep is calculated locally from ring records: deep, light, REM, awake, and duration fields supplied by the SDK.',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Third-party and Sovereignty Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 20),
                    const SizedBox(width: 4),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryLogStatus {
  const HistoryLogStatus({
    required this.path,
    required this.batchCount,
    required this.recordCount,
    required this.lastBatchRecordCount,
    required this.lastLoggedAt,
  });

  final String path;
  final int batchCount;
  final int recordCount;
  final int lastBatchRecordCount;
  final DateTime? lastLoggedAt;

  factory HistoryLogStatus.empty() => const HistoryLogStatus(
    path: 'Not initialized',
    batchCount: 0,
    recordCount: 0,
    lastBatchRecordCount: 0,
    lastLoggedAt: null,
  );
}

class HistorySyncLogger {
  Future<HistoryLogStatus> appendSync({
    required dynamic device,
    required DeviceBasicSnapshot? basicInfo,
    required DeviceFeatureSnapshot? features,
    required RingHistory history,
  }) async {
    final file = await _logFile();
    final batch = buildCloudHistoryBatch(
      device: device,
      basicInfo: basicInfo,
      features: features,
      history: history,
    );
    await file.writeAsString('${jsonEncode(batch)}\n', mode: FileMode.append);
    return status();
  }

  Future<void> clear() async {
    final file = await _logFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<HistoryLogStatus> status() async {
    final file = await _logFile();
    if (!await file.exists()) {
      return HistoryLogStatus(
        path: file.path,
        batchCount: 0,
        recordCount: 0,
        lastBatchRecordCount: 0,
        lastLoggedAt: null,
      );
    }

    final lines = await file.readAsLines();
    var batchCount = 0;
    var recordCount = 0;
    var lastBatchRecordCount = 0;
    DateTime? lastLoggedAt;

    for (final line in lines.where((line) => line.trim().isNotEmpty)) {
      try {
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        batchCount += 1;
        final batchRecords =
            readInt(decoded['summary'], const ['totalRecords']) ?? 0;
        recordCount += batchRecords;
        lastBatchRecordCount = batchRecords;
        final pulledAt = decoded['sync'] is Map
            ? decoded['sync']['pulledAt']?.toString()
            : null;
        lastLoggedAt = pulledAt == null ? null : DateTime.tryParse(pulledAt);
      } on Object {
        continue;
      }
    }

    return HistoryLogStatus(
      path: file.path,
      batchCount: batchCount,
      recordCount: recordCount,
      lastBatchRecordCount: lastBatchRecordCount,
      lastLoggedAt: lastLoggedAt,
    );
  }

  Future<File> _logFile() async {
    final directory = _logDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/vyana_ring_history_sync.jsonl');
  }

  Directory _logDirectory() {
    if (Platform.isAndroid) {
      return Directory('/data/user/0/com.seeknirvana.vyana/files');
    }
    if (Platform.isIOS) {
      return Directory('${Directory.systemTemp.parent.path}/Documents');
    }
    return Directory('${Directory.current.path}/.vyana');
  }
}

class HistoryLogScreen extends StatelessWidget {
  const HistoryLogScreen({
    required this.history,
    required this.status,
    super.key,
  });

  final RingHistory history;
  final HistoryLogStatus status;

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final schema = encoder.convert(cloudHistorySchemaExample());

    return Scaffold(
      appBar: AppBar(title: const Text('Historical Data Log')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Sync Log',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every successful sync appends one JSON line with the SDK batch, normalized records, device identity, feature flags, and raw SDK values needed for later analysis.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SmallMetric(
                          label: 'Batches',
                          value: '${status.batchCount}',
                        ),
                        SmallMetric(
                          label: 'Logged records',
                          value: '${status.recordCount}',
                        ),
                        SmallMetric(
                          label: 'Last batch',
                          value: '${status.lastBatchRecordCount}',
                        ),
                        SmallMetric(
                          label: 'Last log',
                          value: status.lastLoggedAt == null
                              ? '-'
                              : timeLabel(status.lastLoggedAt!.toLocal()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('File', style: Theme.of(context).textTheme.labelSmall),
                    SelectableText(
                      status.path,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            HistoryPanel(history: history),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud Document Shape',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use this as the first backend collection shape: one immutable sync batch document, with typed records inside it. A cloud worker can later fan records into query-optimized tables.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: context.vyana.elevated,
                        border: Border.all(color: context.vyana.border),
                      ),
                      child: SelectableText(
                        schema,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.vyana.greenLight,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventLogPanel extends StatelessWidget {
  const EventLogPanel({required this.events, super.key});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Event Log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const EmptyState(
                icon: Icons.sensors,
                text:
                    'Bluetooth state and real-time vitals events will appear here.',
              )
            else
              ...events
                  .take(8)
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        event,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.card,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: t.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: VyanaType.bodySm.copyWith(color: t.textSec)),
          ),
        ],
      ),
    );
  }
}

class SmallMetric extends StatelessWidget {
  const SmallMetric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: t.card,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
