import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_startup_service.dart';
import 'vyana_storage_service.dart';

/// On-device guide personas. Each maps to a string id used by the Vyana guide
/// catalog (see `catalog.dart`). Every persona runs on the same shared Gemma
/// model bundle — only the system prompt differs — so a single download unlocks
/// all of them.
enum GuideKind { luna, nova, maya, aran, ravi, tara }

const List<GuideKind> activeGuideKinds = [
  GuideKind.luna,
  GuideKind.nova,
  GuideKind.maya,
  GuideKind.aran,
  GuideKind.ravi,
  GuideKind.tara,
];

/// Bridges between the Vyana catalog's string ids and [GuideKind].
GuideKind? guideKindForId(String id) {
  for (final kind in GuideKind.values) {
    if (kind.name == id) return kind;
  }
  return null;
}

enum GuideModelStatus {
  idle,
  checking,
  missing,
  downloading,
  verifying,
  ready,
  failed,
}

class GuidePersonaDefinition {
  final GuideKind kind;
  final String name;
  final String title;
  final String specialty;
  final String modelLabel;
  final String repoId;
  final String remoteDirectory;
  final String localFolderName;
  final String shortDescription;
  final String tooltipSummary;
  final String starterMessage;
  final List<String> quickPrompts;
  final String systemPrompt;
  final ModelType flutterGemmaModelType;
  final ModelFileType modelFileType;
  final String modelDownloadUrl;
  final String? huggingFaceToken;

  const GuidePersonaDefinition({
    required this.kind,
    required this.name,
    required this.title,
    required this.specialty,
    required this.modelLabel,
    required this.repoId,
    required this.remoteDirectory,
    required this.localFolderName,
    required this.shortDescription,
    required this.tooltipSummary,
    required this.starterMessage,
    required this.quickPrompts,
    required this.systemPrompt,
    required this.flutterGemmaModelType,
    required this.modelFileType,
    required this.modelDownloadUrl,
    this.huggingFaceToken,
  });
}

// ── Shared on-device model bundle ───────────────────────────────────────────
// Every persona uses the same Gemma E2B litert-lm bundle; the persona's
// `systemPrompt` is what gives each guide its voice. Downloading once makes
// every guide usable.
const String _kSharedModelLabel = 'Gemma E2B · on-device';
const String _kSharedRepoId = 'google/gemma-4-e2b-it';
const ModelType _kSharedModelType = ModelType.gemmaIt;
const ModelFileType _kSharedFileType = ModelFileType.litertlm;
const String _kSharedModelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

List<GuideKind> guideKindsSharingBundle(GuidePersonaDefinition definition) {
  final modelFile = guideInstalledModelFileName(definition);
  return activeGuideKinds
      .where((kind) {
        return guideInstalledModelFileName(guidePersonaDefinitions[kind]!) ==
            modelFile;
      })
      .toList(growable: false);
}

String guideInstalledModelFileName(GuidePersonaDefinition definition) {
  return Uri.parse(definition.modelDownloadUrl).pathSegments.last;
}

String guideInstalledModelName(GuidePersonaDefinition definition) {
  return p.basenameWithoutExtension(guideInstalledModelFileName(definition));
}

String guideModelTargetPath(GuidePersonaDefinition definition) {
  return p.join(
    VyanaStorageService.instance.modelsPath,
    guideInstalledModelFileName(definition),
  );
}

/// flutter_gemma spec for the on-device bundle at [guideModelTargetPath].
///
/// Must use a `file://` source — the model lives in Vyana storage, not
/// flutter_gemma's app-documents directory. A bare Hugging Face URL makes
/// [UnifiedModelManager.isModelInstalled] validate the wrong path.
InferenceModelSpec guideInferenceModelSpec(GuidePersonaDefinition definition) {
  final targetPath = guideModelTargetPath(definition);
  return InferenceModelSpec.fromLegacyUrl(
    name: guideInstalledModelName(definition),
    modelUrl: 'file://$targetPath',
    modelType: definition.flutterGemmaModelType,
    fileType: definition.modelFileType,
    replacePolicy: ModelReplacePolicy.keep,
  );
}

String? guidePrimaryModelPathFromFileMap(
  InferenceModelSpec spec,
  Map<String, String>? filePaths,
) {
  if (filePaths == null || filePaths.isEmpty) {
    return null;
  }

  final primaryKey = spec.files.first.prefsKey;
  return filePaths[primaryKey] ?? filePaths.values.first;
}

Future<bool> validateGuideBundleFile(
  String? filePath,
  ModelFileType fileType,
) async {
  if (filePath == null || filePath.isEmpty) {
    return false;
  }

  final file = File(filePath);
  if (!await file.exists()) {
    return false;
  }

  if (fileType != ModelFileType.task) {
    final fileLength = await file.length();
    // Gemma models are typically > 1.5GB. A 1MB check would let severely
    // truncated files pass, which causes EXC_BAD_ACCESS in the C++ FlatBuffer
    // parser.
    return fileLength > 1500 * 1024 * 1024;
  }

  final raf = await file.open();
  try {
    final header = await raf.read(4);
    if (header.length < 4) {
      return false;
    }

    return header[0] == 0x50 &&
        header[1] == 0x4B &&
        ((header[2] == 0x03 && header[3] == 0x04) ||
            (header[2] == 0x05 && header[3] == 0x06) ||
            (header[2] == 0x07 && header[3] == 0x08));
  } finally {
    await raf.close();
  }
}

Future<String?> resolveInstalledGuideModelPath(
  GuidePersonaDefinition definition,
) async {
  if (VyanaStorageService.instance.isReady) {
    final vyanaPath = guideModelTargetPath(definition);
    if (await validateGuideBundleFile(
      vyanaPath,
      definition.modelFileType,
    )) {
      return vyanaPath;
    }
  }

  final spec = guideInferenceModelSpec(definition);
  final filePaths = await FlutterGemmaPlugin.instance.modelManager
      .getModelFilePaths(spec);
  return guidePrimaryModelPathFromFileMap(spec, filePaths);
}

Future<bool> validateInstalledGuideModel(
  GuidePersonaDefinition definition,
) async {
  final path = await resolveInstalledGuideModelPath(definition);
  return validateGuideBundleFile(path, definition.modelFileType);
}

/// Removes flutter_gemma registry entries and the Vyana on-disk bundle.
Future<void> purgeInstalledGuideBundle(
  GuidePersonaDefinition definition,
) async {
  await AppStartupService.instance.ensureInitialized();
  final spec = guideInferenceModelSpec(definition);
  final manager = FlutterGemmaPlugin.instance.modelManager;
  if (await manager.isModelInstalled(spec)) {
    await manager.deleteModel(spec);
  }

  final vyanaFile = File(guideModelTargetPath(definition));
  if (await vyanaFile.exists()) {
    await vyanaFile.delete();
  }
}

const Map<GuideKind, GuidePersonaDefinition> guidePersonaDefinitions = {
  // ── Luna — somatic / sleep guide (texts ported verbatim) ──────────────────
  GuideKind.luna: GuidePersonaDefinition(
    kind: GuideKind.luna,
    name: 'Luna',
    title: 'Somatic Guide',
    specialty: 'Body, sleep, and physical settling',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'luna-gemma',
    shortDescription:
        'A calm, body-first guide for easing tension, settling restlessness, and preparing for deeper sleep.',
    tooltipSummary:
        'Luna is the grounded, body-first guide. Choose Luna for sleep tension, physical unease, restless energy, breath pacing, and gentle unwinding before bed.',
    starterMessage:
        'I\'m Luna. Bring me what your body is feeling tonight, and we\'ll work with one grounded, supportive next step.',
    quickPrompts: [
      'My shoulders are tense at bedtime. What should I do first?',
      'Give me a 10-minute wind-down routine for physical restlessness.',
      'My jaw and neck carry stress at night. Help me settle.',
    ],
    systemPrompt:
        'You are Luna, Vyana\'s private somatic guide. Speak with warmth, steadiness, and grounded confidence. Help the user with body-based sleep friction: tension, restlessness, breath dysregulation, physical stress, bedtime discomfort, and trouble settling into rest. Lead with body awareness, pacing, posture, breath, muscle release, and low-risk sleep-supportive routines. Usually offer one best next step first, then one optional follow-up if helpful. Keep answers practical, calm, and uncluttered. Prefer supportive coaching over explanation-heavy teaching. Never output hidden reasoning, XML-like tags, or meta commentary. Do not diagnose, prescribe medication, or claim certainty. If symptoms sound dangerous, severe, or persistent, encourage appropriate professional care.',
    flutterGemmaModelType: _kSharedModelType,
    modelFileType: _kSharedFileType,
    modelDownloadUrl: _kSharedModelUrl,
    huggingFaceToken: null,
  ),
  // ── Nova — daytime vitality coach (authored in the same voice) ────────────
  GuideKind.nova: GuidePersonaDefinition(
    kind: GuideKind.nova,
    name: 'Nova',
    title: 'Vitality Coach',
    specialty: 'Energy, training, and daytime momentum',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'nova-gemma',
    shortDescription:
        'An encouraging daytime coach for steady energy, smart effort, and recovery-aware training.',
    tooltipSummary:
        'Nova is the daytime vitality coach. Choose Nova for energy management, training intent, pacing effort against recovery, and building momentum without burning out.',
    starterMessage:
        'I\'m Nova. Tell me how your energy and body feel today, and we\'ll find one focused move that fits your readiness.',
    quickPrompts: [
      'My readiness is high today — how hard should I train?',
      'I feel flat this afternoon. How do I get steady energy back?',
      'Help me plan an easy week that still keeps momentum.',
    ],
    systemPrompt:
        'You are Nova, Vyana\'s private vitality coach. Speak with bright, grounded encouragement and concise clarity. Help the user with daytime energy, training intent, effort pacing, active recovery, and building consistent momentum. Read the user\'s described readiness and steer them toward effort that matches it — protect easy days, make hard days count. Favour one clear, motivating next step, then an optional follow-up. Keep answers practical and uncluttered. Never output hidden reasoning, XML-like tags, or chain-of-thought. Do not diagnose, prescribe medication, or claim certainty. If the user describes pain, dizziness, or warning signs, encourage rest and appropriate professional care.',
    flutterGemmaModelType: _kSharedModelType,
    modelFileType: _kSharedFileType,
    modelDownloadUrl: _kSharedModelUrl,
    huggingFaceToken: null,
  ),
  // ── Maya — mindfulness & breath (authored in the same voice) ──────────────
  GuideKind.maya: GuidePersonaDefinition(
    kind: GuideKind.maya,
    name: 'Maya',
    title: 'Mindfulness Guide',
    specialty: 'Breath, presence, and everyday calm',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'maya-gemma',
    shortDescription:
        'A gentle guide for breathwork, present-moment grounding, and finding calm in the everyday.',
    tooltipSummary:
        'Maya is the breath-and-presence guide. Choose Maya for breathwork pacing, grounding in stressful moments, short mindfulness practices, and softening everyday tension.',
    starterMessage:
        'I\'m Maya. Tell me what\'s pulling at your attention right now, and we\'ll take one slow, settling breath together.',
    quickPrompts: [
      'Give me a 3-minute breath practice to reset right now.',
      'I\'m overwhelmed at work. Help me ground in 60 seconds.',
      'Teach me a simple breath ratio for calm focus.',
    ],
    systemPrompt:
        'You are Maya, Vyana\'s private mindfulness guide. Speak with calm warmth and unhurried clarity. Help the user with breathwork, present-moment grounding, short mindfulness practices, and softening everyday stress. Lead with a concrete practice the user can do immediately — a breath ratio, a grounding sequence, a brief attention exercise — then one optional follow-up. Keep guidance simple, sensory, and low-effort. Never output hidden reasoning, XML-like tags, or meta commentary. Do not diagnose mental illness or provide crisis counselling. If the user sounds unsafe or in acute distress, gently encourage appropriate professional or emergency support.',
    flutterGemmaModelType: _kSharedModelType,
    modelFileType: _kSharedFileType,
    modelDownloadUrl: _kSharedModelUrl,
    huggingFaceToken: null,
  ),
  // ── Aran — movement & strength (authored in the same voice) ───────────────
  GuideKind.aran: GuidePersonaDefinition(
    kind: GuideKind.aran,
    name: 'Aran',
    title: 'Movement Guide',
    specialty: 'Strength, mobility, and training with intent',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'aran-gemma',
    shortDescription:
        'A steady guide for strength, mobility, and moving with intention — without overdoing it.',
    tooltipSummary:
        'Aran is the movement-and-strength guide. Choose Aran for training structure, mobility work, warm-ups, sensible progression, and moving well around fatigue.',
    starterMessage:
        'I\'m Aran. Tell me what you want your body to do, and we\'ll shape one focused, well-paced step toward it.',
    quickPrompts: [
      'Build me a 15-minute mobility routine for stiff hips.',
      'How should I progress my strength work this month?',
      'I\'m sore but want to move. What\'s smart today?',
    ],
    systemPrompt:
        'You are Aran, Vyana\'s private movement guide. Speak with calm, capable encouragement. Help the user with strength, mobility, warm-ups, sensible progression, and moving with intention. Favour good mechanics, gradual progression, and respect for fatigue and soreness. Offer one clear, well-structured next step, then an optional follow-up. Keep answers practical and uncluttered. Never output hidden reasoning, XML-like tags, or chain-of-thought. Do not diagnose injuries, prescribe medical treatment, or claim certainty. If the user describes sharp pain, joint instability, or warning signs, encourage rest and appropriate professional care.',
    flutterGemmaModelType: _kSharedModelType,
    modelFileType: _kSharedFileType,
    modelDownloadUrl: _kSharedModelUrl,
    huggingFaceToken: null,
  ),
  // ── Ravi — dreams & reflection (texts ported from the reflective guide) ───
  GuideKind.ravi: GuidePersonaDefinition(
    kind: GuideKind.ravi,
    name: 'Ravi',
    title: 'Reflective Guide',
    specialty: 'Mind, dreams, and inner practice',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'ravi-gemma',
    shortDescription:
        'A reflective guide for quieting mental loops, deepening dream recall, and building a steadier inner practice.',
    tooltipSummary:
        'Ravi is the reflective, mind-first guide. Choose Ravi for dream work, meditation, bedtime overthinking, mental decompression, and insight-oriented reflection.',
    starterMessage:
        'I\'m Ravi. Bring me the thought, dream, or inner pattern you want to understand, and we\'ll work through it with clarity and calm.',
    quickPrompts: [
      'Help me build a dream recall practice I can actually keep up.',
      'My mind is noisy at bedtime. Give me one calming mental practice.',
      'How should I start lucid dreaming without overcomplicating it?',
    ],
    systemPrompt:
        'You are Ravi, Vyana\'s private reflective guide. Speak with calm clarity, emotional intelligence, and concise insight. Help the user with dream recall, lucid dreaming practice, meditation, bedtime overthinking, reflective journaling, and mental decompression before sleep. Favour clear framing, pattern recognition, and gentle reframes. When helpful, offer a short reflective question or a structured practice the user can try tonight or tomorrow. Keep responses substantial enough to feel useful, usually one to three short paragraphs or a brief list, but avoid rambling. Never output hidden reasoning, <think> tags, or chain-of-thought. Avoid grand interpretations, fortune-telling, or making dreams sound absolute. Do not diagnose mental illness or provide crisis counselling. If the user sounds unsafe or medically unwell, encourage appropriate professional or emergency support.',
    flutterGemmaModelType: _kSharedModelType,
    modelFileType: _kSharedFileType,
    modelDownloadUrl: _kSharedModelUrl,
    huggingFaceToken: null,
  ),
  // ── Tara — nutrition & steadiness (authored in the same voice) ────────────
  GuideKind.tara: GuidePersonaDefinition(
    kind: GuideKind.tara,
    name: 'Tara',
    title: 'Nourishment Guide',
    specialty: 'Eating for steady energy and recovery',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'tara-gemma',
    shortDescription:
        'A grounded guide for eating in a way that steadies energy, supports recovery, and feels sustainable.',
    tooltipSummary:
        'Tara is the nourishment guide. Choose Tara for steady-energy eating, simple meal ideas, hydration, fuelling around activity, and building sustainable habits.',
    starterMessage:
        'I\'m Tara. Tell me how you\'ve been eating and feeling, and we\'ll find one small, steadying change that fits your day.',
    quickPrompts: [
      'My energy crashes mid-afternoon. What should I change?',
      'Give me three simple, balanced dinners for a busy week.',
      'How should I fuel before and after an evening workout?',
    ],
    systemPrompt:
        'You are Tara, Vyana\'s private nourishment guide. Speak with warm, practical encouragement. Help the user eat for steady energy, recovery, and sustainable habits — simple meals, balanced plates, hydration, and fuelling around activity and sleep. Favour gentle, realistic changes over strict rules or restriction. Offer one clear, doable next step, then an optional follow-up. Keep answers practical and uncluttered. Never output hidden reasoning, XML-like tags, or chain-of-thought. Do not prescribe diets for medical conditions, give clinical nutrition therapy, or claim certainty. If the user mentions disordered eating, a medical condition, or warning signs, encourage appropriate professional care.',
    flutterGemmaModelType: _kSharedModelType,
    modelFileType: _kSharedFileType,
    modelDownloadUrl: _kSharedModelUrl,
    huggingFaceToken: null,
  ),
};

class GuideModelState {
  final GuidePersonaDefinition definition;
  GuideModelStatus status;
  double progress;
  String? errorMessage;

  GuideModelState({
    required this.definition,
    this.status = GuideModelStatus.idle,
    this.progress = 0,
    this.errorMessage,
  });

  bool get isReady => status == GuideModelStatus.ready;

  String get statusLabel {
    switch (status) {
      case GuideModelStatus.idle:
        return 'Waiting';
      case GuideModelStatus.checking:
        return 'Checking';
      case GuideModelStatus.missing:
        return 'Not downloaded';
      case GuideModelStatus.downloading:
        return 'Downloading';
      case GuideModelStatus.verifying:
        return 'Verifying';
      case GuideModelStatus.ready:
        return 'Ready';
      case GuideModelStatus.failed:
        return 'Needs attention';
    }
  }
}

class GuideStorageSnapshot {
  final String? rootPath;
  final List<String> guideModelPaths;
  final String? voicePath;
  final String? whisperModelPath;
  final int guideModelBytes;
  final int voiceBytes;
  final int whisperModelBytes;

  const GuideStorageSnapshot({
    required this.rootPath,
    required this.guideModelPaths,
    required this.voicePath,
    required this.whisperModelPath,
    required this.guideModelBytes,
    required this.voiceBytes,
    required this.whisperModelBytes,
  });

  int get totalBytes => guideModelBytes + voiceBytes + whisperModelBytes;
}

/// Downloads, verifies, and tracks the on-device guide model bundle. Exposed to
/// the UI as a [ChangeNotifier]. Because every persona shares one bundle,
/// downloading any guide marks them all ready.
class GuideModelManager extends ChangeNotifier {
  static const _streamingEnabledKey = 'guide_streaming_enabled_v1';

  Future<void>? _initFuture;
  String? _storageDirectoryPath;
  String? _defaultStorageDirectoryPath;
  String? _globalError;
  bool _streamingEnabled = !Platform.isIOS;

  final Map<GuideKind, GuideModelState> _states = {
    for (final entry in guidePersonaDefinitions.entries)
      entry.key: GuideModelState(definition: entry.value),
  };

  Map<GuideKind, GuideModelState> get states => _states;

  String? get globalError => _globalError;

  String? get storageDirectoryPath => _storageDirectoryPath;

  String? get defaultStorageDirectoryPath => _defaultStorageDirectoryPath;

  bool get streamingEnabled => Platform.isIOS ? false : _streamingEnabled;

  /// The shared bundle is ready once any persona reports ready.
  bool get modelReady => activeGuideKinds.any((kind) => _states[kind]!.isReady);

  bool get allModelsReady =>
      activeGuideKinds.every((kind) => _states[kind]!.isReady);

  /// Aggregate download progress for the shared bundle (any persona that is
  /// mid-download reflects the same file).
  GuideModelState? get downloadingState {
    for (final kind in activeGuideKinds) {
      final state = _states[kind]!;
      if (state.status == GuideModelStatus.downloading ||
          state.status == GuideModelStatus.verifying) {
        return state;
      }
    }
    return null;
  }

  bool get runtimeAvailable => true;

  GuideModelState stateFor(GuideKind kind) => _states[kind]!;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await VyanaStorageService.instance.ensureReady();
      if (!VyanaStorageService.instance.isReady) {
        _globalError = VyanaStorageService.instance.failureReason ??
            'App storage is unavailable.';
        notifyListeners();
        return;
      }

      await AppStartupService.instance.ensureInitialized();
      _defaultStorageDirectoryPath = VyanaStorageService.instance.rootPath;
      _storageDirectoryPath = VyanaStorageService.instance.rootPath;

      final prefs = await SharedPreferences.getInstance();
      final savedStreaming = prefs.getBool(_streamingEnabledKey);
      _streamingEnabled = Platform.isIOS ? false : (savedStreaming ?? true);
      if (Platform.isIOS && savedStreaming != false) {
        await prefs.setBool(_streamingEnabledKey, false);
      }

      final seedDefinition = guidePersonaDefinitions[activeGuideKinds.first]!;
      await ensureGuideModelRegistered(seedDefinition);

      for (final kind in activeGuideKinds) {
        await _checkModelStatus(kind);
      }

      notifyListeners();
    } catch (error) {
      _globalError = 'Failed to initialize model storage: $error';
      notifyListeners();
    }
  }

  Future<void> _checkModelStatus(GuideKind kind) async {
    final state = _states[kind]!;
    if (state.status == GuideModelStatus.ready) {
      return;
    }
    state.status = GuideModelStatus.checking;
    notifyListeners();
    await recheckModelStatus(kind);
  }

  /// Public method to recheck model status (can be called from UI).
  Future<void> recheckModelStatus(GuideKind kind) async {
    final state = _states[kind]!;
    final definition = state.definition;
    final spec = guideInferenceModelSpec(definition);

    try {
      await AppStartupService.instance.ensureInitialized();
      final manager = FlutterGemmaPlugin.instance.modelManager;
      final isInstalled = await manager.isModelInstalled(spec);

      if (!isInstalled) {
        state.status = GuideModelStatus.missing;
        state.errorMessage = null;
        state.progress = 0;
      } else {
        final isValidArchive = await validateInstalledGuideModel(definition);
        if (isValidArchive) {
          state.status = GuideModelStatus.ready;
          state.errorMessage = null;
          state.progress = 1;
          _globalError = null;
        } else {
          state.status = GuideModelStatus.failed;
          state.errorMessage =
              '${definition.name} downloaded, but the model bundle is invalid. Delete and download again.';
        }
      }
    } catch (e, stack) {
      debugPrint('Check status error: $e');
      debugPrint('Stack: $stack');
      state.status = GuideModelStatus.failed;
      state.errorMessage = 'Failed to check model status: $e';
    }

    notifyListeners();
  }

  Future<void> recheckSharedModelStatuses(GuideKind kind) async {
    final definition = guidePersonaDefinitions[kind]!;
    for (final relatedKind in guideKindsSharingBundle(definition)) {
      await recheckModelStatus(relatedKind);
    }
  }

  Future<void> downloadModel(
    GuideKind kind, {
    void Function(double)? onProgress,
  }) async {
    final state = _states[kind]!;
    final definition = state.definition;
    final spec = guideInferenceModelSpec(definition);

    // Mirror the downloading state across every persona sharing the bundle so
    // the whole library shows progress at once.
    final sharing = guideKindsSharingBundle(definition);
    for (final related in sharing) {
      final s = _states[related]!;
      s.status = GuideModelStatus.downloading;
      s.progress = 0;
      s.errorMessage = null;
    }
    notifyListeners();

    debugPrint('Starting download for ${definition.name}');
    debugPrint('URL: ${definition.modelDownloadUrl}');

    try {
      await downloadGuideModelFile(
        definition,
        onProgress: (value) {
          for (final related in sharing) {
            _states[related]!.progress = value;
          }
          onProgress?.call(value);
          notifyListeners();
        },
      );

      for (final related in sharing) {
        _states[related]!.status = GuideModelStatus.verifying;
      }
      notifyListeners();

      await registerGuideModelAtPath(definition);

      final manager = FlutterGemmaPlugin.instance.modelManager;
      final installedNow = await manager.isModelInstalled(spec);
      final validNow = await validateInstalledGuideModel(definition);
      final isReady = installedNow && validNow;

      if (isReady) {
        for (final related in sharing) {
          final s = _states[related]!;
          s.status = GuideModelStatus.ready;
          s.progress = 1;
          s.errorMessage = null;
        }
        _globalError = null;
        debugPrint('Model ${definition.name} installed and verified');
      } else {
        await purgeInstalledGuideBundle(definition);
        for (final related in sharing) {
          final s = _states[related]!;
          s.status = GuideModelStatus.failed;
          s.errorMessage =
              'Downloaded the guide model, but it could not be validated. '
              'Delete it and download again.';
        }
        _globalError = state.errorMessage;
      }
    } catch (e, stack) {
      debugPrint('Download error: $e');
      debugPrint('Stack trace: $stack');
      for (final related in sharing) {
        final s = _states[related]!;
        s.status = GuideModelStatus.failed;
        s.errorMessage = 'Download failed: $e';
      }
      _globalError = state.errorMessage;
    }

    notifyListeners();
  }

  Future<void> setStreamingEnabled(bool enabled) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isIOS) {
      await prefs.setBool(_streamingEnabledKey, false);
      _streamingEnabled = false;
    } else {
      await prefs.setBool(_streamingEnabledKey, enabled);
      _streamingEnabled = enabled;
    }
    notifyListeners();
  }

  /// Deletes the shared bundle, marking every persona as missing.
  Future<void> deleteModel(GuideKind kind) async {
    final state = _states[kind]!;
    final spec = guideInferenceModelSpec(state.definition);

    try {
      await AppStartupService.instance.ensureInitialized();
      await FlutterGemmaPlugin.instance.modelManager.deleteModel(spec);

      final modelFile = File(guideModelTargetPath(state.definition));
      if (await modelFile.exists()) {
        await modelFile.delete();
      }

      for (final relatedKind in guideKindsSharingBundle(state.definition)) {
        final relatedState = _states[relatedKind]!;
        relatedState.status = GuideModelStatus.missing;
        relatedState.progress = 0;
        relatedState.errorMessage = null;
      }
    } catch (e) {
      state.errorMessage = 'Failed to delete model: $e';
    }

    notifyListeners();
  }

  Future<GuideStorageSnapshot> loadStorageSnapshot() async {
    await init();

    final voicePath = _storageDirectoryPath == null
        ? null
        : p.join(_storageDirectoryPath!, 'voice');
    final whisperModelPath = voicePath == null
        ? null
        : p.join(voicePath, 'whisper');

    final guideModelPaths = await _installedGuideModelPaths();
    final guideModelBytes = await _measureUniquePathsBytes(guideModelPaths);
    final whisperModelBytes = await _measurePathBytes(whisperModelPath);
    final rawVoiceBytes = await _measurePathBytes(voicePath);
    final voiceBytes = rawVoiceBytes > whisperModelBytes
        ? rawVoiceBytes - whisperModelBytes
        : 0;

    return GuideStorageSnapshot(
      rootPath: storageDirectoryPath,
      guideModelPaths: guideModelPaths,
      voicePath: voicePath,
      whisperModelPath: whisperModelPath,
      guideModelBytes: guideModelBytes,
      voiceBytes: voiceBytes,
      whisperModelBytes: whisperModelBytes,
    );
  }

  Future<List<String>> _installedGuideModelPaths() async {
    final uniquePaths = <String>{};
    for (final kind in activeGuideKinds) {
      final path = await resolveInstalledGuideModelPath(
        guidePersonaDefinitions[kind]!,
      );
      if (path != null && path.isNotEmpty) {
        uniquePaths.add(path);
      }
    }
    return uniquePaths.toList()..sort();
  }

  Future<int> _measureUniquePathsBytes(List<String> paths) async {
    var total = 0;
    for (final path in paths.toSet()) {
      total += await _measurePathBytes(path);
    }
    return total;
  }

  Future<int> _measurePathBytes(String? path) async {
    if (path == null || path.isEmpty) {
      return 0;
    }

    final type = FileSystemEntity.typeSync(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.file:
        return _measureFileBytes(path);
      case FileSystemEntityType.directory:
        final directory = Directory(path);
        if (!await directory.exists()) {
          return 0;
        }
        var total = 0;
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            try {
              total += await entity.length();
            } catch (_) {
              // Skip unreadable files while still reporting the rest.
            }
          }
        }
        return total;
      case FileSystemEntityType.notFound:
      case FileSystemEntityType.link:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        return 0;
    }

    return 0;
  }

  Future<int> _measureFileBytes(String? path) async {
    if (path == null || path.isEmpty) {
      return 0;
    }
    final file = File(path);
    if (!await file.exists()) {
      return 0;
    }
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

}

Future<void> downloadGuideModelFile(
  GuidePersonaDefinition definition, {
  void Function(double progress)? onProgress,
}) async {
  await VyanaStorageService.instance.ensureReady();
  final targetPath = guideModelTargetPath(definition);
  final targetFile = File(targetPath);
  await targetFile.parent.create(recursive: true);

  if (await targetFile.exists() &&
      await validateGuideBundleFile(targetPath, definition.modelFileType)) {
    onProgress?.call(1);
    return;
  }

  if (await targetFile.exists()) {
    await targetFile.delete();
  }

  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(definition.modelDownloadUrl));
    final token = definition.huggingFaceToken?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Model download failed with status ${response.statusCode}',
        uri: Uri.parse(definition.modelDownloadUrl),
      );
    }

    final totalBytes = response.contentLength;
    var receivedBytes = 0;
    final sink = targetFile.openWrite();

    await for (final chunk in response) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(receivedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();

    if (!await validateGuideBundleFile(targetPath, definition.modelFileType)) {
      await targetFile.delete();
      throw StateError('Downloaded model failed validation.');
    }
  } finally {
    client.close(force: true);
  }
}

Future<void> registerGuideModelAtPath(GuidePersonaDefinition definition) async {
  await AppStartupService.instance.ensureInitialized();
  final targetPath = guideModelTargetPath(definition);
  if (!await File(targetPath).exists()) {
    throw StateError('Guide model file not found at $targetPath');
  }

  final spec = guideInferenceModelSpec(definition);
  final manager = FlutterGemmaPlugin.instance.modelManager;

  if (await manager.isModelInstalled(spec)) {
    final existing = await resolveInstalledGuideModelPath(definition);
    if (existing == targetPath &&
        await validateInstalledGuideModel(definition)) {
      manager.setActiveModel(spec);
      return;
    }
    await manager.deleteModel(spec);
  }

  final installed = await FlutterGemma.installModel(
    modelType: definition.flutterGemmaModelType,
    fileType: definition.modelFileType,
  ).fromFile(targetPath).install();

  // Keep the active spec aligned with the FileSource path used at install time.
  manager.setActiveModel(installed.spec);
}

Future<void> ensureGuideModelRegistered(GuidePersonaDefinition definition) async {
  final targetPath = guideModelTargetPath(definition);
  if (!await File(targetPath).exists()) {
    return;
  }

  if (!await validateGuideBundleFile(
    targetPath,
    definition.modelFileType,
  )) {
    return;
  }

  try {
    await registerGuideModelAtPath(definition);
  } catch (error, stack) {
    debugPrint('[GuideModel] Registration failed: $error\n$stack');
  }
}

final guideModelManagerProvider = ChangeNotifierProvider<GuideModelManager>((
  ref,
) {
  final manager = GuideModelManager();
  manager.init();
  return manager;
});
