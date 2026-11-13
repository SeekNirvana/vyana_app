import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'nova_voice_assets.dart';

/// Bug 42 — Nova's own voice, generated on the phone.
///
/// Nova used to speak through the phone's system text-to-speech
/// (`flutter_tts`), which is built for screen reading and sounds flat. She now
/// speaks with Kokoro, a neural voice run locally through sherpa-onnx.
///
/// Three rules hold without exception:
///
/// * **Never a cloud voice.** Every reply would leave the phone, which breaks
///   "This conversation never leaves your phone". Nothing in this file opens
///   a socket; the only network access is the pinned, checksummed download in
///   [nova_voice_assets.dart], which happens once at install.
/// * **Verified before first load.** The model is re-checked against its
///   pinned SHA-256 before it is ever handed to sherpa-onnx.
/// * **Quiet fallback.** If the voice is missing, still downloading or fails
///   its check, [isReady] stays false and the caller falls back to the best
///   offline *system* voice.
///
/// Listening (Whisper, on device) is untouched.
class NovaVoiceService {
  NovaVoiceService._();

  static final NovaVoiceService instance = NovaVoiceService._();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  Future<void>? _loading;
  bool _bindingsReady = false;
  String? _lastError;

  /// Set when the pinned files failed to verify, so the UI can say why it is
  /// using a system voice rather than silently sounding different.
  String? get lastError => _lastError;

  bool get isReady => _tts != null;

  /// Loads Kokoro if its files are present and verified. Safe to call often;
  /// the work happens once. Returns false when the voice is not available,
  /// which is the signal to use a system voice instead.
  Future<bool> ensureLoaded() async {
    if (_tts != null) return true;
    if (!novaVoiceConfigured) return false;
    _loading ??= _load();
    await _loading;
    _loading = null;
    return _tts != null;
  }

  Future<void> _load() async {
    try {
      // Verified again here, not just after download: a file can be corrupted
      // on disk between the two, and the whole point of pinning is that
      // nothing unchecked is ever executed by the runtime.
      if (!await novaVoiceIsReady()) {
        _lastError = 'Nova\'s voice files are missing or did not verify.';
        return;
      }

      if (!_bindingsReady) {
        sherpa.initBindings();
        _bindingsReady = true;
      }

      final dir = await novaVoiceDirectory();
      final dataDir = p.join(dir, kNovaVoiceDataDir);
      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          kokoro: sherpa.OfflineTtsKokoroModelConfig(
            model: p.join(dir, kNovaVoiceModelFile),
            voices: p.join(dir, kNovaVoiceVoicesFile),
            tokens: p.join(dir, kNovaVoiceTokensFile),
            dataDir: dataDir,
          ),
          numThreads: 2,
          debug: false,
        ),
        maxNumSentences: 1,
      );
      _tts = sherpa.OfflineTts(config);
      _lastError = null;
    } on Object catch (error, stack) {
      debugPrint('[NovaVoice] load failed: $error\n$stack');
      _lastError = 'Nova\'s voice could not start: $error';
      _tts = null;
    }
  }

  /// One default voice per language; the picker can still choose a system
  /// voice instead, which is what [GuideVoiceService] falls back to.
  static const int kDefaultSpeakerId = 0;

  /// Speaks [text] and completes when playback finishes.
  ///
  /// Throws if the voice is not loaded — callers check [isReady] first.
  ///
  /// Generation runs on this isolate: the native handle belongs to the one
  /// that created it, and sending the pointer elsewhere would be sharing a
  /// native object across threads for the sake of a few hundred milliseconds.
  /// [maxNumSentences] is 1, so a long reply is generated a sentence at a
  /// time rather than in one blocking run.
  Future<void> speak(String text, {double rate = 1.0}) async {
    final tts = _tts;
    if (tts == null) throw StateError('Nova voice is not loaded');
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    await stop();
    final sherpa.GeneratedAudio audio;
    try {
      audio = tts.generate(
        text: normalized,
        sid: kDefaultSpeakerId,
        speed: rate,
      );
    } on Object catch (error) {
      debugPrint('[NovaVoice] generate failed: $error');
      _lastError = 'Nova could not speak that: $error';
      rethrow;
    }
    if (audio.samples.isEmpty) return;

    final wav = File(p.join(await novaVoiceDirectory(), 'reply.wav'));
    sherpa.writeWave(
      filename: wav.path,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
    await _player.play(DeviceFileSource(wav.path));
    await _player.onPlayerComplete.first;
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // Nothing playing is not an error.
    }
  }

  /// Frees the native handle. Called when the voice is deleted or replaced.
  Future<void> dispose() async {
    await stop();
    _tts?.free();
    _tts = null;
  }
}
