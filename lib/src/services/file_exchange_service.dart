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
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

/// Item 122: a point to anchor the share sheet's popover to on iPad — the
/// middle of the app's window, which is always inside the source view.
Rect? shareSheetAnchor() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return null;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  if (size.isEmpty) return null;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
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
          // Item 122: iPad presents the sheet as a popover and needs an
          // anchor; without one it fails to open. The middle of the screen
          // is a valid anchor everywhere and is ignored on phones.
          sharePositionOrigin: shareSheetAnchor(),
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

  /// Asks the person to choose a folder, once, for the weekly backup.
  ///
  /// Returns null if they chose none. Item 108: on Android and iPhone what
  /// comes back is not a path but a handle the platform will honour next
  /// week — a document tree with a persisted permission on Android
  /// (`content://…`), a security-scoped bookmark on iPhone (`bookmark:…`).
  /// A plain path from the old picker lost its access as soon as the app
  /// closed. Elsewhere it is a path, as before.
  Future<String?> askForFolder() async {
    if (BackupFolder.usesPlatformAccess) {
      try {
        return await BackupFolder._channel.invokeMethod<String>('pick');
      } on Object catch (error) {
        debugPrint('[FileExchange] could not open the folder picker: $error');
        return null;
      }
    }
    try {
      return await getDirectoryPath(
        confirmButtonText: 'Back up here',
      );
    } on Object catch (error) {
      debugPrint('[FileExchange] could not open the folder picker: $error');
      return null;
    }
  }
}

/// Item 108: the weekly backup's folder, read and written the way each
/// platform allows. [handle] is what [FileExchangeService.askForFolder]
/// returned and what is stored in preferences.
class BackupFolder {
  const BackupFolder(this.handle);

  final String handle;

  static const MethodChannel _channel = MethodChannel('vyana/backup_folder');

  /// Whether this platform reaches the folder through its own permission.
  static bool get usesPlatformAccess =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// A handle the platform channel understands, as opposed to a plain path
  /// saved by v1.1.6, which cannot be reached any more on a phone.
  bool get _isPlatformHandle =>
      handle.startsWith('content://') || handle.startsWith('bookmark:');

  bool get _viaChannel => usesPlatformAccess && _isPlatformHandle;

  /// Whether the folder can still be written to.
  Future<bool> reachable() async {
    if (_viaChannel) {
      try {
        return await _channel.invokeMethod<bool>(
              'reachable',
              {'folder': handle},
            ) ??
            false;
      } on Object {
        return false;
      }
    }
    // A plain path on a phone is the v1.1.6 form, which the platform no
    // longer honours: say so, and the person chooses it again.
    if (usesPlatformAccess) return false;
    return Directory(handle).existsSync();
  }

  /// The names of the files directly in the folder.
  Future<List<String>> list() async {
    if (_viaChannel) {
      final names = await _channel.invokeListMethod<String>(
        'list',
        {'folder': handle},
      );
      return names ?? const [];
    }
    return Directory(handle)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
  }

  Future<void> write(String name, Uint8List bytes) async {
    if (_viaChannel) {
      await _channel.invokeMethod<bool>(
        'write',
        {'folder': handle, 'name': name, 'bytes': bytes},
      );
      return;
    }
    await File('$handle${Platform.pathSeparator}$name')
        .writeAsBytes(bytes, flush: true);
  }

  Future<void> delete(String name) async {
    if (_viaChannel) {
      await _channel.invokeMethod<bool>(
        'delete',
        {'folder': handle, 'name': name},
      );
      return;
    }
    final file = File('$handle${Platform.pathSeparator}$name');
    if (file.existsSync()) await file.delete();
  }
}
