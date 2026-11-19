/// Item 53 — backing up and restoring, as one operation each.
///
/// The three layers below this one each do a single thing:
/// [backup_payload.dart] decides what is in a backup, [backup_file.dart]
/// locks it, and [file_exchange_service.dart] moves it across the boundary
/// to the person. This puts them in order and remembers when it last
/// happened, so the screen has one call for each verb and no decisions of
/// its own.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auto_backup.dart';
import 'backup_file.dart';
import 'backup_payload.dart';
import 'file_exchange_service.dart';
import 'vyana_storage_service.dart';

/// One backup service for the app.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

/// What the Your data row says about backing up, under its fixed line.
///
/// Item 108: "Last backup 2 Nov" or "Never backed up", always, so the row
/// says where things stand rather than only when a backup is overdue. A
/// weekly run that did not finish says so instead, until the next one
/// does. Invalidated after every backup and restore so it is never a
/// screen behind.
final backupRowSubtitleProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(backupServiceProvider);
  final auto = await service.autoBackupStatus();
  if (auto.enabled && auto.lastError != null) return auto.lastError!;
  return lastBackupDateLine(await service.lastBackupAt());
});

/// Item 108: the You row's fixed line.
const String kYourDataRowLine =
    'Your history lives only on this phone. Deleting Vyana deletes it.';

/// "Last backup 2 Nov" / "Never backed up". The date rather than an age:
/// a date is something to check against your own memory.
String lastBackupDateLine(DateTime? lastBackup) {
  if (lastBackup == null) return 'Never backed up';
  return 'Last backup ${lastBackup.day} ${_monthShort[lastBackup.month - 1]}';
}

const List<String> _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Item 108: whether the one-time card after the first sync has been
/// answered (Back up now, or Not now). Once is once.
const String kFirstSyncBackupCardKey = 'vyana.backup.first_sync_card_done';

/// Whether to show that card: the ring has synced, nothing has ever been
/// backed up, and the card has not been answered.
bool firstSyncBackupCardDue({
  required bool hasSynced,
  required DateTime? lastBackup,
  required bool answered,
}) =>
    hasSynced && lastBackup == null && !answered;

/// When the last backup was handed off, as an ISO date.
const String kLastBackupKey = 'vyana.backup.last_at';

/// How long before the Your data row mentions it.
///
/// Thirty days, said in grey and nowhere else. No push, no colour, no
/// badge: a backup is a good idea, not an emergency, and an app that
/// nags about its own housekeeping teaches people to ignore it.
const Duration kBackupStaleAfter = Duration(days: 30);

/// What happened when a backup was asked for.
enum BackupOutcome { saved, dismissed, failed }

@immutable
class BackupAttempt {
  const BackupAttempt(this.outcome, {this.message});

  final BackupOutcome outcome;
  final String? message;
}

class BackupService {
  BackupService(this._db, {FileExchangeService? files})
      : _files = files ?? const FileExchangeService();

  final VyanaDatabase _db;
  final FileExchangeService _files;

  /// When the last backup was handed off, or null if never.
  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final manual = DateTime.tryParse(prefs.getString(kLastBackupKey) ?? '');
    // Item 108: a weekly run that finished is a backup too, so the row's
    // "Last backup" date counts it.
    final weekly =
        DateTime.tryParse(prefs.getString(kAutoBackupLastRunKey) ?? '');
    if (manual == null) return weekly;
    if (weekly == null) return manual;
    return weekly.isAfter(manual) ? weekly : manual;
  }

  /// Builds a backup, locks it with [passphrase], and offers it to the
  /// person through the system sheet.
  ///
  /// The date is recorded only when the sheet reports the file was
  /// actually handed off. A backup someone dismissed is not a backup, and
  /// recording it would mean the row says "backed up today" about a file
  /// that does not exist.
  Future<BackupAttempt> backUpNow({
    required String passphrase,
    required String appVersion,
    DateTime? now,
  }) async {
    if (passphrase.isEmpty) {
      return const BackupAttempt(
        BackupOutcome.failed,
        message: 'A backup needs a passphrase.',
      );
    }

    File? temporary;
    try {
      await VyanaStorageService.instance.ensureReady();
      final when = now ?? DateTime.now();

      final settings = await _settingsToBackUp();
      final payload = await buildBackupPayload(
        db: _db,
        settings: settings,
        now: when,
      );
      final photos = await collectMealPhotos(
        db: _db,
        mealPhotosPath: VyanaStorageService.instance.mealPhotosPath,
      );

      final bytes = await writeBackup(
        payload: payload,
        files: photos,
        passphrase: passphrase,
        appVersion: appVersion,
        createdAt: when,
      );

      // Written somewhere temporary, because the sheet needs a path and
      // this file is not ours to keep — the person chooses where it lives.
      final dir = await getTemporaryDirectory();
      temporary = File(p.join(dir.path, backupFileName(when)));
      await temporary.writeAsBytes(bytes, flush: true);

      final result = await _files.offerFile(
        file: temporary,
        subject: 'Vyana backup',
      );

      switch (result) {
        case FileOfferResult.shared:
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(kLastBackupKey, when.toIso8601String());
          return const BackupAttempt(BackupOutcome.saved);
        case FileOfferResult.dismissed:
          return const BackupAttempt(BackupOutcome.dismissed);
        case FileOfferResult.unavailable:
          return const BackupAttempt(
            BackupOutcome.failed,
            message: 'This phone could not open the save sheet.',
          );
      }
    } on Object catch (error) {
      debugPrint('[Backup] failed: $error');
      return BackupAttempt(
        BackupOutcome.failed,
        message: 'The backup could not be made. $error',
      );
    } finally {
      // Never leave a copy of everything lying in a temporary folder.
      try {
        if (temporary != null && temporary.existsSync()) {
          await temporary.delete();
        }
      } on Object {
        // Nothing to do about it, and not worth failing a good backup for.
      }
    }
  }

  /// Opens a chosen backup and puts it back, replacing what is here.
  ///
  /// Throws [BackupException] with the reason, which the caller shows: the
  /// four cases read differently on purpose and the screen must not
  /// flatten them into "restore failed".
  Future<BackupRestoreReport> restoreFrom({
    required File file,
    required String passphrase,
  }) async {
    final contents = await openBackup(
      bytes: await file.readAsBytes(),
      passphrase: passphrase,
    );

    final report = await restoreBackupPayload(
      db: _db,
      payload: contents.payload,
    );

    await VyanaStorageService.instance.ensureReady();
    final photos = await restoreMealPhotos(
      files: contents.files,
      mealPhotosPath: VyanaStorageService.instance.mealPhotosPath,
    );

    await _restoreSettings(contents.payload['settings']);
    return report.withPhotos(photos);
  }

  /// Lets the person choose a backup. Null if they chose none.
  Future<File?> chooseBackup() => _files.askForFile();

  /// Lets the person choose where weekly backups go.
  Future<String?> chooseFolder() => _files.askForFolder();

  // ── The weekly backup (item 53, part five) ─────────────────────────────

  // Keychain on iOS, Keystore-backed on Android. The plugin's own
  // defaults: encryptedSharedPreferences is deprecated and ignored, and
  // passing it would be asking for something that no longer happens.
  static const _secure = FlutterSecureStorage();

  Future<AutoBackupStatus> autoBackupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final run = prefs.getString(kAutoBackupLastRunKey);
    return AutoBackupStatus(
      enabled: prefs.getBool(kAutoBackupEnabledKey) ?? false,
      lastRun: run == null ? null : DateTime.tryParse(run),
      lastError: prefs.getString(kAutoBackupLastErrorKey),
    );
  }

  /// Turns the weekly backup on, given a folder and a passphrase.
  ///
  /// The passphrase goes to the Keychain or the Keystore and nowhere else —
  /// never to preferences, never into the file, never into a log. It is
  /// kept at all only so an unattended run needs no input, which is the
  /// only reason that outweighs not keeping it.
  Future<void> enableAutoBackup({
    required String folder,
    required String passphrase,
  }) async {
    await _secure.write(key: kAutoBackupPassphraseKey, value: passphrase);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoBackupEnabledKey, true);
    await prefs.setString(kAutoBackupFolderKey, folder);
    await prefs.remove(kAutoBackupLastErrorKey);
  }

  /// Turns it off, and forgets the passphrase with it.
  ///
  /// Switching it off is the clearest statement someone can make that they
  /// do not want this, so the stored secret goes too rather than waiting
  /// on a Keystore nobody will think to clear.
  Future<void> disableAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoBackupEnabledKey, false);
    await prefs.remove(kAutoBackupFolderKey);
    await prefs.remove(kAutoBackupLastErrorKey);
    await _secure.delete(key: kAutoBackupPassphraseKey);
  }

  /// Runs the weekly backup if one is due. Safe to call on every launch.
  ///
  /// Returns whether a file was written. Failures are recorded for the Your
  /// data row rather than thrown: the person did not ask to be interrupted,
  /// and a folder that has gone is something to be told about, not
  /// something to stop the app for.
  Future<bool> runAutoBackupIfDue({
    required String appVersion,
    DateTime? now,
  }) async {
    // Item 108: launch and the service heartbeat can both ask at once.
    if (_autoBackupRunning) return false;
    _autoBackupRunning = true;
    try {
      return await _runAutoBackupIfDue(appVersion: appVersion, now: now);
    } finally {
      _autoBackupRunning = false;
    }
  }

  bool _autoBackupRunning = false;

  Future<bool> _runAutoBackupIfDue({
    required String appVersion,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final folder = prefs.getString(kAutoBackupFolderKey);
    final lastRun = prefs.getString(kAutoBackupLastRunKey);

    if (!autoBackupDue(
      enabled: prefs.getBool(kAutoBackupEnabledKey) ?? false,
      folder: folder,
      lastRun: lastRun == null ? null : DateTime.tryParse(lastRun),
      now: now,
    )) {
      return false;
    }

    try {
      final passphrase =
          await _secure.read(key: kAutoBackupPassphraseKey);
      if (passphrase == null || passphrase.isEmpty) {
        // The secret is gone — a restored phone, a cleared Keystore. Not a
        // failure to shout about, but the switch is now a promise that
        // cannot be kept, so it stops claiming otherwise.
        await prefs.setString(
          kAutoBackupLastErrorKey,
          'Switch this on again to set the passphrase.',
        );
        await prefs.setBool(kAutoBackupEnabledKey, false);
        return false;
      }

      // Item 108: through the platform's own access to the folder (a
      // persisted document-tree permission on Android, a security-scoped
      // bookmark on iPhone), not a path that lost its access when the app
      // closed.
      final directory = BackupFolder(folder!);
      if (!await directory.reachable()) {
        await prefs.setString(
          kAutoBackupLastErrorKey,
          'That folder is no longer reachable. Choose it again.',
        );
        return false;
      }

      await VyanaStorageService.instance.ensureReady();
      final when = now ?? DateTime.now();
      final payload = await buildBackupPayload(
        db: _db,
        settings: await _settingsToBackUp(),
        now: when,
      );
      final photos = await collectMealPhotos(
        db: _db,
        mealPhotosPath: VyanaStorageService.instance.mealPhotosPath,
      );
      final bytes = await writeBackup(
        payload: payload,
        files: photos,
        passphrase: passphrase,
        appVersion: appVersion,
        createdAt: when,
      );

      final existing = await directory.list();
      final name =
          uniqueBackupName(backupFileName(when), existing.toSet());
      await directory.write(name, bytes);

      for (final stale in staleBackups([...existing, name])) {
        try {
          await directory.delete(stale);
        } on Object catch (error) {
          // Keeping too many is harmless; failing the run over it is not.
          debugPrint('[Backup] could not remove $stale: $error');
        }
      }

      await prefs.setString(kAutoBackupLastRunKey, when.toIso8601String());
      await prefs.remove(kAutoBackupLastErrorKey);
      return true;
    } on Object catch (error) {
      debugPrint('[Backup] weekly run failed: $error');
      await prefs.setString(
        kAutoBackupLastErrorKey,
        'The last weekly backup did not finish.',
      );
      return false;
    }
  }

  Future<Map<String, Object?>> _settingsToBackUp() async =>
      collectBackupSettings(await SharedPreferences.getInstance());

  Future<void> _restoreSettings(Object? raw) async =>
      applyBackupSettings(await SharedPreferences.getInstance(), raw);
}

/// The settings that go into a backup, read the way the app wrote them.
@visibleForTesting
Map<String, Object?> collectBackupSettings(SharedPreferences prefs) {
  final out = <String, Object?>{};
  for (final key in kBackupSettingKeys) {
    final value = prefs.get(key);
    if (value != null) out[key] = value;
  }
  return out;
}

/// Writes a backup's settings back under the keys the app reads.
@visibleForTesting
Future<void> applyBackupSettings(SharedPreferences prefs, Object? raw) async {
  if (raw is! Map) return;
  for (final entry in Map<String, Object?>.from(raw).entries) {
    // A file written with the plugin's on-disk prefix still means the
    // same setting.
    final key = entry.key.startsWith('flutter.')
        ? entry.key.substring('flutter.'.length)
        : entry.key;
    // Only the keys this build backs up. A backup from a future version
    // may name settings that mean something else here, and a key that
    // describes the phone was never in the file to begin with.
    if (!kBackupSettingKeys.contains(key)) continue;
    final value = entry.value;
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.whereType<String>().toList());
    }
  }
}

/// What the Your data row says under its title.
///
/// Plain, and in the past tense where it can be: a date is something to
/// check against your own memory, "34 days ago" is something to act on.
String lastBackupLine(DateTime? lastBackup, {DateTime? now}) {
  if (lastBackup == null) return 'Never backed up';
  final today = now ?? DateTime.now();
  final days = today.difference(lastBackup).inDays;
  if (days <= 0) return 'Last backup today';
  if (days == 1) return 'Last backup yesterday';
  if (days < kBackupStaleAfter.inDays) return 'Last backup $days days ago';
  return 'Last backup $days days ago';
}

/// Whether the row should mention the age at all.
///
/// Never for a phone with nothing in it yet: telling someone on their
/// second day that they have never backed up is nagging about an empty
/// file.
bool backupIsOverdue({
  required DateTime? lastBackup,
  required Duration historyAge,
  DateTime? now,
}) {
  if (historyAge < const Duration(days: 7)) return false;
  if (lastBackup == null) return true;
  return (now ?? DateTime.now()).difference(lastBackup) > kBackupStaleAfter;
}
