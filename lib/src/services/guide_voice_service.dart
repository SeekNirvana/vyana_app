import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import 'package:whisper_ggml_plus_ffmpeg/whisper_ggml_plus_ffmpeg.dart';

import '../data/db.dart';
import 'audio_route_service.dart';
import 'guide_model_manager.dart';
import 'nova_voice_assets.dart';
import 'nova_voice_service.dart';

@immutable
class GuideVoiceOption {
  final Map<String, String> raw;
  final String name;
  final String locale;
  final String? identifier;
  final String? gender;
  final String? quality;

  const GuideVoiceOption({
    required this.raw,
    required this.name,
    required this.locale,
    this.identifier,
    this.gender,
    this.quality,
  });

  String get stableId => identifier ?? '$name::$locale';

  /// Nova's own Kokoro voice — the only entry there is. It carries a
  /// reserved identifier so a voice stored by an older build, which would
  /// have been a system voice, resolves to nothing rather than to this.
  static const String kNovaIdentifier = 'vyana::nova::kokoro';

  static const GuideVoiceOption nova = GuideVoiceOption(
    raw: {'identifier': kNovaIdentifier},
    name: "Nova's voice",
    locale: 'en-US',
    identifier: kNovaIdentifier,
    quality: 'On this phone',
  );

  bool get isNovaVoice => identifier == kNovaIdentifier;

  String get label {
    final parts = <String>[name];
    if (locale.isNotEmpty) {
      parts.add(locale);
    }
    if (quality != null && quality!.isNotEmpty) {
      parts.add(quality!);
    }
    return parts.join(' · ');
  }
}

/// "Vani Voice" — fully offline speech for the guides: whisper.cpp speech-to-text
/// for voice prompts plus on-device text-to-speech for spoken replies. The
/// speech model is downloaded on demand (it is not fetched at app start).
class GuideVoiceService extends ChangeNotifier {
  static const _voiceResponsesEnabledKey = 'guide_voice_responses_enabled_v1';
  static const _selectedVoiceJsonKey = 'guide_selected_voice_json_v1';
  static const _whisperModelKey = 'guide_whisper_model_v1';

  static bool _ffmpegConverterRegistered = false;

  final GuideModelManager _modelManager;
  final VyanaDatabase _db;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioRouteService _ttsEngine = AudioRouteService.instance;

  Future<void>? _initFuture;
  Future<void>? _speakReadyFuture;
  bool _voiceResponsesEnabled = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isSpeaking = false;
  bool _isPreparingWhisperModel = false;
  bool _isProcessingQueue = false;
  bool _whisperReady = false;
  double _whisperDownloadProgress = 0;
  final List<String> _speakQueue = [];
  String? _activeRecordingPath;
  String? _lastError;
  WhisperModel _whisperModel = WhisperModel.tiny;
  GuideVoiceOption? _selectedVoice;
  bool _novaVoiceReady = false;
  bool _novaVoiceDownloading = false;
  double _novaVoiceDownloadProgress = 0;

  GuideVoiceService({
    required GuideModelManager modelManager,
    required VyanaDatabase db,
  })  : _modelManager = modelManager,
        _db = db;

  bool get voiceResponsesEnabled => _voiceResponsesEnabled;
  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;
  bool get isSpeaking => _isSpeaking;
  bool get isPreparingWhisperModel => _isPreparingWhisperModel;
  bool get whisperModelReady => _whisperReady;
  double get whisperDownloadProgress => _whisperDownloadProgress;
  bool get isBusy => _isRecording || _isTranscribing;
  String? get lastError => _lastError;
  WhisperModel get whisperModel => _whisperModel;
  /// Nova's own voice, or nothing.
  ///
  /// The system voices used to follow it here as a fallback. They are gone:
  /// `flutter_tts` is only ever as good as the engine the phone happens to
  /// have, and on a phone without Google services — which is every install
  /// we cannot assume, since Vyana ships through the dApp Store — that is
  /// the flat screen-reader voice nobody wants to hear guidance in. Reading
  /// aloud is now Kokoro or silence, and silence says why.
  List<GuideVoiceOption> get voices => [
        if (_novaVoiceReady) GuideVoiceOption.nova,
      ];

  /// Whether Nova's Kokoro voice is installed, verified and loaded.
  bool get novaVoiceReady => _novaVoiceReady;

  /// Why Nova is using a system voice, when she is and it is not simply that
  /// the user chose one.
  String? get novaVoiceError => NovaVoiceService.instance.lastError;
  GuideVoiceOption? get selectedVoice => _selectedVoice;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  /// TTS playback does not require the Whisper model — only voice prefs and the
  /// shared on-device engine.
  Future<void> _ensureSpeakReady() {
    return _speakReadyFuture ??= _prepareSpeakEngine();
  }

  Future<void> _prepareSpeakEngine() async {
    String? pendingVoiceJson;
    if (_initFuture == null) {
      final prefs = await SharedPreferences.getInstance();
      final voicePrefs = await _loadVoicePrefs(prefs);
      _voiceResponsesEnabled = voicePrefs?.voiceResponsesEnabled ?? true;
      pendingVoiceJson = voicePrefs?.selectedVoiceJson;
    } else {
      await init();
    }

    await _ttsEngine.prepareGuideSpeech();
    await _ensureNovaVoice();

    if (_selectedVoice == null &&
        pendingVoiceJson != null &&
        pendingVoiceJson.isNotEmpty) {
      _selectedVoice = _voiceFromStoredJson(pendingVoiceJson);
    }
    _selectedVoice ??= _defaultVoiceOption();
  }

  Future<void> _initialize() async {
    await _modelManager.init();
    _registerWhisperConverter();

    final prefs = await SharedPreferences.getInstance();
    final voicePrefs = await _loadVoicePrefs(prefs);
    _voiceResponsesEnabled = voicePrefs?.voiceResponsesEnabled ?? true;

    final savedModel = prefs.getString(_whisperModelKey);
    final parsedModel = WhisperModel.values.where((model) {
      return model.name == savedModel;
    });
    if (parsedModel.isNotEmpty) {
      _whisperModel = parsedModel.first;
    }

    await _ensureNovaVoice();

    try {
      final path = await whisperModelPath();
      if (await File(path).exists() && !await validateWhisperModelFile(path)) {
        await File(path).delete();
      }
      _whisperReady = await isWhisperModelReady();
    } catch (_) {
      _whisperReady = false;
    }

    // Match SeekNirvana mobile-app: prefetch whisper in the background so STT
    // is ready when the user taps the guide mic (still overridable in library).
    unawaited(() async {
      try {
        if (_whisperReady) return;
        await _preloadWhisperModel(notify: false);
      } catch (_) {
        // Surface via lastError / library UI without blocking app init.
      }
    }());

    final selectedVoiceJson = voicePrefs?.selectedVoiceJson;
    if (selectedVoiceJson != null && selectedVoiceJson.isNotEmpty) {
      _selectedVoice = _voiceFromStoredJson(selectedVoiceJson);
    }

    _selectedVoice ??= _defaultVoiceOption();
    if (_selectedVoice != null) {
      await _persistVoicePrefs(notify: false);
    }
    notifyListeners();
  }

  Future<GuideVoicePrefRow?> _loadVoicePrefs(SharedPreferences legacyPrefs) async {
    var row = await _db.getGuideVoicePrefs();
    if (row != null) {
      return row;
    }

    final legacyVoice = legacyPrefs.getString(_selectedVoiceJsonKey);
    final legacyEnabled =
        legacyPrefs.getBool(_voiceResponsesEnabledKey) ?? false;
    if (legacyVoice == null && !legacyEnabled) {
      return null;
    }

    await _db.upsertGuideVoicePrefs(
      selectedVoiceJson: legacyVoice,
      voiceResponsesEnabled: legacyEnabled,
    );
    return _db.getGuideVoicePrefs();
  }

  GuideVoiceOption? _voiceFromStoredJson(String json) {
    try {
      final rawVoice = Map<String, dynamic>.from(jsonDecode(json) as Map);
      final stableId = _stableVoiceId(rawVoice);
      // Bug 42: Nova's own voice is stored like any other choice, but it is
      // not in the system list, so it is matched first.
      // A stored system voice from an older build resolves to nothing, so
      // the user lands on Nova's voice — or on the prompt to install it.
      if (stableId == GuideVoiceOption.kNovaIdentifier) {
        return _novaVoiceReady ? GuideVoiceOption.nova : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistVoicePrefs({bool notify = true}) async {
    final selected = _selectedVoice;
    // Nova's voice is the only one there is, so it is the only one stored.
    final persistable =
        selected != null && selected.isNovaVoice ? jsonEncode(selected.raw) : null;
    await _db.upsertGuideVoicePrefs(
      selectedVoiceJson: persistable,
      voiceResponsesEnabled: _voiceResponsesEnabled,
    );
    if (notify) {
      notifyListeners();
    }
  }

  void _registerWhisperConverter() {
    if (_ffmpegConverterRegistered) {
      return;
    }
    WhisperFFmpegConverter.register();
    _ffmpegConverterRegistered = true;
  }

  /// Bug 42: loads Kokoro if its pinned files are present and verified. A
  /// missing, half-downloaded or failed voice simply leaves [_novaVoiceReady]
  /// false, and the best offline system voice takes over.
  Future<void> _ensureNovaVoice() async {
    if (!novaVoiceConfigured) {
      _novaVoiceReady = false;
      return;
    }
    try {
      _novaVoiceReady = await NovaVoiceService.instance.ensureLoaded();
    } on Object catch (error) {
      debugPrint('[GuideVoice] Nova voice unavailable: $error');
      _novaVoiceReady = false;
    }
  }

  /// Whether this build has a voice to fetch at all. False until the Kokoro
  /// release is mirrored and pinned; the UI says so rather than offering a
  /// download that cannot start.
  bool get novaVoiceAvailableToInstall => novaVoiceConfigured;

  bool get isDownloadingNovaVoice => _novaVoiceDownloading;
  double get novaVoiceDownloadProgress => _novaVoiceDownloadProgress;

  /// What the install prompt should say it will cost. One source, so the
  /// button and the progress bar cannot disagree.
  String get novaVoiceDownloadSize => novaVoiceApproxSizeLabel;

  /// Fetches Nova's voice — the one opt-in download that turns reading
  /// aloud on. Never called at launch: the user asks for it here.
  Future<void> downloadNovaVoiceModel() async {
    if (_novaVoiceDownloading || !novaVoiceConfigured) return;
    _novaVoiceDownloading = true;
    _novaVoiceDownloadProgress = 0;
    _lastError = null;
    notifyListeners();
    try {
      await downloadNovaVoice(
        onProgress: (progress) {
          _novaVoiceDownloadProgress = progress;
          notifyListeners();
        },
      );
      await refreshNovaVoice();
    } on NovaVoiceIntegrityException catch (error) {
      // The file on the host is not the file this build pinned. Say so
      // plainly rather than retrying past a check nobody passed.
      debugPrint('[GuideVoice] $error');
      _lastError =
          "Nova's voice did not match what this build expects, so it was "
          'not installed. Try again after updating Vyana.';
    } on Object catch (error) {
      _lastError = "Nova's voice could not be downloaded: $error";
    } finally {
      _novaVoiceDownloading = false;
      notifyListeners();
    }
  }

  /// Removes the voice and the space it takes. Reading aloud goes quiet
  /// again rather than falling back to anything.
  Future<void> deleteNovaVoiceModel() async {
    await NovaVoiceService.instance.dispose();
    await deleteNovaVoice();
    _novaVoiceReady = false;
    _selectedVoice = null;
    _novaVoiceDownloadProgress = 0;
    await _persistVoicePrefs();
  }

  /// Called after the voice finishes downloading with Nova, so the first
  /// reply already uses it rather than waiting for a restart.
  Future<void> refreshNovaVoice() async {
    await _ensureNovaVoice();
    if (_novaVoiceReady && _selectedVoice == null) {
      _selectedVoice = GuideVoiceOption.nova;
      await _persistVoicePrefs(notify: false);
    }
    notifyListeners();
  }

  Future<void> setVoiceResponsesEnabled(bool enabled) async {
    await init();
    _voiceResponsesEnabled = enabled;
    await _persistVoicePrefs();
  }

  Future<void> setSelectedVoice(GuideVoiceOption? voice) async {
    await _ensureSpeakReady();
    _selectedVoice = voice ?? _defaultVoiceOption();
    await _persistVoicePrefs();
  }

  Future<void> startRecording() async {
    await init();
    _lastError = null;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission is required.');
    }

    if (_isSpeaking) {
      await stopSpeaking();
    }
    await _ttsEngine.prepareRecording();

    final path = await _nextRecordingPath();
    await File(path).parent.create(recursive: true);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _activeRecordingPath = path;
    _isRecording = true;
    notifyListeners();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return _activeRecordingPath;
    }

    final path = await _recorder.stop();
    _isRecording = false;
    _activeRecordingPath = path;
    notifyListeners();
    return path;
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.cancel();
    _isRecording = false;
    _activeRecordingPath = null;
    notifyListeners();
  }

  Future<String> stopRecordingAndTranscribe() async {
    final path = await stopRecording();
    if (path == null || path.isEmpty) {
      throw StateError('No audio was recorded.');
    }
    return transcribeFile(path);
  }

  Future<String> transcribeFile(String path) async {
    await init();
    _isTranscribing = true;
    _lastError = null;
    notifyListeners();

    Whisper? whisper;
    try {
      await _preloadWhisperModel();
      whisper = Whisper(
        model: _whisperModel,
        modelDir: await _whisperModelDirectoryPath(),
      );
      final cores = Platform.numberOfProcessors.clamp(2, 8);
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: path,
          language: 'auto',
          isNoTimestamps: true,
          threads: cores,
          splitOnWord: false,
        ),
        modelPath: await whisperModelPath(),
      );
      final text = response.text.trim();
      if (text.isEmpty) {
        throw StateError('No speech was detected.');
      }
      return text;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      if (whisper != null) {
        try {
          await whisper.dispose();
        } catch (_) {
          // Ignore cleanup failures from native whisper contexts.
        }
      }
      _isTranscribing = false;
      notifyListeners();
    }
  }

  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    _lastError = null;
    await _ensureSpeakReady();

    if (!_novaVoiceReady) {
      // Not an error the user caused, and not something to paper over with
      // the system voice: say what is missing and leave the reply on screen.
      _lastError = novaVoiceUnavailableMessage;
      notifyListeners();
      return;
    }

    // The audio session still has to be routed for playback — Kokoro's WAV
    // goes out through audioplayers, and on iOS that needs the category set
    // back after any recording.
    await _ttsEngine.preparePlayback();

    _isSpeaking = true;
    notifyListeners();
    try {
      await NovaVoiceService.instance.speak(normalized);
    } on Object catch (error) {
      debugPrint('[GuideVoice] Nova voice failed: $error');
      _lastError = NovaVoiceService.instance.lastError ??
          'Nova could not speak that: $error';
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// What the UI says when reading aloud is asked for and the voice is not
  /// installed. One sentence, and it names the way out.
  static String get novaVoiceUnavailableMessage => novaVoiceConfigured
      ? "Nova's voice is not installed yet — download it in Guides › Voice "
          '($novaVoiceApproxSizeLabel).'
      : "Nova's voice is not available in this build yet.";

  Future<void> stopSpeaking() async {
    _speakQueue.clear();
    _isProcessingQueue = false;
    _isSpeaking = false;
    await NovaVoiceService.instance.stop();
    notifyListeners();
  }

  /// Queue a chunk of text for TTS. Sentences are spoken sequentially. Used
  /// during streaming to speak as text arrives.
  void queueSpeak(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _speakQueue.add(normalized);
    if (!_isProcessingQueue) {
      unawaited(_processQueue());
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    _lastError = null;

    try {
      await _ensureSpeakReady();
      if (!_novaVoiceReady) {
        _speakQueue.clear();
        _lastError = novaVoiceUnavailableMessage;
        return;
      }
      await _ttsEngine.preparePlayback();

      _isSpeaking = true;
      notifyListeners();

      // Kokoro generates a whole chunk before any of it plays, so a chunk is
      // a sentence rather than a token — queueSpeak's callers already split
      // on sentence boundaries while streaming.
      while (_speakQueue.isNotEmpty) {
        final chunk = _speakQueue.removeAt(0);
        try {
          await NovaVoiceService.instance.speak(chunk);
        } on Object catch (error) {
          _lastError = NovaVoiceService.instance.lastError ??
              'Unable to speak: $error';
          _speakQueue.clear();
          break;
        }
      }
    } finally {
      _isProcessingQueue = false;
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Speak a short sample using the currently selected voice for previewing.
  Future<void> previewVoice() async {
    const sample =
        'Hello, I\'m your guide. Let me help you find calm and clarity.';
    await speak(sample);
  }

  @override
  void dispose() {
    unawaited(_recorder.dispose());
    unawaited(NovaVoiceService.instance.stop());
    super.dispose();
  }

  /// The only voice there is, once it is installed and verified.
  GuideVoiceOption? _defaultVoiceOption() =>
      _novaVoiceReady ? GuideVoiceOption.nova : null;

  String _stableVoiceId(Map<String, dynamic> rawVoice) {
    final identifier = rawVoice['identifier']?.toString().trim();
    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }
    final name = rawVoice['name']?.toString().trim() ?? '';
    final locale = rawVoice['locale']?.toString().trim() ?? '';
    return '$name::$locale';
  }

  Future<String> _voiceRootPath() async {
    await _modelManager.init();
    final root = _modelManager.storageDirectoryPath;
    if (root == null || root.isEmpty) {
      throw StateError('Guide storage is not ready yet.');
    }
    final voiceRoot = p.join(root, 'voice');
    await Directory(voiceRoot).create(recursive: true);
    return voiceRoot;
  }

  Future<String> _whisperModelDirectoryPath() async {
    final root = await _voiceRootPath();
    final directory = p.join(root, 'whisper');
    await Directory(directory).create(recursive: true);
    return directory;
  }

  Future<String> whisperModelPath() async {
    final directory = await _whisperModelDirectoryPath();
    return p.join(directory, 'ggml-${_whisperModel.modelName}.bin');
  }

  /// Minimum on-disk size for each whisper.cpp ggml bundle. Values sit well
  /// below the published Hugging Face artifacts so truncated downloads fail
  /// fast instead of breaking native inference.
  static int whisperMinimumBytes(WhisperModel model) {
    return switch (model) {
      WhisperModel.tiny || WhisperModel.tinyEn => 50 * 1024 * 1024,
      WhisperModel.base || WhisperModel.baseEn => 100 * 1024 * 1024,
      WhisperModel.small || WhisperModel.smallEn => 400 * 1024 * 1024,
      WhisperModel.medium || WhisperModel.mediumEn => 1200 * 1024 * 1024,
      WhisperModel.large || WhisperModel.largeV3Turbo => 2500 * 1024 * 1024,
    };
  }

  Future<bool> validateWhisperModelFile([String? path]) async {
    final modelPath = path ?? await whisperModelPath();
    final file = File(modelPath);
    if (!await file.exists()) {
      return false;
    }

    final size = await file.length();
    return size >= whisperMinimumBytes(_whisperModel);
  }

  Future<bool> isWhisperModelReady() async {
    return validateWhisperModelFile();
  }

  Future<int> whisperModelBytes() async {
    final modelFile = File(await whisperModelPath());
    if (!await modelFile.exists()) {
      return 0;
    }
    return modelFile.length();
  }

  /// Delete the downloaded speech model (used to free storage / re-download).
  Future<void> deleteWhisperModel() async {
    await init();
    try {
      final file = File(await whisperModelPath());
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      _lastError = 'Unable to remove speech model: $error';
    }
    _whisperReady = false;
    notifyListeners();
  }

  Future<void> preloadWhisperModel({
    bool notify = true,
    bool force = false,
  }) async {
    await init();
    await _preloadWhisperModel(notify: notify, force: force);
  }

  Future<void> _preloadWhisperModel({
    bool notify = true,
    bool force = false,
  }) async {
    if (_isPreparingWhisperModel) {
      return;
    }

    final targetPath = await whisperModelPath();
    final targetFile = File(targetPath);
    if (force && await targetFile.exists()) {
      await targetFile.delete();
    }

    if (await targetFile.exists()) {
      if (await validateWhisperModelFile(targetPath)) {
        _whisperReady = true;
        if (notify) {
          notifyListeners();
        }
        return;
      }
      await targetFile.delete();
    }

    _isPreparingWhisperModel = true;
    _whisperDownloadProgress = 0;
    _lastError = null;
    if (notify) {
      notifyListeners();
    }

    try {
      final request = await HttpClient().getUrl(_whisperModel.modelUri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Model download failed with status ${response.statusCode}',
          uri: _whisperModel.modelUri,
        );
      }

      final contentLength = response.contentLength;
      await targetFile.parent.create(recursive: true);
      final tempFile = File('$targetPath.download');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final sink = tempFile.openWrite();
      var received = 0;
      var lastNotifyAt = DateTime.now();

      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;

          if (contentLength > 0) {
            _whisperDownloadProgress = (received / contentLength).clamp(
              0.0,
              1.0,
            );
          }

          final now = DateTime.now();
          if (now.difference(lastNotifyAt) >=
              const Duration(milliseconds: 200)) {
            lastNotifyAt = now;
            if (notify) {
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      _whisperDownloadProgress = 1.0;
      if (notify) {
        notifyListeners();
      }

      if (!await validateWhisperModelFile(tempFile.path)) {
        await tempFile.delete();
        throw StateError(
          'Downloaded speech model failed validation. Delete it and download again.',
        );
      }

      await tempFile.rename(targetPath);
      _whisperReady = true;
    } catch (error) {
      final partial = File('$targetPath.download');
      if (await partial.exists()) {
        await partial.delete();
      }
      if (await targetFile.exists() && !await validateWhisperModelFile(targetPath)) {
        await targetFile.delete();
      }
      _whisperReady = false;
      _lastError = error is StateError
          ? error.message
          : 'Unable to download speech model: $error';
      rethrow;
    } finally {
      _isPreparingWhisperModel = false;
      _whisperDownloadProgress = 0;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<String> _nextRecordingPath() async {
    final root = await _voiceRootPath();
    final directory = p.join(root, 'recordings');
    await Directory(directory).create(recursive: true);
    return p.join(
      directory,
      'guide_prompt_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
  }
}

final guideVoiceServiceProvider = ChangeNotifierProvider<GuideVoiceService>((
  ref,
) {
  final service = GuideVoiceService(
    modelManager: ref.read(guideModelManagerProvider),
    db: ref.watch(databaseProvider),
  );
  service.init();
  ref.onDispose(service.dispose);
  return service;
});
