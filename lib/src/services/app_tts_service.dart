import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The app's audio-session router. It no longer speaks.
///
/// Vyana used to read guidance aloud through the phone's own text-to-speech.
/// It doesn't any more: `flutter_tts` is only ever as good as the engine the
/// phone happens to have, and on a phone without Google services — which is
/// every install we cannot assume, since Vyana ships through the dApp Store
/// — that is a flat screen-reader voice. Nova speaks with Kokoro or not at
/// all (see [NovaVoiceService]).
///
/// What remains here is the one thing `flutter_tts` still does for us:
/// setting the shared `AVAudioSession` category. That session is
/// process-wide, so it governs Kokoro's playback through `audioplayers` and
/// the mic capture through `record` just as it governed speech before.
/// Playback wants `playback` + `voicePrompt`; capture switches to
/// `playAndRecord` only while recording, because locking `playAndRecord` at
/// startup silences playback.
///
/// This could be done with `audioplayers`' own `AudioContext` and the
/// dependency dropped. It is left here deliberately: this is the routing
/// already proven on device, and swapping it blind would risk guided
/// sessions on a platform this machine cannot test.
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

  /// Route audio for playback — Kokoro's generated WAV and session cues.
  ///
  /// [speechRate] and the pitch/volume calls are vestigial: nothing here
  /// speaks any more, and Kokoro's rate is passed to its own generate(). The
  /// calls are kept because `rebindMethodChannel` plus a settled engine is
  /// what makes the iOS category change below stick.
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
}
