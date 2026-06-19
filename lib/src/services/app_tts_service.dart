import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Single on-device TTS engine for the whole app.
///
/// [flutter_tts] uses one platform channel. Creating multiple [FlutterTts]
/// instances (e.g. guide replies + session voice cues) overwrites the channel
/// handler and breaks spoken playback.
///
/// Guide read-aloud uses the same iOS audio session as SeekNirvana mobile-app
/// (`playback` + `voicePrompt`). Mic capture switches to `playAndRecord` only
/// while recording — locking playAndRecord at startup silences TTS.
class AppTtsService {
  AppTtsService._();

  static final AppTtsService instance = AppTtsService._();

  final FlutterTts tts = FlutterTts();

  /// Re-attach this instance as the active platform-channel handler.
  void rebindMethodChannel() {
    const MethodChannel('flutter_tts')
        .setMethodCallHandler(tts.platformCallHandler);
  }

  void bindHandlers({
    void Function()? onStart,
    void Function()? onComplete,
    void Function()? onCancel,
    ErrorHandler? onError,
  }) {
    if (onStart != null) {
      tts.setStartHandler(onStart);
    }
    if (onComplete != null) {
      tts.setCompletionHandler(onComplete);
    }
    if (onCancel != null) {
      tts.setCancelHandler(onCancel);
    }
    if (onError != null) {
      tts.setErrorHandler(onError);
    }
    rebindMethodChannel();
  }

  /// Configure for guide read-aloud and session voice cues (mobile-app parity).
  Future<void> prepareGuideSpeech({double speechRate = 0.45}) async {
    rebindMethodChannel();
    await tts.awaitSpeakCompletion(true);
    await tts.setSpeechRate(speechRate);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);

    if (Platform.isIOS) {
      await tts.setSharedInstance(true);
      await tts.autoStopSharedSession(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions
              .interruptSpokenAudioAndMixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    if (Platform.isAndroid) {
      await _preferGoogleEngine();
    }
  }

  /// Switch iOS audio route for microphone capture (Whisper STT).
  Future<void> prepareRecording() async {
    if (!Platform.isIOS) return;
    rebindMethodChannel();
    await tts.stop();
    await tts.autoStopSharedSession(false);
    await tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playAndRecord,
      const [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
  }

  /// Stop any in-flight utterance and prime the engine for read-aloud.
  Future<void> preparePlayback({double speechRate = 0.45}) async {
    await prepareGuideSpeech(speechRate: speechRate);
    await tts.stop();
    if (Platform.isAndroid) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  /// Back-compat alias — always re-applies the guide-speech audio route.
  Future<void> ensureReady({double speechRate = 0.45}) {
    return prepareGuideSpeech(speechRate: speechRate);
  }

  Future<void> _preferGoogleEngine() async {
    try {
      final engines = await tts.getEngines;
      if (engines is! List) return;
      final google = engines.cast<String?>().firstWhere(
        (engine) =>
            engine?.toLowerCase().contains('google') ?? false,
        orElse: () => null,
      );
      if (google != null) {
        await tts.setEngine(google);
      }
    } on Object {
      // Best-effort — system default is fine when Google TTS is absent.
    }
  }
}