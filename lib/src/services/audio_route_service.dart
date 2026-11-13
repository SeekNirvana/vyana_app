import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// The app's audio-session router. It does not speak.
///
/// Vyana used to read guidance aloud through the phone's own text-to-speech,
/// and this class wrapped `flutter_tts` to do it. It doesn't any more:
/// `flutter_tts` is only ever as good as the engine the phone happens to
/// have, and on a phone without Google services — which is every install we
/// cannot assume, since Vyana ships through the dApp Store — that is a flat
/// screen-reader voice. Nova speaks with Kokoro or not at all (see
/// `NovaVoiceService`).
///
/// What was left afterwards was one job: setting the shared audio session's
/// category. `flutter_tts` was doing that as a side effect of being a speech
/// engine, which is a strange thing to keep a speech engine for. This uses
/// `audio_session`, which does exactly that and nothing else.
///
/// Two routes, and the order matters:
///
/// * **Playback** — Kokoro's generated WAV through `audioplayers`, and
///   session cues. `playback` on iOS, ducking others.
/// * **Recording** — mic capture through `record` for Whisper. Switches to
///   `playAndRecord` only while recording; locking `playAndRecord` at startup
///   makes playback quiet and tinny, which is the bug this ordering exists
///   to avoid.
class AudioRouteService {
  AudioRouteService._();

  static final AudioRouteService instance = AudioRouteService._();

  AudioSession? _session;
  bool _recordingRoute = false;

  Future<AudioSession> _ensureSession() async {
    return _session ??= await AudioSession.instance;
  }

  /// Route audio for playback — Kokoro's WAV and session cues.
  Future<void> prepareGuideSpeech() async {
    try {
      final session = await _ensureSession();
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
        ),
      );
      await session.setActive(true);
      _recordingRoute = false;
    } on Object catch (error) {
      // A phone that will not give us the session is a phone that plays at
      // whatever route it already had. Worth a line in the log, not worth
      // refusing to speak over.
      debugPrint('[Audio] playback route failed: $error');
    }
  }

  /// Switch the route for microphone capture (Whisper STT).
  Future<void> prepareRecording() async {
    try {
      final session = await _ensureSession();
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        ),
      );
      await session.setActive(true);
      _recordingRoute = true;
    } on Object catch (error) {
      debugPrint('[Audio] recording route failed: $error');
    }
  }

  /// Prime the route for read-aloud, re-applying it if a recording took it.
  Future<void> preparePlayback() async {
    await prepareGuideSpeech();
    if (Platform.isAndroid) {
      // The focus change does not land instantly; playing into it drops the
      // first syllable.
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  /// Hand audio focus back once nothing is playing or recording.
  Future<void> release() async {
    try {
      await _session?.setActive(false);
      _recordingRoute = false;
    } on Object catch (error) {
      debugPrint('[Audio] release failed: $error');
    }
  }

  /// Whether the session is currently routed for capture. Used by callers
  /// that must not start playback mid-recording.
  bool get isRecordingRoute => _recordingRoute;
}
