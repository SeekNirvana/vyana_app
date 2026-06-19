import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_startup_service.dart';
import 'guide_model_manager.dart';
import 'guide_persona_prefs_service.dart';

/// Runs on-device inference for the guides via flutter_gemma. The active chat
/// keeps multi-turn context internally; switching guides offloads and rebuilds
/// the session so each guide starts fresh with its own system prompt.
class GuideRuntimeService {
  GuideRuntimeService({required GuidePersonaPrefsService prefsService})
      : _prefsService = prefsService;

  final GuidePersonaPrefsService _prefsService;

  // flutter_gemma defaults (topK: 1, randomSeed: 1) can degenerate into an
  // infinite identical-token loop when LiteRT's OpenCL sampler is unavailable.
  static const _guideTopK = 40;
  static const _guideTopP = 0.9;
  static const _maxIdenticalStreamTokens = 4;
  // Bump when inference/session defaults change to drop stale in-memory models.
  static const _runtimeConfigEpoch = 2;

  final Random _sessionRandom = Random();
  int? _loadedConfigEpoch;
  int _backendAttemptIndex = 0;
  int? _loadedBackendAttempt;
  DateTime? _loadedPrefsUpdatedAt;

  InferenceModel? _currentModel;
  InferenceChat? _activeChat;

  GuideKind? _activeGuide;
  bool _isGenerating = false;
  String? _lastError;

  GuideKind? get activeGuide => _activeGuide;
  bool get hasLoadedModel => _activeChat != null;
  bool get isGenerating => _isGenerating;
  String? get lastError => _lastError;

  /// Initialize the runtime for a specific guide.
  Future<void> initialize(GuideKind guide) async {
    await AppStartupService.instance.ensureInitialized();

    final definition = guidePersonaDefinitions[guide]!;
    final effective = await _prefsService.effectiveConfig(definition);

    if (_activeGuide == guide &&
        _activeChat != null &&
        _loadedConfigEpoch == _runtimeConfigEpoch &&
        _loadedBackendAttempt == _backendAttemptIndex &&
        _loadedPrefsUpdatedAt == effective.prefsUpdatedAt) {
      return;
    }

    await offload(resetBackendAttempts: false);

    try {
      await _loadGuideModel(definition);
      _lastError = null;
    } catch (e, stack) {
      if (_isZipArchiveError(e)) {
        debugPrint(
          'Invalid model bundle detected for ${definition.name}. Reinstalling once.',
        );
        try {
          await _ensureGuideModelReady(definition, forceReinstall: true);
          await _loadGuideModel(definition);
          _lastError = null;
          return;
        } catch (retryError, retryStack) {
          debugPrint('Retry initialization failed: $retryError');
          debugPrint('Retry stack: $retryStack');
          _lastError = retryError.toString();
          rethrow;
        }
      }

      debugPrint('Error initializing runtime: $e');
      debugPrint('Stack: $stack');
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Generate a full (non-streaming) response for [prompt].
  Future<String> generateResponse({
    required GuideKind guide,
    required String prompt,
  }) async {
    var finalResponse = '';
    await for (final partial in streamResponse(guide: guide, prompt: prompt)) {
      finalResponse = partial;
    }
    return finalResponse;
  }

  /// Stream a response for [prompt] as text accumulates.
  Stream<String> streamResponse({
    required GuideKind guide,
    required String prompt,
  }) async* {
    final definition = guidePersonaDefinitions[guide]!;
    final backendCandidates = _litertLmBackends(definition);
    Object? lastError;

    for (var attempt = 0; attempt < backendCandidates.length; attempt++) {
      _backendAttemptIndex = attempt;
      try {
        await initialize(guide);
        yield* _streamOnce(prompt);
        _backendAttemptIndex = 0;
        _loadedBackendAttempt = 0;
        return;
      } catch (error, stack) {
        lastError = error;
        debugPrint('Error generating response: $error');
        debugPrint('Stack: $stack');
        _lastError = error.toString();

        final canRetry = _isInferenceBackendError(error) &&
            attempt + 1 < backendCandidates.length;
        if (!canRetry) {
          throw _wrapInferenceFailure(error);
        }

        debugPrint(
          '[GuideRuntime] Backend ${backendCandidates[attempt]} failed; '
          'retrying with ${backendCandidates[attempt + 1]}.',
        );
        await offload(resetBackendAttempts: false);
      }
    }

    throw _wrapInferenceFailure(
      lastError ?? StateError('Guide inference failed'),
    );
  }

  Stream<String> _streamOnce(String prompt) async* {
    if (_activeChat == null) {
      throw StateError('Failed to initialize chat');
    }

    if (_isGenerating) {
      throw StateError('Generation already in progress');
    }
    _isGenerating = true;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      try {
        await _activeChat!.addQueryChunk(
          Message.text(text: prompt, isUser: true),
        );
      } catch (e) {
        throw StateError('Failed to add message to chat: $e');
      }

      var responseText = '';

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final response = await _activeChat!.generateChatResponse();
        if (response is! TextResponse) {
          throw StateError('Unexpected response type: ${response.runtimeType}');
        }
        responseText = response.token.trimRight();
        yield responseText;
      } else {
        final buffer = StringBuffer();
        var lastToken = '';
        var identicalTokenStreak = 0;

        await for (final response in _activeChat!.generateChatResponseAsync()) {
          if (response is! TextResponse) {
            continue;
          }

          final token = response.token;
          if (token == lastToken) {
            identicalTokenStreak++;
          } else {
            lastToken = token;
            identicalTokenStreak = 1;
          }

          if (identicalTokenStreak >= _maxIdenticalStreamTokens) {
            debugPrint(
              '[GuideRuntime] Degenerate token loop detected ("$token"); '
              'stopping generation.',
            );
            await _activeChat!.stopGeneration();
            break;
          }

          buffer.write(token);
          yield _trimRepeatingTail(buffer.toString());
        }
        responseText = _trimRepeatingTail(buffer.toString()).trimRight();
      }

      if (responseText.isEmpty) {
        throw StateError('No response generated from model');
      }
      _lastError = null;
    } finally {
      _isGenerating = false;
    }
  }

  /// Offload and free resources.
  Future<void> offload({bool resetBackendAttempts = true}) async {
    if (_isGenerating) {
      var attempts = 0;
      while (_isGenerating && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _activeChat = null;
    _activeGuide = null;
    _loadedConfigEpoch = null;
    _loadedBackendAttempt = null;
    _loadedPrefsUpdatedAt = null;
    _isGenerating = false;
    await _currentModel?.close();
    _currentModel = null;

    if (resetBackendAttempts) {
      _backendAttemptIndex = 0;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> dispose() async {
    await offload();
  }

  Future<void> _loadGuideModel(GuidePersonaDefinition definition) async {
    await _ensureGuideModelReady(definition);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final effective = await _prefsService.effectiveConfig(definition);
    final backend = _preferredBackendFor(definition);
    debugPrint(
      '[GuideRuntime] Loading ${definition.name} on $backend '
      '(maxTokens=${effective.maxTokens}, temp=${effective.temperature})',
    );

    _currentModel = await FlutterGemma.getActiveModel(
      maxTokens: effective.maxTokens,
      preferredBackend: backend,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _activeChat = await _currentModel!.createChat(
      modelType: definition.flutterGemmaModelType,
      systemInstruction: effective.systemPrompt,
      temperature: effective.temperature,
      topK: _guideTopK,
      topP: _guideTopP,
      randomSeed: _sessionRandom.nextInt(1 << 30) + 1,
      isThinking: false,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _activeGuide = definition.kind;
    _loadedConfigEpoch = _runtimeConfigEpoch;
    _loadedBackendAttempt = _backendAttemptIndex;
    _loadedPrefsUpdatedAt = effective.prefsUpdatedAt;
  }

  void invalidatePrefs() {
    _loadedPrefsUpdatedAt = null;
    _loadedConfigEpoch = null;
  }

  Future<void> _ensureGuideModelReady(
    GuidePersonaDefinition definition, {
    bool forceReinstall = false,
  }) async {
    final manager = FlutterGemmaPlugin.instance.modelManager;
    final spec = guideInferenceModelSpec(definition);

    if (forceReinstall) {
      await purgeInstalledGuideBundle(definition);
    }

    var isInstalled = await manager.isModelInstalled(spec);
    if (isInstalled) {
      final isValid = await validateInstalledGuideModel(definition);
      if (!isValid) {
        await purgeInstalledGuideBundle(definition);
        isInstalled = false;
      }
    }

    if (!isInstalled) {
      await downloadGuideModelFile(definition);
      await registerGuideModelAtPath(definition);

      final installedNow =
          await manager.isModelInstalled(spec) &&
          await validateInstalledGuideModel(definition);
      if (!installedNow) {
        await purgeInstalledGuideBundle(definition);
        throw StateError(
          'Downloaded ${definition.name}, but the model bundle is invalid. '
          'Delete it and download again.',
        );
      }
    }

    manager.setActiveModel(spec);
  }

  bool _isZipArchiveError(Object error) {
    return error.toString().contains('Unable to open zip archive');
  }

  List<PreferredBackend> _litertLmBackends(
    GuidePersonaDefinition definition,
  ) {
    if (definition.modelFileType != ModelFileType.litertlm) {
      return [
        defaultTargetPlatform == TargetPlatform.iOS
            ? PreferredBackend.cpu
            : PreferredBackend.gpu,
      ];
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return [PreferredBackend.cpu];
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // GPU is the supported LiteRT-LM path for Gemma 4 E2B. CPU often fails
      // tensor allocation (DYNAMIC_UPDATE_SLICE). NPU is a secondary attempt on
      // Qualcomm / MediaTek / Tensor devices.
      return [PreferredBackend.gpu, PreferredBackend.npu];
    }

    return [PreferredBackend.gpu];
  }

  PreferredBackend _preferredBackendFor(GuidePersonaDefinition definition) {
    final backends = _litertLmBackends(definition);
    final index = _backendAttemptIndex.clamp(0, backends.length - 1);
    return backends[index];
  }

  bool _isInferenceBackendError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed to invoke the compiled model') ||
        message.contains('dynamic_update_slice') ||
        message.contains('failed to allocate tensors') ||
        message.contains('status code: 13') ||
        (error is PlatformException && error.code == 'ERROR');
  }

  Object _wrapInferenceFailure(Object error) {
    if (_isInferenceBackendError(error)) {
      return StateError(
        'On-device inference failed on this phone\'s AI backend. '
        'Restart Vyana and try again. If it keeps failing, your device may '
        'not support the Gemma guide model yet.',
      );
    }
    return error;
  }

  /// Removes a trailing run of identical short fragments (e.g. `" Roch"` loops).
  String _trimRepeatingTail(String text) {
    if (text.length < 8) {
      return text;
    }

    for (var unitLen = 1; unitLen <= 24; unitLen++) {
      if (text.length < unitLen * 3) {
        continue;
      }
      final unit = text.substring(text.length - unitLen);
      var repeats = 1;
      var index = text.length - unitLen;
      while (index >= unitLen &&
          text.substring(index - unitLen, index) == unit) {
        repeats++;
        index -= unitLen;
      }
      if (repeats >= 3) {
        return text.substring(0, index + unitLen);
      }
    }

    return text;
  }

}

/// Single long-lived runtime instance so multi-turn chat context survives
/// widget rebuilds.
final guideRuntimeServiceProvider = Provider<GuideRuntimeService>((ref) {
  final service = GuideRuntimeService(
    prefsService: ref.watch(guidePersonaPrefsServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});