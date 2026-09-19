part of '../../main.dart';

// ── Exports ─────────────────────────────────────────────────────────────────

/// Exported artefacts are account objects, so they live in You; Metrics and
/// Journal deep-link here with an `IN YOU` tag.
/// Which part of the exports screen to show; null shows everything.
enum ExportSection { health, journal, archive }

Future<void> openExports(
  BuildContext context,
  WidgetRef ref, {
  ExportSection? section,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ExportsScreen(section: section)),
  );
}

enum ExportRange { week, month, quarter, all }


extension on ExportRange {
  /// Compact, like Metrics' range control: 7D · 30D · 90D · ALL.
  String get label => switch (this) {
        ExportRange.week => '7D',
        ExportRange.month => '30D',
        ExportRange.quarter => '90D',
        ExportRange.all => 'ALL',
      };
  DateTime? get since => switch (this) {
        ExportRange.week => DateTime.now().subtract(const Duration(days: 7)),
        ExportRange.month => DateTime.now().subtract(const Duration(days: 30)),
        ExportRange.quarter => DateTime.now().subtract(const Duration(days: 90)),
        ExportRange.all => null,
      };
}

/// Your data — a health report over a date range, the journal, and a
/// machine-readable archive of everything. Files are written to Vyana's own
/// exports folder on this device; nothing leaves it unless you move it.
class ExportsScreen extends ConsumerStatefulWidget {
  const ExportsScreen({super.key, this.section});

  /// Limits the screen to one section when opened from a specific You row.
  final ExportSection? section;

  @override
  ConsumerState<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends ConsumerState<ExportsScreen> {
  ExportRange _range = ExportRange.month;

  bool _show(ExportSection s) => widget.section == null || widget.section == s;
  String? _busy;
  String? _lastPath;

  Future<void> _run(String label, Future<String> Function() job) async {
    setState(() => _busy = label);
    try {
      final path = await job();
      if (!mounted) return;
      setState(() => _lastPath = path);
      showVyanaSnackBar(
        context,
        message: 'Saved $label to your exports folder.',
        icon: 'check',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      showVyanaSnackBar(context, message: 'Could not export: $e', icon: 'alert');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ring = ref.read(ringControllerProvider);
    final db = ref.read(databaseProvider);
    final title = switch (widget.section) {
      ExportSection.health => 'Export health data',
      ExportSection.journal => 'Export your journal',
      ExportSection.archive => 'Export everything',
      null => 'Your data',
    };
    return _EditorScaffold(
      title: title,
      sub: 'You',
      ctaLabel: 'Done',
      ctaIcon: 'check',
      canSave: true,
      onSave: () => Navigator.of(context).pop(),
      children: [
        Text(
          'Everything here is written to Vyana\'s exports folder on this device. '
          'Nothing is uploaded.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
        const SizedBox(height: 16),
        // Wrap, not Row: at large text the control drops under the label
        // instead of squashing it.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          spacing: 12,
          children: [
            Text(
              'Period',
              style: VyanaType.label.copyWith(color: t.textSec),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: t.mutedInk.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in ExportRange.values)
                    InkWell(
                      onTap: () => setState(() => _range = r),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
                        decoration: BoxDecoration(
                          color: r == _range
                              ? t.heading.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontFamily: VyanaType.mono,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            fontWeight:
                                r == _range ? FontWeight.w700 : FontWeight.w400,
                            color: r == _range ? t.text : t.mutedInk,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_show(ExportSection.health))
        _ExportGroup(
          icon: 'activity',
          title: 'Health data',
          blurb: 'From your ring, for the period chosen above.',
          children: [
            _ExportOption(
              title: 'Summary',
              blurb: 'A row per day: readiness, sleep, HRV, resting HR, movement',
              tag: 'CSV',
              busy: _busy == 'summary',
              onTap: () => _run(
                'summary',
                () => exportHealthReport(
                  ring.history,
                  since: _range.since,
                  live: ring.vitals,
                ),
              ),
            ),
            _ExportOption(
              title: 'Every vital reading',
              blurb: 'Each HR, HRV, SpO₂, temperature, BP and glucose reading with its timestamp',
              tag: 'CSV',
              busy: _busy == 'vital readings',
              onTap: () => _run(
                'vital readings',
                () => exportVitalReadings(ring.history, since: _range.since),
              ),
            ),
            _ExportOption(
              title: 'Sleep nights',
              blurb: 'Per night: asleep time, deep / light / REM / awake, score',
              tag: 'CSV',
              busy: _busy == 'sleep nights',
              onTap: () => _run(
                'sleep nights',
                () => exportSleepNights(ring.history, since: _range.since),
              ),
            ),
            _ExportOption(
              title: 'ECG recordings',
              blurb: 'Full waveforms and the ring\'s classification for each recording',
              tag: 'JSON',
              busy: _busy == 'ecg',
              onTap: () => _run(
                'ecg',
                () => exportEcgRecordings(ref.read(ecgRecordServiceProvider), since: _range.since),
              ),
            ),
          ],
        ),
        if (_show(ExportSection.journal))
        _ExportGroup(
          icon: 'book',
          title: 'Journal',
          blurb: 'Your own words. Tags and Nova\'s reflections come along.',
          children: [
            _ExportOption(
              title: 'All entries',
              blurb: 'Dreams, reflections and ideas together',
              tag: 'JSON',
              busy: _busy == 'journal',
              onTap: () => _run(
                'journal',
                () => exportJournal(db, since: _range.since, includeMeals: false),
              ),
            ),
            for (final (type, label) in const [
              ('dream', 'Dreams'),
              ('reflection', 'Reflections'),
              ('idea', 'Ideas'),
            ])
              _ExportOption(
                title: label,
                blurb: 'Only ${label.toLowerCase()}',
                tag: 'JSON',
                busy: _busy == label.toLowerCase(),
                onTap: () => _run(
                  label.toLowerCase(),
                  () => exportJournal(db, since: _range.since, types: {type}, includeMeals: false),
                ),
              ),
            _ExportOption(
              title: 'Meals',
              blurb: 'Meal log with type, note and photo path',
              tag: 'JSON',
              busy: _busy == 'meals',
              onTap: () => _run(
                'meals',
                () => exportJournal(db, since: _range.since, types: const {}, includeMeals: true),
              ),
            ),
          ],
        ),
        if (_show(ExportSection.archive))
        _ExportRow(
          icon: 'db',
          title: 'Everything',
          blurb: 'One machine-readable archive: ring records, sessions, journal, meals, patterns.',
          busy: _busy == 'archive',
          onTap: () => _run(
            'archive',
            () => exportArchive(ring, db, since: _range.since),
          ),
        ),
        if (_lastPath != null) ...[
          const SizedBox(height: 14),
          Panel(
            pad: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoEyebrow('SAVED TO', size: 9),
                const SizedBox(height: 6),
                Text(
                  _lastPath!,
                  style: VyanaType.mono10.copyWith(color: t.textSec, height: 1.4),
                ),
                const SizedBox(height: 10),
                Cta(
                  label: 'Copy path',
                  icon: 'db',
                  solid: false,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: _lastPath!));
                    if (!context.mounted) return;
                    showVyanaSnackBar(context,
                        message: 'Path copied.', icon: 'check', success: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.busy,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String blurb;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        pad: 14,
        onTap: busy ? null : onTap,
        child: Row(
          children: [
            VyanaIconBadge(name: icon, color: t.heading),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: VyanaType.label.copyWith(color: t.text)),
                  const SizedBox(height: 3),
                  Text(
                    blurb,
                    style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : VyanaIcon('download', size: 18, color: t.mutedInk),
          ],
        ),
      ),
    );
  }
}

/// A card with a heading and indented sub-options, so "Daily report" reads
/// as a kind of health export, not a peer of "Everything".
class _ExportGroup extends StatelessWidget {
  const _ExportGroup({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.children,
  });

  final String icon;
  final String title;
  final String blurb;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        pad: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  VyanaIconBadge(name: icon, color: t.heading),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: VyanaType.label.copyWith(color: t.text)),
                        const SizedBox(height: 3),
                        Text(
                          blurb,
                          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: t.hairline, width: 2)),
                ),
                child: Column(children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.title,
    required this.blurb,
    required this.tag,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final String blurb;
  final String tag;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VyanaType.bodySm.copyWith(
                        color: t.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      blurb,
                      style: VyanaType.caption.copyWith(color: t.textSec, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              MonoEyebrow(tag, size: 11.5),
              const SizedBox(width: 6),
              busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : VyanaIcon('download', size: 17, color: t.mutedInk),
            ],
          ),
        ),
      ),
    );
  }
}

String _exportStamp() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
}

Future<File> _exportFile(String name) async {
  final dir = Directory(VyanaStorageService.instance.exportsPath);
  if (!await dir.exists()) await dir.create(recursive: true);
  return File(p.join(dir.path, name));
}

/// Per-day CSV: date, readiness, sleep hours, sleep score, HRV, resting HR,
/// steps, distance, calories.
Future<String> exportHealthReport(
  RingHistory history, {
  DateTime? since,
  RingVitals? live,
}) async {
  final hrvByDay = <DateTime, List<double>>{};
  for (final pt in vitalHistoryPoints(history, VitalsMetricKind.hrv)) {
    hrvByDay.putIfAbsent(DateTime(pt.time.year, pt.time.month, pt.time.day), () => [])
        .add(pt.value);
  }
  final hrByDay = <DateTime, List<double>>{};
  for (final pt in vitalHistoryPoints(history, VitalsMetricKind.heartRate)) {
    hrByDay.putIfAbsent(DateTime(pt.time.year, pt.time.month, pt.time.day), () => [])
        .add(pt.value);
  }
  final sleepByDay = {for (final d in sleepDaySummaries(history.sleep)) d.day: d};
  final stepsByDay = {for (final d in stepDaySummaries(history.steps)) d.day: d};
  final readiness = {
    for (final r in readinessSeries(history, 3650)) r.day: r.score,
  };
  // A fresh ring has live spot readings before it has any day records; fold
  // today's vitals in so the report is never header-only.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (live != null) {
    if (live.hrv != null && live.hrv! > 0) {
      hrvByDay.putIfAbsent(today, () => []).add(live.hrv!.toDouble());
    }
    if (live.heartRate != null && live.heartRate! > 0) {
      hrByDay.putIfAbsent(today, () => []).add(live.heartRate!.toDouble());
    }
  }
  final days = {...hrvByDay.keys, ...hrByDay.keys, ...sleepByDay.keys, ...stepsByDay.keys}
      .where((d) => since == null || !d.isBefore(since))
      .toList()
    ..sort();


  // One day = one record.
  final dayRows = <({
    DateTime day,
    int? readiness,
    double? sleepHours,
    int? sleepScore,
    double? hrv,
    double? hr,
    int? steps,
    int? distance,
    int? calories,
  })>[];
  double? meanD(List<double>? v) =>
      v == null || v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  for (final d in days) {
    final sleep = sleepByDay[d];
    final steps = stepsByDay[d];
    dayRows.add((
      day: d,
      readiness: readiness[d],
      sleepHours: sleep == null ? null : sleep.breakdown.asleepSeconds / 3600,
      sleepScore: sleep?.score,
      hrv: meanD(hrvByDay[d]),
      hr: meanD(hrByDay[d]),
      steps: steps?.steps ?? (d == today ? live?.steps : null),
      distance: steps?.distanceMeters ?? (d == today ? live?.distanceMeters : null),
      calories: steps?.calories ?? (d == today ? live?.calories : null),
    ));
  }

  String num_(num? v, [int digits = 0]) =>
      v == null ? '' : (digits == 0 ? '${v.round()}' : v.toStringAsFixed(digits));

  final buf = StringBuffer();
  buf.writeln('date,readiness,sleep_hours,sleep_score,hrv_ms,resting_hr_bpm,steps,distance_m,active_calories');
  for (final r in dayRows) {
    buf.writeln([
      _isoDay(r.day), num_(r.readiness), num_(r.sleepHours, 2), num_(r.sleepScore),
      num_(r.hrv), num_(r.hr), num_(r.steps), num_(r.distance), num_(r.calories),
    ].join(','));
  }
  final file = await _exportFile('vyana-health-summary-${_exportStamp()}.csv');
  await file.writeAsString(buf.toString());
  return file.path;
}

/// Journal export. [types] filters entries (`dream` | `reflection` | `idea`;
/// empty = none), [includeMeals] adds the meal log. The default is the whole
/// vault; the exports screen offers each kind on its own too.
String _isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Every plausible vital reading with its timestamp — the raw material behind
/// the daily report.
Future<String> exportVitalReadings(RingHistory history, {DateTime? since}) async {
  const kinds = [
    (VitalsMetricKind.heartRate, 'heart_rate', 'bpm'),
    (VitalsMetricKind.hrv, 'hrv', 'ms'),
    (VitalsMetricKind.spo2, 'spo2', '%'),
    (VitalsMetricKind.temperature, 'temperature', 'C'),
    (VitalsMetricKind.bloodPressure, 'blood_pressure_systolic', 'mmHg'),
    (VitalsMetricKind.glucose, 'glucose', 'mmol/L'),
    (VitalsMetricKind.stress, 'stress_index', 'idx'),
  ];
  final rows = <(DateTime, String, double, String)>[];
  for (final (kind, name, unit) in kinds) {
    for (final pt in vitalHistoryPoints(history, kind)) {
      if (since != null && pt.time.isBefore(since)) continue;
      rows.add((pt.time, name, pt.value, unit));
    }
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  final buf = StringBuffer('timestamp,metric,value,unit\n');
  for (final (time, name, value, unit) in rows) {
    buf.writeln('${time.toIso8601String()},$name,${value.toStringAsFixed(2)},$unit');
  }
  final file = await _exportFile('vyana-vital-readings-${_exportStamp()}.csv');
  await file.writeAsString(buf.toString());
  return file.path;
}

/// One row per night: how long you slept and how it broke down.
Future<String> exportSleepNights(RingHistory history, {DateTime? since}) async {
  final buf = StringBuffer(
    'night,asleep_hours,deep_min,light_min,rem_min,awake_min,score,window_start,window_end\n',
  );
  for (final n in sleepDaySummaries(history.sleep).reversed) {
    if (since != null && n.day.isBefore(since)) continue;
    final b = n.breakdown;
    buf.writeln([
      _isoDay(n.day),
      (b.asleepSeconds / 3600).toStringAsFixed(2),
      (b.deepSeconds / 60).round(),
      (b.lightSeconds / 60).round(),
      (b.remSeconds / 60).round(),
      (b.awakeSeconds / 60).round(),
      n.score,
      n.windowStart.toIso8601String(),
      n.windowEnd.toIso8601String(),
    ].join(','));
  }
  final file = await _exportFile('vyana-sleep-nights-${_exportStamp()}.csv');
  await file.writeAsString(buf.toString());
  return file.path;
}

/// Every ECG recording with its full waveform and the ring's classification.
Future<String> exportEcgRecordings(EcgRecordService ecg, {DateTime? since}) async {
  final all = await ecg.all();
  final items = <Map<String, dynamic>>[];
  for (final r in all) {
    if (since != null && r.capturedAt.isBefore(since)) continue;
    final payload = await ecg.exportSamples(r.id);
    if (payload != null) {
      payload['classification'] = ecgClassification(r);
      items.add(payload);
    }
  }
  final file = await _exportFile('vyana-ecg-${_exportStamp()}.json');
  await file.writeAsString(jsonEncode({
    'exportedAt': DateTime.now().toIso8601String(),
    'since': since?.toIso8601String(),
    'recordings': items,
  }));
  return file.path;
}

Future<String> exportJournal(
  VyanaDatabase db, {
  DateTime? since,
  Set<String> types = const {'dream', 'reflection', 'idea'},
  bool includeMeals = true,
}) async {
  final entries = types.isEmpty ? const <JournalEntryRow>[] : await db.allEntries();
  final meals = includeMeals ? await db.watchMeals().first : const <MealRow>[];
  final label = types.length == 3 && includeMeals
      ? 'journal'
      : types.isEmpty && includeMeals
          ? 'meals'
          : types.length == 1 && !includeMeals
              ? '${types.first}s'
              : 'journal-entries';
  final payload = {
    'exportedAt': DateTime.now().toIso8601String(),
    'since': since?.toIso8601String(),
    'kinds': [...types, if (includeMeals) 'meal'],
    'entries': [
      for (final e in entries)
        if (types.contains(e.type) && (since == null || e.createdAt.isAfter(since)))
          {
            'id': e.id,
            'type': e.type,
            'title': e.title,
            'body': e.body,
            'tags': splitTags(e.tags),
            'refined': e.refined,
            'reflection': e.reflection,
            'createdAt': e.createdAt.toIso8601String(),
          },
    ],
    'meals': [
      for (final m in meals)
        if (since == null || m.createdAt.isAfter(since))
          {
            'id': m.id,
            'label': m.label,
            'note': m.note,
            'mealType': m.mealType,
            'photoPath': m.photoPath,
            'createdAt': m.createdAt.toIso8601String(),
          },
    ],
  };
  final file = await _exportFile('vyana-$label-${_exportStamp()}.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  return file.path;
}

Future<String> exportArchive(
  RingController ring,
  VyanaDatabase db, {
  DateTime? since,
}) async {
  final sessions = await db.recentSessions(limit: 5000);
  final patterns = await db.allPatterns();
  final journalPath = await exportJournal(db, since: since);
  final journal = jsonDecode(await File(journalPath).readAsString());
  await File(journalPath).delete();
  final payload = {
    'exportedAt': DateTime.now().toIso8601String(),
    'since': since?.toIso8601String(),
    'ring': buildCloudHistoryBatch(
      device: ring.selectedDevice ?? ring.pairedRing?.toDeviceMap(),
      basicInfo: ring.basicInfo,
      features: ring.features,
      history: ring.history,
    ),
    'sessions': [
      for (final s in sessions)
        if (since == null || s.startedAt.isAfter(since))
          {
            'id': s.id,
            'category': s.category,
            'activity': s.vyanaActivityType,
            'startedAt': s.startedAt.toIso8601String(),
            'endedAt': s.endedAt?.toIso8601String(),
            'summary': s.summaryJson == null ? null : jsonDecode(s.summaryJson!),
          },
    ],
    'journal': journal,
    'patterns': [
      for (final pt in patterns)
        {
          'id': pt.id,
          'source': pt.source,
          'subject': pt.subject,
          'claim': pt.claim,
          'status': pt.status,
          'evidenceIds': patternEvidenceIds(pt),
          'firstSeen': pt.firstSeen.toIso8601String(),
          'lastConfirmed': pt.lastConfirmed.toIso8601String(),
          'endedAt': pt.endedAt?.toIso8601String(),
        },
    ],
  };
  final file = await _exportFile('vyana-archive-${_exportStamp()}.json');
  await file.writeAsString(jsonEncode(payload));
  return file.path;
}

// ── Notifications ───────────────────────────────────────────────────────────

Future<void> openNotificationSettings(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
  );
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final prefs = ref.watch(notificationPrefsProvider);
    final ctl = ref.read(notificationPrefsProvider.notifier);
    return _EditorScaffold(
      title: 'Notifications',
      sub: 'You',
      ctaLabel: 'Done',
      ctaIcon: 'check',
      canSave: true,
      onSave: () => Navigator.of(context).pop(),
      children: [
        Text(
          'Vyana pushes only when it cannot tell you later. A missing ring is '
          'urgent because data is being lost right now; a readiness score is '
          'not, because it will still be here when you open the app.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
        const SizedBox(height: 16),
        _NotifyRow(
          title: 'Ring & data',
          blurb: 'Ring offline, not synced in 24 hours, battery low — once, at 15%.',
          on: prefs.ringAndData,
          onTap: () => ctl.setRingAndData(!prefs.ringAndData),
        ),
        _NotifyRow(
          title: 'Health alerts',
          blurb: 'Resting heart rate well outside your band, or a blood-oxygen drop.',
          on: prefs.healthAlerts,
          onTap: () => ctl.setHealthAlerts(!prefs.healthAlerts),
        ),
        _NotifyRow(
          title: 'Nudges',
          blurb: 'Sleep summary ready, practice reminders, a streak about to break. Off by default.',
          on: prefs.nudges,
          onTap: () => ctl.setNudges(!prefs.nudges),
        ),
        const SizedBox(height: 8),
        Text(
          'If the system permission is denied these stay in-app: the stale-ring '
          'banner on Home and Metrics is the guaranteed channel; push is the escalation.',
          style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.45),
        ),
      ],
    );
  }
}

class _NotifyRow extends StatelessWidget {
  const _NotifyRow({
    required this.title,
    required this.blurb,
    required this.on,
    required this.onTap,
  });

  final String title;
  final String blurb;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        pad: 14,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: VyanaType.label.copyWith(color: t.text)),
                  const SizedBox(height: 3),
                  Text(
                    blurb,
                    style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            VSwitch(on: on, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

// ── Nova footprint ──────────────────────────────────────────────────────────

Future<void> openNovaFootprint(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const NovaFootprintScreen()),
  );
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1000) return '${(mb / 1024).toStringAsFixed(2)} GB';
  return '${mb.round()} MB';
}

/// Nova appears on every screen and is a multi-GB on-device model; You is the
/// one place "what is this costing me" is a fair question.
class NovaFootprintScreen extends ConsumerStatefulWidget {
  const NovaFootprintScreen({super.key});

  @override
  ConsumerState<NovaFootprintScreen> createState() => _NovaFootprintScreenState();
}

class _NovaFootprintScreenState extends ConsumerState<NovaFootprintScreen> {
  GuideStorageSnapshot? _storage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final snap = await ref.read(guideModelManagerProvider).loadStorageSnapshot();
    if (mounted) setState(() => _storage = snap);
  }

  Future<void> _remove() async {
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Remove Nova from this phone?',
      message: 'This deletes the on-device model. Nova can be installed again '
          'from the guide pill at any time; your journal and vitals are untouched.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await ref.read(guideModelManagerProvider).deleteModel(GuideKind.nova);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final manager = ref.watch(guideModelManagerProvider);
    final definition = guidePersonaDefinitions[GuideKind.nova]!;
    final state = manager.stateFor(GuideKind.nova);
    final s = _storage;
    return _EditorScaffold(
      title: 'Nova',
      sub: 'Private AI guide',
      ctaLabel: state.isReady ? 'Remove from this phone' : 'Install Nova',
      ctaIcon: state.isReady ? 'x' : 'download',
      canSave: state.status != GuideModelStatus.downloading,
      onSave: state.isReady ? _remove : () => openGuideStore(context),
      children: [
        _KV('STATUS', state.statusLabel),
        _KV('MODEL', definition.modelLabel),
        _KV('FILE', guideInstalledModelFileName(definition)),
        _KV('ON DISK', s == null ? '…' : formatBytes(s.guideModelBytes)),
        _KV('VOICE (VANI)', s == null ? '…' : formatBytes(s.voiceBytes + s.whisperModelBytes)),
        _KV('TOTAL', s == null ? '…' : formatBytes(s.totalBytes)),
        const SizedBox(height: 10),
        Text(
          'One model, one assistant. Nova runs entirely on this phone — every '
          'reflection, every pattern, every chat stays here.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: MonoEyebrow(k, size: 9)),
          Expanded(
            child: Text(
              v,
              style: VyanaType.caption.copyWith(color: t.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Training frequency (resting-HR band) ────────────────────────────────────

/// Asked as behaviour, never identity: people answer frequency reliably and
/// identity badly. Three options, because the bands overlap and a finer scale
/// implies precision the mapping does not have.
Future<void> showTrainingFrequencySheet(BuildContext context, WidgetRef ref) {
  final t = context.vyana;
  final profile = ref.read(userProfileProvider).valueOrNull ?? const UserProfile();
  final current = TrainingFrequencyX.fromName(profile.trainingFrequency);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Panel(
        pad: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoEyebrow('RESTING HEART RATE', size: 9),
            const SizedBox(height: 6),
            Text(
              'How often do you train?',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 21),
            ),
            const SizedBox(height: 6),
            Text(
              'Sets the band Metrics judges your resting heart rate against. '
              'Unanswered uses the clinical 60–100.',
              style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
            ),
            const SizedBox(height: 14),
            for (final f in TrainingFrequency.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  pad: 13,
                  onTap: () async {
                    await ref.read(userProfileProvider.notifier).save(
                          profile.copyWith(trainingFrequency: f.name),
                        );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.label,
                          style: VyanaType.label.copyWith(
                            color: current == f ? t.green : t.text,
                          ),
                        ),
                      ),
                      MonoEyebrow('${f.bandLabel} BPM', size: 9),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
