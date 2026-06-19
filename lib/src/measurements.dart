part of '../main.dart';

class MeasurementPageSnapshot {
  const MeasurementPageSnapshot({
    required this.connected,
    required this.busy,
    required this.activeMeasurement,
    required this.status,
    required this.ecgResult,
    required this.ecgSession,
    required this.features,
    required this.history,
    required this.vitals,
  });

  final bool connected;
  final bool busy;
  final String? activeMeasurement;
  final String status;
  final ParsedEcgResult? ecgResult;
  final EcgSessionSnapshot ecgSession;
  final DeviceFeatureSnapshot? features;
  final RingHistory history;
  final RingVitals vitals;
}

class MeasurementSeriesPoint {
  const MeasurementSeriesPoint({
    required this.time,
    required this.value,
    required this.label,
    this.live = false,
  });

  final DateTime time;
  final double value;
  final String label;
  final bool live;
}

class MeasurementSeries {
  const MeasurementSeries({
    required this.points,
    required this.latestText,
    required this.unit,
  });

  final List<MeasurementSeriesPoint> points;
  final String latestText;
  final String unit;
}

class MeasurementAction {
  const MeasurementAction(this.label, this.type, this.icon, this.featureKeys);

  final String label;
  final DeviceAppControlMeasureHealthDataType type;
  final IconData icon;
  final List<String> featureKeys;
}

const realtimeMeasurementActions = [
  MeasurementAction(
    'Heart rate',
    DeviceAppControlMeasureHealthDataType.heartRate,
    Icons.favorite,
    ['isSupportStartHeartRateMeasurement', 'isSupportHeartRate'],
  ),
  MeasurementAction(
    'SpO2',
    DeviceAppControlMeasureHealthDataType.bloodOxygen,
    Icons.bloodtype,
    ['isSupportStartBloodOxygenMeasurement', 'isSupportBloodOxygen'],
  ),
  MeasurementAction(
    'Blood pressure',
    DeviceAppControlMeasureHealthDataType.bloodPressure,
    Icons.speed,
    ['isSupportStartBloodPressureMeasurement', 'isSupportBloodPressure'],
  ),
  MeasurementAction(
    'Temperature',
    DeviceAppControlMeasureHealthDataType.bodyTemperature,
    Icons.thermostat,
    ['isSupportStartBodyTemperatureMeasurement', 'isSupportTemperature'],
  ),
  MeasurementAction(
    'HRV',
    DeviceAppControlMeasureHealthDataType.hrv,
    Icons.timeline,
    ['isSupportStartHRVMeasurement', 'isSupportHRV'],
  ),
  MeasurementAction(
    'Pressure',
    DeviceAppControlMeasureHealthDataType.pressure,
    Icons.psychology,
    ['isSupportStartPressureMeasurement', 'isSupportPressure'],
  ),
  MeasurementAction(
    'Glucose',
    DeviceAppControlMeasureHealthDataType.bloodGlucose,
    Icons.water_drop,
    ['isSupportStartBloodGlucoseMeasurement', 'isSupportBloodGlucose'],
  ),
];

class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({
    required this.snapshotListenable,
    required this.onMeasure,
    required this.onStartEcg,
    required this.onStopEcg,
    required this.onGetEcgResult,
    required this.onSync,
    super.key,
  });

  final ValueListenable<MeasurementPageSnapshot> snapshotListenable;
  final Future<void> Function(MeasurementAction action) onMeasure;
  final Future<void> Function() onStartEcg;
  final Future<void> Function() onStopEcg;
  final Future<void> Function() onGetEcgResult;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MeasurementPageSnapshot>(
      valueListenable: snapshotListenable,
      builder: (context, snapshot, _) {
        final feature = snapshot.features;
        final supportedActions = feature == null
            ? const <MeasurementAction>[]
            : realtimeMeasurementActions
                  .where((action) => feature.supportsAny(action.featureKeys))
                  .toList();
        final supportsEcg =
            feature?.supportsAny(const [
              'isSupportRealTimeECG',
              'isSupportHistoricalECG',
              'isSupportECGDiagnosis',
            ]) ??
            false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Measurements'),
            actions: [
              IconButton(
                tooltip: 'Sync records',
                onPressed: snapshot.connected ? onSync : null,
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _MeasurementStatusCard(snapshot: snapshot),
                const SizedBox(height: 16),
                if (feature == null)
                  const EmptyState(
                    icon: Icons.monitor_heart,
                    text:
                        'Connect and sync to load supported measurements from the ring.',
                  )
                else if (supportedActions.isEmpty && !supportsEcg)
                  const EmptyState(
                    icon: Icons.monitor_heart,
                    text:
                        'This ring does not report support for realtime one-shot measurements.',
                  )
                else ...[
                  ...supportedActions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MeasurementSeriesCard(
                        action: action,
                        series: measurementSeriesFor(action, snapshot),
                        snapshot: snapshot,
                        onMeasure: onMeasure,
                      ),
                    ),
                  ),
                  if (supportsEcg)
                    EcgMeasurementCard(
                      snapshot: snapshot,
                      onStartEcg: onStartEcg,
                      onStopEcg: onStopEcg,
                      onGetEcgResult: onGetEcgResult,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeasurementStatusCard extends StatelessWidget {
  const _MeasurementStatusCard({required this.snapshot});

  final MeasurementPageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (snapshot.busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                snapshot.connected ? Icons.check_circle : Icons.link_off,
                color: snapshot.connected
                    ? context.vyana.green
                    : context.vyana.gold,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                snapshot.busy &&
                        snapshot.activeMeasurement != null &&
                        snapshot.activeMeasurement != 'ECG'
                    ? '${snapshot.activeMeasurement} measurement in progress'
                    : snapshot.status,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MeasurementSeriesCard extends StatelessWidget {
  const MeasurementSeriesCard({
    required this.action,
    required this.series,
    required this.snapshot,
    required this.onMeasure,
    super.key,
  });

  final MeasurementAction action;
  final MeasurementSeries series;
  final MeasurementPageSnapshot snapshot;
  final Future<void> Function(MeasurementAction action) onMeasure;

  @override
  Widget build(BuildContext context) {
    final active = snapshot.activeMeasurement == action.label;
    final canMeasure = snapshot.connected && !snapshot.busy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(action.icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: canMeasure ? () => onMeasure(action) : null,
                  icon: active
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(active ? 'Running' : 'Test'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    series.latestText,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(series.unit, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            TimeSeriesChart(points: series.points),
          ],
        ),
      ),
    );
  }
}

class EcgMeasurementCard extends StatelessWidget {
  const EcgMeasurementCard({
    required this.snapshot,
    required this.onStartEcg,
    required this.onStopEcg,
    required this.onGetEcgResult,
    super.key,
  });

  final MeasurementPageSnapshot snapshot;
  final Future<void> Function() onStartEcg;
  final Future<void> Function() onStopEcg;
  final Future<void> Function() onGetEcgResult;

  @override
  Widget build(BuildContext context) {
    final ecgIsActive = snapshot.activeMeasurement == 'ECG';
    final session = snapshot.ecgSession;
    final result = snapshot.ecgResult;
    final canStart = snapshot.connected && !snapshot.busy;
    final canStop = snapshot.connected && ecgIsActive;
    final canReadResult =
        snapshot.connected && !snapshot.busy && session.canReadResult;
    final startLabel = session.isPreparing
        ? 'Get ready'
        : session.waitingForContact
        ? 'Waiting'
        : session.isRecording
        ? 'Recording'
        : 'Start';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ECG',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: canStart ? onStartEcg : null,
                  icon: Icon(
                    ecgIsActive ? Icons.monitor_heart : Icons.play_arrow,
                  ),
                  label: Text(ecgIsActive ? startLabel : 'Start'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (session.hasSession) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(value: session.progress),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    session.isRecording
                        ? '${session.remaining.inSeconds}s left'
                        : session.stateLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            EcgWaveformChart(
              samples: session.displaySamples,
              contactAttached: session.contactAttached,
              emptyText: _ecgWaveformEmptyText(session),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EcgMetricTile(
                  label: 'Samples',
                  value: '${session.sampleCount}',
                  icon: Icons.show_chart,
                ),
                _EcgMetricTile(
                  label: 'Contact',
                  value: session.contactLabel,
                  icon: session.contactAttached == false
                      ? Icons.warning_amber
                      : Icons.sensors,
                ),
                _EcgMetricTile(
                  label: 'Heart rate',
                  value: _intMetric(session.heartRate, 'bpm'),
                  icon: Icons.favorite,
                ),
                _EcgMetricTile(
                  label: 'HRV',
                  value: _intMetric(session.hrv, 'ms'),
                  icon: Icons.timeline,
                ),
                _EcgMetricTile(
                  label: 'RR',
                  value: _intMetric(session.rr, 'ms'),
                  icon: Icons.graphic_eq,
                ),
                _EcgMetricTile(
                  label: 'Blood pressure',
                  value: session.bloodPressure ?? '-',
                  icon: Icons.speed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: canStop ? onStopEcg : null,
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Stop'),
                ),
                OutlinedButton.icon(
                  onPressed: canReadResult ? onGetEcgResult : null,
                  icon: const Icon(Icons.assignment),
                  label: const Text('Result'),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _EcgResultPanel(result: result),
            ] else if (session.failureReason != null) ...[
              const SizedBox(height: 12),
              _EcgRetryPanel(message: session.failureReason!),
            ],
          ],
        ),
      ),
    );
  }
}

class EcgWaveformChart extends StatelessWidget {
  const EcgWaveformChart({
    required this.samples,
    required this.contactAttached,
    required this.emptyText,
    super.key,
  });

  final List<double> samples;
  final bool? contactAttached;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: context.vyana.card,
        border: Border.all(color: context.vyana.border),
      ),
      child: samples.isEmpty
          ? EmptyState(icon: Icons.monitor_heart, text: emptyText)
          : CustomPaint(
              painter: EcgWaveformPainter(
                samples: samples,
                contactAttached: contactAttached,
              ),
            ),
    );
  }
}

class EcgWaveformPainter extends CustomPainter {
  EcgWaveformPainter({required this.samples, required this.contactAttached});

  final List<double> samples;
  final bool? contactAttached;

  @override
  void paint(Canvas canvas, Size size) {
    final minorGridPaint = Paint()
      ..color = const Color(0xFF1C222C)
      ..strokeWidth = 0.7;
    final majorGridPaint = Paint()
      ..color = const Color(0xFF233041)
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorGridPaint);
    }
    for (var y = 0.0; y <= size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorGridPaint);
    }
    for (var x = 0.0; x <= size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorGridPaint);
    }
    for (var y = 0.0; y <= size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorGridPaint);
    }

    final maxPaintedPoints = (size.width * 2).round().clamp(120, 1400).toInt();
    final stride = (samples.length / maxPaintedPoints)
        .ceil()
        .clamp(1, samples.length)
        .toInt();
    final plotted = <double>[
      for (var index = 0; index < samples.length; index += stride)
        samples[index],
    ];
    if (plotted.length < 2) return;

    final minValue = plotted.reduce((a, b) => a < b ? a : b);
    final maxValue = plotted.reduce((a, b) => a > b ? a : b);
    final valueSpan = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;
    final midlinePaint = Paint()
      ..color = const Color(0xFF3A4452)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      midlinePaint,
    );

    final path = Path();
    for (var index = 0; index < plotted.length; index += 1) {
      final x = index / (plotted.length - 1) * size.width;
      final normalized = (plotted[index] - minValue) / valueSpan;
      final y = 10 + (1 - normalized) * (size.height - 20);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = contactAttached == false
            ? const Color(0xFFB7791F)
            : const Color(0xFFB4232A)
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant EcgWaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.contactAttached != contactAttached;
  }
}

class _EcgMetricTile extends StatelessWidget {
  const _EcgMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 176),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.vyana.border),
          color: context.vyana.elevated,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: context.vyana.textSec),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgResultPanel extends StatelessWidget {
  const _EcgResultPanel({required this.result});

  final ParsedEcgResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.vyana.border),
        color: context.vyana.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.interpretation,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EcgMetricTile(
                label: 'AF flag',
                value: result.afFlag ? 'Flagged' : 'Clear',
                icon: Icons.flag,
              ),
              _EcgMetricTile(
                label: 'QRS type',
                value: '${result.qrsType}',
                icon: Icons.analytics,
              ),
              if ((result.heartRate ?? 0) != 0)
                _EcgMetricTile(
                  label: 'Heart rate',
                  value: _intMetric(result.heartRate, 'bpm'),
                  icon: Icons.favorite,
                ),
              if ((result.hrv ?? 0) != 0)
                _EcgMetricTile(
                  label: 'HRV',
                  value: _doubleMetric(result.hrv, 'ms', decimals: 0),
                  icon: Icons.timeline,
                ),
              if ((result.pressure ?? 0) != 0)
                _EcgMetricTile(
                  label: 'Pressure',
                  value: _doubleMetric(result.pressure, ''),
                  icon: Icons.psychology,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EcgRetryPanel extends StatelessWidget {
  const _EcgRetryPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.vyana.gold.withValues(alpha: 0.5)),
        color: context.vyana.gold.withValues(alpha: context.vyana.isDark ? 0.14 : 0.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.refresh, size: 20, color: context.vyana.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.vyana.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _intMetric(int? value, String unit) {
  if (value == null || value == 0) return '-';
  return unit.isEmpty ? '$value' : '$value $unit';
}

String _doubleMetric(double? value, String unit, {int decimals = 1}) {
  if (value == null || value == 0) return '-';
  final text = value.toStringAsFixed(decimals);
  return unit.isEmpty ? text : '$text $unit';
}

String _ecgWaveformEmptyText(EcgSessionSnapshot session) {
  if (session.isPreparing) {
    return 'Place your finger on the ring ECG contact.';
  }
  if (session.waitingForContact) {
    return 'Hold contact until the waveform starts.';
  }
  if (session.failureReason != null) {
    return 'No clean ECG waveform was recorded.';
  }
  return 'Start ECG to stream the waveform.';
}

class TimeSeriesChart extends StatelessWidget {
  const TimeSeriesChart({required this.points, super.key});

  final List<MeasurementSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        text: 'No fetched or live test records yet.',
      );
    }
    return Container(
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: context.vyana.card,
        border: Border.all(color: context.vyana.border),
      ),
      child: CustomPaint(painter: TimeSeriesPainter(points)),
    );
  }
}

class TimeSeriesPainter extends CustomPainter {
  TimeSeriesPainter(this.points);

  final List<MeasurementSeriesPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const top = 12.0;
    const bottom = 24.0;
    final right = size.width - 8;
    final plotWidth = (right - left).clamp(1.0, double.infinity).toDouble();
    final plotHeight = size.height - top - bottom;
    final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
    final minValue = sorted.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxValue = sorted.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final valueSpan = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;
    final start = sorted.first.time.millisecondsSinceEpoch;
    final end = sorted.last.time.millisecondsSinceEpoch;
    final timeSpan = end == start ? 1 : end - start;

    final gridPaint = Paint()
      ..color = const Color(0xFF233041)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i += 1) {
      final y = top + plotHeight * i / 2;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    Offset pointOffset(MeasurementSeriesPoint point) {
      final x =
          left +
          ((point.time.millisecondsSinceEpoch - start) / timeSpan) * plotWidth;
      final y = top + (1 - ((point.value - minValue) / valueSpan)) * plotHeight;
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < sorted.length; i += 1) {
      final offset = pointOffset(sorted[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00A86B)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final point in sorted) {
      final offset = pointOffset(point);
      canvas.drawCircle(
        offset,
        point.live ? 4.5 : 3.5,
        Paint()
          ..color = point.live
              ? const Color(0xFFE0BF56)
              : const Color(0xFF00A86B),
      );
    }

    const labelStyle = TextStyle(color: Color(0xFF98A2B3), fontSize: 10);
    _paintText(
      canvas,
      maxValue.toStringAsFixed(1),
      Offset(8, top - 2),
      labelStyle,
    );
    _paintText(
      canvas,
      minValue.toStringAsFixed(1),
      Offset(8, top + plotHeight - 8),
      labelStyle,
    );
    _paintText(
      canvas,
      timeOfDayLabel(sorted.first.time),
      Offset(left, size.height - 17),
      labelStyle,
    );
    _paintText(
      canvas,
      timeOfDayLabel(sorted.last.time),
      Offset(right - 34, size.height - 17),
      labelStyle,
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TimeSeriesPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

MeasurementSeries measurementSeriesFor(
  MeasurementAction action,
  MeasurementPageSnapshot snapshot,
) {
  switch (action.type) {
    case DeviceAppControlMeasureHealthDataType.heartRate:
      final points = [
        ..._pointsFromRecords(snapshot.history.heartRate, const [
          'heartRate',
        ], 'bpm'),
        if (snapshot.vitals.heartRate != null)
          _livePoint(snapshot.vitals.heartRate!.toDouble(), 'bpm'),
      ];
      return MeasurementSeries(
        points: points,
        latestText: valueOrDash(snapshot.vitals.heartRate),
        unit: 'bpm',
      );
    case DeviceAppControlMeasureHealthDataType.bloodOxygen:
      final points = [
        ..._pointsFromRecords(snapshot.history.combined, const [
          'bloodOxygen',
        ], '%'),
        if (snapshot.vitals.bloodOxygen != null)
          _livePoint(snapshot.vitals.bloodOxygen!.toDouble(), '%'),
      ];
      return MeasurementSeries(
        points: points,
        latestText: valueOrDash(snapshot.vitals.bloodOxygen),
        unit: '%',
      );
    case DeviceAppControlMeasureHealthDataType.bloodPressure:
      final points = [
        ..._pointsFromRecords(snapshot.history.bloodPressure, const [
          'systolicBloodPressure',
          'systolic',
        ], 'mmHg'),
      ];
      final systolic = snapshot.vitals.bloodPressure?.split('/').first;
      final systolicValue = double.tryParse(systolic ?? '');
      if (systolicValue != null) points.add(_livePoint(systolicValue, 'mmHg'));
      return MeasurementSeries(
        points: points,
        latestText: snapshot.vitals.bloodPressure ?? '-',
        unit: 'mmHg',
      );
    case DeviceAppControlMeasureHealthDataType.bodyTemperature:
      final points = [
        ..._pointsFromRecords(
          snapshot.history.combined,
          const ['temperature'],
          'C',
          filter: validTemperature,
        ),
        if (snapshot.vitals.temperature != null)
          _livePoint(snapshot.vitals.temperature!, 'C'),
      ];
      return MeasurementSeries(
        points: points,
        latestText: doubleOrDash(snapshot.vitals.temperature, 1),
        unit: 'C',
      );
    case DeviceAppControlMeasureHealthDataType.hrv:
      final points = [
        ..._pointsFromRecords(snapshot.history.combined, const ['hrv'], 'ms'),
        if (snapshot.vitals.hrv != null)
          _livePoint(snapshot.vitals.hrv!.toDouble(), 'ms'),
      ];
      return MeasurementSeries(
        points: points,
        latestText: valueOrDash(snapshot.vitals.hrv),
        unit: 'ms',
      );
    case DeviceAppControlMeasureHealthDataType.pressure:
      final points = [
        if (snapshot.vitals.pressure != null)
          _livePoint(snapshot.vitals.pressure!, ''),
      ];
      return MeasurementSeries(
        points: points,
        latestText: doubleOrDash(snapshot.vitals.pressure, 1),
        unit: '',
      );
    case DeviceAppControlMeasureHealthDataType.bloodGlucose:
      final points = [
        ..._pointsFromRecords(snapshot.history.combined, const [
          'bloodGlucose',
        ], 'mmol/L'),
        ..._pointsFromRecords(snapshot.history.invasive, const [
          'bloodGlucose',
        ], 'mmol/L'),
        if (snapshot.vitals.bloodGlucose != null)
          _livePoint(snapshot.vitals.bloodGlucose!, 'mmol/L'),
      ];
      return MeasurementSeries(
        points: points,
        latestText: doubleOrDash(snapshot.vitals.bloodGlucose, 1),
        unit: 'mmol/L',
      );
    default:
      return const MeasurementSeries(points: [], latestText: '-', unit: '');
  }
}

List<MeasurementSeriesPoint> _pointsFromRecords(
  List<dynamic> records,
  List<String> valueFields,
  String unit, {
  double? Function(double?)? filter,
}) {
  final points = <MeasurementSeriesPoint>[];
  for (final record in records) {
    final timestamp = timestampOf(record);
    final rawValue = readDouble(record, valueFields);
    final value = filter == null ? rawValue : filter(rawValue);
    if (timestamp == null || timestamp <= 0 || value == null || value == 0) {
      continue;
    }
    points.add(
      MeasurementSeriesPoint(
        time: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
        value: value,
        label: '$value $unit',
      ),
    );
  }
  return points;
}

MeasurementSeriesPoint _livePoint(double value, String unit) {
  return MeasurementSeriesPoint(
    time: DateTime.now(),
    value: value,
    label: '$value $unit',
    live: true,
  );
}
