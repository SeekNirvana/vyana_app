part of '../../main.dart';

/// Computed weekly metrics from the local vault. The "north-star" correlation
/// (activity ↔ sleep/HRV over weeks) needs accumulated history to be
/// meaningful, so the engine computes what it reliably can from this week's
/// sessions (active days, training load, calm minutes) and leaves the
/// longer-horizon narrative to the seed until enough data exists.
class WeeklyComputed {
  const WeeklyComputed({
    required this.sessionCount,
    required this.activeDays,
    required this.loadByDay,
    required this.calmMinutes,
    required this.avgHr,
  });

  final int sessionCount;
  final int activeDays;

  /// Minutes of session per weekday, Mon(0)…Sun(6).
  final List<int> loadByDay;
  final int calmMinutes;
  final int? avgHr;

  bool get hasData => sessionCount > 0;
}

class CorrelationEngine {
  CorrelationEngine._();

  /// Reduces this week's sessions (Mon-anchored) into [WeeklyComputed].
  static WeeklyComputed weekly(List<SessionRow> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday as the start of the week.
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final loadByDay = List<int>.filled(7, 0);
    final activeDayKeys = <int>{};
    var calmMinutes = 0;
    var count = 0;
    var hrSum = 0;
    var hrCount = 0;

    for (final s in sessions) {
      final started = s.startedAt;
      if (started.isBefore(weekStart)) continue;
      final weekday = started.weekday - 1; // 0..6
      if (weekday < 0 || weekday > 6) continue;

      final ended = s.endedAt ?? started;
      final minutes = ended.difference(started).inMinutes.clamp(0, 600);
      loadByDay[weekday] += minutes;
      activeDayKeys.add(weekday);
      count++;
      if (s.category == 'mind' || s.category == 'wellness') {
        calmMinutes += minutes;
      }
      final avg = _summaryInt(s.summaryJson, 'avgHr');
      if (avg != null) {
        hrSum += avg;
        hrCount++;
      }
    }

    return WeeklyComputed(
      sessionCount: count,
      activeDays: activeDayKeys.length,
      loadByDay: loadByDay,
      calmMinutes: calmMinutes,
      avgHr: hrCount == 0 ? null : (hrSum / hrCount).round(),
    );
  }

  static int? _summaryInt(String? summaryJson, String key) {
    if (summaryJson == null) return null;
    try {
      final map = jsonDecode(summaryJson);
      if (map is Map && map[key] is num) return (map[key] as num).round();
    } on Object {
      return null;
    }
    return null;
  }
}

/// Recomputes whenever the vault changes (watchSessions drives it).
final weeklyComputedProvider = StreamProvider<WeeklyComputed>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchSessions().map(CorrelationEngine.weekly);
});
