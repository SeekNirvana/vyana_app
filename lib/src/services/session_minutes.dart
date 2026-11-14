/// Item 80 — how long a session was, answered the same way everywhere.
///
/// Four screens counted it four ways. The summary excluded pauses, because
/// it read the live timer. "Last 7 days", "Your practice", "Done today" and
/// the history list all used `endedAt - startedAt`, which counts the pause
/// — so a run with a ten-minute stop at a crossing was ten minutes longer
/// on three screens than in its own summary.
///
/// Two smaller faults rode along. `.inMinutes` truncates, so three
/// fifty-second sessions summed to "0m": not short, but worth nothing. And
/// the history list grouped by start time while the week grouped by end
/// time, so a session begun at 23:50 and finished at 00:10 was on Tuesday
/// in one place and Wednesday in the other.
///
/// The active seconds are already written into each session's summary as
/// `durationSec`; nothing read them. These functions do, with
/// `endedAt - startedAt` as the fallback for a session saved before this or
/// recovered after a crash, where no pause record survives.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The `durationSec` a session recorded, or null when it has none.
///
/// Returns null rather than zero for a missing or unreadable summary, so
/// the caller falls back to the clock instead of reporting a real session
/// as having taken no time.
int? storedActiveSeconds(String? summaryJson) {
  if (summaryJson == null || summaryJson.isEmpty) return null;
  try {
    final decoded = jsonDecode(summaryJson);
    if (decoded is! Map) return null;
    final value = decoded['durationSec'];
    if (value is int) return value < 0 ? null : value;
    if (value is num) {
      final seconds = value.round();
      return seconds < 0 ? null : seconds;
    }
    return null;
  } on Object catch (error) {
    debugPrint('[SessionMinutes] could not read durationSec: $error');
    return null;
  }
}

/// How long a session was actually running.
///
/// Prefers the recorded active seconds; falls back to the wall clock. A
/// session still in progress ([endedAt] null, no stored duration) is zero,
/// because nothing has been recorded about it yet.
int sessionSeconds({
  required String? summaryJson,
  required DateTime startedAt,
  DateTime? endedAt,
}) {
  final stored = storedActiveSeconds(summaryJson);
  if (stored != null) return stored;
  if (endedAt == null) return 0;
  final seconds = endedAt.difference(startedAt).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// The same, in whole minutes.
///
/// Rounded, not truncated: a fifty-second session is a minute's worth of
/// someone's day, and three of them truncating to zero is how "0m" came to
/// stand for "you did nothing".
int sessionMinutes({
  required String? summaryJson,
  required DateTime startedAt,
  DateTime? endedAt,
}) {
  final seconds = sessionSeconds(
    summaryJson: summaryJson,
    startedAt: startedAt,
    endedAt: endedAt,
  );
  return (seconds / 60).round();
}

/// A total of minutes, as it is shown.
///
/// `under 1m` rather than `0m` for anything above zero: a short practice
/// was still done, and a screen saying 0 about it is simply wrong.
String minutesLabel(int minutes, {int? seconds}) {
  if (minutes > 0) return '${minutes}m';
  final left = seconds ?? 0;
  if (left > 0) return 'under 1m';
  return '0m';
}

/// Which day a session belongs to.
///
/// By the time it started. The history list already grouped this way and
/// the week grouped by end time, so a session begun at 23:50 and finished
/// at 00:10 appeared on different days in different places. Start is the
/// honest answer to "when did you practise": it is the day someone chose
/// and the day they remember.
DateTime sessionDay(DateTime startedAt) =>
    DateTime(startedAt.year, startedAt.month, startedAt.day);

/// How many whole days back from [today] a session sits, or null when it is
/// outside the window.
///
/// Shared so that a window of seven days means the same seven days on every
/// screen that offers one.
int? daysBack({
  required DateTime startedAt,
  required DateTime today,
  required int window,
}) {
  final day = sessionDay(startedAt);
  final from = DateTime(today.year, today.month, today.day);
  final back = from.difference(day).inDays;
  if (back < 0 || back >= window) return null;
  return back;
}
