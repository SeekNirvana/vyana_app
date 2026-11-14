/// Item 53, part five — backing up every week, if the person asks for it.
///
/// Off by default, and that is the whole shape of it: nothing leaves this
/// phone unless someone switches this on or backs one up by hand. When it
/// is on, it writes the same encrypted file the manual button writes, into
/// a folder the person chose once, and keeps the last few.
///
/// Three decisions live here rather than in the UI, because each is a rule
/// about someone's data and not about a screen.
library;

import 'package:flutter/foundation.dart';

/// Whether the weekly backup is on. Absent means off — a feature that
/// sends data somewhere must never default to on by the absence of a
/// setting.
const String kAutoBackupEnabledKey = 'vyana.backup.auto.enabled';

/// The folder chosen once, as the picker returned it.
const String kAutoBackupFolderKey = 'vyana.backup.auto.folder';

/// When the last automatic run finished.
const String kAutoBackupLastRunKey = 'vyana.backup.auto.last_run';

/// Why the last automatic run did not happen, if it did not.
const String kAutoBackupLastErrorKey = 'vyana.backup.auto.last_error';

/// Where the passphrase is kept so an unattended run needs no input.
/// Keychain on iOS, Keystore-backed on Android — never in preferences.
const String kAutoBackupPassphraseKey = 'vyana.backup.auto.passphrase';

/// How often.
const Duration kAutoBackupEvery = Duration(days: 7);

/// How many files are kept in the folder.
///
/// Four, so a month of weekly backups is there and a single bad one — a
/// restore taken from a phone mid-problem, a corrupted write — is not the
/// only thing left to restore from.
const int kAutoBackupKeep = 4;

/// Whether an automatic run is due.
///
/// Never when it is switched off, and never without a folder to write to:
/// a run with nowhere to go is not a backup, it is an encryption exercise
/// that ends in a thrown-away file.
bool autoBackupDue({
  required bool enabled,
  required String? folder,
  required DateTime? lastRun,
  DateTime? now,
}) {
  if (!enabled) return false;
  if (folder == null || folder.isEmpty) return false;
  if (lastRun == null) return true;
  return (now ?? DateTime.now()).difference(lastRun) >= kAutoBackupEvery;
}

/// Which files in the folder should go, oldest first.
///
/// Deliberately matched by name rather than by modification time: a folder
/// synced to Drive or iCloud rewrites timestamps as it pleases, and the
/// date in the name is the one thing that came from the backup itself.
/// Anything that is not one of ours is left alone — the person chose that
/// folder and may keep other things in it.
List<String> staleBackups(List<String> fileNames, {int keep = kAutoBackupKeep}) {
  final ours = fileNames
      .where((name) => _backupName.hasMatch(name))
      .toList()
    ..sort();
  if (ours.length <= keep) return const [];
  return ours.take(ours.length - keep).toList();
}

final RegExp _backupName =
    RegExp(r'^vyana-backup-\d{4}-\d{2}-\d{2}(-\d+)?\.vyana$');

/// What the Your data row says about the weekly backup, if anything.
///
/// A failure is said here, in grey, and nowhere else — no notification, no
/// badge. The person did not ask to be interrupted; they asked for a file
/// to appear in a folder, and being told it did not is enough.
@immutable
class AutoBackupStatus {
  const AutoBackupStatus({
    required this.enabled,
    this.lastRun,
    this.lastError,
  });

  final bool enabled;
  final DateTime? lastRun;
  final String? lastError;

  String get line {
    if (!enabled) return 'Off';
    final error = lastError;
    if (error != null && error.isNotEmpty) return error;
    final at = lastRun;
    if (at == null) return 'On · first backup will run this week';
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'On · backed up today';
    if (days == 1) return 'On · backed up yesterday';
    return 'On · backed up $days days ago';
  }
}

/// A name that will not collide if two run on the same day.
String uniqueBackupName(String base, Set<String> taken) {
  if (!taken.contains(base)) return base;
  final dot = base.lastIndexOf('.');
  final stem = dot < 0 ? base : base.substring(0, dot);
  final ext = dot < 0 ? '' : base.substring(dot);
  for (var i = 2; i < 100; i++) {
    final candidate = '$stem-$i$ext';
    if (!taken.contains(candidate)) return candidate;
  }
  return base;
}
