import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 119 — the ring's hardware ID stays out of the sync log, and the log
/// can be opened.
void main() {
  const mac = '08:00:00:00:01:5A';
  final device = {'name': 'R36', 'macAddress': mac};

  test('the batch id is never built from the MAC address', () {
    final batch = buildCloudHistoryBatch(
      device: device,
      basicInfo: null,
      features: null,
      history: RingHistory.empty(),
    );
    final sync = batch['sync'] as Map? ?? const {};
    final id = (sync['batchId'] ?? batch['batchId']).toString();
    expect(id, isNot(contains('08:00:00')));
    expect(id, isNot(contains('08_00_00')));
  });

  test('for the log, the address appears nowhere in the batch', () {
    final batch = buildCloudHistoryBatch(
      device: device,
      basicInfo: null,
      features: null,
      history: RingHistory.empty(),
      includeAddress: false,
    );
    final text = batch.toString();
    expect(text, isNot(contains('08:00:00:00:01:5A')));
    expect(text, isNot(contains('08_00_00_00_01_5A')));
  });

  test('About → Diagnostics opens the sync log', () {
    final about = File('lib/src/info_panels.dart').readAsStringSync();
    expect(about, contains("label: 'Sync log'"));
    expect(about, contains('openHistory('));
  });
}
