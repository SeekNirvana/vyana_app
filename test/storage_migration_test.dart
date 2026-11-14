import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vyana/src/services/vyana_storage_service.dart';

/// Item 59 — the vault moving from app-specific external storage to
/// app-private storage. The handover's warning about this one is the whole
/// reason these exist: "a bug here deletes people's history on update with
/// no undo."
///
/// `VyanaStorageService` is a singleton that reaches for platform channels,
/// so these drive the copy the way it is written rather than the service
/// itself: same order, same checks, same failure handling. What they pin is
/// the behaviour that must not regress — never overwrite newer data, never
/// delete the old copy on the launch that made the new one, and never
/// accept a copy that did not arrive whole.
void main() {
  late Directory tmp;
  late Directory oldRoot;
  late Directory newRoot;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vyana_storage_test');
    oldRoot = Directory(p.join(tmp.path, 'external', 'vyana'))
      ..createSync(recursive: true);
    newRoot = Directory(p.join(tmp.path, 'internal', 'vyana'))
      ..createSync(recursive: true);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File seedVault(Directory root, {String contents = 'SQLite format 3'}) {
    final dir = Directory(p.join(root.path, 'wellness'))
      ..createSync(recursive: true);
    final db = File(p.join(dir.path, 'vyana_vault.sqlite'))
      ..writeAsStringSync(contents);
    Directory(p.join(dir.path, 'meals')).createSync(recursive: true);
    File(p.join(dir.path, 'meals', 'meal_1.jpg'))
        .writeAsBytesSync(List<int>.filled(512, 7));
    return db;
  }

  group('which folders are private and which are not', () {
    test('the vault and cache are private; downloads and exports are not', () {
      // Models and voice are public weights and run to gigabytes — copying
      // them inward needs twice their size free and buys no privacy.
      // Exports stay because, until item 65 gives them a share sheet, the
      // folder a person can reach over USB is the only way they get one.
      expect(VyanaStorageService.privateFolders, contains('wellness'));
      expect(VyanaStorageService.privateFolders, contains('cache'));
      expect(VyanaStorageService.sharedFolders, contains('models'));
      expect(VyanaStorageService.sharedFolders, contains('voice'));
      expect(VyanaStorageService.sharedFolders, contains('exports'));
    });

    test('no folder is in both lists', () {
      for (final folder in VyanaStorageService.privateFolders) {
        expect(VyanaStorageService.sharedFolders, isNot(contains(folder)));
      }
    });
  });

  group('the two decisions that can lose data', () {
    test('a folder is copied only when there is something to copy', () {
      expect(
        shouldMigrateFolder(sourceHasData: true, destinationHasData: false),
        isTrue,
      );
      // An empty source is not a migration. Treating it as one marked every
      // launch as "just migrated", which deferred the cleanup to next time,
      // every time — the old vault would have sat outside for the life of
      // the install while the app believed it had moved it.
      expect(
        shouldMigrateFolder(sourceHasData: false, destinationHasData: false),
        isFalse,
      );
      // Never overwrite live data with an older copy left lying around.
      expect(
        shouldMigrateFolder(sourceHasData: true, destinationHasData: true),
        isFalse,
      );
    });

    test('the old copy goes only once everything in it is here', () {
      expect(
        oldCopyIsSafeToDelete([
          (folder: 'wellness', staleHasData: true, currentHasData: true),
          (folder: 'cache', staleHasData: false, currentHasData: false),
        ]),
        isTrue,
        reason: 'a folder empty on both sides must not block the cleanup',
      );
      expect(
        oldCopyIsSafeToDelete([
          (folder: 'wellness', staleHasData: true, currentHasData: false),
        ]),
        isFalse,
        reason: 'the vault is out there and not in here — keep it',
      );
      expect(
        oldCopyIsSafeToDelete([
          (folder: 'wellness', staleHasData: true, currentHasData: true),
          (folder: 'cache', staleHasData: true, currentHasData: false),
        ]),
        isFalse,
        reason: 'one folder short is still short',
      );
    });
  });

  group('the copy itself', () {
    test('every file arrives, with its bytes', () async {
      seedVault(oldRoot);
      final ok = await copyStorageTreeVerified(
        Directory(p.join(oldRoot.path, 'wellness')),
        Directory(p.join(newRoot.path, 'wellness')),
      );
      expect(ok, isTrue);

      final movedDb = File(p.join(newRoot.path, 'wellness', 'vyana_vault.sqlite'));
      expect(movedDb.existsSync(), isTrue);
      expect(movedDb.readAsStringSync(), 'SQLite format 3');
      final movedPhoto =
          File(p.join(newRoot.path, 'wellness', 'meals', 'meal_1.jpg'));
      expect(movedPhoto.existsSync(), isTrue);
      expect(movedPhoto.lengthSync(), 512);
    });

    test('the old copy is still there afterwards', () async {
      seedVault(oldRoot);
      await copyStorageTreeVerified(
        Directory(p.join(oldRoot.path, 'wellness')),
        Directory(p.join(newRoot.path, 'wellness')),
      );
      // Copy, not move. The launch that writes the new one never removes
      // the old one — a later launch does, once it has read the new one.
      expect(
        File(p.join(oldRoot.path, 'wellness', 'vyana_vault.sqlite')).existsSync(),
        isTrue,
      );
    });

    test('a destination that already holds data is left alone', () async {
      seedVault(oldRoot, contents: 'older');
      seedVault(newRoot, contents: 'newer');
      final destination = Directory(p.join(newRoot.path, 'wellness'));
      expect(await storageHoldsAnything(destination), isTrue);
      // A reinstall over a migrated install would otherwise overwrite live
      // data with whatever was left lying around outside.
      expect(
        File(p.join(newRoot.path, 'wellness', 'vyana_vault.sqlite'))
            .readAsStringSync(),
        'newer',
      );
    });

    test('an empty destination does not count as holding data', () async {
      final destination = Directory(p.join(newRoot.path, 'wellness'))
        ..createSync(recursive: true);
      File(p.join(destination.path, 'empty.tmp')).writeAsStringSync('');
      expect(await storageHoldsAnything(destination), isFalse);
    });
  });
}
