/// Bug 42 — the files that make up Nova's own voice, and the rules they are
/// fetched under.
///
/// Nova speaks with **Kokoro** (Apache 2.0, commercial use allowed), run on
/// the phone through **sherpa-onnx** (Apache 2.0). The model is weights only
/// (ONNX) and is executed inside sherpa-onnx: no code is downloaded and
/// nothing is executed from these files.
///
/// Every rule in the handover is enforced here rather than left to the caller:
///
/// * **Our own HTTPS host only.** [kNovaVoiceHost] is checked on every file;
///   a third-party mirror is refused at runtime, not merely discouraged.
/// * **SHA-256 pinned in the app build.** Each file carries its digest.
///   It is verified after download and again before first load; on a mismatch
///   the file is deleted and the download retried once.
/// * **Offline after download.** Nothing here runs at speak time.
/// * **App-private storage**, so deleting Nova deletes the voice with it.
///
/// **The exact artifact.** `kokoro-en-v0_19` from sherpa-onnx's pretrained
/// TTS models — English, 11 voices, full fp32 weights:
///
/// | File | Size |
/// |---|---|
/// | `model.onnx` | 330 MB |
/// | `voices.bin` | 5.5 MB |
/// | `tokens.txt` | 1.1 KB |
/// | `espeak-ng-data/` | ~18 MB |
///
/// **Deliberately not quantised.** int8 roughly thirds the model but its
/// spectral correlation against fp32 is about 0.92 — audible, and this is a
/// voice whose whole job is to sound calm during a practice. int8 also saves
/// download size and memory rather than inference time, so the usual reason
/// to accept the quality loss does not apply. The multi-lang packs carry a
/// Chinese lexicon and a 26 MB voice bank we would never call; the
/// English-only pack's `voices.bin` is 5.5 MB, which is where the real
/// saving is.
///
/// > **Packaging step, before this can ship.** [kNovaVoiceFiles] is empty
/// > until the Kokoro release is mirrored on our own host. For each file:
/// > take it from the official sherpa-onnx release, check it against the
/// > checksum published with that release, upload that exact file to
/// > `https://$kNovaVoiceHost/voices/kokoro/<version>/`, then record its URL,
/// > its `sha256sum` and its size below. Until then [novaVoiceConfigured] is
/// > false, no download is attempted, and the read-out feature is simply
/// > unavailable — it never falls back to a system voice or a cloud one.
/// The only host Nova's voice may be fetched from. We mirror Kokoro's release
/// ourselves so a third party cannot change what the app downloads.

library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'vyana_storage_service.dart';

/// The only host Nova's voice may be fetched from. We mirror Kokoro's release
/// ourselves so a third party cannot change what the app downloads.
const String kNovaVoiceHost = 'cdn.seeknirvana.app';

/// The Kokoro release this build is pinned to. Part of the stored path, so a
/// new version lands beside the old one rather than half-overwriting it.
///
/// This is the name sherpa-onnx publishes, not one of ours: there is no
/// `kokoro-v0.19-int8` upstream — v0.19 ships as fp32 only, and the int8
/// builds exist for the multi-lang packs. Naming a build that does not exist
/// is how a packaging step gets attempted and abandoned.
const String kNovaVoiceVersion = 'kokoro-en-v0_19';

/// One downloaded file, pinned by digest.
class PinnedAsset {
  const PinnedAsset({
    required this.name,
    required this.url,
    required this.sha256,
    required this.bytes,
  });

  /// File name on disk, inside the voice folder.
  final String name;

  /// Absolute HTTPS URL on our own host.
  final String url;

  /// Lower-case hex SHA-256 of the exact file we packaged.
  final String sha256;

  /// Expected size in bytes, used for the progress bar and as a cheap first
  /// check before hashing.
  final int bytes;
}

/// The files Kokoro needs through sherpa-onnx: the model, the voice
/// embeddings, the token table and the espeak-ng data directory.
///
/// Empty until the packaging step above is done. See the library doc.
const List<PinnedAsset> kNovaVoiceFiles = <PinnedAsset>[];

/// The name of the ONNX model inside [kNovaVoiceFiles], once it is populated.
/// Full-precision weights, as shipped — see the library doc on why.
const String kNovaVoiceModelFile = 'model.onnx';
const String kNovaVoiceVoicesFile = 'voices.bin';
const String kNovaVoiceTokensFile = 'tokens.txt';

/// The espeak-ng data directory, shipped as a tarball and expanded on first
/// use. sherpa-onnx wants a directory path, not a file.
const String kNovaVoiceDataArchive = 'espeak-ng-data.tar';
const String kNovaVoiceDataDir = 'espeak-ng-data';

/// Roughly the model plus its data, for the install prompt: 330 MB of
/// weights, 5.5 MB of voices and about 18 MB of espeak-ng data. Confirm
/// against the real files on a device once they are packaged.
///
/// This is large enough that it must stay an opt-in download the user asks
/// for — never part of the APK, and never fetched on first launch.
const int kNovaVoiceApproxBytes = 355 * 1024 * 1024;

/// The download size as the UI should say it, so the prompt, the settings
/// row and the progress bar cannot drift apart. MB below a gigabyte —
/// "0.35 GB" reads as a rounding error rather than a real number.
String get novaVoiceApproxSizeLabel {
  const mb = 1024 * 1024;
  if (kNovaVoiceApproxBytes < 1024 * mb) {
    return '${(kNovaVoiceApproxBytes / mb).round()} MB';
  }
  return '${(kNovaVoiceApproxBytes / (1024 * mb)).toStringAsFixed(1)} GB';
}

/// Whether this build actually has a voice to fetch. False until the files
/// above are packaged and pinned; everything downstream falls back quietly.
bool get novaVoiceConfigured => kNovaVoiceFiles.isNotEmpty;

/// Where the voice lives: app-private storage, beside Nova's own model, so
/// deleting Nova deletes the voice too.
Future<String> novaVoiceDirectory() async {
  await VyanaStorageService.instance.ensureReady();
  return p.join(
    VyanaStorageService.instance.modelsPath,
    'nova-voice',
    kNovaVoiceVersion,
  );
}

Future<String> novaVoiceFilePath(String name) async =>
    p.join(await novaVoiceDirectory(), name);

/// A file's SHA-256, streamed so a 90 MB model is never held in memory twice.
Future<String> fileSha256(File file) async {
  final digest = await file.openRead().transform(sha256).first;
  return digest.toString();
}

/// Whether [asset] is present and matches its pinned digest. Verified after
/// download *and* before first load, as the handover asks.
Future<bool> novaVoiceAssetIsValid(PinnedAsset asset) async {
  try {
    final file = File(await novaVoiceFilePath(asset.name));
    if (!await file.exists()) return false;
    if (await file.length() != asset.bytes) return false;
    return await fileSha256(file) == asset.sha256.toLowerCase();
  } on Object catch (error) {
    debugPrint('[NovaVoice] verify failed for ${asset.name}: $error');
    return false;
  }
}

/// Whether every pinned file is present and verified.
Future<bool> novaVoiceIsReady() async {
  if (!novaVoiceConfigured) return false;
  for (final asset in kNovaVoiceFiles) {
    if (!await novaVoiceAssetIsValid(asset)) return false;
  }
  return true;
}

/// Thrown when a pinned file does not match what we packaged. Never retried
/// more than once: a second mismatch means the file on the host is not the
/// file this build was pinned to, and guessing past that is how you end up
/// loading something nobody checked.
class NovaVoiceIntegrityException implements Exception {
  const NovaVoiceIntegrityException(this.asset, this.actual);

  final PinnedAsset asset;
  final String actual;

  @override
  String toString() =>
      'Nova voice file ${asset.name} did not match its pinned checksum '
      '(expected ${asset.sha256}, got $actual).';
}

/// Downloads every pinned file that is missing or invalid.
///
/// [onProgress] reports 0–1 across the whole set. Throws
/// [NovaVoiceIntegrityException] if a file still fails verification after one
/// retry, leaving nothing behind on disk.
Future<void> downloadNovaVoice({
  void Function(double progress)? onProgress,
}) async {
  if (!novaVoiceConfigured) return;
  final dir = Directory(await novaVoiceDirectory());
  await dir.create(recursive: true);

  final total = kNovaVoiceFiles.fold<int>(0, (sum, a) => sum + a.bytes);
  var done = 0;

  final client = HttpClient();
  try {
    for (final asset in kNovaVoiceFiles) {
      if (await novaVoiceAssetIsValid(asset)) {
        done += asset.bytes;
        onProgress?.call(total == 0 ? 1 : done / total);
        continue;
      }
      await _fetchVerified(
        client,
        asset,
        onBytes: (received) => onProgress?.call(
          total == 0 ? 1 : (done + received) / total,
        ),
      );
      done += asset.bytes;
      onProgress?.call(total == 0 ? 1 : done / total);
    }
  } finally {
    client.close(force: true);
  }
}

Future<void> _fetchVerified(
  HttpClient client,
  PinnedAsset asset, {
  void Function(int received)? onBytes,
}) async {
  final uri = Uri.parse(asset.url);
  // Our own host, over HTTPS, every time. A redirect to anywhere else is a
  // different file than the one this build pinned.
  if (uri.scheme != 'https' || uri.host != kNovaVoiceHost) {
    throw StateError(
      'Nova voice files are only fetched from https://$kNovaVoiceHost — '
      'refusing ${asset.url}',
    );
  }

  final file = File(await novaVoiceFilePath(asset.name));
  for (var attempt = 0; attempt < 2; attempt++) {
    if (await file.exists()) await file.delete();

    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Nova voice download failed with status ${response.statusCode}',
        uri: uri,
      );
    }

    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onBytes?.call(received);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    final actual = await fileSha256(file);
    if (actual == asset.sha256.toLowerCase()) return;

    // Delete and retry once, as the handover asks.
    debugPrint(
      '[NovaVoice] ${asset.name} checksum mismatch '
      '(expected ${asset.sha256}, got $actual)',
    );
    await file.delete();
    if (attempt == 1) throw NovaVoiceIntegrityException(asset, actual);
  }
}

/// Removes the voice. Called when Nova is deleted, so the two never drift
/// apart on disk.
Future<void> deleteNovaVoice() async {
  try {
    final dir = Directory(p.dirname(await novaVoiceDirectory()));
    if (await dir.exists()) await dir.delete(recursive: true);
  } on Object catch (error) {
    debugPrint('[NovaVoice] delete failed: $error');
  }
}

/// The Apache 2.0 notices that must travel with the binaries, shown in
/// You → About → Licences.
const List<({String name, String url, String licence})> kNovaVoiceLicences = [
  (
    name: 'Kokoro',
    url: 'https://github.com/hexgrad/kokoro',
    licence: 'Apache License 2.0',
  ),
  (
    name: 'sherpa-onnx',
    url: 'https://github.com/k2-fsa/sherpa-onnx',
    licence: 'Apache License 2.0',
  ),
];

/// Pretty-prints the pinned set for the Diagnostics screen, so a tester can
/// see which voice build is installed without digging in storage.
String novaVoiceFingerprint() {
  if (!novaVoiceConfigured) return 'not packaged';
  return jsonEncode({
    'version': kNovaVoiceVersion,
    'files': [
      for (final a in kNovaVoiceFiles)
        {'name': a.name, 'sha256': a.sha256.substring(0, 12)},
    ],
  });
}
