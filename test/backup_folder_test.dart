import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/file_exchange_service.dart';

/// Item 108 — the weekly backup's folder, reached the way each platform
/// allows.
void main() {
  test('off a phone, a folder is a path and works as one', () async {
    final dir = await Directory.systemTemp.createTemp('vyana_weekly');
    addTearDown(() => dir.delete(recursive: true));
    final folder = BackupFolder(dir.path);
    expect(await folder.reachable(), isTrue);
    await folder.write('a.vyana', Uint8List.fromList([1, 2, 3]));
    expect(await folder.list(), ['a.vyana']);
    await folder.delete('a.vyana');
    expect(await folder.list(), isEmpty);
  });

  test('Android and iPhone keep a permission, not a path', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/seeknirvana/vyana/BackupFolderHandler.kt',
    ).readAsStringSync();
    expect(kotlin, contains('takePersistableUriPermission'));
    expect(kotlin, contains('ACTION_OPEN_DOCUMENT_TREE'));
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('bookmarkData('));
    expect(swift, contains('startAccessingSecurityScopedResource'));
  });

  test('Android runs the weekly check on the service heartbeat', () {
    final shell = File('lib/src/shell/vyana_shell.dart').readAsStringSync();
    expect(shell, contains('addTaskDataCallback(_onServiceTick)'));
  });
}
