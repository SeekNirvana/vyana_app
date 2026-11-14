import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/backup_file.dart';

/// Item 53 — the backup file.
///
/// These are the cases where being wrong costs someone their history: a
/// round trip that must be exact, and four failures that must be told
/// apart. "Wrong passphrase" and "this file is damaged" send a person to
/// different places, and sending them to the wrong one wastes the only
/// copy they have.
void main() {
  // The real Argon2id cost is ~19 MB and two passes, which is right on a
  // phone and far too slow to run in a unit test for every case. The round
  // trip below uses the real parameters once; the rest reuse that file.
  const passphrase = 'correct horse battery staple';

  final payload = <String, Object?>{
    'payloadVersion': 1,
    'profile': {'firstName': 'Leena', 'age': 31},
    'journal': [
      {'id': 'a', 'title': 'Water again', 'body': 'A shallow river.'},
    ],
    'meals': [
      {'id': 'm', 'label': 'Dal and rice', 'photo': 'meal_1.jpg'},
    ],
    'ringHistory': {'days': 240},
  };

  late List<int> file;

  setUpAll(() async {
    file = await writeBackup(
      payload: payload,
      passphrase: passphrase,
      appVersion: '1.1.6',
      createdAt: DateTime.utc(2026, 11, 15, 9, 30),
    );
  });

  group('a backup goes out and comes back whole', () {
    test('what goes in is what comes out', () async {
      final restored = await openBackup(bytes: file, passphrase: passphrase);
      expect(restored['payloadVersion'], 1);
      expect((restored['profile'] as Map)['firstName'], 'Leena');
      expect((restored['journal'] as List).first['title'], 'Water again');
      expect((restored['ringHistory'] as Map)['days'], 240);
    });

    test('nothing in the file gives the contents away', () {
      final text = utf8.decode(file);
      // The header is plaintext by design, so it must carry nothing of the
      // person it belongs to.
      expect(text, isNot(contains('Leena')));
      expect(text, isNot(contains('Water again')));
      expect(text, isNot(contains('Dal and rice')));
      // And never the passphrase, in any form.
      expect(text, isNot(contains(passphrase)));
    });

    test('two backups of the same data are different files', () async {
      // A fresh salt and nonce each time, so identical content does not
      // produce identical ciphertext.
      final again = await writeBackup(
        payload: payload,
        passphrase: passphrase,
        appVersion: '1.1.6',
        createdAt: DateTime.utc(2026, 11, 15, 9, 30),
      );
      expect(again, isNot(equals(file)));
    });
  });

  group('the header can be read without the passphrase', () {
    test('it says who wrote it and when', () {
      final header = readBackupHeader(file);
      expect(header.version, kBackupFormatVersion);
      expect(header.appVersion, '1.1.6');
      expect(header.createdAt.toUtc(), DateTime.utc(2026, 11, 15, 9, 30));
      expect(header.isReadable, isTrue);
    });

    test('a newer backup is named as such, not blamed on the passphrase', () {
      // Deciding this needs the version, which is why the header is
      // readable without decrypting: "Update Vyana first" cannot wait for
      // a decryption that was never going to work.
      final header = jsonDecode(utf8.decode(
        file.sublist(0, file.indexOf(0x0a)),
      )) as Map<String, Object?>;
      header['version'] = kBackupFormatVersion + 1;
      final newer = [
        ...utf8.encode(jsonEncode(header)),
        0x0a,
        ...file.sublist(file.indexOf(0x0a) + 1),
      ];

      expect(readBackupHeader(newer).isReadable, isFalse);
      expect(
        () => openBackup(bytes: newer, passphrase: passphrase),
        throwsA(isA<BackupException>()
            .having((e) => e.failure, 'failure', BackupFailure.tooNew)
            .having((e) => e.message, 'message', contains('Update Vyana'))),
      );
    });
  });

  group('failures are told apart', () {
    test('the wrong passphrase says so, and says it is unrecoverable', () {
      expect(
        () => openBackup(bytes: file, passphrase: 'not the one'),
        throwsA(isA<BackupException>()
            .having((e) => e.failure, 'failure', BackupFailure.wrongPassphrase)
            .having((e) => e.message, 'message', contains('no way to recover'))),
      );
    });

    test('some other file is not blamed on the passphrase', () {
      final notOurs = utf8.encode('{"hello":"world"}\nsome body');
      expect(
        () => openBackup(bytes: notOurs, passphrase: passphrase),
        throwsA(isA<BackupException>()
            .having((e) => e.failure, 'failure', BackupFailure.notABackup)),
      );
      expect(
        () => readBackupHeader(utf8.encode('not json at all')),
        throwsA(isA<BackupException>()
            .having((e) => e.failure, 'failure', BackupFailure.notABackup)),
      );
    });

    test('a truncated backup is refused, not half-restored', () async {
      // The reason for GCM: a cut-short file fails its MAC rather than
      // decrypting to plausible nonsense and overwriting a history with it.
      final cut = file.sublist(0, file.length - 40);
      await expectLater(
        openBackup(bytes: cut, passphrase: passphrase),
        throwsA(isA<BackupException>()),
      );
    });

    test('an edited backup is refused', () async {
      final tampered = [...file];
      // Flip a byte well inside the body.
      final at = tampered.length - 20;
      tampered[at] = tampered[at] == 0x41 ? 0x42 : 0x41;
      await expectLater(
        openBackup(bytes: tampered, passphrase: passphrase),
        throwsA(isA<BackupException>()),
      );
    });

    test('a backup with no passphrase is refused outright', () {
      expect(
        () => writeBackup(
          payload: payload,
          passphrase: '',
          appVersion: '1.1.6',
        ),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('the cost of opening it is recorded in the file', () {
    test('so raising it later does not orphan older backups', () {
      final header = readBackupHeader(file);
      // Read back from the file rather than assumed from this build's
      // constants — that is the whole point of writing them down.
      expect(header.memoryKb, kBackupKdfMemoryKb);
      expect(header.iterations, kBackupKdfIterations);
      expect(header.parallelism, kBackupKdfParallelism);
      // OWASP's floor for Argon2id. Below this the passphrase is the
      // weakest part of the file by a long way.
      expect(header.memoryKb, greaterThanOrEqualTo(19456));
      expect(header.iterations, greaterThanOrEqualTo(2));
    });

    test('salt and nonce are the sizes AES-GCM expects', () {
      final header = readBackupHeader(file);
      expect(header.salt.length, 16);
      expect(header.nonce.length, 12);
    });

    test('a deterministic source still gives a usable file', () async {
      // Guards the generation code itself, independent of Random.secure.
      final seeded = await writeBackup(
        payload: const {'x': 1},
        passphrase: 'pass',
        appVersion: '1.1.6',
        random: Random(7),
      );
      final back = await openBackup(bytes: seeded, passphrase: 'pass');
      expect(back['x'], 1);
    });
  });
}
