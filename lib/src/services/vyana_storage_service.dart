import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// App-scoped storage for all durable Vyana data.
///
/// Item 59: everything used to live under one root, and on Android that root
/// was `getExternalStorageDirectory()` —
/// `Android/data/com.seeknirvana.vyana/files/vyana/`. That directory is not
/// private. It is readable over USB and adb on every Android version, and on
/// Android 8 and 9 — which this app still supports — by any app the user has
/// granted storage permission to. The vault in it holds ring history,
/// journal entries and cycle days.
///
/// So there are two roots now, and which one a folder belongs in is decided
/// by what is in it rather than by how large it is:
///
/// * [dataRootPath] — internal, app-private, readable by nothing but Vyana.
///   `wellness/` (the vault and meal photos) and `cache/`. This is the whole
///   point of the item.
/// * [rootPath] — the external app directory, unchanged. `models/` and
///   `voice/` are public model weights with nothing personal in them, and
///   they run to gigabytes; copying them inward would need twice their size
///   free on the way, and buys no privacy at all. `exports/` stays too, and
///   item 65 — which gave exports the share sheet this comment once said
///   they were waiting for — is the reason it stays rather than the reason
///   it moves. An export is written here first and offered second, so the
///   file survives a sheet the person closes or a phone that cannot open
///   one. That fallback is only a fallback while the folder is reachable:
///   moving it inward would leave someone whose sheet fails with a path
///   they can read and a file they cannot get at, which is the exact
///   failure item 65 exists to end. Nothing personal is kept here that is
///   not already in a file the person asked us to write for them.
///
/// The move itself is built to fail safe: copy, verify every byte, keep the
/// old copy until a later launch has proved the new one, and on any doubt
/// keep reading from where the data already is.
class VyanaStorageService {
  VyanaStorageService._();

  static final VyanaStorageService instance = VyanaStorageService._();

  static const rootFolderName = 'vyana';

  /// Folders holding something only the user should see.
  static const privateFolders = ['wellness', 'cache'];

  /// Folders holding downloads and files the user goes looking for.
  static const sharedFolders = ['models', 'voice', 'exports'];

  /// Set once the vault has been copied inward, holding the old root. The
  /// old copy is deleted on a *later* launch, never the one that wrote it:
  /// if the new location is somehow wrong, the data is still in both places
  /// and the next launch is the one that notices.
  static const _pendingCleanupKey = 'vyana.storage.old_root_pending_delete';

  /// Item 99: the folders an attempt at the move is copying, written before
  /// the first byte and removed when the attempt ends either way. Found on
  /// a launch, it means the last attempt was killed part-way, and the
  /// folders it names are wiped at the new location and copied again.
  static const _moveAttemptKey = 'vyana.storage.move_attempt';

  /// Item 99: the root the app last read the vault from. A copy at the new
  /// location is only ever replaced when the app was not reading it, so
  /// the live vault can never be wiped by the move.
  static const _readingFromKey = 'vyana.storage.reading_from';

  /// The vault's database file, as drift names it in [VyanaDatabase].
  static const vaultDatabaseFile = 'vyana_vault.sqlite';

  static const MethodChannel _channel = MethodChannel('vyana/storage');

  String? _rootPath;
  String? _dataRootPath;
  String? _failureReason;
  bool _ready = false;
  Future<void>? _initFuture;

  bool get isReady => _ready;

  String? get failureReason => _failureReason;

  /// Where downloads and exports live. On Android, app-specific external
  /// storage; elsewhere the same place as [dataRootPath].
  String? get rootPath => _rootPath;

  /// Where the user's own records live. App-private on every platform.
  String? get dataRootPath => _dataRootPath;

  String get modelsPath => _requireShared('models');

  String get voicePath => _requireShared('voice');

  String get exportsPath => _requireShared('exports');

  String get wellnessPath => _requirePrivate('wellness');

  String get cachePath => _requirePrivate('cache');

  /// Where meal photos live, so nothing has to remember a path across an
  /// update. See [mealPhotosPath]'s callers in meal_photo_service.dart.
  String get mealPhotosPath => p.join(wellnessPath, 'meals');

  String _requireShared(String child) => _require(_rootPath, child);

  String _requirePrivate(String child) => _require(_dataRootPath, child);

  String _require(String? root, String child) {
    if (root == null || root.isEmpty) {
      throw StateError('Vyana storage is not ready.');
    }
    return p.join(root, child);
  }

  Future<void> ensureReady() {
    return _initFuture ??= _initialize();
  }

  /// Tries again after a failure, for the Retry on the storage screen.
  ///
  /// Item 91: [ensureReady] caches its attempt, so calling it again after a
  /// refusal returned the same refusal — which is why the screen could only
  /// say "restart the app". Clearing the cached attempt is what makes a
  /// retry mean anything. A successful init is never redone.
  Future<void> retry() async {
    if (_ready) return;
    _initFuture = null;
    _failureReason = null;
    await ensureReady();
  }

  Future<void> _initialize() async {
    if (_ready) return;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final access = await _requestAndroidStorageAccess();
        if (access['granted'] != true) {
          _failureReason = access['reason'] as String? ??
              'Storage access is required for Vyana to save your data.';
          return;
        }
      }

      final shared = await _resolveSharedRoot();
      final private = await _resolvePrivateRoot();
      if (shared == null || shared.isEmpty || private == null ||
          private.isEmpty) {
        _failureReason =
            'Could not access app storage. Vyana needs local storage to run.';
        return;
      }

      await _createLayout(shared, sharedFolders);
      await _createLayout(private, privateFolders);
      if (!await _verifyWritable(shared) || !await _verifyWritable(private)) {
        _failureReason =
            'App storage is not writable. Grant storage access or free space, then restart Vyana.';
        return;
      }

      _rootPath = shared;
      _dataRootPath = private;

      // Only after both roots are known good, and never in a way that can
      // leave the app with neither copy. A move that cannot be completed
      // leaves the data where it is and the app reading it there — the one
      // outcome worse than not moving is moving halfway.
      if (await _migratePrivateFolders(from: shared, to: private)) {
        await _deleteOldCopyIfAlreadyProved(private);
      } else {
        _dataRootPath = shared;
        await _createLayout(shared, privateFolders);
        debugPrint('[VyanaStorage] migration deferred; reading from $shared');
      }

      // Item 99: which root the app is reading, for the next launch's move.
      await _rememberReadingFrom(_dataRootPath!);

      _ready = true;
      _failureReason = null;
      debugPrint('[VyanaStorage] Ready — data $private, downloads $shared');
      await _excludeFromDeviceBackup([private, shared]);
    } catch (error, stack) {
      debugPrint('[VyanaStorage] Init failed: $error\n$stack');
      _failureReason =
          'Failed to prepare app storage. Restart Vyana after checking free space.';
    }
  }

  Future<void> _rememberReadingFrom(String root) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_readingFromKey, root);
    } on Object catch (error) {
      debugPrint('[VyanaStorage] could not record the vault root: $error');
    }
  }

  /// Item 102: on iPhone, keeps the vault out of iCloud device backups.
  ///
  /// Android does this in the manifest (allowBackup="false" and the data
  /// extraction rules). iPhone has no manifest switch: the flag is set per
  /// file or folder, and is lost when one is recreated, so it is set at
  /// every launch — by the app delegate before Flutter starts, and again
  /// here once the folders are known to exist. A failure is logged, never
  /// fatal: the app works either way.
  static const _backupExclusionChannel =
      MethodChannel('vyana/backup_exclusion');

  Future<void> _excludeFromDeviceBackup(List<String> paths) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _backupExclusionChannel.invokeMethod<int>(
        'excludeFromBackup',
        {'paths': paths.toSet().toList()},
      );
    } on Object catch (error) {
      debugPrint('[VyanaStorage] could not exclude from backup: $error');
    }
  }

  Future<Map<String, dynamic>> _requestAndroidStorageAccess() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'ensureAccess',
      );
      return result ?? {'granted': false, 'reason': 'Storage access denied.'};
    } on PlatformException catch (error) {
      return {
        'granted': false,
        'reason': error.message ?? 'Storage permission unavailable.',
      };
    }
  }

  /// Where big downloads and user-facing exports go.
  Future<String?> _resolveSharedRoot() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return p.join(external.path, rootFolderName);
      // No external storage at all: better app-private than nothing.
      return _resolvePrivateRoot();
    }
    return _resolvePrivateRoot();
  }

  /// Where the user's own records go — app-private on every platform.
  Future<String?> _resolvePrivateRoot() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid || Platform.isIOS) {
      final support = await getApplicationSupportDirectory();
      return p.join(support.path, rootFolderName);
    }
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, rootFolderName);
  }

  Future<void> _createLayout(String root, List<String> segments) async {
    for (final segment in segments) {
      await Directory(p.join(root, segment)).create(recursive: true);
    }
  }

  Future<bool> _verifyWritable(String root) async {
    final probe = File(p.join(root, '.storage_probe'));
    try {
      await probe.parent.create(recursive: true);
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on Object {
      return false;
    }
  }

  /// Moves [privateFolders] from the old shared root to the private one.
  ///
  /// Deliberately not a rename: the two live on different mounts even when
  /// they are the same physical storage, so a rename fails and a half-done
  /// one is the worst possible result. Copy, verify, and only then record
  /// that the old copy may go — on a later launch.
  /// Returns false when the vault could not be copied, which means the
  /// caller must go on reading from where it already is.
  Future<bool> _migratePrivateFolders({
    required String from,
    required String to,
  }) async {
    if (from == to) return true;
    final prefs = await SharedPreferences.getInstance();
    final moveCompleted = prefs.getString(_pendingCleanupKey) == from;
    final readingNew = prefs.getString(_readingFromKey) == to;

    // Item 99: an attempt that was killed part-way left folders at the new
    // location that nothing has proved. They are wiped and copied again
    // from scratch, never trusted.
    final unfinished = prefs.getStringList(_moveAttemptKey);
    if (unfinished != null) {
      if (!moveCompleted) {
        debugPrint('[VyanaStorage] an earlier move did not finish; redoing it');
        for (final folder in unfinished) {
          await _rollback(Directory(p.join(to, folder)));
        }
      }
      await prefs.remove(_moveAttemptKey);
    }

    // Decide every folder before copying any, so the attempt is one unit.
    final plan = <String>[];
    for (final folder in privateFolders) {
      final source = Directory(p.join(from, folder));
      final destination = Directory(p.join(to, folder));
      final move = folderMoveFor(
        sourceHasData: await storageHoldsAnything(source),
        destinationHasData: await storageHoldsAnything(destination),
        moveCompleted: moveCompleted,
        readingDestination: readingNew,
      );
      switch (move) {
        case FolderMove.skip:
          continue;
        case FolderMove.recopy:
          // Data on both sides with no finished move recorded: the copy
          // here is from an attempt that did not complete (v1.1.6 left
          // exactly this), and the app went on writing to the old place.
          // The old place is the newer one.
          debugPrint('[VyanaStorage] $folder here is stale; copying again');
          await _rollback(destination);
          plan.add(folder);
        case FolderMove.copy:
          plan.add(folder);
      }
    }
    if (plan.isEmpty) return true;

    await prefs.setStringList(_moveAttemptKey, plan);
    Future<bool> abandon(String why) async {
      // Item 99: every folder this attempt copied goes, not only the one
      // that failed. Leaving `wellness` here after `cache` failed is what
      // let a later launch skip it, read the stale copy, and delete the
      // newer one.
      debugPrint('[VyanaStorage] $why; undoing this attempt, staying put');
      for (final folder in plan) {
        await _rollback(Directory(p.join(to, folder)));
      }
      await prefs.remove(_moveAttemptKey);
      return false;
    }

    for (final folder in plan) {
      final copied = await copyStorageTreeVerified(
        Directory(p.join(from, folder)),
        Directory(p.join(to, folder)),
      );
      // Reading from the old place is not what the item asks for, and it
      // is a great deal better than either reading from a half-written
      // new one or refusing to start. The next launch tries again.
      if (!copied) return abandon('$folder did not copy cleanly');
    }

    // Item 99: the database has to open at the new location before the
    // app is switched to it. A byte-for-byte copy of a file that does not
    // open is still a vault nobody can read.
    if (plan.contains('wellness')) {
      final vault = File(p.join(to, 'wellness', vaultDatabaseFile));
      if (vault.existsSync() && !storageDatabaseOpens(vault.path)) {
        return abandon('the vault does not open at the new location');
      }
    }

    _migratedThisLaunch = true;
    // The finished move is recorded before the attempt marker goes, so a
    // kill between the two still reads as finished.
    await prefs.setString(_pendingCleanupKey, from);
    await prefs.remove(_moveAttemptKey);
    debugPrint('[VyanaStorage] Vault copied inward; old copy kept for now');
    return true;
  }

  /// Removes a half-written destination so the next launch tries again
  /// cleanly rather than finding a partial copy and trusting it.
  Future<void> _rollback(Directory destination) async {
    try {
      if (await destination.exists()) await destination.delete(recursive: true);
    } on Object catch (error) {
      debugPrint('[VyanaStorage] rollback failed: $error');
    }
  }

  /// Deletes the old copy, but only on a launch *after* the one that made
  /// the new one, and only once the new vault is there to be read.
  Future<void> _deleteOldCopyIfAlreadyProved(String private) async {
    final prefs = await SharedPreferences.getInstance();
    final oldRoot = prefs.getString(_pendingCleanupKey);
    if (oldRoot == null || oldRoot.isEmpty || oldRoot == private) return;

    // The marker was written by this same run; this launch has not proved
    // anything yet. Leave both copies and let the next one decide.
    if (_migratedThisLaunch) return;

    // Every folder that had something out there must have something in
    // here before anything is deleted. Asking instead that *all* private
    // folders hold data would mean an empty `cache/` blocked the cleanup
    // for good, which is the same end state as never having written this.
    final states = <FolderMigrationState>[];
    for (final folder in privateFolders) {
      states.add((
        folder: folder,
        staleHasData:
            await storageHoldsAnything(Directory(p.join(oldRoot, folder))),
        currentHasData:
            await storageHoldsAnything(Directory(p.join(private, folder))),
      ));
    }
    if (!oldCopyIsSafeToDelete(states)) {
      debugPrint('[VyanaStorage] data outside with none here; keeping old copy');
      return;
    }

    for (final folder in privateFolders) {
      final stale = Directory(p.join(oldRoot, folder));
      try {
        if (await stale.exists()) await stale.delete(recursive: true);
      } on Object catch (error) {
        debugPrint('[VyanaStorage] could not remove old $folder: $error');
        return;
      }
    }
    await prefs.remove(_pendingCleanupKey);
    debugPrint('[VyanaStorage] old copy removed; new location proved');
  }

  /// True once this launch has written the new copy, so the launch that
  /// made it is never also the launch that deletes the old one.
  bool _migratedThisLaunch = false;
}

/// Whether [dir] holds a file with anything in it.
///
/// An empty directory, or one with only zero-length leftovers, is not data —
/// the distinction decides whether a migration is allowed to write there.
Future<bool> storageHoldsAnything(Directory dir) async {
  if (!await dir.exists()) return false;
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && await entity.length() > 0) return true;
  }
  return false;
}

/// Copies every file under [source] into [destination], then checks each one
/// arrived whole. Returns false on the first that did not.
///
/// Byte-for-byte rather than by length: a truncated or torn copy of an
/// SQLite file is the one failure that would look fine and read wrong, and
/// the vault is small enough that there is no reason to accept a cheaper
/// check.
Future<bool> copyStorageTreeVerified(
  Directory source,
  Directory destination,
) async {
  try {
    await destination.create(recursive: true);
    var files = 0;
    await for (final entity in source.list(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final target = p.join(destination.path, relative);
      if (entity is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entity is File) {
        await Directory(p.dirname(target)).create(recursive: true);
        await entity.copy(target);
        if (!await storageFilesMatch(entity, File(target))) {
          debugPrint('[VyanaStorage] $relative did not copy intact');
          return false;
        }
        files++;
      }
    }
    debugPrint('[VyanaStorage] verified $files file(s) into ${destination.path}');
    return true;
  } on Object catch (error) {
    debugPrint('[VyanaStorage] copy failed: $error');
    return false;
  }
}

/// Whether two files hold exactly the same bytes.
Future<bool> storageFilesMatch(File a, File b) async {
  if (!await b.exists()) return false;
  final lengthA = await a.length();
  if (lengthA != await b.length()) return false;
  final bytesA = await a.readAsBytes();
  final bytesB = await b.readAsBytes();
  for (var i = 0; i < bytesA.length; i++) {
    if (bytesA[i] != bytesB[i]) return false;
  }
  return true;
}

/// One private folder's state on both sides of the move.
typedef FolderMigrationState = ({
  String folder,
  bool staleHasData,
  bool currentHasData,
});

/// Item 99: what to do with one private folder at launch.
enum FolderMove {
  /// Nothing to copy, or the new location is the live one.
  skip,

  /// Something to copy and nothing in the way.
  copy,

  /// Data on both sides and no finished move: the copy at the new location
  /// is left over from an attempt that did not complete, and is replaced.
  recopy,
}

/// Item 99: decides a folder's move.
///
/// The case that lost data: `wellness` copied, `cache` failed, and the app
/// went on writing to the old location. The next launch saw data at the
/// new location, skipped `wellness`, and read the stale copy. Data on both
/// sides is only ever right once a move has finished (the old copy then
/// waits to be deleted); before that, it means the new copy is stale.
///
/// [readingDestination] is whether the app last read the vault from the new
/// location. Then the new copy is the live one, whatever else is true, and
/// is never replaced.
FolderMove folderMoveFor({
  required bool sourceHasData,
  required bool destinationHasData,
  required bool moveCompleted,
  bool readingDestination = false,
}) {
  if (!sourceHasData) return FolderMove.skip;
  if (!destinationHasData) return FolderMove.copy;
  if (moveCompleted || readingDestination) return FolderMove.skip;
  return FolderMove.recopy;
}

/// Item 99: whether the SQLite file at [path] opens and passes a quick
/// integrity check. Opened read-only, so checking can never change it.
bool storageDatabaseOpens(String path) {
  sqlite.Database? db;
  try {
    db = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    final rows = db.select('PRAGMA quick_check');
    return rows.isNotEmpty && rows.first.values.first == 'ok';
  } on Object catch (error) {
    debugPrint('[VyanaStorage] vault did not open at $path: $error');
    return false;
  } finally {
    db?.dispose();
  }
}

/// Whether a folder should be copied inward.
///
/// Only when there is something to copy and nothing already there. An empty
/// source is not a migration — treating it as one marks the launch as having
/// migrated, which defers the cleanup to "next time", every time.
bool shouldMigrateFolder({
  required bool sourceHasData,
  required bool destinationHasData,
}) {
  return sourceHasData && !destinationHasData;
}

/// Whether the old copy can go.
///
/// Every folder that holds something out there must hold something in here.
/// A folder empty on both sides is fine — demanding that *all* of them hold
/// data would let an empty `cache/` block the cleanup for the life of the
/// install, leaving the vault sitting outside exactly as before.
bool oldCopyIsSafeToDelete(List<FolderMigrationState> states) {
  return states.every((s) => !s.staleHasData || s.currentHasData);
}
