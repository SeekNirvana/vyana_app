part of '../../main.dart';

/// Nova's pattern engine — one engine reading the user's own words *and* the
/// ring, feeding the "Nova found a pattern" card on Metrics and Journal and
/// the full history on Weekly Insights.
///
/// A pattern is a claim with a lifespan. Every run recomputes the candidates,
/// then reconciles them against the persisted [Patterns] table so a finding
/// that was holding can weaken and end rather than silently vanish — the
/// ending is often the payoff ("this stopped after you acted on it").
///
/// Counts are computed, never written: the journal claim is literally a tag
/// count, and the evidence ids let the detail screen show the records the
/// claim rests on.

enum PatternStatus { holding, weakening, broken }

extension PatternStatusX on PatternStatus {
  static PatternStatus fromName(String name) => switch (name) {
        'weakening' => PatternStatus.weakening,
        'broken' => PatternStatus.broken,
        _ => PatternStatus.holding,
      };

  String get eyebrow => switch (this) {
        PatternStatus.holding => 'NOVA FOUND A PATTERN',
        PatternStatus.weakening => 'PATTERN WEAKENING',
        PatternStatus.broken => 'PATTERN ENDED',
      };
}

/// A candidate computed from the current data, before lifecycle reconciling.
class PatternCandidate {
  const PatternCandidate({
    required this.id,
    required this.source,
    required this.subject,
    required this.claim,
    required this.evidenceIds,
    required this.evidenceCount,
    required this.matchCount,
    this.counterIds = const [],
    this.baseline,
    this.weakeningClaim,
  });

  final String id;

  /// `journal` | `metrics`
  final String source;
  final String subject;
  final String claim;
  final List<String> evidenceIds;

  /// §8 (10a): the records in the window that did not match, so the claim's
  /// denominator is visible rather than asserted.
  final List<String> counterIds;

  /// §8 (10b): what the per-row deltas are measured against.
  final double? baseline;

  final int evidenceCount;
  final int matchCount;

  /// The claim shrunk to what is still true, used when the match count drops.
  final String? weakeningClaim;
}

/// Minimal projection of a journal entry for the pure engine.
class PatternEntry {
  const PatternEntry({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.tags,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final List<String> tags;
}

/// Minimal projection of a finished session for the pure engine.
class PatternSession {
  const PatternSession({
    required this.id,
    required this.activityId,
    required this.startedAt,
  });

  final String id;
  final String activityId;
  final DateTime startedAt;
}

/// The night a wake-logged entry belongs to: anything logged before noon is
/// about the night that just ended (the sleep day is the morning's date).
DateTime nightKeyForEntry(DateTime createdAt) {
  final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
  return createdAt.hour < 12 ? day : day.add(const Duration(days: 1));
}

/// "Sleep broke after 3am": an awake segment after 03:00, or a night short
/// enough that the score falls under 65.
bool sleepBrokeAfterThree(SleepDaySummary night) {
  final threeAm = DateTime(night.day.year, night.day.month, night.day.day, 3);
  for (final seg in night.waveform) {
    if (seg.sleepType != SleepType.awake) continue;
    if (seg.durationSeconds < 5 * 60) continue;
    final start = DateTime.fromMillisecondsSinceEpoch(seg.startTimeStamp * 1000);
    if (start.isAfter(threeAm) && start.isBefore(night.windowEnd)) return true;
  }
  return night.score < 65;
}

String _capitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _countWord(int n) => switch (n) {
      1 => 'one',
      2 => 'two',
      3 => 'three',
      4 => 'four',
      5 => 'five',
      6 => 'six',
      7 => 'seven',
      8 => 'eight',
      9 => 'nine',
      _ => '$n',
    };

/// Journal pattern: the tag that recurs most across the last 30 days of
/// dreams, joined to those nights' sleep. Needs at least two dreams carrying
/// the tag and the tag in at least a third of dreams to be a pattern at all.
PatternCandidate? journalPatternCandidate({
  required List<PatternEntry> entries,
  required List<SleepDaySummary> nights,
  required DateTime now,
}) {
  final since = now.subtract(const Duration(days: 30));
  final dreams = entries
      .where((e) => e.type == 'dream' && e.createdAt.isAfter(since))
      .toList();
  if (dreams.length < 3) return null;

  final counts = <String, List<PatternEntry>>{};
  for (final d in dreams) {
    for (final tag in d.tags.toSet()) {
      counts.putIfAbsent(tag.toLowerCase(), () => []).add(d);
    }
  }
  if (counts.isEmpty) return null;
  final best = counts.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
  final tag = best.key;
  final tagged = best.value;
  if (tagged.length < 2 || tagged.length * 3 < dreams.length) return null;

  final nightByKey = {for (final n in nights) n.day: n};
  var broke = 0;
  var joined = 0;
  for (final d in tagged) {
    final night = nightByKey[nightKeyForEntry(d.createdAt)];
    if (night == null) continue;
    joined++;
    if (sleepBrokeAfterThree(night)) broke++;
  }

  final n = _countWord(tagged.length);
  final of = _countWord(dreams.length);
  final base = '${_capitalise(tag)} turns up in $n of your $of dreams this month';
  final claim = joined >= 2 && broke == joined
      ? '$base — each on a night your sleep broke after 3am.'
      : joined >= 2 && broke * 2 >= joined
          ? '$base — ${_countWord(broke)} of them on nights your sleep broke after 3am.'
          : '$base.';

  return PatternCandidate(
    id: 'journal:tag:$tag',
    source: 'journal',
    subject: tag,
    claim: claim,
    evidenceIds: [for (final d in tagged) d.id],
    counterIds: [
      for (final d in dreams)
        if (!tagged.contains(d)) d.id,
    ],
    evidenceCount: dreams.length,
    matchCount: tagged.length,
    weakeningClaim:
        '${_capitalise(tag)} dreams are thinning — $n of the last $of.',
  );
}

/// Metrics pattern: the activity after which next-morning HRV runs clearly
/// higher than the user's baseline. Needs three sessions with a next-day HRV
/// reading and a median lift of at least 5%.
PatternCandidate? metricsPatternCandidate({
  required List<PatternSession> sessions,
  required List<VitalHistoryPoint> hrvPoints,
  required DateTime now,
}) {
  if (hrvPoints.length < 10) return null;
  final since = now.subtract(const Duration(days: 90));
  final recent = hrvPoints.where((p) => p.time.isAfter(since)).toList();
  if (recent.length < 10) return null;
  final baseline =
      recent.map((p) => p.value).reduce((a, b) => a + b) / recent.length;
  if (baseline <= 0) return null;

  // Morning HRV per day: the first reading before noon, else the day's mean.
  final byDay = <DateTime, List<double>>{};
  for (final p in recent) {
    final day = DateTime(p.time.year, p.time.month, p.time.day);
    byDay.putIfAbsent(day, () => []).add(p.value);
  }
  double? morningHrv(DateTime day) {
    final vals = byDay[day];
    if (vals == null || vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  final byActivity = <String, List<PatternSession>>{};
  for (final s in sessions) {
    if (s.startedAt.isBefore(since)) continue;
    byActivity.putIfAbsent(s.activityId, () => []).add(s);
  }

  PatternCandidate? best;
  var bestLift = 0.0;
  byActivity.forEach((activityId, list) {
    final lifts = <double>[];
    final ids = <String>[];
    for (final s in list) {
      final next = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)
          .add(const Duration(days: 1));
      final hrv = morningHrv(next);
      if (hrv == null) continue;
      lifts.add((hrv - baseline) / baseline);
      ids.add(s.id);
    }
    if (lifts.length < 3) return;
    lifts.sort();
    final median = lifts[lifts.length ~/ 2];
    if (median < 0.05 || median <= bestLift) return;
    bestLift = median;
    final pct = (median * 100).round();
    final name = activityById(activityId)?.name ?? activityId;
    best = PatternCandidate(
      id: 'metrics:hrv-after:$activityId',
      source: 'metrics',
      subject: activityId,
      claim: 'Your HRV runs $pct% higher the day after a $name session.',
      evidenceIds: ids,
      baseline: baseline,
      evidenceCount: ids.length,
      matchCount: pct,
      weakeningClaim: 'The HRV lift after $name is fading — $pct%.',
    );
  });
  return best;
}

/// Reconciles candidates against the persisted rows and returns the rows to
/// write. Holding → weakening when the match count drops but is not zero →
/// broken when it reaches zero or the candidate disappears entirely.
List<PatternCandidate> _candidates(
  List<PatternEntry> entries,
  List<SleepDaySummary> nights,
  List<PatternSession> sessions,
  List<VitalHistoryPoint> hrvPoints,
  DateTime now,
) =>
    [
      ?journalPatternCandidate(entries: entries, nights: nights, now: now),
      ?metricsPatternCandidate(
        sessions: sessions,
        hrvPoints: hrvPoints,
        now: now,
      ),
    ];

class PatternEngine {
  PatternEngine(this._db);

  final VyanaDatabase _db;
  DateTime? _lastRun;
  bool _running = false;

  static const _minGap = Duration(minutes: 5);

  Future<void> recompute({
    required RingHistory history,
    bool force = false,
  }) async {
    if (_running) return;
    final now = DateTime.now();
    if (!force && _lastRun != null && now.difference(_lastRun!) < _minGap) {
      return;
    }
    _running = true;
    try {
      final rows = await _db.allEntries();
      final entries = [
        for (final r in rows)
          PatternEntry(
            id: r.id,
            type: r.type,
            createdAt: r.createdAt,
            tags: splitTags(r.tags),
          ),
      ];
      final sessionRows = await _db.recentSessions(limit: 400);
      final sessions = [
        for (final s in sessionRows)
          if (s.endedAt != null)
            PatternSession(
              id: s.id,
              activityId: s.vyanaActivityType,
              startedAt: s.startedAt,
            ),
      ];
      final candidates = _candidates(
        entries,
        sleepDaySummaries(history.sleep),
        sessions,
        vitalHistoryPoints(history, VitalsMetricKind.hrv),
        now,
      );
      final existing = {for (final p in await _db.allPatterns()) p.id: p};
      final seen = <String>{};

      for (final c in candidates) {
        seen.add(c.id);
        final prior = existing[c.id];
        if (prior == null) {
          await _db.upsertPattern(
            id: c.id,
            source: c.source,
            subject: c.subject,
            claim: c.claim,
            status: PatternStatus.holding.name,
            evidenceIds: c.evidenceIds,
            counterIds: c.counterIds,
            baseline: c.baseline,
            evidenceCount: c.evidenceCount,
            matchCount: c.matchCount,
            firstSeen: now,
            lastConfirmed: now,
          );
          continue;
        }
        final weakening = prior.status != PatternStatus.broken.name &&
            c.matchCount < prior.matchCount &&
            c.matchCount * 2 <= prior.matchCount;
        await _db.upsertPattern(
          id: c.id,
          source: c.source,
          subject: c.subject,
          claim: weakening ? (c.weakeningClaim ?? c.claim) : c.claim,
          status: (weakening ? PatternStatus.weakening : PatternStatus.holding)
              .name,
          evidenceIds: c.evidenceIds,
          counterIds: c.counterIds,
          baseline: c.baseline,
          evidenceCount: c.evidenceCount,
          matchCount: weakening ? prior.matchCount : c.matchCount,
          firstSeen: prior.firstSeen,
          lastConfirmed: now,
        );
      }

      // Anything that was live and no longer qualifies has ended.
      for (final p in existing.values) {
        if (seen.contains(p.id) || p.status == PatternStatus.broken.name) {
          continue;
        }
        await _db.upsertPattern(
          id: p.id,
          source: p.source,
          subject: p.subject,
          claim: _endedClaim(p),
          status: PatternStatus.broken.name,
          evidenceIds: _decodeIds(p.evidenceIdsJson),
          evidenceCount: p.evidenceCount,
          matchCount: 0,
          firstSeen: p.firstSeen,
          lastConfirmed: p.lastConfirmed,
          endedAt: now,
        );
      }
      _lastRun = now;
    } finally {
      _running = false;
    }
  }

  static String _endedClaim(PatternRow p) {
    final held = p.lastConfirmed.difference(p.firstSeen).inDays;
    final span = held >= 14 ? ' — it held ${(held / 7).round()} weeks' : '';
    if (p.source == 'journal') {
      return '${_capitalise(p.subject)} dreams have stopped turning up$span.';
    }
    final name = activityById(p.subject)?.name ?? p.subject;
    return '$name no longer moves your HRV — your baseline rose to meet it$span.';
  }
}

List<String> _decodeIds(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) return decoded.map((e) => e.toString()).toList();
  } catch (_) {}
  return const [];
}

List<String> patternEvidenceIds(PatternRow row) => _decodeIds(row.evidenceIdsJson);

PatternStatus patternStatusOf(PatternRow row) =>
    PatternStatusX.fromName(row.status);

final patternEngineProvider = Provider<PatternEngine>(
  (ref) => PatternEngine(ref.watch(databaseProvider)),
);

final patternsProvider = StreamProvider<List<PatternRow>>(
  (ref) => ref.watch(databaseProvider).watchPatterns(),
);

/// The one pattern a card shows for its source: the strongest current finding
/// — holding beats weakening beats a recent ending; anything ended more than
/// two weeks ago belongs only in Weekly Insights. Null → the card does not
/// render at all.
PatternRow? currentPatternFor(List<PatternRow> rows, String source) {
  PatternRow? pick;
  int rank(PatternRow r) => switch (patternStatusOf(r)) {
        PatternStatus.holding => 0,
        PatternStatus.weakening => 1,
        PatternStatus.broken => 2,
      };
  for (final r in rows) {
    if (r.source != source) continue;
    if (patternStatusOf(r) == PatternStatus.broken) {
      final ended = r.endedAt;
      if (ended == null || DateTime.now().difference(ended).inDays > 14) {
        continue;
      }
    }
    if (pick == null || rank(r) < rank(pick)) pick = r;
  }
  return pick;
}

/// §8 (10a): the records in the window that did not match the claim.
List<String> patternCounterIds(PatternRow row) => _decodeIds(row.counterIdsJson);
