import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/wellness/wellness_state.dart';
import 'package:vyana_sdk/vyana_sdk.dart';

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
            counterIdsJson: '[]',
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
        sleepStatus: SleepNightStatus.complete,
      );
      expect(readSentenceFor(DayIntent.recover, state, dashboard), contains('protecting'));
      expect(readSentenceFor(DayIntent.perform, state, dashboard), contains('capacity'));
      expect(readSentenceFor(DayIntent.settle, state, dashboard), contains('calm'));
    });
  });

  group('sleep night completeness (bug 14)', () {
    /// A night shaped like the ring's real records: staged segments that end
    /// on light sleep, because the ring stops recording when you get up
    /// rather than emitting a trailing "awake" stage. On a real device only
    /// 5 of 25 nights ended on an awake segment.
    List<dynamic> nightRecord({
      required DateTime start,
      required Duration asleep,
      int lastType = SleepType.lightSleep,
    }) {
      final startTs = start.millisecondsSinceEpoch ~/ 1000;
      final endTs = startTs + asleep.inSeconds;
      return [
        {
          'isNewSleepProtocol': true,
          'startTimeStamp': startTs,
          'endTimeStamp': endTs,
          'deepSleepSeconds': (asleep.inSeconds * 0.2).round(),
          'lightSleepSeconds': (asleep.inSeconds * 0.6).round(),
          'remSleepSeconds': (asleep.inSeconds * 0.2).round(),
          'detail': [
            {
              'startTimeStamp': startTs,
              'duration': (asleep.inSeconds * 0.5).round(),
              'sleepType': SleepType.deepSleep,
            },
            {
              'startTimeStamp': startTs + (asleep.inSeconds * 0.5).round(),
              'duration': (asleep.inSeconds * 0.5).round(),
              'sleepType': lastType,
            },
          ],
        },
      ];
    }

    RingHistory historyWith(List<dynamic> sleep, {List<dynamic> after = const []}) =>
        RingHistory(
          steps: const [],
          sleep: sleep,
          heartRate: after,
          bloodPressure: const [],
          combined: const [],
          invasive: const [],
          sport: const [],
        );

    test('a full night ending on light sleep is complete, not incomplete', () {
      final start = DateTime(2026, 10, 2, 23);
      final records = nightRecord(start: start, asleep: const Duration(hours: 7, minutes: 41));
      final night = sleepDaySummaries(records).first;
      // The regression: requiring a trailing `awake` stage wrote off a
      // perfectly good 7h41m night.
      expect(
        sleepNightStatus(night, now: night.day, history: historyWith(records)),
        SleepNightStatus.complete,
      );
    });

    test('a short night the ring kept measuring through is still complete', () {
      final start = DateTime(2026, 10, 2, 3);
      final records = nightRecord(start: start, asleep: const Duration(hours: 2));
      final night = sleepDaySummaries(records).first;
      // Biomarkers after the night mean the ring was alive and worn, so the
      // short night is real rather than a truncated recording.
      final after = [
        // Real ring records key their time as `startTimeStamp`.
        {
          'startTimeStamp': night.windowEnd
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'heartRate': 62,
        },
      ];
      expect(
        sleepNightStatus(
          night,
          now: night.day,
          history: historyWith(records, after: after),
        ),
        SleepNightStatus.complete,
      );
    });

    test('a short night with nothing measured afterwards is incomplete', () {
      final start = DateTime(2026, 10, 2, 3);
      final records = nightRecord(start: start, asleep: const Duration(hours: 2));
      final night = sleepDaySummaries(records).first;
      expect(
        sleepNightStatus(night, now: night.day, history: historyWith(records)),
        SleepNightStatus.incomplete,
      );
    });

    test('a night that is not today is missing, never shown as today', () {
      final start = DateTime(2026, 10, 2, 23);
      final records = nightRecord(start: start, asleep: const Duration(hours: 8));
      final night = sleepDaySummaries(records).first;
      expect(
        sleepNightStatus(
          night,
          now: night.day.add(const Duration(days: 2)),
          history: historyWith(records),
        ),
        SleepNightStatus.missing,
      );
    });
  });

  group('readiness composition', () {
    test('Home and the Metrics chart share one computation', () {
      // Same inputs must give the same number: Home used the overnight HRV
      // while the chart averaged the whole day's readings, so the big score
      // and today's point on the chart could disagree.
      expect(
        readinessScoreFrom(sleepScore: 80, hrv: 45),
        readinessScoreFrom(sleepScore: 80, hrv: 45),
      );
      // Bug 22 (3): HRV is scored against the band that applies to this
      // person, not a fixed 20–90 scale. 45 ms sits 35% up the typical
      // 21–90 band, so 80 × 0.65 + 35 × 0.35 = 64.
      expect(readinessScoreFrom(sleepScore: 80, hrv: 45), 64);
    });

    test('HRV is scored against the base, not a fixed scale', () {
      // The same reading means different things to different bodies: at the
      // bottom of your own range it is a poor night whatever the number is.
      const low = VitalReferenceRange(
        low: 40,
        high: 100,
        caption: 'YOUR RANGE 40–100 MS',
      );
      const high = VitalReferenceRange(
        low: 10,
        high: 40,
        caption: 'YOUR RANGE 10–40 MS',
      );
      expect(readinessScoreFrom(hrv: 40, hrvBase: low), 0);
      expect(readinessScoreFrom(hrv: 40, hrvBase: high), 100);
    });

    test('readiness is about today: last night only, never accumulated', () {
      // A good night after poor ones scores on its own merit. Sleep debt is
      // deliberately not carried into the score — the read describes today.
      final goodAfterBad = readinessScoreFrom(sleepScore: 88, hrv: 50);
      final goodAfterGood = readinessScoreFrom(sleepScore: 88, hrv: 50);
      expect(goodAfterBad, goodAfterGood);
    });

    test('the day turns over at wake, not at midnight (bug 22)', () {
      final lastNight = DateTime(2026, 10, 20);
      // 00:30: the calendar day has rolled over but the user is still
      // asleep. Last night is still the night that describes them.
      expect(isNightForDay(lastNight, DateTime(2026, 10, 21, 0, 30)), isTrue);
      expect(isNightForDay(lastNight, DateTime(2026, 10, 21, 8, 0)), isTrue);
      // By noon a night that was coming has come; holding on is stale.
      expect(isNightForDay(lastNight, DateTime(2026, 10, 21, 12, 1)), isFalse);
      // An older night is never today's, at any hour.
      expect(
        isNightForDay(DateTime(2026, 10, 18), DateTime(2026, 10, 21, 2, 0)),
        isFalse,
      );
    });

    test('a range knows which side is a problem (bug 23)', () {
      // Higher is fine: an HRV above the band is not a red flag.
      expect(
        vitalVerdict(
          kind: VitalsMetricKind.hrv,
          range: kHrvRange,
          value: 95,
        ).quality,
        'good',
      );
      // An athlete's resting HR under the band is not a verdict either way.
      final band = restingHrBand(null);
      expect(
        vitalVerdict(
          kind: VitalsMetricKind.heartRate,
          range: band,
          value: 48,
        ).quality,
        'level',
      );
      // But a floor still applies, with an explanation rather than a colour.
      final veryLow = vitalVerdict(
        kind: VitalsMetricKind.heartRate,
        range: band,
        value: 38,
      );
      expect(veryLow.quality, 'watch');
      expect(veryLow.note, contains('talk to a doctor'));
      // Over the band is still poor, and says which way.
      expect(
        vitalVerdict(
          kind: VitalsMetricKind.heartRate,
          range: band,
          value: 110,
        ).captionSuffix,
        'ABOVE',
      );
      // A lie-in is long, not bad.
      final long = vitalVerdict(
        kind: VitalsMetricKind.sleep,
        range: kSleepRange,
        value: 10.5,
      );
      expect(long.quality, 'level');
      expect(long.captionSuffix, 'LONG');
    });

    test('without a usable night, HRV alone carries the score', () {
      // 45 ms, 35% up the typical band, carries the score on its own.
      expect(readinessScoreFrom(sleepScore: null, hrv: 45), 35);
      expect(readinessScoreFrom(sleepScore: null, hrv: null), isNull);
    });
  });

  group('your week / month (bug 29)', () {
    SessionRow session({
      required String id,
      required String activity,
      required String category,
      required DateTime started,
      required int minutes,
    }) =>
        SessionRow(
          id: id,
          category: category,
          vyanaActivityType: activity,
          ringSportType: 0,
          startedAt: started,
          endedAt: started.add(Duration(minutes: minutes)),
          phoneLocationEnabled: false,
        );

    // Wednesday.
    final now = DateTime(2026, 10, 21, 18);

    test('a week totals only its own sessions, by the day they ended', () {
      final rows = [
        session(
          id: 'a',
          activity: 'outdoorRun',
          category: 'sport',
          started: DateTime(2026, 10, 19, 8),
          minutes: 40,
        ), // Monday
        session(
          id: 'b',
          activity: 'breathwork',
          category: 'mind',
          started: DateTime(2026, 10, 21, 7),
          minutes: 20,
        ), // Wednesday
        session(
          id: 'c',
          activity: 'outdoorRun',
          category: 'sport',
          started: DateTime(2026, 10, 12, 8),
          minutes: 30,
        ), // last week
      ];
      final summary = PeriodSummary.of(
        rows,
        const PracticePeriod(month: false, offset: 0),
        now: now,
      );
      expect(summary.sessions, 2);
      expect(summary.minutes, 60);
      expect(summary.activeDays, 2);
      expect(summary.dayCount, 7);
      // Mindfulness and wellness only.
      expect(summary.mindfulMinutes, 20);
      // Sorted by time, longest first.
      expect(summary.byPractice.first.activityId, 'outdoorRun');
      expect(summary.byPractice.first.minutes, 40);
    });

    test('last week is a different period, reachable by going back', () {
      final rows = [
        session(
          id: 'c',
          activity: 'outdoorRun',
          category: 'sport',
          started: DateTime(2026, 10, 12, 8),
          minutes: 30,
        ),
      ];
      const thisWeek = PracticePeriod(month: false, offset: 0);
      expect(PeriodSummary.of(rows, thisWeek, now: now).sessions, 0);
      expect(PeriodSummary.of(rows, thisWeek.earlier, now: now).sessions, 1);
      // Nothing ahead of the current period to look at.
      expect(thisWeek.later, isNull);
      expect(thisWeek.earlier.later, isNotNull);
    });

    test('nothing falls back to a seed', () {
      final summary = PeriodSummary.of(
        const [],
        const PracticePeriod(month: false, offset: 0),
        now: now,
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.sessions, 0);
      expect(summary.minutes, 0);
      expect(summary.activeDays, 0);
      expect(summary.byPractice, isEmpty);
    });
  });
}
