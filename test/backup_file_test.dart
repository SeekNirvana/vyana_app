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
      final payload = restored.payload;
      expect(payload['payloadVersion'], 1);
      expect((payload['profile'] as Map)['firstName'], 'Leena');
      expect((payload['journal'] as List).first['title'], 'Water again');
      expect((payload['ringHistory'] as Map)['days'], 240);
      expect(restored.files, isEmpty);
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
      expect(back.payload['x'], 1);
    });
  });

  group('meal photos travel with the record', () {
    // Photos are files, not rows, and unlike the model and the voice they
    // do not download again — a restore without them gives someone their
    // meals with the pictures missing.
    final photoA = List<int>.filled(2048, 7);
    final photoB = List<int>.filled(1024, 9);

    Future<List<int>> withPhotos() => writeBackup(
          payload: const {'payloadVersion': 1},
          passphrase: passphrase,
          appVersion: '1.1.6',
          files: {
            'meal_1.jpg': () async => photoA,
            'meal_2.jpg': () async => photoB,
          },
        );

    test('they come back byte for byte', () async {
      final restored =
          await openBackup(bytes: await withPhotos(), passphrase: passphrase);
      expect(restored.files.keys, ['meal_1.jpg', 'meal_2.jpg']);
      expect(restored.files['meal_1.jpg'], photoA);
      expect(restored.files['meal_2.jpg'], photoB);
    });

    test('the header says how many, but never what they are called', () async {
      final bytes = await withPhotos();
      final header = readBackupHeader(bytes);
      expect(header.attachments, 2);
      // A meal photo's name is the user's. It lives in the encrypted
      // manifest, not in the line anyone can read.
      final headerLine = utf8.decode(bytes.sublist(0, bytes.indexOf(0x0a)));
      expect(headerLine, isNot(contains('meal_1.jpg')));
    });

    test('each photo gets its own nonce', () async {
      // Reusing a nonce with the same key is how AES-GCM is broken, so two
      // identical photos must still encrypt differently.
      final same = await writeBackup(
        payload: const {'payloadVersion': 1},
        passphrase: passphrase,
        appVersion: '1.1.6',
        files: {
          'a.jpg': () async => photoA,
          'b.jpg': () async => photoA,
        },
      );
      final text = utf8.decode(same);
      final lines = text.split('\n');
      expect(lines.length, 4);
      expect(lines[2], isNot(equals(lines[3])));
    });

    test('a missing photo is damage, not a wrong passphrase', () async {
      // The body has already proved the key by the time photos are read.
      final bytes = await withPhotos();
      final cut = utf8.decode(bytes).split('\n')..removeLast();
      await expectLater(
        openBackup(bytes: utf8.encode(cut.join('\n')), passphrase: passphrase),
        throwsA(isA<BackupException>()
            .having((e) => e.failure, 'failure', BackupFailure.damaged)),
      );
    });

    test('a backup with no photos still works', () async {
      final restored = await openBackup(bytes: file, passphrase: passphrase);
      expect(restored.files, isEmpty);
      expect(readBackupHeader(file).attachments, 0);
    });
  });
}
