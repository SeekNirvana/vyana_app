import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/services/backup_payload.dart';

/// Item 53 — the payload.
///
/// Restore *replaces* what is on the phone, so these cover the cases where
/// being wrong destroys a history rather than merely failing to save one.
void main() {
  late VyanaDatabase db;

  setUp(() => db = VyanaDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.addJournalEntry(
      id: 'j1',
      type: 'dream',
      title: 'Water again',
      body: 'A shallow river, the current warm.',
    );
    await db.addJournalEntry(
      id: 'j2',
      type: 'note',
      title: 'Slept badly',
      body: 'Woke at three.',
    );
    await db.insertChatSession(
      id: 'chat_1',
      personaId: 'nova',
      title: 'My readiness is low',
      backend: 'device',
      modelLabel: 'Gemma E2B',
      startedAt: DateTime(2026, 11, 14),
    );
    await db.insertChatMessage(
      id: 'chat_1_0',
      sessionId: 'chat_1',
      ordinal: 0,
      fromUser: true,
      body: 'My readiness is low today.',
      createdAt: DateTime(2026, 11, 14),
    );
  }

  Future<int> count(String table) async {
    final rows =
        await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle();
    return rows.data['n'] as int;
  }

  group('a vault goes into a payload and comes back', () {
    test('the rows survive the round trip', () async {
      await seed();
      final payload = await buildBackupPayload(db: db, settings: const {});

      // Wipe it the way a reinstall would.
      await db.customStatement('DELETE FROM chat_messages');
      await db.customStatement('DELETE FROM chat_sessions');
      await db.customStatement('DELETE FROM journal_entries');
      expect(await count('journal_entries'), 0);

      final report = await restoreBackupPayload(db: db, payload: payload);

      expect(await count('journal_entries'), 2);
      expect(await count('chat_sessions'), 1);
      expect(await count('chat_messages'), 1);
      expect(report.rowsByTable['journal_entries'], 2);
      expect(report.totalRows, 4);
      expect(report.summary, '4 records restored');
    });

    test('the words come back, not just the row count', () async {
      await seed();
      final payload = await buildBackupPayload(db: db, settings: const {});
      await db.customStatement('DELETE FROM journal_entries');
      await restoreBackupPayload(db: db, payload: payload);

      final entries = await db.allEntries();
      expect(entries.map((e) => e.title), containsAll(
        ['Water again', 'Slept badly'],
      ));
      expect(
        entries.firstWhere((e) => e.title == 'Water again').body,
        'A shallow river, the current warm.',
      );
    });

    test('settings travel with it', () async {
      final payload = await buildBackupPayload(
        db: db,
        settings: const {'flutter.vyana.user_profile': '{"firstName":"Leena"}'},
      );
      expect(
        (payload['settings'] as Map)['flutter.vyana.user_profile'],
        contains('Leena'),
      );
    });

    test('restore replaces rather than merges', () async {
      await seed();
      final payload = await buildBackupPayload(db: db, settings: const {});

      // Something written after the backup is not kept: restore is
      // "put the phone back as it was", not "add these to what is here".
      await db.addJournalEntry(
        id: 'j3',
        type: 'idea',
        title: 'Written later',
        body: 'After the backup.',
      );
      expect(await count('journal_entries'), 3);

      await restoreBackupPayload(db: db, payload: payload);
      expect(await count('journal_entries'), 2);
      final titles = (await db.allEntries()).map((e) => e.title);
      expect(titles, isNot(contains('Written later')));
    });
  });

  group('a backup outlives the build that wrote it', () {
    test('a column this build no longer has is dropped, not fatal', () async {
      await seed();
      final payload = await buildBackupPayload(db: db, settings: const {});
      // A column from a future or former schema.
      for (final row
          in (payload['tables'] as Map)['journal_entries'] as List) {
        (row as Map)['mood_ring_colour'] = 'teal';
      }

      final report = await restoreBackupPayload(db: db, payload: payload);
      expect(await count('journal_entries'), 2);
      expect(report.skippedColumns, contains('journal_entries.mood_ring_colour'));
    });

    test('a table this build no longer has is skipped, not fatal', () async {
      await seed();
      final payload = await buildBackupPayload(db: db, settings: const {});
      (payload['tables'] as Map)['tea_leaves'] = [
        {'id': 'x'},
      ];
      final report = await restoreBackupPayload(db: db, payload: payload);
      expect(await count('journal_entries'), 2);
      expect(report.rowsByTable.containsKey('tea_leaves'), isFalse);
    });

    test('a newer payload is refused rather than half-applied', () async {
      await seed();
      final payload = await buildBackupPayload(db: db, settings: const {});
      payload['payloadVersion'] = kBackupPayloadVersion + 1;

      await expectLater(
        restoreBackupPayload(db: db, payload: payload),
        throwsA(isA<StateError>()),
      );
      // And the vault is untouched.
      expect(await count('journal_entries'), 2);
    });
  });

  group('what is deliberately not in a backup', () {
    test('the ring SDK log is left out', () {
      expect(kBackupExcludedTables, contains('raw_sdk_events'));
      expect(kBackupTables, isNot(contains('raw_sdk_events')));
    });

    test('nothing that describes this particular phone', () {
      // Restoring a paired ring's address onto a different handset would
      // describe a phone that does not exist.
      expect(
        kBackupExcludedSettingKeys,
        contains('flutter.vyana.paired_prana_ring'),
      );
      for (final key in kBackupExcludedSettingKeys) {
        expect(kBackupSettingKeys, isNot(contains(key)));
      }
    });

    test('the profile and pins are in', () {
      expect(kBackupSettingKeys, contains('flutter.vyana.user_profile'));
      expect(kBackupSettingKeys, contains('flutter.vyana.practice.pins'));
    });
  });
}
