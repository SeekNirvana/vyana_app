import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import 'package:whisper_ggml_plus_ffmpeg/whisper_ggml_plus_ffmpeg.dart';

import '../data/db.dart';
import 'app_tts_service.dart';
import 'guide_model_manager.dart';

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
  final AppTtsService _ttsEngine = AppTtsService.instance;
  FlutterTts get _tts => _ttsEngine.tts;

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
  List<GuideVoiceOption> _voices = const [];
  GuideVoiceOption? _selectedVoice;

  GuideVoiceService({
    required GuideModelManager modelManager,
    required VyanaDatabase db,
  })  : _modelManager = modelManager,
        _db = db {
    _bindSpeakHandlers();
  }

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
  List<GuideVoiceOption> get voices => _voices;
  GuideVoiceOption? get selectedVoice => _selectedVoice;
  bool get hasVoices => _voices.isNotEmpty;

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
    _bindSpeakHandlers();
    if (_voices.isEmpty) {
      await _refreshVoices(notify: false);
    }

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

    await _refreshVoices(notify: false);

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
      return _voices.cast<GuideVoiceOption?>().firstWhere(
        (voice) => voice?.stableId == stableId,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistVoicePrefs({bool notify = true}) async {
    final selected = _selectedVoice;
    final persistable = selected != null && !_isSyntheticVoice(selected)
        ? jsonEncode(selected.raw)
        : null;
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

  Future<void> refreshVoices({bool notify = true}) async {
    await init();
    await _refreshVoices(notify: notify);
  }

  Future<void> _refreshVoices({
    bool notify = true,
    int attempt = 0,
  }) async {
    try {
      await _tts.getLanguages;
      final parsed = <GuideVoiceOption>[];
      final rawVoices = await _tts.getVoices;
      if (rawVoices is List) {
        parsed.addAll(
          rawVoices
              .whereType<Map>()
              .map((item) => _parseVoiceOption(Map<String, dynamic>.from(item)))
              .whereType<GuideVoiceOption>(),
        );
      }

      if (parsed.isEmpty && attempt < 4) {
        await Future<void>.delayed(
          Duration(milliseconds: 200 * (attempt + 1)),
        );
        return _refreshVoices(notify: notify, attempt: attempt + 1);
      }

      _voices = parsed.toSet().toList()
        ..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
      if (_selectedVoice != null) {
        final selectedId = _selectedVoice!.stableId;
        _selectedVoice = _voices.cast<GuideVoiceOption?>().firstWhere(
          (voice) => voice?.stableId == selectedId,
          orElse: () => _defaultVoiceOption(),
        );
      } else {
        _selectedVoice = _defaultVoiceOption();
      }
      _lastError = null;
    } catch (error) {
      _lastError = 'Unable to load device voices: $error';
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setVoiceResponsesEnabled(bool enabled) async {
    await init();
    _voiceResponsesEnabled = enabled;
    await _persistVoicePrefs();
  }

  Future<void> setSelectedVoice(GuideVoiceOption? voice) async {
    await _ensureSpeakReady();
    final next = voice ?? _defaultVoiceOption();
    if (next != null && _isSyntheticVoice(next)) {
      return;
    }
    _selectedVoice = next;
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
    await _tts.stop();
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

  void _bindSpeakHandlers() {
    _ttsEngine.bindHandlers(
      onStart: () {
        _isSpeaking = true;
        notifyListeners();
      },
      onComplete: () {
        _isSpeaking = false;
        notifyListeners();
      },
      onCancel: () {
        _isSpeaking = false;
        notifyListeners();
      },
      onError: (message) {
        _isSpeaking = false;
        _lastError = message?.toString();
        notifyListeners();
      },
    );
  }

  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    _lastError = null;
    await _ensureSpeakReady();

    if (_isSpeaking) {
      await _tts.stop();
    }

    await _ttsEngine.preparePlayback();
    _bindSpeakHandlers();
    await _applySpeakVoice();

    _isSpeaking = true;
    notifyListeners();

    try {
      await _tts.speak(normalized, focus: true);
    } catch (error) {
      _isSpeaking = false;
      _lastError = 'Unable to speak the response: $error';
      notifyListeners();
      rethrow;
    }
  }

  bool _isSyntheticVoice(GuideVoiceOption voice) {
    return voice.name == 'System voice' || voice.name == 'System default';
  }

  Map<String, String> _voiceMapFor(GuideVoiceOption voice) {
    final map = <String, String>{
      'name': voice.name,
      'locale': voice.locale,
    };
    if (voice.identifier != null && voice.identifier!.isNotEmpty) {
      map['identifier'] = voice.identifier!;
    }
    return map;
  }

  Future<void> _applySpeakVoice() async {
    final selected = _selectedVoice ?? _defaultVoiceOption();
    if (selected == null || _isSyntheticVoice(selected)) {
      return;
    }

    if (selected.locale.isNotEmpty) {
      await _tts.setLanguage(selected.locale);
    }
    await _tts.setVoice(_voiceMapFor(selected));
  }

  Future<void> stopSpeaking() async {
    _speakQueue.clear();
    _isProcessingQueue = false;
    _isSpeaking = false;
    await _tts.stop();
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
      await _ttsEngine.preparePlayback();
      _bindSpeakHandlers();
      await _applySpeakVoice();

      _isSpeaking = true;
      notifyListeners();

      while (_speakQueue.isNotEmpty) {
        final chunk = _speakQueue.removeAt(0);
        try {
          await _tts.speak(chunk, focus: true);
        } catch (error) {
          _lastError = 'Unable to speak: $error';
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
    unawaited(_tts.stop());
    super.dispose();
  }

  GuideVoiceOption? _parseVoiceOption(Map<String, dynamic> raw) {
    final mapped = raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    final name = mapped['name']?.trim() ?? '';
    final locale = [mapped['locale'], mapped['language']]
        .map((value) => value?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (name.isEmpty || locale.isEmpty) {
      return null;
    }
    final identifier = _stringOrNull(mapped['identifier']);
    final voiceMap = <String, String>{
      'name': name,
      'locale': locale,
      if (identifier != null) 'identifier': identifier,
    };
    return GuideVoiceOption(
      raw: voiceMap,
      name: name,
      locale: locale,
      identifier: identifier,
      gender: _stringOrNull(mapped['gender']),
      quality: _stringOrNull(mapped['quality']),
    );
  }

  GuideVoiceOption? _defaultVoiceOption() {
    if (_voices.isEmpty) {
      return null;
    }

    final preferredEnglish = _voices.cast<GuideVoiceOption?>().firstWhere(
      (voice) => voice?.locale.toLowerCase().startsWith('en') ?? false,
      orElse: () => null,
    );
    return preferredEnglish ?? _voices.first;
  }

  String _stableVoiceId(Map<String, dynamic> rawVoice) {
    final identifier = rawVoice['identifier']?.toString().trim();
    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }
    final name = rawVoice['name']?.toString().trim() ?? '';
    final locale = rawVoice['locale']?.toString().trim() ?? '';
    return '$name::$locale';
  }

  String? _stringOrNull(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
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
