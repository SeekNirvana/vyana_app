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
/// **Shape.** One plaintext header line, the encrypted body, then one line
/// per attached file:
///
/// ```
/// {"format":"vyana-backup","version":1,"kdf":{...},"attachments":12,…}
/// <base64 ciphertext+mac>            — the vault, settings, and the
///                                      manifest naming the files below
/// <base64 nonce+ciphertext+mac>      — meal photo 1
/// <base64 nonce+ciphertext+mac>      — meal photo 2
/// ```
///
/// Photos are a section of their own rather than base64 inside the JSON,
/// and the reason is memory. Inline, a long history means building a
/// hundred-megabyte string, encoding it, and encrypting it — three copies
/// alive at once on a phone that may have 4 GB. Separately encrypted, only
/// one photo is in hand at a time. Each gets its own nonce, because
/// reusing one with the same key is the way AES-GCM is broken. Their names
/// live in the encrypted manifest, not in the plaintext header.
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

/// Reads a file's bytes, one at a time, when the backup is written.
typedef BackupFileReader = Future<List<int>> Function();

/// What came out of a backup: the record, and the files that go with it.
@immutable
class BackupContents {
  const BackupContents({required this.payload, required this.files});

  final Map<String, Object?> payload;

  /// File name to bytes — meal photos, which unlike the model and the
  /// voice do not download again.
  final Map<String, Uint8List> files;
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
    this.attachments = 0,
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

  /// How many files follow the body. A count only — the names are inside
  /// the encrypted manifest, because a meal photo's name is the user's.
  final int attachments;

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
        'attachments': attachments,
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
    attachments: json['attachments'] as int? ?? 0,
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
  Map<String, BackupFileReader> files = const {},
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
  Uint8List bytes(int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));

  final salt = bytes(16);
  final nonce = bytes(12);
  final names = files.keys.toList();

  final header = BackupHeader(
    version: kBackupFormatVersion,
    createdAt: createdAt ?? DateTime.now(),
    appVersion: appVersion,
    salt: salt,
    nonce: nonce,
    memoryKb: kBackupKdfMemoryKb,
    iterations: kBackupKdfIterations,
    parallelism: kBackupKdfParallelism,
    attachments: names.length,
  );

  final key = await _deriveKey(passphrase, header);
  final aes = AesGcm.with256bits();

  // The manifest travels inside the encrypted body, so the plaintext
  // header never carries a file name.
  final body = <String, Object?>{...payload, 'files': names};
  final box = await aes.encrypt(
    utf8.encode(jsonEncode(body)),
    secretKey: key,
    nonce: nonce,
  );

  final out = <int>[
    ...utf8.encode(jsonEncode(header.toJson())),
    0x0a,
    ...utf8.encode(base64Encode([...box.cipherText, ...box.mac.bytes])),
  ];

  // One file at a time: read, encrypt, append, let it go. A long history
  // of meal photos must not need all of them in memory at once.
  for (final name in names) {
    final fileNonce = bytes(12);
    final content = await files[name]!();
    final sealed = await aes.encrypt(
      content,
      secretKey: key,
      nonce: fileNonce,
    );
    out
      ..add(0x0a)
      ..addAll(utf8.encode(base64Encode(
        [...fileNonce, ...sealed.cipherText, ...sealed.mac.bytes],
      )));
  }

  return Uint8List.fromList(out);
}

/// Opens a backup, or says precisely why it could not.
Future<BackupContents> openBackup({
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

  final lines = _lines(bytes);
  if (lines.length < 2) {
    throw const BackupException(BackupFailure.damaged, 'no body');
  }

  final key = await _deriveKey(passphrase, header);
  final aes = AesGcm.with256bits();

  final plain = await _open(
    aes: aes,
    key: key,
    nonce: header.nonce,
    raw: _base64(lines[1], 'body'),
    // The body is the first thing decrypted, so a wrong passphrase shows
    // up here — which is where it should be reported from.
    blameThePassphrase: true,
  );

  final Map<String, Object?> payload;
  try {
    final decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map) {
      throw const BackupException(BackupFailure.damaged, 'payload not a map');
    }
    payload = Map<String, Object?>.from(decoded);
  } on BackupException {
    rethrow;
  } on Object catch (error) {
    throw BackupException(BackupFailure.damaged, '$error');
  }

  final manifest = payload['files'];
  final names = manifest is List ? manifest.whereType<String>().toList() : [];
  if (names.length != header.attachments || lines.length - 2 < names.length) {
    throw const BackupException(
      BackupFailure.damaged,
      'the file list and the files do not agree',
    );
  }

  final files = <String, Uint8List>{};
  for (var i = 0; i < names.length; i++) {
    final raw = _base64(lines[2 + i], 'attachment ${i + 1}');
    if (raw.length <= 28) {
      throw const BackupException(BackupFailure.damaged, 'attachment too short');
    }
    files[names[i]] = Uint8List.fromList(
      await _open(
        aes: aes,
        key: key,
        nonce: raw.sublist(0, 12),
        raw: raw.sublist(12),
        blameThePassphrase: false,
      ),
    );
  }

  return BackupContents(payload: payload, files: files);
}

/// Splits on newlines without decoding the whole file as text first.
List<List<int>> _lines(List<int> bytes) {
  final out = <List<int>>[];
  var start = 0;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0x0a) {
      out.add(bytes.sublist(start, i));
      start = i + 1;
    }
  }
  if (start < bytes.length) out.add(bytes.sublist(start));
  return out;
}

List<int> _base64(List<int> line, String what) {
  try {
    return base64Decode(utf8.decode(line).trim());
  } on Object {
    throw BackupException(BackupFailure.damaged, '$what is not base64');
  }
}

Future<List<int>> _open({
  required AesGcm aes,
  required SecretKey key,
  required List<int> nonce,
  required List<int> raw,
  required bool blameThePassphrase,
}) async {
  if (raw.length <= 16) {
    throw const BackupException(BackupFailure.damaged, 'section too short');
  }
  try {
    return await aes.decrypt(
      SecretBox(
        raw.sublist(0, raw.length - 16),
        nonce: nonce,
        mac: Mac(raw.sublist(raw.length - 16)),
      ),
      secretKey: key,
    );
  } on SecretBoxAuthenticationError {
    // GCM cannot tell "wrong key" from "edited file". For the body, the
    // first is overwhelmingly likelier and the message has to be useful.
    // For an attachment the key has already been proved by the body, so a
    // failure there really is damage.
    throw BackupException(
      blameThePassphrase
          ? BackupFailure.wrongPassphrase
          : BackupFailure.damaged,
    );
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
