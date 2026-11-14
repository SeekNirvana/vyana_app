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
import 'backup_file.dart';
import 'backup_payload.dart';
import 'file_exchange_service.dart';
import 'vyana_storage_service.dart';

/// One backup service for the app.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

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
    final stored = prefs.getString(kLastBackupKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
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

  Future<Map<String, Object?>> _settingsToBackUp() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, Object?>{};
    for (final key in kBackupSettingKeys) {
      final value = prefs.get(key);
      if (value != null) out[key] = value;
    }
    return out;
  }

  Future<void> _restoreSettings(Object? raw) async {
    if (raw is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in Map<String, Object?>.from(raw).entries) {
      // Only the keys this build backs up. A backup from a future version
      // may name settings that mean something else here, and a key that
      // describes the phone was never in the file to begin with.
      if (!kBackupSettingKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(
          entry.key,
          value.whereType<String>().toList(),
        );
      }
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
