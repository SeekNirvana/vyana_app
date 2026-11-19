/// Item 92 — why a night's length did not match the times above it.
///
/// Reported on several nights: fell asleep 00:07, woke 09:00, awake 0m, and
/// sleep length 8h 05m. Those are 48 minutes apart and nothing on screen
/// accounted for them.
///
/// The two numbers came from different places. The times are the earliest
/// start and latest end of the ring's sleep records for that night (records
/// less than 90 minutes apart are joined into one night). The length added
/// up only the minutes the ring had labelled deep, light or REM. Minutes
/// inside the night that the ring labelled as nothing — a gap between two
/// records, or a record whose stages do not cover its own span — were
/// counted as neither sleep nor awake. They simply vanished.
///
/// The rule, decided 14 November: **sleep length is fell asleep to woke up,
/// minus awake minutes.** Which means every minute of the night has to be
/// one of three things, and this library is what decides which:
///
/// * staged or awake — what the ring said;
/// * unstaged sleep — unlabelled, but the ring was still taking heart-rate
///   readings, so the person was there and wearing it;
/// * not recorded — unlabelled with no readings at all, which is a ring on
///   its charger or out of battery. Not counted as sleep, and said out
///   loud rather than quietly dropped.
///
/// The third case is the reason this is not simply "fill the gaps". Calling
/// a charging gap sleep would invent hours someone did not sleep, which is
/// a worse error than the one being fixed.
library;

import 'package:flutter/foundation.dart';

/// Records less than this apart are one night, so a gap can be this long
/// and still be inside the night rather than between two of them.
const Duration kSleepNightMergeGap = Duration(minutes: 90);

/// A stretch of the night with no ring data at all.
@immutable
class SleepGap {
  const SleepGap({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  int get seconds => to.difference(from).inSeconds;

  @override
  bool operator ==(Object other) =>
      other is SleepGap && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'SleepGap($from → $to)';
}

/// What the unlabelled minutes of a night turned out to be.
@immutable
class SleepGapSplit {
  const SleepGapSplit({
    required this.unstagedSeconds,
    required this.notRecordedSeconds,
    required this.notRecorded,
  });

  static const empty = SleepGapSplit(
    unstagedSeconds: 0,
    notRecordedSeconds: 0,
    notRecorded: <SleepGap>[],
  );

  /// Unlabelled time the ring was measuring through: sleep, unstaged.
  final int unstagedSeconds;

  /// Unlabelled time with no readings at all. Not sleep, not awake.
  final int notRecordedSeconds;

  /// Where those stretches were, so the sleep screen can say
  /// "The ring recorded nothing 03:12–03:52" rather than leaving a hole.
  final List<SleepGap> notRecorded;

  bool get isEmpty => unstagedSeconds == 0 && notRecordedSeconds == 0;
}

/// A span of the night the ring did label.
@immutable
class SleepSpan {
  const SleepSpan({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

/// Works out what the unlabelled minutes between [windowStart] and
/// [windowEnd] were.
///
/// [labelled] are the spans the ring staged or called awake, in any order
/// and possibly overlapping. [measuring] answers whether the ring was
/// taking readings across a given stretch — in the app, whether any heart
/// rate landed in it.
///
/// A gap is split at the boundaries where [measuring] changes, by walking
/// it in [probe] steps. Stepping rather than scanning the readings keeps
/// this independent of how heart rate is stored, which is what lets it be
/// tested without a ring; five minutes is finer than any gap worth naming
/// and coarse enough that a nine-hour night is a few hundred checks.
SleepGapSplit splitSleepGaps({
  required DateTime windowStart,
  required DateTime windowEnd,
  required List<SleepSpan> labelled,
  required bool Function(DateTime from, DateTime to) measuring,
  Duration probe = const Duration(minutes: 5),
}) {
  if (!windowEnd.isAfter(windowStart)) return SleepGapSplit.empty;

  final merged = _mergeSpans(labelled, windowStart, windowEnd);
  var unstaged = 0;
  var notRecorded = 0;
  final gaps = <SleepGap>[];

  void classify(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return;
    // Walk the gap, grouping neighbouring steps that agree.
    DateTime? runStart;
    var runMeasuring = false;
    var cursor = from;
    while (cursor.isBefore(to)) {
      var next = cursor.add(probe);
      if (next.isAfter(to)) next = to;
      final isMeasuring = measuring(cursor, next);
      if (runStart == null) {
        runStart = cursor;
        runMeasuring = isMeasuring;
      } else if (isMeasuring != runMeasuring) {
        final seconds = cursor.difference(runStart).inSeconds;
        if (runMeasuring) {
          unstaged += seconds;
        } else {
          notRecorded += seconds;
          gaps.add(SleepGap(from: runStart, to: cursor));
        }
        runStart = cursor;
        runMeasuring = isMeasuring;
      }
      cursor = next;
    }
    if (runStart != null) {
      final seconds = to.difference(runStart).inSeconds;
      if (runMeasuring) {
        unstaged += seconds;
      } else {
        notRecorded += seconds;
        gaps.add(SleepGap(from: runStart, to: to));
      }
    }
  }

  var cursor = windowStart;
  for (final span in merged) {
    classify(cursor, span.from);
    if (span.to.isAfter(cursor)) cursor = span.to;
  }
  classify(cursor, windowEnd);

  return SleepGapSplit(
    unstagedSeconds: unstaged,
    notRecordedSeconds: notRecorded,
    notRecorded: List.unmodifiable(gaps),
  );
}

/// Overlapping and touching spans joined, clipped to the night, in order.
List<SleepSpan> _mergeSpans(
  List<SleepSpan> spans,
  DateTime windowStart,
  DateTime windowEnd,
) {
  final clipped = <SleepSpan>[];
  for (final span in spans) {
    final from = span.from.isBefore(windowStart) ? windowStart : span.from;
    final to = span.to.isAfter(windowEnd) ? windowEnd : span.to;
    if (to.isAfter(from)) clipped.add(SleepSpan(from: from, to: to));
  }
  clipped.sort((a, b) => a.from.compareTo(b.from));

  final out = <SleepSpan>[];
  for (final span in clipped) {
    if (out.isEmpty || span.from.isAfter(out.last.to)) {
      out.add(span);
      continue;
    }
    if (span.to.isAfter(out.last.to)) {
      out[out.length - 1] = SleepSpan(from: out.last.from, to: span.to);
    }
  }
  return out;
}

/// "Not recorded · 40m", for the breakdown.
String notRecordedLabel(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return 'Not recorded · ${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? 'Not recorded · ${hours}h'
      : 'Not recorded · ${hours}h ${rest.toString().padLeft(2, '0')}m';
}

/// Item 105: the unlabelled sleep in a night, by the agreed rule.
///
/// Sleep length is fell asleep to woke up, minus awake, minus not recorded
/// (decided 14 Nov). Item 92 counted the gaps *between* records, but each
/// record was still counted as its stages, so a record whose stages did not
/// cover its own span lost those minutes. Taking the span and subtracting
/// is what counts them: whatever is neither staged, awake nor not recorded
/// is sleep the ring did not stage. Never negative, because overlapping
/// records can stage more than the span.
int unlabelledSleepSeconds({
  required int spanSeconds,
  required int stagedSeconds,
  required int awakeSeconds,
  required int notRecordedSeconds,
}) {
  final rest = spanSeconds - stagedSeconds - awakeSeconds - notRecordedSeconds;
  return rest < 0 ? 0 : rest;
}

/// Item 105: where in the night the unstaged sleep is, for the stage chart
/// to draw in a neutral tone: everything between [windowStart] and
/// [windowEnd] that no [labelled] span covers and is not [notRecorded].
List<SleepSpan> unlabelledSleepSpans({
  required DateTime windowStart,
  required DateTime windowEnd,
  required List<SleepSpan> labelled,
  List<SleepGap> notRecorded = const [],
}) {
  if (!windowEnd.isAfter(windowStart)) return const [];
  final covered = _mergeSpans(
    [
      ...labelled,
      for (final gap in notRecorded) SleepSpan(from: gap.from, to: gap.to),
    ],
    windowStart,
    windowEnd,
  );
  final out = <SleepSpan>[];
  var cursor = windowStart;
  for (final span in covered) {
    if (span.from.isAfter(cursor)) {
      out.add(SleepSpan(from: cursor, to: span.from));
    }
    if (span.to.isAfter(cursor)) cursor = span.to;
  }
  if (windowEnd.isAfter(cursor)) out.add(SleepSpan(from: cursor, to: windowEnd));
  return out;
}
