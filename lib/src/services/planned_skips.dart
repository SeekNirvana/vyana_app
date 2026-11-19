/// Item 94 — "Not today" on a planned practice.
///
/// A planned practice stays on Home until it is done or 22:00 (item 46).
/// The only way to change it was editing My week, which changes it every
/// week — so someone who simply could not run today had the choice of
/// looking at it until the evening or rewriting their week.
///
/// A skip is for one day. It is stored per date and ignored from the next
/// day, so the plan itself is never touched: the question "do I run on
/// Tuesdays" and the question "am I running today" are different
/// questions, and only the second one is being answered.
library;

import 'package:flutter/foundation.dart';

/// The preferences key holding the practices skipped on [day].
///
/// Keyed by date rather than one rolling list, so yesterday's skips expire
/// by never being read again — no cleanup pass, and nothing to go wrong if
/// the app is not opened for a week.
String plannedSkipKeyFor(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return 'vyana.plan.skipped.${day.year}-$month-$date';
}

/// Which planned practice is on offer, given what is done and what is
/// skipped.
///
/// Returns the first planned id that is neither, or null when the day's
/// plan is used up — at which point Home falls back to the ordinary
/// suggestion for the time of day.
String? firstUnskippedPlanned({
  required List<String> plannedIds,
  required Set<String> done,
  required Set<String> skipped,
}) {
  for (final id in plannedIds) {
    if (done.contains(id)) continue;
    if (skipped.contains(id)) continue;
    return id;
  }
  return null;
}

/// How a skipped practice is described to Nova.
///
/// Item 94: she is told, because a plan the person has stood down from is
/// not a plan they are ignoring, and Nova asking why they have not walked
/// yet would be reading the day wrong.
String plannedSkippedPhrase(String activityName) =>
    '$activityName (skipped today)';

/// One day's skips, with the day they belong to.
@immutable
class PlannedSkips {
  const PlannedSkips({required this.day, required this.activityIds});

  const PlannedSkips.none(this.day) : activityIds = const <String>{};

  final DateTime day;
  final Set<String> activityIds;

  bool holds(String activityId) => activityIds.contains(activityId);

  PlannedSkips plus(String activityId) => PlannedSkips(
        day: day,
        activityIds: {...activityIds, activityId},
      );

  PlannedSkips minus(String activityId) => PlannedSkips(
        day: day,
        activityIds: {...activityIds}..remove(activityId),
      );

  /// Whether these skips are still about today.
  ///
  /// Read as well as written, because the app can be left open across
  /// midnight — a skip made at 23:50 must not be holding at 00:10.
  bool appliesOn(DateTime now) =>
      day.year == now.year && day.month == now.month && day.day == now.day;

  /// The practices skipped for [now]'s day: these, or none once the day
  /// has turned over.
  Set<String> skippedOn(DateTime now) =>
      appliesOn(now) ? activityIds : const <String>{};
}
