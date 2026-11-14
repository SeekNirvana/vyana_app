import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/auto_backup.dart';

/// Item 53, part five — the rules a weekly backup has to follow.
void main() {
  final now = DateTime(2026, 11, 15);

  group('when a run is due', () {
    test('never while it is switched off', () {
      // The feature sends data off the phone. Off has to mean off, and the
      // absence of a setting has to mean off too.
      expect(
        autoBackupDue(
          enabled: false,
          folder: '/somewhere',
          lastRun: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('never without a folder to write to', () {
      // A run with nowhere to go is not a backup, it is an encryption
      // exercise that ends in a thrown-away file.
      expect(
        autoBackupDue(enabled: true, folder: null, lastRun: null, now: now),
        isFalse,
      );
      expect(
        autoBackupDue(enabled: true, folder: '', lastRun: null, now: now),
        isFalse,
      );
    });

    test('immediately after being switched on', () {
      expect(
        autoBackupDue(
          enabled: true,
          folder: '/somewhere',
          lastRun: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('a week after the last one, not before', () {
      expect(
        autoBackupDue(
          enabled: true,
          folder: '/somewhere',
          lastRun: now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isFalse,
      );
      expect(
        autoBackupDue(
          enabled: true,
          folder: '/somewhere',
          lastRun: now.subtract(const Duration(days: 7)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('keeping the last few', () {
    test('four are kept, the oldest go', () {
      final names = [
        'vyana-backup-2026-09-01.vyana',
        'vyana-backup-2026-09-08.vyana',
        'vyana-backup-2026-09-15.vyana',
        'vyana-backup-2026-09-22.vyana',
        'vyana-backup-2026-09-29.vyana',
        'vyana-backup-2026-10-06.vyana',
      ];
      expect(staleBackups(names), [
        'vyana-backup-2026-09-01.vyana',
        'vyana-backup-2026-09-08.vyana',
      ]);
    });

    test('nothing goes while there are four or fewer', () {
      expect(
        staleBackups([
          'vyana-backup-2026-09-01.vyana',
          'vyana-backup-2026-09-08.vyana',
        ]),
        isEmpty,
      );
    });

    test('anything that is not ours is left alone', () {
      // The person chose that folder and may keep other things in it.
      final names = [
        'tax-return.pdf',
        'holiday.jpg',
        'vyana-backup-2026-09-01.vyana',
        'vyana-backup-2026-09-08.vyana',
        'vyana-backup-2026-09-15.vyana',
        'vyana-backup-2026-09-22.vyana',
        'vyana-backup-2026-09-29.vyana',
      ];
      final stale = staleBackups(names);
      expect(stale, ['vyana-backup-2026-09-01.vyana']);
      expect(stale, isNot(contains('tax-return.pdf')));
    });

    test('sorted by the name, not by the file system', () {
      // A folder synced to Drive or iCloud rewrites timestamps as it
      // pleases; the date in the name came from the backup itself.
      final names = [
        'vyana-backup-2026-10-06.vyana',
        'vyana-backup-2026-09-01.vyana',
        'vyana-backup-2026-09-29.vyana',
        'vyana-backup-2026-09-08.vyana',
        'vyana-backup-2026-09-15.vyana',
      ];
      expect(staleBackups(names), ['vyana-backup-2026-09-01.vyana']);
    });
  });

  group('two in one day do not overwrite each other', () {
    test('a taken name gets a suffix', () {
      expect(
        uniqueBackupName('vyana-backup-2026-11-15.vyana', {
          'vyana-backup-2026-11-15.vyana',
        }),
        'vyana-backup-2026-11-15-2.vyana',
      );
    });

    test('a free name is used as it is', () {
      expect(
        uniqueBackupName('vyana-backup-2026-11-15.vyana', const {}),
        'vyana-backup-2026-11-15.vyana',
      );
    });

    test('a suffixed name is still recognised as ours', () {
      expect(
        staleBackups([
          'vyana-backup-2026-11-15.vyana',
          'vyana-backup-2026-11-15-2.vyana',
          'vyana-backup-2026-11-16.vyana',
          'vyana-backup-2026-11-17.vyana',
          'vyana-backup-2026-11-18.vyana',
        ]),
        ['vyana-backup-2026-11-15-2.vyana'],
      );
    });
  });

  group('what the row says', () {
    test('off says off, and nothing more', () {
      expect(const AutoBackupStatus(enabled: false).line, 'Off');
    });

    test('a failure is said here, in the row, and nowhere else', () {
      expect(
        const AutoBackupStatus(
          enabled: true,
          lastError: 'That folder is no longer reachable.',
        ).line,
        'That folder is no longer reachable.',
      );
    });

    test('on, but not yet run', () {
      expect(
        const AutoBackupStatus(enabled: true).line,
        'On · first backup will run this week',
      );
    });
  });
}
