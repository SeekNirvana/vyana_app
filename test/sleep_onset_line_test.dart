import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Guards the sleep-onset line against the failure that nearly shipped in
/// v1.1.3: the sentence was written into `SleepDayCard`, a widget nothing
/// instantiates, so Dart tree-shook it out of the release snapshot and the
/// only thing that noticed was the release fingerprint check.
///
/// Pumping the real screen — rather than the card on its own — is the whole
/// point. A test that instantiated the dead widget directly would have
/// passed while no user could ever see the line.
void main() {
  late RingHistory history;

  setUpAll(() {
    final raw = File('test/fixtures_real_history.json').readAsStringSync();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    List<dynamic> recs(String key) =>
        (map[key] as List<dynamic>? ?? const []).toList();
    history = RingHistory(
      steps: recs('steps'),
      sleep: recs('sleep'),
      heartRate: recs('heartRate'),
      bloodPressure: recs('bloodPressure'),
      combined: recs('combined'),
      invasive: recs('invasive'),
      sport: recs('sport'),
    );
  });

  testWidgets('the day view explains where the night starts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: SleepDetailScreen(history: history)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    // The screen anchors to the most recent day that has data, not to
    // DateTime.now(), so this does not rot as the fixture ages.
    //
    // This ring never opens a night with an awake stage, so the fallback
    // branch renders — and it is the exact string that
    // scripts/release-manifest.txt fingerprints. If this ever flips to
    // `inBedLabel`, the manifest entry needs revisiting too.
    expect(
      find.textContaining('counts as light sleep'),
      findsOneWidget,
      reason: 'the sleep-onset line is not in the live widget tree',
    );
  });
}
