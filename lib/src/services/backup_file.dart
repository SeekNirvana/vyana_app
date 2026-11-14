/// Item 53 — the backup file: what goes in it, and how it is locked.
///
/// Everything Vyana holds lives on the phone, which is the point. The cost
/// is that deleting the app deletes the history, and neither Android nor
/// iOS tells an app it is being uninstalled — so there is no moment at
/// which to warn anyone. Exports already existed, but nothing could read
/// one back in, so they were a way out and not a way home.
///
/// This is the file that goes both ways. It is deliberately a *document*,
/// not a cloud account: the user chooses where it lands, and nothing about
/// it reaches us.
///
/// **Shape.** One plaintext header line, then the encrypted body:
///
/// ```
/// {"format":"vyana-backup","version":1,"kdf":{...},"salt":"…","nonce":"…"}
/// <base64 ciphertext+mac>
/// ```
///
/// The header is readable without the passphrase on purpose. A backup from
/// a newer Vyana has to be able to say "Update Vyana first" rather than
/// "wrong passphrase", and that judgement cannot wait until after a
/// decryption that was never going to work.
///
/// **Lock.** AES-256-GCM, with the key derived from the passphrase by
/// Argon2id. GCM rather than CBC so the file authenticates itself: a
/// truncated or edited backup fails its MAC instead of restoring plausible
/// nonsense over someone's history. Argon2id rather than a plain hash
/// because the passphrase is the only secret and it will usually be a
/// human one.
///
/// **The passphrase is never stored by this file.** It is not in the
/// header, not derivable from it, and not recoverable. That is the whole
/// security of the thing, and it is why the UI has to say, once and
/// plainly: without this passphrase the backup cannot be opened.
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// The format this build writes.
///
/// Bumped only when the *container* changes. What is inside it carries its
/// own version, so adding a table does not make every older backup
/// unreadable.
const int kBackupFormatVersion = 1;

/// Marks the file as ours before anything else is attempted.
const String kBackupFormatName = 'vyana-backup';

/// The extension the file is written with.
const String kBackupFileExtension = 'vyana';

/// Argon2id cost. Deliberately stated in the file rather than assumed, so a
/// backup written today still opens if these are raised later.
///
/// 19 MB and two passes is the OWASP floor for Argon2id, and about the most
/// that is comfortable on the oldest phone Vyana supports — the work has to
/// happen while someone waits, on a handset we do not choose.
const int kBackupKdfMemoryKb = 19456;
const int kBackupKdfIterations = 2;
const int kBackupKdfParallelism = 1;

/// Why a backup could not be opened.
///
/// Separate cases because they need separate words. "Wrong passphrase" and
/// "this file is damaged" send someone to different places, and telling
/// them the wrong one wastes the only copy of their history.
enum BackupFailure {
  /// Not a Vyana backup at all.
  notABackup,

  /// Written by a newer Vyana than this one.
  tooNew,

  /// The passphrase did not open it — or the file was altered.
  wrongPassphrase,

  /// Ours, the right version, and still unreadable.
  damaged,
}

class BackupException implements Exception {
  const BackupException(this.failure, [this.detail]);

  final BackupFailure failure;
  final String? detail;

  /// What a person should be told. Each one names what to do next, because
  /// "backup failed" leaves someone holding a file and no idea why.
  String get message {
    switch (failure) {
      case BackupFailure.notABackup:
        return 'That file is not a Vyana backup.';
      case BackupFailure.tooNew:
        return 'This backup was made by a newer version of Vyana. '
            'Update Vyana, then restore it.';
      case BackupFailure.wrongPassphrase:
        return 'That passphrase did not open the backup. It is the one you '
            'set when the backup was made, and there is no way to recover it.';
      case BackupFailure.damaged:
        return 'This backup could not be read. The file may be incomplete.';
    }
  }

  @override
  String toString() => 'BackupException(${failure.name}): $message';
}

/// What a backup says about itself before it is opened.
@immutable
class BackupHeader {
  const BackupHeader({
    required this.version,
    required this.createdAt,
    required this.appVersion,
    required this.salt,
    required this.nonce,
    required this.memoryKb,
    required this.iterations,
    required this.parallelism,
  });

  final int version;
  final DateTime createdAt;

  /// The Vyana that wrote it, for the "update first" message and for support.
  final String appVersion;

  final Uint8List salt;
  final Uint8List nonce;
  final int memoryKb;
  final int iterations;
  final int parallelism;

  /// Whether this build can open it at all.
  bool get isReadable => version <= kBackupFormatVersion;

  Map<String, Object?> toJson() => {
        'format': kBackupFormatName,
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'app': appVersion,
        'kdf': {
          'name': 'argon2id',
          'memoryKb': memoryKb,
          'iterations': iterations,
          'parallelism': parallelism,
        },
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
      };
}

/// Reads the header without the passphrase, and without decrypting.
///
/// Throws [BackupException] with [BackupFailure.notABackup] for anything
/// that is not one of ours, so a mis-picked file is named as such rather
/// than blamed on the passphrase.
BackupHeader readBackupHeader(List<int> bytes) {
  final newline = bytes.indexOf(0x0a);
  if (newline <= 0) {
    throw const BackupException(BackupFailure.notABackup, 'no header line');
  }
  Map<String, Object?> json;
  try {
    final decoded = jsonDecode(utf8.decode(bytes.sublist(0, newline)));
    if (decoded is! Map) {
      throw const BackupException(BackupFailure.notABackup);
    }
    json = Map<String, Object?>.from(decoded);
  } on BackupException {
    rethrow;
  } on Object {
    throw const BackupException(BackupFailure.notABackup, 'header not JSON');
  }

  if (json['format'] != kBackupFormatName) {
    throw const BackupException(BackupFailure.notABackup);
  }
  final version = json['version'];
  if (version is! int) {
    throw const BackupException(BackupFailure.notABackup, 'no version');
  }

  final kdf = json['kdf'];
  final kdfMap = kdf is Map ? Map<String, Object?>.from(kdf) : const {};

  return BackupHeader(
    version: version,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
    appVersion: json['app'] as String? ?? 'unknown',
    salt: _bytes(json['salt']),
    nonce: _bytes(json['nonce']),
    memoryKb: kdfMap['memoryKb'] as int? ?? kBackupKdfMemoryKb,
    iterations: kdfMap['iterations'] as int? ?? kBackupKdfIterations,
    parallelism: kdfMap['parallelism'] as int? ?? kBackupKdfParallelism,
  );
}

Uint8List _bytes(Object? value) {
  if (value is! String || value.isEmpty) return Uint8List(0);
  try {
    return base64Decode(value);
  } on Object {
    return Uint8List(0);
  }
}

/// Turns [payload] into the bytes of a backup file.
///
/// [payload] is the whole of what is being kept — the vault's rows plus
/// profile and settings. Models, the voice and caches are left out on
/// purpose: they are large, they are not the user's, and they download
/// again.
Future<Uint8List> writeBackup({
  required Map<String, Object?> payload,
  required String passphrase,
  required String appVersion,
  DateTime? createdAt,
  Random? random,
}) async {
  if (passphrase.isEmpty) {
    throw const BackupException(
      BackupFailure.wrongPassphrase,
      'a backup needs a passphrase',
    );
  }

  final rng = random ?? Random.secure();
  final salt = Uint8List.fromList(
    List<int>.generate(16, (_) => rng.nextInt(256)),
  );
  final nonce = Uint8List.fromList(
    List<int>.generate(12, (_) => rng.nextInt(256)),
  );

  final header = BackupHeader(
    version: kBackupFormatVersion,
    createdAt: createdAt ?? DateTime.now(),
    appVersion: appVersion,
    salt: salt,
    nonce: nonce,
    memoryKb: kBackupKdfMemoryKb,
    iterations: kBackupKdfIterations,
    parallelism: kBackupKdfParallelism,
  );

  final key = await _deriveKey(passphrase, header);
  final plain = utf8.encode(jsonEncode(payload));
  final box = await AesGcm.with256bits().encrypt(
    plain,
    secretKey: key,
    nonce: nonce,
  );

  final headerLine = utf8.encode(jsonEncode(header.toJson()));
  final body = base64Encode([...box.cipherText, ...box.mac.bytes]);
  return Uint8List.fromList([...headerLine, 0x0a, ...utf8.encode(body)]);
}

/// Opens a backup, or says precisely why it could not.
Future<Map<String, Object?>> openBackup({
  required List<int> bytes,
  required String passphrase,
}) async {
  final header = readBackupHeader(bytes);
  if (!header.isReadable) {
    throw const BackupException(BackupFailure.tooNew);
  }
  if (header.salt.isEmpty || header.nonce.isEmpty) {
    throw const BackupException(BackupFailure.damaged, 'no salt or nonce');
  }

  final newline = bytes.indexOf(0x0a);
  final List<int> raw;
  try {
    raw = base64Decode(utf8.decode(bytes.sublist(newline + 1)).trim());
  } on Object {
    throw const BackupException(BackupFailure.damaged, 'body not base64');
  }
  if (raw.length <= 16) {
    throw const BackupException(BackupFailure.damaged, 'body too short');
  }

  final key = await _deriveKey(passphrase, header);
  final cipherText = raw.sublist(0, raw.length - 16);
  final mac = Mac(raw.sublist(raw.length - 16));

  final List<int> plain;
  try {
    plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: header.nonce, mac: mac),
      secretKey: key,
    );
  } on SecretBoxAuthenticationError {
    // GCM cannot tell "wrong key" from "edited file", and for someone
    // holding their only backup the first is overwhelmingly the likelier.
    throw const BackupException(BackupFailure.wrongPassphrase);
  } on Object catch (error) {
    throw BackupException(BackupFailure.damaged, '$error');
  }

  try {
    final decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map) {
      throw const BackupException(BackupFailure.damaged, 'payload not a map');
    }
    return Map<String, Object?>.from(decoded);
  } on BackupException {
    rethrow;
  } on Object catch (error) {
    throw BackupException(BackupFailure.damaged, '$error');
  }
}

Future<SecretKey> _deriveKey(String passphrase, BackupHeader header) async {
  final argon2 = Argon2id(
    memory: header.memoryKb,
    iterations: header.iterations,
    parallelism: header.parallelism,
    hashLength: 32,
  );
  return argon2.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: header.salt,
  );
}
