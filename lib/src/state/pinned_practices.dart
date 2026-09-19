part of '../../main.dart';

/// The user's own pinned set on the Practice tab. Colour is assigned by pin
/// slot from a fixed palette — "this one is yours" — never by activity type.
class PinnedPracticesController extends StateNotifier<List<String>> {
  PinnedPracticesController() : super(const []) {
    unawaited(_load());
  }

  static const _key = 'vyana.practice.pins';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? const [];
    if (mounted) {
      state = stored.where((id) => activityById(id) != null).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }

  bool isPinned(String id) => state.contains(id);

  Future<void> pin(String id) async {
    if (state.contains(id)) return;
    state = [...state, id];
    await _persist();
  }

  Future<void> unpin(String id) async {
    if (!state.contains(id)) return;
    state = [for (final s in state) if (s != id) s];
    await _persist();
  }

  Future<void> toggle(String id) => isPinned(id) ? unpin(id) : pin(id);

  /// Move a pin to a new slot (edit mode drag); [newIndex] is the final slot.
  /// Colours follow the slot, so reordering also recolours — that is the
  /// point of slot-based hues.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    final target = newIndex.clamp(0, state.length - 1);
    if (target == oldIndex) return;
    final next = [...state];
    final id = next.removeAt(oldIndex);
    next.insert(target, id);
    state = next;
    await _persist();
  }
}

final pinnedPracticesProvider =
    StateNotifierProvider<PinnedPracticesController, List<String>>(
  (_) => PinnedPracticesController(),
);

/// Recent finished sessions, newest first, for pin metadata and history.
final recentSessionsProvider = StreamProvider<List<SessionRow>>(
  (ref) => ref.watch(databaseProvider).watchSessions(),
);

/// "SUN 32M · 129BPM" — day · duration · average HR, the shape every practice
/// can report because the ring derives HR for any activity. Null when the
/// practice has never been done.
String? pinMetaFor(List<SessionRow> sessions, String activityId) {
  for (final s in sessions) {
    if (s.vyanaActivityType != activityId || s.endedAt == null) continue;
    final day = const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][
        s.startedAt.weekday - 1];
    final minutes = s.endedAt!.difference(s.startedAt).inMinutes;
    int? avgHr;
    final raw = s.summaryJson;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final v = decoded['avgHr'];
          if (v is num && v > 0) avgHr = v.round();
        }
      } catch (_) {}
    }
    final parts = ['$day ${minutes}M', if (avgHr != null) '${avgHr}BPM'];
    return parts.join(' · ');
  }
  return null;
}
