import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vyana/src/data/db.dart';

/// Item 72 — an upgrade from an old schema must not stop the app opening.
///
/// This is the worst class of bug in the app: `onUpgrade` throwing means
/// the database never opens, so Vyana is dead on launch with every record
/// still sitting there intact and unreachable. Nobody can work around it
/// and nothing in the UI can report it.
///
/// The fault was that `createTable` builds a table from the *current*
/// definition, so a device with no `ring_orders` got one already holding
/// `order_type`, `shipping_country` and `order_message` — and the
/// unguarded `addColumn` calls behind `from < 6` then hit "duplicate
/// column name".
///
/// An old device is built here by creating a current database and then
/// taking it backwards: dropping the tables that did not exist yet and
/// winding `user_version` back. That borrows the real column definitions
/// instead of hand-writing a schema from memory, and it is the only way to
/// get a faithful old database without drift's generated snapshots, which
/// this project does not keep.
///
/// A first attempt used an empty in-memory database with an old
/// `user_version`, which is not a schema 4 at all: `onUpgrade` never
/// creates `activity_sessions`, `samples`, `route_points` or
/// `raw_sdk_events`, because those have existed since the first release.
/// The tests failed on a missing table rather than on the bug.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vyana-upgrade-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  File dbFile() => File(p.join(dir.path, 'vyana.sqlite'));

  /// Builds a current database, then winds it back to [version], dropping
  /// [drop] so the migration has something to do.
  Future<void> makeOldDatabase(
    int version, {
    List<String> drop = const [],
    List<String> then = const [],
  }) async {
    final fresh = VyanaDatabase(NativeDatabase(dbFile()));
    // Any query forces onCreate to finish before we meddle.
    await fresh.recentSessions(limit: 1);
    await fresh.close();

    final raw = NativeDatabase(dbFile());
    final shim = VyanaDatabase(raw);
    for (final table in drop) {
      await shim.customStatement('DROP TABLE IF EXISTS $table');
    }
    for (final statement in then) {
      await shim.customStatement(statement);
    }
    await shim.customStatement('PRAGMA user_version = $version');
    await shim.close();
  }

  Future<VyanaDatabase> reopen() async {
    final db = VyanaDatabase(NativeDatabase(dbFile()));
    addTearDown(db.close);
    return db;
  }

  group('a device whose ring_orders table does not exist yet', () {
    // 4 is the version in the report. The others are swept because a crash
    // of this kind should never be one version wide.
    for (final from in [1, 2, 3, 4, 5]) {
      test('upgrades from schema $from without throwing', () async {
        await makeOldDatabase(from, drop: ['ring_orders']);
        final db = await reopen();

        // Opening is the whole claim: before the fix this threw
        // "duplicate column name: order_type" and the app never started.
        await expectLater(db.recentSessions(limit: 1), completes);
      });
    }

    test('and the three columns are usable afterwards', () async {
      // Proves the table ended up in the current shape, rather than just
      // that nothing threw.
      await makeOldDatabase(4, drop: ['ring_orders']);
      final db = await reopen();

      await db.customInsert(
        'INSERT INTO ring_orders (id, status, product_name, color, size, '
        'amount_usdc, treasury_address, wallet_address, shipping_eta_days, '
        'order_type, shipping_country, order_message, created_at) VALUES '
        "('o1', 'paid', 'PRANA V1', 'black', 9, 199.0, 't', 'w', 30, "
        "'purchase', 'IN', 'leave at door', 0)",
      );
      final rows = await db
          .customSelect(
            'SELECT order_type, shipping_country, order_message '
            'FROM ring_orders',
          )
          .get();
      expect(rows.single.read<String>('order_type'), 'purchase');
      expect(rows.single.read<String>('shipping_country'), 'IN');
      expect(rows.single.read<String>('order_message'), 'leave at door');
    });
  });

  group('a device whose ring_orders table is from the older shape', () {
    test('gains the v6 columns and keeps its rows', () async {
      // The other half of the condition, and why the addColumn calls cannot
      // simply be deleted: a table that was already there needs them added
      // by hand.
      await makeOldDatabase(
        5,
        drop: ['ring_orders'],
        then: [
          'CREATE TABLE ring_orders ('
              'id TEXT NOT NULL PRIMARY KEY, '
              'status TEXT NOT NULL, '
              'product_name TEXT NOT NULL, '
              'color TEXT NOT NULL, '
              'size INTEGER NOT NULL, '
              'amount_usdc REAL NOT NULL, '
              'referral_code TEXT NULL, '
              'treasury_address TEXT NOT NULL, '
              'wallet_address TEXT NOT NULL, '
              'tx_signature TEXT NULL, '
              'shipping_eta_days INTEGER NOT NULL DEFAULT 30, '
              'error_message TEXT NULL, '
              'created_at INTEGER NOT NULL)',
          'INSERT INTO ring_orders (id, status, product_name, color, size, '
              'amount_usdc, treasury_address, wallet_address, '
              'shipping_eta_days, created_at) VALUES '
              "('old', 'paid', 'PRANA V1', 'black', 9, 199.0, 't', 'w', 30, 0)",
        ],
      );
      final db = await reopen();

      final columns =
          await db.customSelect('PRAGMA table_info(ring_orders)').get();
      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll(['order_type', 'shipping_country', 'order_message']),
      );

      // An order placed before the upgrade is still there afterwards.
      final rows = await db.customSelect('SELECT id FROM ring_orders').get();
      expect(rows.single.read<String>('id'), 'old');
    });
  });

  group('the other tables that gain columns after creation', () {
    test('patterns and journal_entries upgrade from an old schema',
        () async {
      // The same shape as ring_orders: created whole by createTable, then
      // asked for columns it already has. They were guarded already, so
      // this is the regression test they never had.
      await makeOldDatabase(4, drop: ['patterns', 'journal_entries']);
      final db = await reopen();
      await expectLater(db.recentSessions(limit: 1), completes);

      for (final (table, column) in [
        ('patterns', 'counter_ids_json'),
        ('patterns', 'baseline'),
        ('journal_entries', 'reflection'),
      ]) {
        final columns =
            await db.customSelect('PRAGMA table_info($table)').get();
        expect(
          columns.map((r) => r.read<String>('name')),
          contains(column),
          reason: '$table.$column missing after an upgrade from 4',
        );
      }
    });
  });

  group('a current database is left alone', () {
    test('a fresh install has every column', () async {
      final db = VyanaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(await db.recentSessions(limit: 1), isEmpty);
      final columns =
          await db.customSelect('PRAGMA table_info(ring_orders)').get();
      expect(
        columns.map((r) => r.read<String>('name')),
        contains('order_message'),
      );
    });
  });
}
