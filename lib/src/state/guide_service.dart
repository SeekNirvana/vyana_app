part of '../../main.dart';

/// A single chat turn in the guides UI.
class GuideMessage {
  const GuideMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// Maps a catalog [GuidePersona] id to its on-device runtime [GuideKind].
GuideKind guideKindForPersona(GuidePersona persona) =>
    guideKindForId(persona.id) ?? GuideKind.nova;

/// The runtime persona definition (system prompt, starter line, quick prompts)
/// backing a catalog [GuidePersona].
GuidePersonaDefinition guideDefinitionFor(GuidePersona persona) =>
    guidePersonaDefinitions[guideKindForPersona(persona)]!;

/// The single currently-active guide (only one runs at a time).
final activeGuideIdProvider = StateProvider<String>((_) => 'nova');

/// Personas whose on-device model is installed. Every guide shares one model
/// bundle, so they all become available the moment it finishes downloading.
final installedGuidesProvider = Provider<Set<String>>((ref) {
  final manager = ref.watch(guideModelManagerProvider);
  if (!manager.modelReady) return const <String>{};
  return GuideKind.values.map((kind) => kind.name).toSet();
});

/// Whether the on-device guide model bundle is downloaded and verified.
final guideModelReadyProvider = Provider<bool>((ref) {
  return ref.watch(guideModelManagerProvider).modelReady;
});

/// Whether the Vani Voice speech model (offline STT) is installed.
final vaniVoiceInstalledProvider = Provider<bool>((ref) {
  return ref.watch(guideVoiceServiceProvider).whisperModelReady;
});
