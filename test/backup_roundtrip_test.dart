import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/services/backup_file.dart';
import 'package:vyana/src/services/backup_payload.dart';

/// Item 53 — the whole way out and back, through a real file on disk.
///
/// The parts are tested separately; this is the one that would catch them
/// disagreeing. It goes through bytes written to a file and read back,
/// because that is what a restore actually is — not a map handed from one
/// function to another.
void main() {
  late VyanaDatabase db;
  late Directory temp;
  late Directory photos;

  setUp(() async {
    db = VyanaDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('vyana_roundtrip');
    photos = Directory(p.join(temp.path, 'meals'))..createSync(recursive: true);
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Future<int> count(String table) async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle();
    return row.data['n'] as int;
  }

  test('a phone is backed up, wiped, and comes back', () async {
    // A history worth losing.
    await db.addJournalEntry(
      id: 'j1',
      type: 'dream',
      title: 'Water again',
      body: 'A shallow river, the current warm.',
    );
    final photo = File(p.join(photos.path, 'meal_1.jpg'))
      ..writeAsBytesSync(List<int>.filled(4096, 11));
    await db.addMeal(
      id: 'm1',
      label: 'Dal and rice',
      mealType: 'dinner',
      photoPath: photo.path,
    );

    // Back up: payload, photos, encrypted, written to a file.
    final payload = await buildBackupPayload(
      db: db,
      settings: const {'flutter.vyana.user_profile': '{"firstName":"Leena"}'},
    );
    final collected =
        await collectMealPhotos(db: db, mealPhotosPath: photos.path);
    expect(collected.keys, ['meal_1.jpg']);

    final file = File(p.join(temp.path, 'vyana-backup-2026-11-15.vyana'));
    await file.writeAsBytes(
      await writeBackup(
        payload: payload,
        files: collected,
        passphrase: 'a passphrase worth keeping',
        appVersion: '1.1.6',
      ),
      flush: true,
    );
    expect(file.lengthSync(), greaterThan(4096));

    // The reinstall: nothing left.
    await db.customStatement('DELETE FROM journal_entries');
    await db.customStatement('DELETE FROM meals');
    photo.deleteSync();
    expect(await count('journal_entries'), 0);

    // Restore, from the bytes on disk.
    final contents = await openBackup(
      bytes: await file.readAsBytes(),
      passphrase: 'a passphrase worth keeping',
    );
    final report =
        await restoreBackupPayload(db: db, payload: contents.payload);

    // A new phone's folder, not the one the photo was saved in.
    final newPhone = Directory(p.join(temp.path, 'other_meals'));
    final restoredPhotos = await restoreMealPhotos(
      files: contents.files,
      mealPhotosPath: newPhone.path,
    );

    expect(await count('journal_entries'), 1);
    expect(await count('meals'), 1);
    expect((await db.allEntries()).single.title, 'Water again');
    expect(restoredPhotos, 1);

    final back = File(p.join(newPhone.path, 'meal_1.jpg'));
    expect(back.existsSync(), isTrue);
    expect(back.lengthSync(), 4096);
    expect(back.readAsBytesSync(), Uint8List.fromList(List.filled(4096, 11)));

    expect(
      (contents.payload['settings'] as Map)['flutter.vyana.user_profile'],
      contains('Leena'),
    );
    expect(report.withPhotos(restoredPhotos).summary,
        '2 records and 1 photo restored');
  });

  test('the wrong passphrase leaves the phone untouched', () async {
    await db.addJournalEntry(
      id: 'j1',
      type: 'note',
      title: 'Still here',
      body: 'Nothing should remove this.',
    );
    final file = File(p.join(temp.path, 'b.vyana'));
    await file.writeAsBytes(
      await writeBackup(
        payload: await buildBackupPayload(db: db, settings: const {}),
        passphrase: 'right',
        appVersion: '1.1.6',
      ),
      flush: true,
    );

    // A restore that cannot even be opened must not have touched anything
    // on the way to finding that out.
    await expectLater(
      openBackup(bytes: await file.readAsBytes(), passphrase: 'wrong'),
      throwsA(isA<BackupException>()
          .having((e) => e.failure, 'failure', BackupFailure.wrongPassphrase)),
    );
    expect(await count('journal_entries'), 1);
    expect((await db.allEntries()).single.title, 'Still here');
  });
}
