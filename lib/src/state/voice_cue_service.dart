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

  /// How long an ordinary cue may wait for the one before it to finish.
  static const Duration _defaultWait = Duration(seconds: 4);

  bool get isAvailable => NovaVoiceService.instance.isReady;

  /// Item 130: cues play one after another, never over each other. A new
  /// cue used to stop the one playing, so a short hold cut "Breathe in"
  /// off mid-word.
  Future<void> _chain = Future<void>.value();

  /// Bumped by [stop], so cues already waiting are dropped with it.
  int _epoch = 0;

  /// Item 130: generates [phrases] ahead of time so each plays the moment
  /// it is asked for. Done before a pacer starts: generation holds up the
  /// main isolate while it runs, and inside a running pacer that is the
  /// stall that made the countdown drift.
  Future<void> prepare(Iterable<String> phrases) async {
    if (!await NovaVoiceService.instance.ensureLoaded()) return;
    for (final phrase in phrases) {
      final text = phrase.trim();
      if (text.isEmpty) continue;
      await NovaVoiceService.instance.prepare(text, rate: _cueRate);
    }
  }

  /// Whether [text] is ready to play at once.
  bool isPrepared(String text) =>
      NovaVoiceService.instance.isPrepared(text.trim(), rate: _cueRate);

  /// Speaks [text] once the cue before it has finished.
  ///
  /// Item 130: [within] is how long it may wait for that. A pacer passes
  /// the length of the phase the cue belongs to, so a cue that could not
  /// start inside its own phase is dropped rather than heard late, and
  /// never cuts the one before it.
  Future<void> speak(String text, {Duration? within}) {
    final normalized = text.trim();
    if (normalized.isEmpty) return Future<void>.value();
    final deadline = DateTime.now().add(within ?? _defaultWait);
    final epoch = _epoch;
    final run = _chain.then((_) async {
      if (epoch != _epoch) return;
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('VOICE_CUE dropped, too late for its phase: $normalized');
        return;
      }
      await _speakNow(normalized);
    }).catchError((Object e) {
      debugPrint('VOICE_CUE failed: $e');
    });
    _chain = run;
    return run;
  }

  Future<void> _speakNow(String text) async {
    if (!await NovaVoiceService.instance.ensureLoaded()) {
      debugPrint('VOICE_CUE skipped: Nova\'s voice is not installed');
      return;
    }
    await _audio.preparePlayback();
    await NovaVoiceService.instance.speak(text, rate: _cueRate);
  }

  /// Quick check from You → Voice cues that playback is routed correctly.
  Future<void> preview() {
    return speak(
      'Voice cues are on. You\'ll hear guidance during breath, rest, and movement sessions.',
      within: const Duration(seconds: 10),
    );
  }

  Future<void> stop() {
    _epoch++;
    return NovaVoiceService.instance.stop();
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

/// Item 98: whether the one-time download question has been asked.
const String kVoiceCueDownloadAskedKey = 'vyana.voice_cues.download_asked';

/// The question's title, with the size from the one place it is kept.
String novaVoiceForCuesTitle(String size) =>
    "Download Nova's voice ($size) for spoken cues";

/// Item 98 (decided 16 Nov): ask people to download the voice rather than
/// fall back to another one. The first time a practice with voice cues
/// starts and the voice is not installed, ask once — Download or Not now.
/// Never asked again; You → Voice cues offers the download after that.
/// Until it is installed, cues show as text on screen.
Future<void> maybeOfferNovaVoiceForCues(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(voiceCuesEnabledProvider)) return;
  if (!novaVoiceConfigured) return;
  if (NovaVoiceService.instance.isReady || await novaVoiceIsReady()) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kVoiceCueDownloadAskedKey) ?? false) return;
  await prefs.setBool(kVoiceCueDownloadAskedKey, true);
  if (!context.mounted) return;
  final voice = ref.read(guideVoiceServiceProvider);
  final download = await showVyanaConfirmDialog<bool>(
    context: context,
    title: novaVoiceForCuesTitle(voice.novaVoiceDownloadSize),
    message: 'Until it is installed, cues show as text on screen. It is a '
        'large download, so Wi-Fi is best.',
    confirmLabel: 'Download',
    cancelLabel: 'Not now',
  );
  if (download == true) unawaited(voice.downloadNovaVoiceModel());
}
