import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/backup_service.dart';

/// Item 53 — what the Your data row says, and when it says it.
///
/// The backup itself is covered by backup_file and backup_payload. These
/// are the judgements about *nagging*: an app that mentions its own
/// housekeeping too eagerly teaches people to ignore it.
void main() {
  final now = DateTime(2026, 11, 15);

  group('the row says how long it has been', () {
    test('never, before there is anything', () {
      expect(lastBackupLine(null), 'Never backed up');
    });

    test('today and yesterday read as words, not as a count', () {
      expect(lastBackupLine(now, now: now), 'Last backup today');
      expect(
        lastBackupLine(now.subtract(const Duration(days: 1)), now: now),
        'Last backup yesterday',
      );
    });

    test('older than that reads as days', () {
      expect(
        lastBackupLine(now.subtract(const Duration(days: 34)), now: now),
        'Last backup 34 days ago',
      );
    });
  });

  group('it only mentions being overdue when that is fair', () {
    test('not on a phone with barely any history', () {
      // Telling someone on their second day that they have never backed up
      // is nagging about an empty file.
      expect(
        backupIsOverdue(
          lastBackup: null,
          historyAge: const Duration(days: 2),
          now: now,
        ),
        isFalse,
      );
    });

    test('never backed up, once there is a week of history', () {
      expect(
        backupIsOverdue(
          lastBackup: null,
          historyAge: const Duration(days: 8),
          now: now,
        ),
        isTrue,
      );
    });

    test('a recent backup is not overdue', () {
      expect(
        backupIsOverdue(
          lastBackup: now.subtract(const Duration(days: 3)),
          historyAge: const Duration(days: 200),
          now: now,
        ),
        isFalse,
      );
    });

    test('thirty days is the line', () {
      expect(kBackupStaleAfter, const Duration(days: 30));
      expect(
        backupIsOverdue(
          lastBackup: now.subtract(const Duration(days: 29)),
          historyAge: const Duration(days: 200),
          now: now,
        ),
        isFalse,
      );
      expect(
        backupIsOverdue(
          lastBackup: now.subtract(const Duration(days: 31)),
          historyAge: const Duration(days: 200),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
