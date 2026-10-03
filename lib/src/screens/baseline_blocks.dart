part of '../../main.dart';

/// §14 — the strip above KEY METRICS while the app is still learning what
/// normal looks like for this person, and the one question Nova asks about it.

class BaselineLearningStrip extends ConsumerWidget {
  const BaselineLearningStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final baselines = ref.watch(personalBaselinesProvider);
    final day = baselines.learningDay;
    if (day == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          VyanaIcon('insights', size: 14, color: t.mutedInk),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Learning your normal',
              style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 12),
            ),
          ),
          MonoEyebrow(
            'DAY $day OF $kBaselineLearningDays',
            size: 11.5,
            spacing: 0.9,
          ),
        ],
      ),
    );
  }
}

/// The inline, dismissable card under the row it concerns. Nova-neutral grey:
/// it is a question, not a verdict, so it borrows no quality colour.
class BaselineQuestionCard extends ConsumerStatefulWidget {
  const BaselineQuestionCard({super.key, required this.question});

  final BaselineQuestion question;

  @override
  ConsumerState<BaselineQuestionCard> createState() =>
      _BaselineQuestionCardState();
}

class _BaselineQuestionCardState extends ConsumerState<BaselineQuestionCard> {
  bool _dismissed = false;

  Future<void> _answer(BaselineAnswer answer) async {
    final controller = ref.read(personalBaselinesProvider.notifier);
    await controller.answer(widget.question.vital, answer);
    final ring = ref.read(ringControllerProvider);
    final nights = averageableNights(
      sleepDaySummaries(ring.history.sleep),
      history: ring.history,
    );
    controller.applySleepTarget([
      for (final n in nights.take(14)) n.breakdown.asleepSeconds,
    ]);
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final t = context.vyana;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VyanaIcon('sparkles', size: 15, color: t.mutedInk),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.question.prompt,
                  style: VyanaType.bodySm.copyWith(
                    color: t.text,
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  // A dismissal is a deferral: keep the typical range and ask
                  // again in a fortnight, never silently adopt.
                  await ref
                      .read(personalBaselinesProvider.notifier)
                      .answer(widget.question.vital, BaselineAnswer.deferred);
                  if (mounted) setState(() => _dismissed = true);
                },
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: VyanaIcon('x', size: 15, color: t.mutedInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          // Wraps so a long answer never squashes its neighbour at large text.
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final (label, answer) in widget.question.options)
                BorderedPill(label: label, onTap: () => _answer(answer)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decides whether a question is due, and which one. One per day at most.
///
/// Returns null while learning, when today's question has been asked, or when
/// no vital is both atypical and steady.
BaselineQuestion? dueBaselineQuestion({
  required RingController controller,
  required PersonalBaselinesState baselines,
  TrainingFrequency? trainingFrequency,
}) {
  if (baselines.isLearning || baselines.askedToday) return null;

  final history = controller.history;

  /// Daily means over the learning window, newest first.
  List<double> dailyMeans(VitalsMetricKind kind) {
    final points = vitalHistoryPoints(history, kind);
    final byDay = <DateTime, List<double>>{};
    for (final p in points) {
      byDay
          .putIfAbsent(DateTime(p.time.year, p.time.month, p.time.day), () => [])
          .add(p.value);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final d in days.take(kBaselineLearningDays))
        byDay[d]!.reduce((a, b) => a + b) / byDay[d]!.length,
    ];
  }

  int atypicalCount(List<double> values, VitalReferenceRange range) =>
      values.where((v) => v < range.low || v > range.high).length;

  // Sleep first: it is the question users most often have an answer to.
  final nights = averageableNights(
    sleepDaySummaries(history.sleep),
    history: history,
  );
  if (baselines.recordFor(BaselineVital.sleep).askable &&
      nights.length >= kBaselineLearningDays) {
    final hours = [
      for (final n in nights.take(kBaselineLearningDays))
        n.breakdown.asleepSeconds / 3600,
    ];
    if (baselineQuestionDue(recentValues: hours, typical: kSleepRange)) {
      final sorted = [...hours]..sort();
      final median = sorted[sorted.length ~/ 2];
      return baselineQuestionFor(
        BaselineVital.sleep,
        atypicalDays: atypicalCount(hours, kSleepRange),
        windowDays: kBaselineLearningDays,
        usualSleepLabel: _hoursLabel(median),
      );
    }
  }

  // Stress and resting HR are one question, asked off the HRV series that
  // stress is derived from.
  if (baselines.recordFor(BaselineVital.restingHr).askable) {
    final hrv = dailyMeans(VitalsMetricKind.hrv);
    if (baselineQuestionDue(recentValues: hrv, typical: kHrvRange)) {
      return baselineQuestionFor(
        BaselineVital.restingHr,
        atypicalDays: atypicalCount(hrv, kHrvRange),
        windowDays: kBaselineLearningDays,
      );
    }
  }

  return null;
}

String _hoursLabel(double hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// What the You row says about the baselines under it.
String baselineSummaryLine(PersonalBaselinesState baselines) {
  final day = baselines.learningDay;
  if (day != null) {
    return 'Learning your normal · judged against typical ranges for now';
  }
  final adopted = [
    for (final v in const [
      BaselineVital.hrv,
      BaselineVital.restingHr,
      BaselineVital.sleep,
    ])
      if (baselines.recordFor(v).adopted) v.label,
  ];
  if (adopted.isEmpty) {
    return 'Judged against your own 30-day averages';
  }
  return 'Your own range for ${adopted.join(' · ')}';
}

/// §14: "Answers editable in You beside How often do you train?". Changing an
/// answer here re-applies the sleep target immediately, so a score never
/// disagrees with the setting that produced it.
Future<void> showBaselineAnswersSheet(BuildContext context, WidgetRef ref) {
  final t = context.vyana;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Consumer(
        builder: (context, ref, _) {
          final baselines = ref.watch(personalBaselinesProvider);
          return Panel(
            pad: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoEyebrow('WHAT COUNTS AS NORMAL', size: 9),
                const SizedBox(height: 6),
                Text(
                  'Your normal',
                  style: VyanaType.titleSerif
                      .copyWith(color: t.text, fontSize: 21),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nova asks about the feeling, never the number. Saying a '
                  'reading is normal for you changes what counts as low — the '
                  'typical range stays visible either way, and SpO₂, an '
                  'irregular rhythm and a very high heart rate are never '
                  'personalised.',
                  style:
                      VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                ),
                const SizedBox(height: 14),
                for (final vital in const [
                  BaselineVital.sleep,
                  BaselineVital.restingHr,
                  BaselineVital.hrv,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      pad: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vital.label,
                            style: VyanaType.label.copyWith(color: t.text),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final answer in const [
                                BaselineAnswer.adopted,
                                BaselineAnswer.kept,
                                BaselineAnswer.deferred,
                              ])
                                BorderedPill(
                                  label: answer.label,
                                  color:
                                      baselines.recordFor(vital).answer == answer
                                          ? t.green
                                          : null,
                                  onTap: () async {
                                    final controller = ref.read(
                                      personalBaselinesProvider.notifier,
                                    );
                                    await controller.answer(vital, answer);
                                    final ring =
                                        ref.read(ringControllerProvider);
                                    controller.applySleepTarget([
                                      for (final n in averageableNights(
                                        sleepDaySummaries(ring.history.sleep),
                                        history: ring.history,
                                      ).take(14))
                                        n.breakdown.asleepSeconds,
                                    ]);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
