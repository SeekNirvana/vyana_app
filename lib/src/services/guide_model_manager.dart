import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_startup_service.dart';
import 'nova_voice_assets.dart';
import 'on_device_models.dart';
import 'vyana_storage_service.dart';

/// On-device guide personas. Each maps to a string id used by the Vyana guide
/// catalog (see `catalog.dart`). Every persona runs on the same shared Gemma
/// model bundle — only the system prompt differs — so a single download unlocks
/// all of them.
/// One assistant, one model. Luna, Maya, Aran, Ravi and Tara were defined
/// here and surfaced nowhere — `catalog.dart` has only ever listed Nova — so
/// they have been removed rather than left as five authored voices that no
/// code path can reach.
enum GuideKind { nova }

const List<GuideKind> activeGuideKinds = [GuideKind.nova];

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
/// The model the user picked, as the download, the validator, the spec and
/// every label all read it.
///
/// Module-level and mutable, which is unusual here and deliberate: the
/// persona definitions are `const` and carry Nova's words, while the model
/// is a setting that changes under them. The alternative was threading a
/// model through a dozen helpers that only ever have a definition to hand,
/// which spreads the question "which model is this?" rather than answering
/// it once. [GuideModelManager] keeps it in step with the stored choice.
OnDeviceModel _activeOnDeviceModel =
    onDeviceModelById(kDefaultOnDeviceModelId);

OnDeviceModel get activeOnDeviceModel => _activeOnDeviceModel;

void setActiveOnDeviceModel(OnDeviceModel model) {
  _activeOnDeviceModel = model;
}

const String _kSharedModelLabel = 'Gemma E2B';

/// Exact download size of the model now selected, in bytes.
///
/// Was a const tied to Gemma; it follows the picker now.
///
/// A byte count rather than a hand-typed string because the string was
/// wrong: it read "3.1 GB" against a file of 2,586,706,331 bytes — half a
/// gigabyte of overstatement on the one number that decides whether someone
/// starts the download at all. It had also been "3.2 GB" at one point, to
/// fold in a voice that was never part of this file.
///
/// Confirmed with `curl -sIL` against the Hugging Face URL below; re-check
/// it when [_kSharedModelUrl] changes.
int get kGuideModelBytes => activeOnDeviceModel.bytes;

/// That size, said the way the UI should say it.
String get kGuideModelSizeLabel => formatDownloadSize(kGuideModelBytes);

/// Download sizes in the units people read them in: GB to one decimal above
/// a gigabyte, whole MB below. Decimal, like every download manager and
/// every store listing — not the 1024-based figure, which would call this
/// file 2.4 GB and disagree with the phone.
String formatDownloadSize(int bytes) {
  if (bytes <= 0) return '0 MB';
  const mb = 1000 * 1000;
  if (bytes >= 1000 * mb) {
    return '${(bytes / (1000 * mb)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / mb).round()} MB';
}

/// **Nova's voice is not in this figure.** It used to be: the voice was
/// folded into the same install step at an estimated 90 MB. It is its own
/// opt-in now and advertises its own size ([novaVoiceApproxSizeLabel]).
/// Nova works without it; she just does not read her replies aloud.
const String kGuideModelSizeNote =
    "Nova's voice is a separate download.";

/// Item 51 — Nova's instructions. Roughly 150 tokens, about half the length
/// of the prompt it replaces, because the cap it shares with the data blocks
/// and the conversation is small (see [GuidePersonaPrefsService.maxTokensFor]).
///
/// The first two rules are the fix: answer what was asked, and say plainly
/// when the data does not show something. [kNovaListenFirstRules] keeps them
/// in force even behind a custom prompt.
const String kNovaSystemPrompt =
    "You are Nova, Vyana's private guide, running only on the user's phone. "
    'You help with readiness and training, sleep and recovery, dreams and '
    'journaling, breath and mindfulness, movement and food.\n'
    '$kNovaListenFirstRules\n'
    "Warm, plain and brief. Don't diagnose or mention medication. For pain, "
    'dizziness, chest symptoms or self-harm, urge rest and professional care.';

/// The two rules that survive a custom prompt (item 51). Without them a
/// custom prompt would bring the original bug straight back.
const String kNovaListenFirstRules =
    'Listen first: respond fully to what the person asked or wants to talk '
    'about, using the DATA and LOOKUP lines, and add a relevant follow-up if '
    'it helps. Only once that is settled, you may offer one suggestion or ask '
    "about today's plan.\n"
    "If the data doesn't show something, say so plainly and name what to "
    'check (ring worn, charged, synced). Never guess numbers.';


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
  return Uri.parse(activeOnDeviceModel.url).pathSegments.last;
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
    modelType: activeOnDeviceModel.modelType,
    fileType: activeOnDeviceModel.fileType,
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

/// Whether the bundle at [filePath] is whole enough to hand to the native
/// parser.
///
/// [expectedBytes] is what the model is supposed to weigh. It used to be a
/// flat `> 1.5 GB`, with a comment saying "Gemma models are typically
/// > 1.5GB" — true of Gemma and of nothing else. A 614 MB Qwen bundle
/// downloaded perfectly and was then deleted as corrupt, which is a hard
/// failure to read from the outside: the download bar fills and the model
/// never appears.
///
/// A truncated file is still rejected, and more precisely than before: the
/// point of the check is that a half-written bundle crashes the C++
/// FlatBuffer parser with EXC_BAD_ACCESS, and 2% short of the expected size
/// catches that far better than a threshold borrowed from a different model.
Future<bool> validateGuideBundleFile(
  String? filePath,
  ModelFileType fileType, {
  required int expectedBytes,
}) async {
  if (filePath == null || filePath.isEmpty) {
    return false;
  }

  final file = File(filePath);
  if (!await file.exists()) {
    return false;
  }

  if (fileType != ModelFileType.task) {
    final fileLength = await file.length();
    if (expectedBytes > 0) {
      return fileLength >= (expectedBytes * 0.98).floor();
    }
    // No expectation recorded: fall back to "not obviously truncated".
    return fileLength > 1024 * 1024;
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
      activeOnDeviceModel.fileType,
      expectedBytes: activeOnDeviceModel.bytes,
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
  return validateGuideBundleFile(
    path,
    activeOnDeviceModel.fileType,
    expectedBytes: activeOnDeviceModel.bytes,
  );
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
  // ── Nova — daytime vitality coach (authored in the same voice) ────────────
  GuideKind.nova: GuidePersonaDefinition(
    kind: GuideKind.nova,
    name: 'Nova',
    title: 'Private guide',
    specialty: 'Sleep, mind, movement and nourishment — one guide for all of it',
    modelLabel: _kSharedModelLabel,
    repoId: _kSharedRepoId,
    remoteDirectory: '',
    localFolderName: 'nova-gemma',
    shortDescription:
        'Your one private guide: readiness and training, sleep and recovery, dreams and reflection, breath and calm, and eating for steady energy — all on-device.',
    tooltipSummary:
        'Nova is the single Vyana guide. Ask about today\'s readiness and how hard to train, sleep and recovery, a dream or a reflection, a breath practice to settle, or what to eat for steady energy.',
    starterMessage:
        'I\'m Nova. Tell me what\'s on your mind — how you slept, how you feel, a dream, a plan for today — and we\'ll find one focused next step.',
    quickPrompts: [
      'My readiness is low today — what should I do?',
      'I woke at 3am again. What might be going on?',
      'Help me settle in the next four minutes.',
      'I keep dreaming about water — what could it mean?',
    ],
    // Item 51: Nova used to be told to "favour one clear next step" and what
    // "a broken night means for today", with no rule to answer the question
    // first or to admit she cannot see something — so asked why last night's
    // score was missing she kept steering back to today. Listening comes
    // first now, and the DATA/LOOKUP blocks give her something to answer
    // with. About half the tokens of the old prompt.
    systemPrompt: kNovaSystemPrompt,
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
    debugPrint('URL: ${activeOnDeviceModel.url}');

    // Bug 42: Nova's voice installs with Nova, in the same step. The voice is
    // a rounding error beside the model, so the bar stays on the model and
    // the voice takes the last sliver.
    const voiceShare = 0.03;
    try {
      await downloadGuideModelFile(
        definition,
        onProgress: (value) {
          final scaled = value * (1 - voiceShare);
          for (final related in sharing) {
            _states[related]!.progress = scaled;
          }
          onProgress?.call(scaled);
          notifyListeners();
        },
      );

      // Hosted by us, pinned by SHA-256 and verified before it is ever
      // loaded. A failure here never fails the install: Nova falls back to
      // the best offline system voice (see NovaVoiceService).
      try {
        await downloadNovaVoice(
          onProgress: (value) {
            final scaled = (1 - voiceShare) + value * voiceShare;
            for (final related in sharing) {
              _states[related]!.progress = scaled;
            }
            onProgress?.call(scaled);
            notifyListeners();
          },
        );
      } on Object catch (error) {
        debugPrint('[GuideModel] Nova voice download failed: $error');
      }

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

      // Bug 42: deleting Nova deletes her voice. It lives in app-private
      // storage beside the model, and leaving ~90 MB behind for a guide the
      // user has removed is not a kindness.
      await deleteNovaVoice();

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
      await validateGuideBundleFile(targetPath, activeOnDeviceModel.fileType,
          expectedBytes: activeOnDeviceModel.bytes)) {
    onProgress?.call(1);
    return;
  }

  if (await targetFile.exists()) {
    await targetFile.delete();
  }

  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(activeOnDeviceModel.url));
    final token = definition.huggingFaceToken?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Model download failed with status ${response.statusCode}',
        uri: Uri.parse(activeOnDeviceModel.url),
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

    if (!await validateGuideBundleFile(targetPath, activeOnDeviceModel.fileType,
        expectedBytes: activeOnDeviceModel.bytes)) {
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
    modelType: activeOnDeviceModel.modelType,
    fileType: activeOnDeviceModel.fileType,
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
    activeOnDeviceModel.fileType,
    expectedBytes: activeOnDeviceModel.bytes,
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
