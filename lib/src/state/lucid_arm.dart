part of '../../main.dart';

/// The overnight handoff from the Lucid Dreaming practice to the Journal.
///
/// Completing the practice at 22:40 arms the next morning's wake capture,
/// which switches to "Did you catch it?", timestamps the attempt and softens
/// the ask. Saving a dream — or 18 hours passing — disarms it.
class LucidArmedController extends StateNotifier<DateTime?> {
  LucidArmedController() : super(null) {
    unawaited(_load());
  }

  static const _key = 'vyana.lucid.armed_at';
  static const _window = Duration(hours: 18);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final at = raw == null ? null : DateTime.tryParse(raw);
    if (at == null) return;
    if (DateTime.now().difference(at) > _window) {
      await prefs.remove(_key);
      return;
    }
    if (mounted) state = at;
  }

  Future<void> arm([DateTime? at]) async {
    final when = at ?? DateTime.now();
    state = when;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, when.toIso8601String());
  }

  Future<void> disarm() async {
    if (state == null) return;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// True while an attempt from last night is still waiting for its dream.
  bool get isArmed {
    final at = state;
    return at != null && DateTime.now().difference(at) <= _window;
  }
}

final lucidArmedProvider =
    StateNotifierProvider<LucidArmedController, DateTime?>(
  (_) => LucidArmedController(),
);
