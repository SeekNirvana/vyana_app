import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:vyana/src/services/vyana_storage_service.dart';

/// Item 99 — an interrupted storage move can no longer lose new data.
void main() {
  group('what each launch does with a folder', () {
    test('nothing at the old place: nothing to do', () {
      expect(
        folderMoveFor(
          sourceHasData: false,
          destinationHasData: true,
          moveCompleted: false,
        ),
        FolderMove.skip,
      );
    });

    test('nothing at the new place: copy', () {
      expect(
        folderMoveFor(
          sourceHasData: true,
          destinationHasData: false,
          moveCompleted: false,
        ),
        FolderMove.copy,
      );
    });

    test('both, after a finished move: the new copy is live, keep it', () {
      expect(
        folderMoveFor(
          sourceHasData: true,
          destinationHasData: true,
          moveCompleted: true,
        ),
        FolderMove.skip,
      );
    });

    test('both, and the app reads the new place: never replaced', () {
      expect(
        folderMoveFor(
          sourceHasData: true,
          destinationHasData: true,
          moveCompleted: false,
          readingDestination: true,
        ),
        FolderMove.skip,
      );
    });

    test('both, no finished move: the new copy is stale, copy again', () {
      // The handover's case: wellness copied, cache failed, the app kept
      // writing to the old place. v1.1.6 skipped wellness here.
      expect(
        folderMoveFor(
          sourceHasData: true,
          destinationHasData: true,
          moveCompleted: false,
        ),
        FolderMove.recopy,
      );
    });
  });

  group("the handover's sequence, launch by launch", () {
    late Directory tmp;
    late Directory oldRoot;
    late Directory newRoot;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('vyana_move');
      oldRoot = Directory(p.join(tmp.path, 'old'))..createSync();
      newRoot = Directory(p.join(tmp.path, 'new'))..createSync();
    });
    tearDown(() => tmp.delete(recursive: true));

    File write(Directory root, String folder, String name, String body) {
      final f = File(p.join(root.path, folder, name))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(body);
      return f;
    }

    test('cache fails, data is written, two relaunches: nothing lost',
        () async {
      write(oldRoot, 'wellness', 'journal.txt', 'v1');
      write(oldRoot, 'cache', 'c.txt', 'cache');

      // Launch 1: wellness copies, cache fails → the whole attempt is
      // undone, so nothing is left at the new place.
      expect(
        await copyStorageTreeVerified(
          Directory(p.join(oldRoot.path, 'wellness')),
          Directory(p.join(newRoot.path, 'wellness')),
        ),
        isTrue,
      );
      for (final folder in VyanaStorageService.privateFolders) {
        final d = Directory(p.join(newRoot.path, folder));
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
      // The app goes on writing at the old place.
      write(oldRoot, 'wellness', 'journal.txt', 'v2 — newer');

      // Launch 2: nothing at the new place, so both folders copy.
      for (final folder in VyanaStorageService.privateFolders) {
        final move = folderMoveFor(
          sourceHasData: await storageHoldsAnything(
            Directory(p.join(oldRoot.path, folder)),
          ),
          destinationHasData: await storageHoldsAnything(
            Directory(p.join(newRoot.path, folder)),
          ),
          moveCompleted: false,
        );
        expect(move, FolderMove.copy);
        await copyStorageTreeVerified(
          Directory(p.join(oldRoot.path, folder)),
          Directory(p.join(newRoot.path, folder)),
        );
      }

      // What the app reads after the move is the newer data.
      expect(
        File(p.join(newRoot.path, 'wellness', 'journal.txt'))
            .readAsStringSync(),
        'v2 — newer',
      );
    });
  });

  group('the vault has to open before the app moves to it', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('vault'));
    tearDown(() => tmp.delete(recursive: true));

    test('a real database opens', () {
      final path = p.join(tmp.path, VyanaStorageService.vaultDatabaseFile);
      sqlite3.open(path)
        ..execute('CREATE TABLE t (x INTEGER)')
        ..execute('INSERT INTO t VALUES (1)')
        ..close();
      expect(storageDatabaseOpens(path), isTrue);
    });

    test('a file that is not a database does not', () {
      final path = p.join(tmp.path, 'broken.sqlite');
      File(path).writeAsStringSync('SQLite format 3 but not really');
      expect(storageDatabaseOpens(path), isFalse);
    });
  });
}
