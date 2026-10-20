part of '../../main.dart';

/// Bug 14(d): the ring sometimes ends the night at a brief waking and records
/// nothing after it, so a night the user slept on through is cut short.
///
/// The correction is one question, asked once per night, and only where the
/// ring's own data supports it ([sleptOnAfter]). There is deliberately no
/// manual editing of sleep times and no confirmation on normal nights: a
/// wearable that asks you to check its work every morning is worse than one
/// that is occasionally wrong.
class SleepExtensionState {
  const SleepExtensionState({this.extendedTo = const {}, this.declined = const {}});

  /// Sleep day → the end the user confirmed.
  final Map<DateTime, DateTime> extendedTo;

  /// Sleep days where the user said no. The night stands as the ring had it.
  final Set<DateTime> declined;

  /// Whether this night still has a question to ask.
  bool isAnswered(DateTime day) =>
      extendedTo.containsKey(day) || declined.contains(day);
}

class SleepExtensionController extends StateNotifier<SleepExtensionState> {
  SleepExtensionController() : super(const SleepExtensionState()) {
    unawaited(_load());
  }

  static const _extendedKey = 'vyana.sleep.extendedTo.v1';
  static const _declinedKey = 'vyana.sleep.declined.v1';

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final extended = <DateTime, DateTime>{};
    for (final entry in prefs.getStringList(_extendedKey) ?? const <String>[]) {
      // `2026-10-21|2026-10-21T10:05:00.000`
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      final day = _parseDay(parts[0]);
      final end = DateTime.tryParse(parts[1]);
      if (day != null && end != null) extended[day] = end;
    }
    final declined = <DateTime>{
      for (final s in prefs.getStringList(_declinedKey) ?? const <String>[])
        ?_parseDay(s),
    };
    state = SleepExtensionState(extendedTo: extended, declined: declined);
    _publish();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_extendedKey, [
      for (final e in state.extendedTo.entries)
        '${_dayKey(e.key)}|${e.value.toIso8601String()}',
    ]);
    await prefs.setStringList(_declinedKey, [
      for (final d in state.declined) _dayKey(d),
    ]);
    _publish();
  }

  /// Pushes into the global every sleep computation reads, so Home, Metrics,
  /// the bases and the patterns all see the same night.
  void _publish() => sleepNightExtensions = Map.of(state.extendedTo);

  /// "Yes, until 10:05" — the night runs to [end], stored as unstaged sleep.
  Future<void> extend(DateTime day, DateTime end) async {
    final key = DateTime(day.year, day.month, day.day);
    state = SleepExtensionState(
      extendedTo: {...state.extendedTo, key: end},
      declined: {...state.declined}..remove(key),
    );
    await _persist();
  }

  /// "No" — the ring's night stands, and the question is not asked again.
  Future<void> decline(DateTime day) async {
    final key = DateTime(day.year, day.month, day.day);
    state = SleepExtensionState(
      extendedTo: {...state.extendedTo}..remove(key),
      declined: {...state.declined, key},
    );
    await _persist();
  }
}

final sleepExtensionProvider =
    StateNotifierProvider<SleepExtensionController, SleepExtensionState>(
  (_) => SleepExtensionController(),
);
