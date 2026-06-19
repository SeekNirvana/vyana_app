part of '../../main.dart';

/// Speaks session voice cues via on-device TTS (no network, no mic). The cue
/// banner is driven separately by [SessionController.activeCue]; this just
/// vocalises the line.
class VoiceCueService {
  final AppTtsService _tts = AppTtsService.instance;

  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    try {
      _tts.rebindMethodChannel();
      await _tts.preparePlayback(speechRate: 0.46);
      await _tts.tts.setVolume(0.9);
      await _tts.tts.speak(normalized, focus: true);
    } on Object catch (e) {
      debugPrint('VOICE_CUE tts failed: $e');
      rethrow;
    }
  }

  /// Quick check from You → Voice cues that TTS is routed correctly.
  Future<void> preview() {
    return speak(
      'Voice cues are on. You\'ll hear guidance during breath, rest, and movement sessions.',
    );
  }

  Future<void> stop() async {
    try {
      await _tts.tts.stop();
    } on Object {
      // ignore
    }
  }
}

final voiceCueServiceProvider = Provider<VoiceCueService>((ref) {
  final service = VoiceCueService();
  ref.onDispose(service.stop);
  return service;
});

/// Whether spoken cues are enabled (persisted, on by default).
class VoiceCuesController extends StateNotifier<bool> {
  VoiceCuesController() : super(true) {
    _load();
  }
  static const _key = 'vyana_voice_cues_enabled';
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final voiceCuesEnabledProvider =
    StateNotifierProvider<VoiceCuesController, bool>(
  (ref) => VoiceCuesController(),
);
