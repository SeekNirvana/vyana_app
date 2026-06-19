import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-scoped storage root for all durable Vyana data.
///
/// Android: `Android/data/com.seeknirvana.vyana/files/vyana/`
/// iOS:     `<Application Support>/vyana/`
class VyanaStorageService {
  VyanaStorageService._();

  static final VyanaStorageService instance = VyanaStorageService._();

  static const rootFolderName = 'vyana';

  static const MethodChannel _channel = MethodChannel('vyana/storage');

  String? _rootPath;
  String? _failureReason;
  bool _ready = false;
  Future<void>? _initFuture;

  bool get isReady => _ready;

  String? get failureReason => _failureReason;

  String? get rootPath => _rootPath;

  String get modelsPath => _requirePath('models');

  String get voicePath => _requirePath('voice');

  String get wellnessPath => _requirePath('wellness');

  String get cachePath => _requirePath('cache');

  String get exportsPath => _requirePath('exports');

  String _requirePath(String child) {
    final root = _rootPath;
    if (root == null || root.isEmpty) {
      throw StateError('Vyana storage is not ready.');
    }
    return p.join(root, child);
  }

  Future<void> ensureReady() {
    return _initFuture ??= _initialize();
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

      final root = await _resolveRootPath();
      if (root == null || root.isEmpty) {
        _failureReason =
            'Could not access app storage. Vyana needs local storage to run.';
        return;
      }

      await _createLayout(root);
      if (!await _verifyWritable(root)) {
        _failureReason =
            'App storage is not writable. Grant storage access or free space, then restart Vyana.';
        return;
      }

      _rootPath = root;
      _ready = true;
      _failureReason = null;
      debugPrint('[VyanaStorage] Ready at $root');
    } catch (error, stack) {
      debugPrint('[VyanaStorage] Init failed: $error\n$stack');
      _failureReason =
          'Failed to prepare app storage. Restart Vyana after checking free space.';
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

  Future<String?> _resolveRootPath() async {
    if (kIsWeb) {
      return null;
    }

    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return p.join(external.path, rootFolderName);
      }
      return null;
    }

    if (Platform.isIOS) {
      final support = await getApplicationSupportDirectory();
      return p.join(support.path, rootFolderName);
    }

    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, rootFolderName);
  }

  Future<void> _createLayout(String root) async {
    for (final segment in ['models', 'voice', 'wellness', 'cache', 'exports']) {
      await Directory(p.join(root, segment)).create(recursive: true);
    }
  }

  Future<bool> _verifyWritable(String root) async {
    final probe = File(p.join(root, '.storage_probe'));
    try {
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on Object {
      return false;
    }
  }
}