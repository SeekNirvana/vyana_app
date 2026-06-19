import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
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

/// Resolved inference settings for one persona after applying DB overrides.
class GuidePersonaEffectiveConfig {
  final String personaId;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final GuideResponseLength responseLength;
  final bool usesCustomSystemPrompt;
  final bool usesTemperatureOverride;
  final DateTime? prefsUpdatedAt;

  const GuidePersonaEffectiveConfig({
    required this.personaId,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
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
  static const int androidBalancedMaxTokens = 1024;
  static const int iosBalancedMaxTokens = 512;

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
      systemPrompt: usesCustom ? customPrompt : definition.systemPrompt,
      temperature: (prefs?.temperatureOverride ?? defaultTemperature)
          .clamp(0.2, 1.2),
      maxTokens: maxTokensFor(responseLength),
      responseLength: responseLength,
      usesCustomSystemPrompt: usesCustom,
      usesTemperatureOverride: usesTemperature,
      prefsUpdatedAt: prefs?.updatedAt,
    );
  }

  int maxTokensFor(GuideResponseLength length) {
    final balanced = defaultTargetPlatform == TargetPlatform.iOS
        ? iosBalancedMaxTokens
        : androidBalancedMaxTokens;

    return switch (length) {
      GuideResponseLength.short => (balanced * 0.5).round(),
      GuideResponseLength.balanced => balanced,
      GuideResponseLength.detailed => (balanced * 1.5).round(),
    };
  }

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