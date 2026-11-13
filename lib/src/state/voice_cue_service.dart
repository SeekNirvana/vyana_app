part of '../../main.dart';

/// Speaks session voice cues (no network, no mic). The cue banner is driven
/// separately by [SessionController.activeCue]; this just vocalises the line.
///
/// Cues speak with Kokoro, like everything else Vyana says out loud. They
/// used to go through the phone's own text-to-speech, which meant a breath
/// session could be counted down by a screen-reader voice on one phone and
/// by a decent one on another. Without the voice installed a cue is silent
/// — the banner already carries the words.
class VoiceCueService {
  final AudioRouteService _audio = AudioRouteService.instance;

  /// Slightly under normal pace: a cue lands mid-breath, not mid-sentence.
  static const double _cueRate = 0.92;

  bool get isAvailable => NovaVoiceService.instance.isReady;

  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    if (!await NovaVoiceService.instance.ensureLoaded()) {
      debugPrint('VOICE_CUE skipped: Nova\'s voice is not installed');
      return;
    }

    try {
      await _audio.preparePlayback();
      await NovaVoiceService.instance.speak(normalized, rate: _cueRate);
    } on Object catch (e) {
      debugPrint('VOICE_CUE failed: $e');
      rethrow;
    }
  }

  /// Quick check from You → Voice cues that playback is routed correctly.
  Future<void> preview() {
    return speak(
      'Voice cues are on. You\'ll hear guidance during breath, rest, and movement sessions.',
    );
  }

  Future<void> stop() => NovaVoiceService.instance.stop();
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
