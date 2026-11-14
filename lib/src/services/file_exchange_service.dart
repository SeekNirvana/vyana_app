/// Item 53 and 65 — handing a file to the person, and taking one back.
///
/// Vyana could write files and never give them to anyone. Exports landed
/// in a folder and the app said "Saved to your exports folder", which was
/// true only while that folder happened to be reachable over USB — on
/// iPhone it never was, and once the vault moved to app-private storage it
/// would not have been on Android either. And a backup is worthless if it
/// cannot be chosen again on a new phone.
///
/// So there are exactly two operations here, and the rest of the app knows
/// about neither plugin:
///
/// * [offerFile] — the system sheet, where the person chooses Files, Drive,
///   iCloud Drive, a message, wherever. Vyana does not pick the
///   destination and never sees it.
/// * [askForFile] — the system picker, which hands back one file the
///   person chose and nothing else.
///
/// Both are deliberately dumb. Naming, encryption and what the bytes mean
/// belong to [backup_file.dart]; this moves them across the boundary.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_file.dart' show kBackupFileExtension;

/// The name a backup is saved under.
///
/// Dated, because the first question anyone asks of a backup is "how old
/// is this one", and a folder of files called `vyana-backup.vyana` cannot
/// answer it. Sortable order, so a file manager lists them oldest to
/// newest without being asked.
String backupFileName(DateTime when) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'vyana-backup-${when.year}-${two(when.month)}-${two(when.day)}'
      '.$kBackupFileExtension';
}

/// What came back from the system sheet.
enum FileOfferResult {
  /// Handed off. Where it went is the person's business and is not reported
  /// back to us by either platform.
  shared,

  /// Dismissed without choosing anywhere.
  dismissed,

  /// The sheet could not be opened at all.
  unavailable,
}

class FileExchangeService {
  const FileExchangeService();

  /// Offers [file] through the system sheet.
  ///
  /// [subject] is what a mail app would use as a subject line; [text] is
  /// not set, because a backup needs no covering note and anything written
  /// here would be the app talking about the user's data in someone else's
  /// app.
  Future<FileOfferResult> offerFile({
    required File file,
    required String subject,
  }) async {
    if (!file.existsSync()) return FileOfferResult.unavailable;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: subject,
        ),
      );
      switch (result.status) {
        case ShareResultStatus.success:
          return FileOfferResult.shared;
        case ShareResultStatus.dismissed:
          return FileOfferResult.dismissed;
        case ShareResultStatus.unavailable:
          return FileOfferResult.unavailable;
      }
    } on Object catch (error) {
      debugPrint('[FileExchange] could not offer ${file.path}: $error');
      return FileOfferResult.unavailable;
    }
  }

  /// Asks the person to choose a file, returning null if they chose none.
  ///
  /// Deliberately unfiltered. `.vyana` is a custom extension with no UTI
  /// and no MIME type, and a picker asked to filter on one it does not
  /// know can grey out the very file someone came for — or, on iOS, refuse
  /// the request outright, which this would then report as "cancelled".
  /// Letting any file through and checking it afterwards is the kinder
  /// failure: the reader already tells a file that is not a Vyana backup
  /// from a wrong passphrase, and says so.
  Future<File?> askForFile() async {
    try {
      final picked = await openFile();
      if (picked == null) return null;
      return File(picked.path);
    } on Object catch (error) {
      debugPrint('[FileExchange] could not open the picker: $error');
      return null;
    }
  }
}
