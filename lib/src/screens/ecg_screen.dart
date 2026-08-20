part of '../../main.dart';

/// History of every ECG recording saved on this device. Tap a row to open the
/// full waveform + diagnosis. The raw samples behind each recording are the
/// input for a future A-Fib / V-Fib foundation-model analysis.
class EcgHistoryScreen extends ConsumerWidget {
  const EcgHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final service = ref.watch(ecgRecordServiceProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    IconBtn(
                      icon: 'chevL',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ECG',
                            style: VyanaType.eyebrow.copyWith(color: t.gold),
                          ),
                          Text(
                            'Recordings',
                            style: VyanaType.appBarSerif.copyWith(color: t.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<EcgRecordingRow>>(
                  stream: service.watch(),
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? const <EcgRecordingRow>[];
                    if (rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: EmptyState(
                          icon: Icons.monitor_heart,
                          text: 'No ECG recordings yet. Run a 60-second ECG '
                              'from the measurements screen — it will be saved '
                              'here automatically.',
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _EcgHistoryTile(row: rows[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcgHistoryTile extends StatelessWidget {
  const _EcgHistoryTile({required this.row});

  final EcgRecordingRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final afColor = row.afFlag ? t.gold : t.green;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => EcgDetailScreen(row: row)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: t.card,
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Icon(Icons.monitor_heart, color: afColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.interpretation ?? qrsTypeLabel(row.qrsType),
                      style: VyanaType.bodySm.copyWith(
                        color: t.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${timeLabel(row.capturedAt)}  ·  '
                      '${row.afFlag ? 'AF flagged' : 'No AF'}'
                      '${(row.heartRate ?? 0) != 0 ? '  ·  ${row.heartRate} bpm' : ''}',
                      style: VyanaType.bodySm.copyWith(color: t.textSec),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textSec),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the most-recently-saved recording's detail — the target of the
/// "Result" button on the ECG card. Streams so the row appears as soon as the
/// just-finished recording is persisted.
class EcgLatestResultScreen extends ConsumerWidget {
  const EcgLatestResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final service = ref.watch(ecgRecordServiceProvider);
    return StreamBuilder<List<EcgRecordingRow>>(
      stream: service.watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data;
        if (rows != null && rows.isNotEmpty) {
          return EcgDetailScreen(row: rows.first);
        }
        // No saved recording yet (still being written, or none run).
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: t.bgGradient),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: IconBtn(
                      icon: 'chevL',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: EmptyState(
                      icon: Icons.monitor_heart,
                      text: snapshot.connectionState == ConnectionState.waiting
                          ? 'Preparing your ECG result…'
                          : 'No ECG result yet. Run a 60-second ECG to see it '
                              'here.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full detail for one saved recording: waveform + diagnosis + metrics.
class EcgDetailScreen extends StatelessWidget {
  const EcgDetailScreen({super.key, required this.row});

  final EcgRecordingRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final samples = _decodeSamples(row.filteredSamplesJson);
    final display = samples.isNotEmpty
        ? samples
        : _decodeSamples(row.rawSamplesJson);
    final result = _resultFromRow(row);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(
                children: [
                  IconBtn(
                    icon: 'chevL',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ECG · ${timeLabel(row.capturedAt)}',
                          style: VyanaType.eyebrow.copyWith(color: t.gold),
                        ),
                        Text(
                          row.interpretation ?? qrsTypeLabel(row.qrsType),
                          style: VyanaType.appBarSerif.copyWith(color: t.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              EcgWaveformChart(
                samples: display,
                contactAttached: row.contactQuality == 'lost' ? false : null,
                emptyText: 'This recording has no stored waveform.',
              ),
              const SizedBox(height: 12),
              _EcgAfBanner(afFlag: row.afFlag),
              const SizedBox(height: 10),
              _EcgQrsExplainer(result: result),
              const SizedBox(height: 12),
              ecgMetricGrid([
                if ((row.heartRate ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'Heart rate',
                    value: _intMetric(row.heartRate, 'bpm'),
                    icon: Icons.favorite,
                    fill: true,
                  ),
                if ((row.hrv ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'HRV',
                    value: _doubleMetric(row.hrv, 'ms', decimals: 0),
                    icon: Icons.timeline,
                    fill: true,
                  ),
                if ((row.bloodPressure ?? '').isNotEmpty)
                  _EcgMetricTile(
                    label: 'Blood pressure',
                    value: row.bloodPressure!,
                    icon: Icons.speed,
                    fill: true,
                  ),
                if ((row.respiratoryRate ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'Breathing',
                    value: _intMetric(row.respiratoryRate, '/min'),
                    icon: Icons.air,
                    fill: true,
                  ),
                if ((row.pressure ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'Stress',
                    value: ecgStressLabel(row.pressure),
                    icon: Icons.psychology,
                    fill: true,
                  ),
                if ((row.heavyLoad ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'Body load',
                    value: _doubleMetric(row.heavyLoad, ''),
                    icon: Icons.fitness_center,
                    fill: true,
                  ),
                if ((row.body ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'Vitality',
                    value: _doubleMetric(row.body, ''),
                    icon: Icons.bolt,
                    fill: true,
                  ),
                if ((row.sympatheticActivityIndex ?? 0) != 0)
                  _EcgMetricTile(
                    label: 'Autonomic balance',
                    value: _doubleMetric(row.sympatheticActivityIndex, ''),
                    icon: Icons.balance,
                    fill: true,
                  ),
              ]),
              const SizedBox(height: 12),
              _EcgRecordingMeta(row: row),
              const SizedBox(height: 12),
              _EcgAiPlaceholder(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Capture metadata + storage stats for a saved recording.
class _EcgRecordingMeta extends StatelessWidget {
  const _EcgRecordingMeta({required this.row});

  final EcgRecordingRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final seconds = (row.durationMs / 1000).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.card,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recording',
            style: VyanaType.bodySm.copyWith(
              color: t.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${row.sampleCount} samples · ${seconds}s · '
            '${row.sampleRateHz} Hz · contact ${row.contactQuality ?? 'unknown'}',
            style: VyanaType.bodySm.copyWith(color: t.textSec),
          ),
        ],
      ),
    );
  }
}

/// Reserved slot for the future A-Fib / V-Fib foundation-model analysis.
class _EcgAiPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.elevated,
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: t.textSec),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI analysis coming soon. The full waveform is stored on this '
              'device, ready for A-Fib / V-Fib analysis by a foundation model.',
              style: VyanaType.bodySm.copyWith(color: t.textSec),
            ),
          ),
        ],
      ),
    );
  }
}

List<double> _decodeSamples(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return [for (final v in decoded) (v as num).toDouble()];
    }
  } on Object catch (_) {/* corrupt row */}
  return const [];
}

ParsedEcgResult _resultFromRow(EcgRecordingRow row) {
  return ParsedEcgResult(
    heartRate: row.heartRate,
    qrsType: row.qrsType,
    afFlag: row.afFlag,
    hrv: row.hrv,
    heavyLoad: row.heavyLoad,
    pressure: row.pressure,
    body: row.body,
    sympatheticActivityIndex: row.sympatheticActivityIndex,
    respiratoryRate: row.respiratoryRate,
    interpretation: row.interpretation ??
        ecgInterpretation(
          afFlag: row.afFlag,
          qrsType: row.qrsType,
          heartRate: row.heartRate,
          hrv: row.hrv,
        ),
  );
}
