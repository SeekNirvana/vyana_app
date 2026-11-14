import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/backup_file.dart';
import 'package:vyana/src/services/file_exchange_service.dart';

/// Item 53/65 — the name a backup is saved under.
///
/// The sheet and the picker are platform calls and are exercised on a
/// device. What is testable here is the part that decides what a person
/// sees in their file manager a year from now.
void main() {
  group('a backup is named so it can be recognised later', () {
    test('it carries its date', () {
      expect(
        backupFileName(DateTime(2026, 11, 15)),
        'vyana-backup-2026-11-15.vyana',
      );
    });

    test('months and days are padded, so files sort by name', () {
      // A folder of backups should list oldest to newest without being
      // asked, which only works if every name is the same length.
      final january = backupFileName(DateTime(2026, 1, 2));
      final october = backupFileName(DateTime(2026, 10, 20));
      expect(january, 'vyana-backup-2026-01-02.vyana');
      expect(january.length, october.length);
      expect([october, january]..sort(), [january, october]);
    });

    test('the extension comes from one definition', () {
      // The file writer and the name have to agree about this, so they
      // read it from one place rather than each spelling it out.
      expect(backupFileName(DateTime(2026, 1, 1)),
          endsWith('.$kBackupFileExtension'));
    });
  });
}
