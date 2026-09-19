import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/wellness/wellness_state.dart';

void main() {
  group('intent pre-set', () {
    final tuesday = DateTime(2026, 9, 15, 8); // a Tuesday

    test('trains most Tuesdays → Tuesday opens on Perform', () {
      final starts = [
        for (var w = 1; w <= 5; w++)
          tuesday.subtract(Duration(days: 7 * w)),
      ];
      expect(
        presetIntent(now: tuesday, sessionStarts: starts, readiness: 78),
        DayIntent.perform,
      );
    });

    test('consistent rest day → Recover even when readiness is high', () {
      final monday = tuesday.subtract(const Duration(days: 1));
      final starts = [
        for (var w = 1; w <= 5; w++) monday.subtract(Duration(days: 7 * w)),
      ];
      expect(
        presetIntent(now: tuesday, sessionStarts: starts, readiness: 84),
        DayIntent.recover,
      );
    });

    test('low readiness wins; tense body settles', () {
      expect(
        presetIntent(now: tuesday, sessionStarts: const [], readiness: 42),
        DayIntent.recover,
      );
      expect(
        presetIntent(
          now: tuesday,
          sessionStarts: const [],
          readiness: 80,
          tense: true,
        ),
        DayIntent.settle,
      );
    });

    test('no history falls back to the body', () {
      expect(
        presetIntent(now: tuesday, sessionStarts: const [], readiness: 75),
        DayIntent.perform,
      );
      expect(
        presetIntent(now: tuesday, sessionStarts: const [], readiness: 60),
        DayIntent.recover,
      );
    });
  });

  group('reference ranges', () {
    test('resting-HR band follows training frequency, clinical when unanswered',
        () {
      expect(restingHrBand(null).caption, 'TYPICAL 60–100 BPM');
      expect(restingHrBand(TrainingFrequency.mostDays).caption,
          'YOUR BAND 40–60 BPM');
      expect(restingHrBand(TrainingFrequency.fewTimesAWeek).high, 70);
      expect(restingHrBand(TrainingFrequency.rarely).low, 60);
    });

    test('four ring windows plus sleep and resting HR', () {
      expect(referenceRangeFor(VitalsMetricKind.hrv)!.caption, 'TYPICAL 21–90 MS');
      expect(referenceRangeFor(VitalsMetricKind.sleep)!.contains(7.5), isTrue);
      expect(referenceRangeFor(VitalsMetricKind.sleep)!.contains(6.2), isFalse);
      expect(referenceRangeFor(VitalsMetricKind.stress)!.contains(36), isFalse);
      expect(referenceRangeFor(VitalsMetricKind.spo2)!.contains(97), isTrue);
      expect(referenceRangeFor(VitalsMetricKind.steps), isNull);
    });

    test('peak badge is computed from the series, not per metric', () {
      expect(
        peakBadgeFor(today: 65, window: [50, 54, 60, 58, 61], windowDays: 7),
        '7-DAY HIGH',
      );
      expect(
        peakBadgeFor(today: 40, window: [50, 54, 60, 52, 49], windowDays: 30),
        '30-DAY LOW',
      );
      expect(
        peakBadgeFor(today: 55, window: [50, 54, 60, 52, 57], windowDays: 90),
        isNull,
      );
      // Fewer than five prior days: no badge, however extreme today looks.
      expect(peakBadgeFor(today: 99, window: [55, 55, 55], windowDays: 7), isNull);
    });
  });

  group('patterns', () {
    test('entries logged before noon belong to the night that just ended', () {
      expect(nightKeyForEntry(DateTime(2026, 9, 15, 4, 44)), DateTime(2026, 9, 15));
      expect(nightKeyForEntry(DateTime(2026, 9, 15, 21, 2)), DateTime(2026, 9, 16));
    });

    test('journal pattern counts the recurring tag and states the join', () {
      final now = DateTime(2026, 9, 18, 9);
      PatternEntry dream(int day, List<String> tags) => PatternEntry(
            id: 'd$day',
            type: 'dream',
            createdAt: DateTime(2026, 9, day, 5),
            tags: tags,
          );
      final entries = [
        dream(17, ['water', 'recurring']),
        dream(14, ['water']),
        dream(12, ['animals']),
        dream(9, ['recurring']),
        dream(6, ['water', 'recurring']),
        PatternEntry(
          id: 'r1',
          type: 'reflection',
          createdAt: DateTime(2026, 9, 16, 9),
          tags: const ['water'],
        ),
      ];
      final c = journalPatternCandidate(entries: entries, nights: const [], now: now);
      expect(c, isNotNull);
      expect(c!.subject, 'water');
      expect(c.matchCount, 3);
      expect(c.evidenceCount, 5);
      expect(c.evidenceIds, ['d17', 'd14', 'd6']);
      expect(c.claim, 'Water turns up in three of your five dreams this month.');
    });

    test('no pattern under three dreams or when no tag recurs', () {
      final now = DateTime(2026, 9, 18, 9);
      final few = [
        PatternEntry(id: 'a', type: 'dream', createdAt: DateTime(2026, 9, 17, 5), tags: const ['water']),
        PatternEntry(id: 'b', type: 'dream', createdAt: DateTime(2026, 9, 16, 5), tags: const ['water']),
      ];
      expect(journalPatternCandidate(entries: few, nights: const [], now: now), isNull);
      final scattered = [
        PatternEntry(id: 'a', type: 'dream', createdAt: DateTime(2026, 9, 17, 5), tags: const ['water']),
        PatternEntry(id: 'b', type: 'dream', createdAt: DateTime(2026, 9, 16, 5), tags: const ['fire']),
        PatternEntry(id: 'c', type: 'dream', createdAt: DateTime(2026, 9, 15, 5), tags: const ['air']),
      ];
      expect(journalPatternCandidate(entries: scattered, nights: const [], now: now), isNull);
    });

    test('card shows the strongest current pattern and hides old endings', () {
      PatternRow row(String id, String status, {DateTime? endedAt}) => PatternRow(
            id: id,
            source: 'journal',
            subject: 'water',
            claim: id,
            status: status,
            evidenceIdsJson: '[]',
            evidenceCount: 5,
            matchCount: 3,
            firstSeen: DateTime(2026, 8, 1),
            lastConfirmed: DateTime(2026, 9, 1),
            endedAt: endedAt,
          );
      final recentEnd = row('ended-recent', 'broken',
          endedAt: DateTime.now().subtract(const Duration(days: 3)));
      final oldEnd = row('ended-old', 'broken',
          endedAt: DateTime.now().subtract(const Duration(days: 40)));
      expect(currentPatternFor([oldEnd], 'journal'), isNull);
      expect(currentPatternFor([recentEnd], 'journal')?.id, 'ended-recent');
      expect(
        currentPatternFor([recentEnd, row('weak', 'weakening'), row('hold', 'holding')], 'journal')?.id,
        'hold',
      );
      expect(currentPatternFor([row('hold', 'holding')], 'metrics'), isNull);
    });
  });

  group('metrics', () {
    test('ECG classification set', () {
      EcgRecordingRow rec({bool af = false, int qrs = 1, String? text}) =>
          EcgRecordingRow(
            id: 'e',
            capturedAt: DateTime(2026, 9, 1),
            durationMs: 30000,
            sampleRateHz: 250,
            sampleCount: 7500,
            rawSamplesJson: '[]',
            filteredSamplesJson: '[]',
            afFlag: af,
            qrsType: qrs,
            interpretation: text,
            createdAt: DateTime(2026, 9, 1),
          );
      expect(ecgClassification(rec(af: true)), 'AFib');
      expect(ecgClassification(rec(qrs: 0)), 'Inconclusive');
      expect(ecgClassification(rec(qrs: 14)), 'Inconclusive');
      expect(ecgClassification(rec(text: 'Suspected bradycardia')), 'Irregular');
      expect(ecgClassification(rec(text: 'Normal sinus rhythm')), 'Sinus');
    });

    test('read sentence follows the chosen intent', () {
      final state = WellnessState.from(hrv: 65, readinessScore: 78);
      final dashboard = HomeDashboard(
        stepStreak: 0,
        todaySteps: 0,
        todayDistanceMeters: 0,
        todayCalories: 0,
        todayActiveMinutes: 0,
        lastSleepDuration: null,
        readinessScore: 78,
        readinessLabel: 'Steady',
        readinessDelta: null,
        drivers: const [],
        insights: const [],
        practiceHint: '',
        hasRingHistory: true,
      );
      expect(readSentenceFor(DayIntent.recover, state, dashboard), contains('protecting'));
      expect(readSentenceFor(DayIntent.perform, state, dashboard), contains('capacity'));
      expect(readSentenceFor(DayIntent.settle, state, dashboard), contains('calm'));
    });
  });
}
