import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyana/src/data/db.dart';
import 'package:drift/native.dart';
import 'package:vyana/src/services/auto_backup.dart';
import 'package:vyana/src/services/backup_service.dart';

/// Item 108 — the You row and the card after the first sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the row says the date, or that there has been none', () {
    expect(lastBackupDateLine(null), 'Never backed up');
    expect(lastBackupDateLine(DateTime(2026, 11, 2, 21)), 'Last backup 2 Nov');
  });

  test('the row says the sentence', () {
    expect(kYourDataRowLine, contains('lives only on this phone'));
    expect(kYourDataRowLine, contains('Deleting Vyana deletes it'));
  });

  group('the card after the first sync', () {
    test('shows once the ring has synced and nothing is backed up', () {
      expect(
        firstSyncBackupCardDue(
          hasSynced: true,
          lastBackup: null,
          answered: false,
        ),
        isTrue,
      );
    });

    test('not before a sync, not after a backup, not once answered', () {
      expect(
        firstSyncBackupCardDue(
            hasSynced: false, lastBackup: null, answered: false),
        isFalse,
      );
      expect(
        firstSyncBackupCardDue(
          hasSynced: true,
          lastBackup: DateTime(2026, 11, 2),
          answered: false,
        ),
        isFalse,
      );
      expect(
        firstSyncBackupCardDue(
            hasSynced: true, lastBackup: null, answered: true),
        isFalse,
      );
    });
  });

  test('a finished weekly run counts as the last backup', () async {
    SharedPreferences.setMockInitialValues({
      kLastBackupKey: DateTime(2026, 11, 2).toIso8601String(),
      kAutoBackupLastRunKey: DateTime(2026, 11, 9).toIso8601String(),
    });
    final db = VyanaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final last = await BackupService(db).lastBackupAt();
    expect(last, DateTime(2026, 11, 9));
  });
}
