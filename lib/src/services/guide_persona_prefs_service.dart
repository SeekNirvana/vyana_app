import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import 'device_capability_service.dart';
import 'guide_model_manager.dart';

/// User-selectable response length presets mapped to on-device max tokens.
enum GuideResponseLength {
  short,
  balanced,
  detailed;

  String get storageValue => name;

  String get label => switch (this) {
        GuideResponseLength.short => 'Short',
        GuideResponseLength.balanced => 'Balanced',
        GuideResponseLength.detailed => 'Detailed',
      };

  String get description => switch (this) {
        GuideResponseLength.short =>
          'Quick coaching — about one short paragraph.',
        GuideResponseLength.balanced =>
          'Default depth — concise but complete.',
        GuideResponseLength.detailed =>
          'Richer answers — up to a few paragraphs or a list.',
      };

  static GuideResponseLength fromStorage(String? raw) {
    return GuideResponseLength.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => GuideResponseLength.balanced,
    );
  }
}

/// What to ask of the model about length, in words.
///
/// Item 70: "Short" used to be implemented by halving the context window,
/// which does not shorten an answer — it shortens the model's memory of
/// the question. Asking in the system prompt costs about ten tokens and
/// actually describes the thing wanted.
String replyLengthInstruction(GuideResponseLength length) =>
    switch (length) {
      GuideResponseLength.short =>
        'Keep your answer to two or three sentences.',
      GuideResponseLength.balanced =>
        'Keep your answer to a short paragraph.',
      GuideResponseLength.detailed =>
        'You may take a few short paragraphs if the question needs them.',
    };

/// Resolved inference settings for one persona after applying DB overrides.
class GuidePersonaEffectiveConfig {
  final String personaId;
  final String systemPrompt;
  final double temperature;

  /// The whole context window: instructions, data blocks, the conversation
  /// and the reply. Item 70: this is a property of the phone, not of how
  /// long someone likes their answers, and treating it as both is what let
  /// "Short" halve the window to 256 on iOS and push every message over.
  final int contextTokens;

  /// How long a reply may be. The cap an endpoint is given, and what the
  /// instruction in the system prompt asks of an on-device model.
  final int replyTokens;

  final GuideResponseLength responseLength;
  final bool usesCustomSystemPrompt;
  final bool usesTemperatureOverride;
  final DateTime? prefsUpdatedAt;

  const GuidePersonaEffectiveConfig({
    required this.personaId,
    required this.systemPrompt,
    required this.temperature,
    required this.contextTokens,
    required this.replyTokens,
    required this.responseLength,
    required this.usesCustomSystemPrompt,
    required this.usesTemperatureOverride,
    this.prefsUpdatedAt,
  });
}

/// Persists and resolves per-persona guide overrides from the local vault DB.
class GuidePersonaPrefsService extends ChangeNotifier {
  GuidePersonaPrefsService(this._db);

  static const double defaultTemperature = 0.8;
  /// The context window, shared by the instructions, the data blocks, the
  /// conversation and the reply itself.
  ///
  /// Item 124 (decided 15 Nov, replacing item 51's "leave the cap alone"):
  /// 2,048 tokens on a phone with enough memory, 1,024 on a low-memory one,
  /// the same on Android and iPhone. 2,048 is Google's own published setup
  /// for Gemma 4 E2B on LiteRT-LM on phones; the model itself takes 32k.
  /// 1,024 left about 700 words for instructions, data, conversation and
  /// reply together, which is one of the suspects in Nova stopping after a
  /// few words (123). The app chooses; there is no user setting.
  ///
  /// Item 70 changed how they are *used*: the response length setting does
  /// not scale them. A smaller window does not produce a shorter answer, it
  /// produces a forgotten question.
  static const int fullWindowTokens = 2048;
  static const int lowMemoryWindowTokens = 1024;

  final VyanaDatabase _db;

  Future<GuidePersonaPrefRow?> getPrefs(String personaId) {
    return _db.getGuidePersonaPrefs(personaId);
  }

  Stream<GuidePersonaPrefRow?> watchPrefs(String personaId) {
    return _db.watchGuidePersonaPrefs(personaId);
  }

  Future<GuidePersonaEffectiveConfig> effectiveConfigForPersonaId(
    String personaId,
  ) async {
    final kind = guideKindForId(personaId);
    if (kind == null) {
      throw ArgumentError('Unknown persona id: $personaId');
    }
    return effectiveConfig(guidePersonaDefinitions[kind]!);
  }

  Future<GuidePersonaEffectiveConfig> effectiveConfig(
    GuidePersonaDefinition definition,
  ) async {
    final personaId = definition.kind.name;
    final prefs = await _db.getGuidePersonaPrefs(personaId);
    final responseLength =
        GuideResponseLength.fromStorage(prefs?.responseLength);
    final customPrompt = prefs?.customSystemPrompt?.trim();
    final usesCustom = customPrompt != null && customPrompt.isNotEmpty;
    final usesTemperature = prefs?.temperatureOverride != null;

    return GuidePersonaEffectiveConfig(
      personaId: personaId,
      // Item 51: a custom prompt replaces the built-in one, but the two
      // rules that fix the reported bug are kept — without them a custom
      // prompt brings "let's focus on today" straight back. The data blocks
      // are appended either way, by the caller.
      // Item 70: the response length is asked for in words now, because
      // shrinking the window was never a way to shorten an answer.
      systemPrompt: [
        usesCustom
            ? '$customPrompt\n$kNovaListenFirstRules'
            : definition.systemPrompt,
        replyLengthInstruction(responseLength),
      ].join('\n'),
      temperature: (prefs?.temperatureOverride ?? defaultTemperature)
          .clamp(0.2, 1.2),
      contextTokens: contextTokensFor(
        lowRam: await DeviceCapabilityService.instance.isLowRam(),
      ),
      replyTokens: replyTokensFor(responseLength),
      responseLength: responseLength,
      usesCustomSystemPrompt: usesCustom,
      usesTemperatureOverride: usesTemperature,
      prefsUpdatedAt: prefs?.updatedAt,
    );
  }

  /// The context window for this phone.
  ///
  /// Item 124: by memory, not by platform. [lowRam] is
  /// [DeviceCapabilityService.isLowRam] (under 6 GB); a phone whose memory
  /// cannot be read gets the full window, as Gemma's own setup does.
  static int contextTokensFor({required bool lowRam}) =>
      lowRam ? lowMemoryWindowTokens : fullWindowTokens;

  /// How long a reply may be.
  ///
  /// Reply-sized numbers rather than window-sized ones, and the same on
  /// every platform: this is the cap sent to someone's own server as
  /// `max_tokens`, where the window is not the phone's problem. On-device
  /// the instruction below is what does the steering, since the runtime
  /// takes no per-reply cap.
  static int replyTokensFor(GuideResponseLength length) =>
      switch (length) {
        GuideResponseLength.short => 200,
        GuideResponseLength.balanced => 400,
        GuideResponseLength.detailed => 800,
      };

  Future<void> savePrefs({
    required String personaId,
    String? customSystemPrompt,
    required GuideResponseLength responseLength,
    double? temperatureOverride,
  }) async {
    final trimmedPrompt = customSystemPrompt?.trim();
    await _db.upsertGuidePersonaPrefs(
      personaId: personaId,
      customSystemPrompt:
          trimmedPrompt == null || trimmedPrompt.isEmpty ? null : trimmedPrompt,
      responseLength: responseLength.storageValue,
      temperatureOverride: temperatureOverride,
    );
    notifyListeners();
  }

  Future<void> resetPrefs(String personaId) async {
    await _db.deleteGuidePersonaPrefs(personaId);
    notifyListeners();
  }
}

final guidePersonaPrefsServiceProvider =
    ChangeNotifierProvider<GuidePersonaPrefsService>((ref) {
  final service = GuidePersonaPrefsService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});