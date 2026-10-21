import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Runs the user's real cached ring history through the actual chart code,
/// rather than a reimplementation of it, so a claim about the chart being
/// empty can be checked instead of argued about.
void main() {
  late RingHistory history;
  late DateTime anchor;

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
    // The fixture is a frozen snapshot of real cached history, and
    // readinessSeries() windows back from today. Measure the ranges from
    // the newest night in the snapshot instead, or this starts failing a
    // week after it was captured for reasons that say nothing about the
    // chart.
    anchor = sleepDaySummaries(history.sleep).first.day;
  });

  test('readiness series is populated at 7D / 30D / 90D', () {
    for (final days in [7, 30, 90]) {
      final series = readinessSeries(history, days, now: anchor);
      final values = series.map((e) => e.score).toList();
      final avg = values.isEmpty
          ? null
          : (values.reduce((a, b) => a + b) / values.length).round();
      // ignore: avoid_print
      print('${days}D -> ${series.length} points, avg $avg, '
          'first ${series.isEmpty ? '-' : series.first.day} '
          'last ${series.isEmpty ? '-' : series.last.day}');
      // The chart draws a line only from two points up.
      expect(series.length, greaterThanOrEqualTo(2),
          reason: '${days}D series is too short to draw');
      expect(avg, isNotNull, reason: '${days}D has no average');
    }
  });

  test('the ranges are not all identical', () {
    final week = readinessSeries(history, 7, now: anchor).length;
    final month = readinessSeries(history, 30, now: anchor).length;
    // ignore: avoid_print
    print('7D=$week  30D=$month');
    expect(week, lessThan(month),
        reason: 'the range control is not changing the data');
  });
}
