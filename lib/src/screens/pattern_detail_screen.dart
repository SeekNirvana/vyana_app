part of '../../main.dart';

Future<void> openPatternDetail(BuildContext context, PatternRow pattern) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => PatternDetailScreen(pattern: pattern)),
  );
}

/// Tapping a pattern card opens the evidence: the claim, its lifespan, then
/// the specific records it was computed from — the dream entries beside the
/// sleep data for those nights, or the session days beside their next-day
/// HRV — so "your sleep broke after 3am" is shown rather than asserted.
/// One screen type, parameterised by pattern; strength stated honestly.
class PatternDetailScreen extends ConsumerWidget {
  const PatternDetailScreen({super.key, required this.pattern});
  final PatternRow pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final p = pattern;
    final look = patternLook(p, t);
    final status = patternStatusOf(p);
    final ended = status == PatternStatus.broken;
    final tint = ended ? t.mutedInk : look.tint;
    final ring = ref.watch(ringControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(
                children: [
                  IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonoEyebrow(status.eyebrow, color: tint),
                        const SizedBox(height: 2),
                        Text(
                          'Evidence',
                          style: VyanaType.appBarSerif.copyWith(color: t.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tint.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.claim,
                      style: TextStyle(
                        fontFamily: VyanaType.serif,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Lifespan(pattern: p, tint: tint),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _strengthLine(p),
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
              ),
              const SizedBox(height: 22),
              if (p.source == 'journal')
                _JournalEvidence(pattern: p, ring: ring, tint: tint)
              else
                _MetricsEvidence(pattern: p, ring: ring, tint: tint),
            ],
          ),
        ),
      ),
    );
  }

  static String _strengthLine(PatternRow p) {
    if (p.source == 'journal') {
      final n = p.matchCount;
      final of = p.evidenceCount;
      if (p.status == PatternStatus.broken.name) {
        return 'This held for a while and has stopped. It was a pattern, not '
            'a proof — but if you changed something, this is what changed with it.';
      }
      return '$n of $of is a pattern, not a proof. Each record below is '
          'tappable, so the claim can be checked in one place.';
    }
    if (p.status == PatternStatus.broken.name) {
      return 'The lift has gone — most often because the baseline rose to '
          'meet it. That is a result, not a failure.';
    }
    return 'Computed from ${p.evidenceCount} sessions with a next-morning '
        'HRV reading against your 90-day baseline. A median, so one good '
        'morning does not make it.';
  }
}

class _Lifespan extends StatelessWidget {
  const _Lifespan({required this.pattern, required this.tint});
  final PatternRow pattern;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    String d(DateTime x) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${x.day} ${months[x.month - 1]}';
    }

    final parts = <String>[
      'FOUND ${d(pattern.firstSeen).toUpperCase()}',
      if (pattern.endedAt != null)
        'ENDED ${d(pattern.endedAt!).toUpperCase()}'
      else
        'CONFIRMED ${d(pattern.lastConfirmed).toUpperCase()}',
      if (pattern.source == 'journal') 'FROM ${pattern.evidenceCount} ENTRIES',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final part in parts) MonoEyebrow(part, size: 10.5, color: t.mutedInk),
      ],
    );
  }
}

/// Dream entries beside the sleep night each one was logged after.
class _JournalEvidence extends ConsumerWidget {
  const _JournalEvidence({
    required this.pattern,
    required this.ring,
    required this.tint,
  });

  final PatternRow pattern;
  final RingController ring;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ids = patternEvidenceIds(pattern).toSet();
    final entries = ref.watch(_journalEntriesProvider).valueOrNull ?? const [];
    final rows = entries.where((e) => ids.contains(e.id)).toList();
    final nights = {
      for (final n in sleepDaySummaries(ring.history.sleep)) n.day: n,
    };
    if (rows.isEmpty) {
      return Text(
        'The entries behind this pattern are no longer in your journal.',
        style: VyanaType.caption.copyWith(color: t.textSec),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoEyebrow('THE ${rows.length} ENTRIES · AND THOSE NIGHTS', size: 10.5),
        const SizedBox(height: 8),
        for (final e in rows) ...[
          Builder(builder: (context) {
            final night = nights[nightKeyForEntry(e.createdAt)];
            final broke = night != null && sleepBrokeAfterThree(night);
            return HairlineCard(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              onTap: () => showJournalEntrySheet(context, ref, e),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VyanaIcon('dream', size: 14, color: t.jDream),
                      const SizedBox(width: 6),
                      Expanded(
                        child: MonoEyebrow(
                          'DREAM · ${_dayLabel(e.createdAt)} ${_timeShort(e.createdAt)}',
                          size: 10.5,
                          color: t.jDream,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.title,
                    style: VyanaType.caption.copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: t.mutedInk.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        VyanaIcon('moon', size: 14, color: t.idSleep),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            night == null
                                ? 'No sleep data for that night'
                                : '${durationText(night.breakdown.asleepSeconds)} asleep · '
                                    'score ${night.score} · '
                                    '${broke ? 'broke after 3am' : 'held through the night'}',
                            style: VyanaType.caption.copyWith(
                              color: t.textSec,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Session days beside their next-morning HRV.
class _MetricsEvidence extends ConsumerWidget {
  const _MetricsEvidence({
    required this.pattern,
    required this.ring,
    required this.tint,
  });

  final PatternRow pattern;
  final RingController ring;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ids = patternEvidenceIds(pattern).toSet();
    final sessions = ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    final rows = sessions.where((s) => ids.contains(s.id)).toList();
    final hrvPoints = vitalHistoryPoints(ring.history, VitalsMetricKind.hrv);
    final byDay = <DateTime, List<double>>{};
    for (final p in hrvPoints) {
      byDay.putIfAbsent(DateTime(p.time.year, p.time.month, p.time.day), () => [])
          .add(p.value);
    }
    final activity = activityById(pattern.subject);
    if (rows.isEmpty) {
      return Text(
        'The sessions behind this pattern are no longer in your vault.',
        style: VyanaType.caption.copyWith(color: t.textSec),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoEyebrow('THE ${rows.length} SESSIONS · AND THE MORNINGS AFTER', size: 10.5),
        const SizedBox(height: 8),
        for (final s in rows) ...[
          Builder(builder: (context) {
            final next = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)
                .add(const Duration(days: 1));
            final vals = byDay[next];
            final hrv = vals == null || vals.isEmpty
                ? null
                : vals.reduce((a, b) => a + b) / vals.length;
            final minutes = s.endedAt?.difference(s.startedAt).inMinutes;
            return HairlineCard(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: VyanaIcon(activity?.icon ?? 'activity', size: 16, color: tint),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${activity?.name ?? pattern.subject} · ${_dayLabel(s.startedAt)}'
                          '${minutes == null ? '' : ' · ${minutes}m'}',
                          style: VyanaType.caption.copyWith(
                            color: t.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hrv == null
                              ? 'No HRV the next morning'
                              : 'Next morning HRV ${hrv.round()} ms',
                          style: VyanaType.caption.copyWith(
                            color: t.textSec,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
  return '${d.day} ${months[d.month - 1]}';
}

String _timeShort(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

final _journalEntriesProvider = StreamProvider<List<JournalEntryRow>>(
  (ref) => ref.watch(databaseProvider).watchEntries(),
);
