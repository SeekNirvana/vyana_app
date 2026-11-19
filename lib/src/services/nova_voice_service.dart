import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'nova_voice_assets.dart';
import 'spoken_text.dart';

/// Nova's own voice, generated on the phone — and the only voice she has.
///
/// Nova used to speak through the phone's system text-to-speech
/// (`flutter_tts`), which is built for screen reading and sounds flat. That
/// fallback is gone: it was only ever as good as the engine the phone
/// happened to have, and on a phone without Google services — which the
/// dApp Store build cannot assume — it was the screen-reader voice nobody
/// wants guidance in. She speaks with Kokoro, run locally through
/// sherpa-onnx, or she does not speak.
///
/// Three rules hold without exception:
///
/// * **Never a cloud voice.** Every reply would leave the phone, which breaks
///   "This conversation never leaves your phone". Nothing in this file opens
///   a socket; the only network access is the pinned, checksummed download in
///   [nova_voice_assets.dart], which happens once, when the user asks for it.
/// * **Verified before first load.** The model is re-checked against its
///   pinned SHA-256 before it is ever handed to sherpa-onnx.
/// * **Silence, not a worse voice.** If the voice is missing, still
///   downloading or fails its check, [isReady] stays false, the reply stays
///   on screen, and the UI says what is missing.
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

  /// Set when the pinned files failed to verify, so the UI can say why Nova
  /// has gone quiet rather than leaving the reply unexplained.
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
      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          kokoro: sherpa.OfflineTtsKokoroModelConfig(
            model: p.join(dir, kNovaVoiceModelFile),
            voices: p.join(dir, kNovaVoiceVoicesFile),
            tokens: p.join(dir, kNovaVoiceTokensFile),
            // Not `dataDir`. sherpa-onnx 2.0.1 tokenises Kokoro through the
            // lexicon only: with an espeak directory and no lexicon every
            // sentence fails with "No lexicon available" and generate()
            // hands back an empty waveform — silence that looks like a
            // working voice. See nova_voice_assets.dart.
            lexicon: p.join(dir, kNovaVoiceLexiconFile),
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

  /// Which of the pack's 11 English voices Nova uses.
  static const int kDefaultSpeakerId = 0;

  /// Cue audio prepared in advance, by [cueKey] (item 130).
  final Map<String, ({String path, Duration length})> _prepared = {};

  /// Completed when the current playback ends, or is stopped. Waiting on
  /// onPlayerComplete alone hung forever after a stop(), which never fires
  /// it.
  Completer<void>? _playing;

  /// The key a prepared phrase is kept under: the words as spoken, the
  /// rate, and the voice pack, so a new voice never plays an old file.
  static String cueKey(String text, double rate) =>
      '$kNovaVoiceVersion|$kDefaultSpeakerId|${rate.toStringAsFixed(2)}|'
      '${speakableText(text)}';

  /// Whether [text] at [rate] is ready to play without generating.
  bool isPrepared(String text, {double rate = 1.0}) =>
      _prepared.containsKey(cueKey(text, rate));

  /// Item 130: generates [text] once and keeps it as a file, so playing it
  /// later starts at once instead of 1–2 s after it was asked for.
  ///
  /// Kept on disk by a hash of [cueKey], so the next session (and the next
  /// launch) finds it without generating again. Generation runs on this
  /// isolate and blocks it while it runs, which is why callers do this
  /// before a pacer starts rather than when a phase changes.
  Future<void> prepare(String text, {double rate = 1.0}) async {
    final key = cueKey(text, rate);
    if (_prepared.containsKey(key)) return;
    final tts = _tts;
    if (tts == null) return;
    final normalized = speakableText(text);
    if (normalized.isEmpty) return;

    final dir = Directory(p.join(await novaVoiceDirectory(), 'cues'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${_stableHash(key)}.wav'));
    if (await file.exists() && await file.length() > 44) {
      _prepared[key] = (path: file.path, length: _wavLength(file));
      return;
    }
    try {
      final audio = tts.generate(
        text: normalized,
        sid: kDefaultSpeakerId,
        speed: rate,
      );
      if (audio.samples.isEmpty) return;
      sherpa.writeWave(
        filename: file.path,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      _prepared[key] = (
        path: file.path,
        length: Duration(
          microseconds:
              (audio.samples.length / audio.sampleRate * 1e6).round(),
        ),
      );
    } on Object catch (error) {
      debugPrint('[NovaVoice] could not prepare "$normalized": $error');
    }
  }

  /// Speaks [text] and completes when playback finishes.
  ///
  /// Throws if the voice is not loaded — callers check [isReady] first.
  ///
  /// Item 130: a phrase prepared with [prepare] plays straight away.
  /// Anything else is generated now, on this isolate: the native handle
  /// belongs to the one that created it, and sending the pointer elsewhere
  /// would be sharing a native object across threads. [maxNumSentences] is
  /// 1, so a long reply is generated a sentence at a time rather than in
  /// one blocking run.
  Future<void> speak(String text, {double rate = 1.0}) async {
    final tts = _tts;
    if (tts == null) throw StateError('Nova voice is not loaded');
    // The one place text becomes speech, so the one place numbers become
    // words. Kokoro's lexicon has no entry for any digit and skips what it
    // cannot find, which turned "Halfway. 5 minutes." into "Halfway.
    // minutes." — see spoken_text.dart.
    final normalized = speakableText(text);
    if (normalized.isEmpty) return;

    final ready = _prepared[cueKey(text, rate)];
    if (ready != null && File(ready.path).existsSync()) {
      await stop();
      await _play(ready.path, ready.length);
      return;
    }

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
    await _play(
      wav.path,
      Duration(
        microseconds: (audio.samples.length / audio.sampleRate * 1e6).round(),
      ),
    );
  }

  Future<void> _play(String path, Duration length) async {
    final done = Completer<void>();
    _playing = done;
    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _player.play(DeviceFileSource(path));
      // A ceiling, in case the player never reports the end.
      await done.future.timeout(
        length + const Duration(seconds: 2),
        onTimeout: () {},
      );
    } finally {
      await sub.cancel();
      if (identical(_playing, done)) _playing = null;
    }
  }

  Future<void> stop() async {
    final playing = _playing;
    if (playing != null && !playing.isCompleted) playing.complete();
    try {
      await _player.stop();
    } on Object {
      // Nothing playing is not an error.
    }
  }

  /// FNV-1a, so a cue's file name is the same on every launch (String
  /// hashCode is not guaranteed to be).
  static String _stableHash(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Length of a 16-bit mono WAV from its size; a ceiling for [_play].
  static Duration _wavLength(File file) {
    try {
      final bytes = file.lengthSync() - 44;
      final header = file.openSync()..setPositionSync(24);
      final rateBytes = header.readSync(4);
      header.closeSync();
      final sampleRate = rateBytes[0] |
          (rateBytes[1] << 8) |
          (rateBytes[2] << 16) |
          (rateBytes[3] << 24);
      if (sampleRate <= 0) return const Duration(seconds: 5);
      // sherpa writes 16-bit mono.
      return Duration(
        microseconds: (bytes / 2 / sampleRate * 1e6).round(),
      );
    } on Object {
      return const Duration(seconds: 5);
    }
  }

  /// Frees the native handle. Called when the voice is deleted or replaced.
  Future<void> dispose() async {
    await stop();
    _tts?.free();
    _tts = null;
  }
}
