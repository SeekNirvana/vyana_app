import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/services/ai_backend_service.dart';
import 'package:vyana/src/services/guide_model_manager.dart';
import 'package:vyana/src/services/guide_persona_prefs_service.dart';
import 'package:vyana/src/services/guide_voice_service.dart';
import 'package:vyana/src/services/nova_voice_assets.dart';
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

  group('the last 7 days, not this week (bug 50)', () {
    // A Wednesday. The Monday-anchored week would be 19–25 Oct; the rolling
    // window is 15–21 Oct.
    final now = DateTime(2026, 10, 21, 18);
    const week = PracticePeriod(month: false, offset: 0);

    test('the window ends today and is seven days long', () {
      expect(week.start(now), DateTime(2026, 10, 15));
      expect(week.end(now), DateTime(2026, 10, 22));
      expect(week.dayCount(now), 7);
      // Going back steps seven days, not to a calendar week.
      expect(week.earlier.start(now), DateTime(2026, 10, 8));
      expect(week.earlier.end(now), DateTime(2026, 10, 15));
    });

    test('the labels follow the dates, ending on today', () {
      // 15 Oct 2026 is a Thursday, so the row runs T F S S M T W.
      expect(week.dayLabels(now), ['T', 'F', 'S', 'S', 'M', 'T', 'W']);
    });

    test('the period is named, then dated', () {
      expect(week.label(now), 'Last 7 days');
      expect(week.earlier.label(now), '8–14 Oct');
      // Across a month boundary both months are named.
      expect(
        const PracticePeriod(month: false, offset: 0)
            .label(DateTime(2026, 10, 4, 9)),
        'Last 7 days',
      );
      expect(
        const PracticePeriod(month: false, offset: 1)
            .label(DateTime(2026, 10, 11, 9)),
        '28 Sep – 4 Oct',
      );
    });

    test('the month is still a calendar month', () {
      const month = PracticePeriod(month: true, offset: 0);
      expect(month.start(now), DateTime(2026, 10, 1));
      expect(month.end(now), DateTime(2026, 11, 1));
      expect(month.label(now), 'Oct 2026');
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

  group('sleep corrections (bugs 14d, 20)', () {
    test('unstaged sleep lengthens the night but not its stages', () {
      const staged = SleepStageBreakdown(
        deepSeconds: 3600,
        lightSeconds: 7200,
        remSeconds: 1800,
        awakeSeconds: 600,
        segmentCount: 10,
      );
      expect(staged.asleepSeconds, 12600);
      // "Yes, until 10:05" adds an hour of unstaged sleep.
      final extended = staged.withUnstaged(3600);
      expect(extended.asleepSeconds, 16200);
      // Deep and REM are untouched: nothing is known about that stretch.
      expect(extended.deepSeconds, staged.deepSeconds);
      expect(extended.remSeconds, staged.remSeconds);
      expect(extended.stagedAsleepSeconds, staged.asleepSeconds);
    });

    test('this ring labels time in bed as light sleep, never awake', () {
      // Bug 20 case (2), checked against the real cached history rather
      // than assumed: if a night ever opened awake, the sleep start would
      // move to the first real stage and the detail would say "In bed …".
      final raw = File('test/fixtures_real_history.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final nights = sleepDaySummaries(
        (map['sleep'] as List<dynamic>? ?? const []).toList(),
      );
      expect(nights, isNotEmpty);
      for (final n in nights) {
        expect(
          n.inBedBeforeSleep,
          isFalse,
          reason: 'no recorded night opens with an awake stage',
        );
        expect(n.sleepOnset, n.windowStart);
      }
    });
  });

  group('Nova listens first and can see your data (item 51)', () {
    final now = DateTime(2026, 11, 10, 15, 20); // a Tuesday

    NovaFacts facts({
      NovaDay? lastNight,
      MissingNightReason reason = MissingNightReason.recorded,
      List<String> concerns = const [],
      List<String> patterns = const [],
      DateTime? lastSync,
    }) =>
        NovaFacts(
          now: now,
          lastNight: lastNight,
          nightReason: reason,
          yesterday: NovaDay(
            day: DateTime(2026, 11, 9),
            sleepSeconds: 6 * 3600 + 50 * 60,
            sleepScore: 78,
            readiness: 71,
          ),
          today: NovaDay(
            day: DateTime(2026, 11, 10),
            readiness: 62,
            hrv: 48,
            restingHr: 58,
          ),
          hrvBase: 55,
          restingHrBase: 54,
          intent: DayIntent.recover,
          intentConfirmed: false,
          hasRing: true,
          lastSyncedAt: lastSync ?? DateTime(2026, 11, 9, 23, 10),
          batteryPercent: 12,
          suggestion: 'Body Scan',
          suggestionMinutes: 15,
          plannedActivity: 'Yoga Flow',
          plannedDone: false,
          patterns: patterns,
          concerns: concerns,
        );

    test('a missing night says why, and when the ring last synced', () {
      final block = formatNovaData(
        facts(reason: MissingNightReason.notSynced),
      );
      expect(block, startsWith('DATA (from the ring and app, not the user)'));
      expect(block, contains('last night: missing'));
      expect(block, contains('not synced since last night'));
      expect(block, contains('no sync since Mon 9 Nov 23:10'));
    });

    test("today's numbers carry their baselines", () {
      final block = formatNovaData(facts());
      expect(block, contains('today: readiness 62 · HRV 48 (base 55)'));
      expect(block, contains('resting HR 58 (base 54)'));
      expect(block, contains('yesterday: sleep 6h 50m · score 78'));
    });

    test("today's plan covers intent, suggestion and the planned practice",
        () {
      final block = formatNovaData(facts());
      expect(
        block,
        contains(
          "today's plan: intent Recover (not confirmed) · "
          'suggested Body Scan 15 min · planned Yoga Flow (not done)',
        ),
      );
    });

    test('lines with nothing in them are left out', () {
      final block = formatNovaData(facts());
      expect(block, isNot(contains('patterns:')));
      expect(block, isNot(contains('concerning:')));
      final loud = formatNovaData(
        facts(
          patterns: ['water dreams on 3 of last 5 nights after late dinners'],
          concerns: ['no sleep last night', 'battery low'],
        ),
      );
      expect(loud, contains('patterns: water dreams on 3 of'));
      expect(loud, contains('concerning: no sleep last night · battery low'));
    });

    test('the block stays near its size target', () {
      final block = formatNovaData(
        facts(
          patterns: ['water dreams on 3 of last 5 nights after late dinners'],
          concerns: ['no sleep last night', 'battery low'],
        ),
      );
      // ~4 characters a token: a generous ceiling on the 150-token target.
      expect(block.length, lessThan(kNovaDataTargetTokens * 6));
    });

    test('a past day or range is recognised; today alone is not', () {
      NovaLookupRange? at(String m) => novaLookupRangeFor(m, now: now);
      expect(at('how did I sleep on Tuesday?')?.label, 'Tue');
      expect(at('what about yesterday?')?.label, 'yesterday');
      expect(at('how was last week?')?.label, 'last week');
      expect(at('show me this month')?.label, 'this month');
      expect(at('what happened on 3 Nov?')?.from, DateTime(2026, 11, 3));
      expect(at('is my HRV trending down?')?.label, 'last 7 days');
      // No date, no metric over time — nothing to look up.
      expect(at('I feel tired'), isNull);
      expect(at('what should I do now?'), isNull);
    });

    test('a long range is summarised rather than listed', () {
      final days = [
        for (var i = 0; i < 20; i++)
          NovaDay(
            day: DateTime(2026, 10, 20 + i),
            sleepScore: 60 + i,
            nightMissing: i == 3,
          ),
      ];
      final short = formatNovaLookup(days.take(5).toList(), label: '5 days');
      expect(short.split('\n').length, 6); // header + 5 day lines
      final long = formatNovaLookup(days, label: 'last 20 days');
      expect(long, contains('20 days'));
      expect(long, contains('average score'));
      expect(long, contains('best 79'));
      expect(long, contains('worst 60'));
      expect(long, contains('1 missing night'));
      expect(long.split('\n').length, 2);
    });

    test('the instructions say to listen first and to admit a gap', () {
      expect(kNovaSystemPrompt, contains('Listen first'));
      expect(kNovaSystemPrompt, contains("If the data doesn't show something"));
      expect(kNovaSystemPrompt, contains('Never guess numbers'));
      // Roughly half the old prompt: ~150 tokens.
      expect(kNovaSystemPrompt.length, lessThan(1000));
      // The two rules survive a custom prompt.
      expect(kNovaListenFirstRules, contains('Listen first'));
      expect(
        kNovaListenFirstRules,
        contains("If the data doesn't show something"),
      );
    });

    test('the token cap is unchanged — item 51 says to measure first', () {
      expect(GuidePersonaPrefsService.androidBalancedMaxTokens, 1024);
      expect(GuidePersonaPrefsService.iosBalancedMaxTokens, 512);
    });
  });

  group('my week, the optional plan (item 46)', () {
    SessionRow did(String activity, DateTime at, {int minutes = 30}) =>
        SessionRow(
          id: '$activity-${at.millisecondsSinceEpoch}',
          category: activityById(activity)?.cat ?? 'mind',
          vyanaActivityType: activity,
          ringSportType: 0,
          startedAt: at,
          endedAt: at.add(Duration(minutes: minutes)),
          phoneLocationEnabled: false,
        );

    // A Tuesday.
    final tuesday = DateTime(2026, 11, 10, 14);
    WeeklyPlan planOn(int weekday, List<String> ids) => WeeklyPlan({
          weekday: PlannedDay(weekday: weekday, activityIds: ids),
        });

    HomeSuggestion suggestion({
      required WeeklyPlan plan,
      DateTime? now,
      int? readiness = 70,
      List<SessionRow> today = const [],
      List<SessionRow> history = const [],
      List<String> pins = const [],
    }) =>
        homeSuggestionFor(
          intent: DayIntent.perform,
          state: WellnessState.empty(),
          readiness: readiness,
          moment: homeMomentAt(now ?? tuesday),
          now: now ?? tuesday,
          pins: pins,
          history: history,
          todaysFinished: today,
          plan: plan,
        );

    test('no plan changes nothing', () {
      expect(WeeklyPlan.empty.isEmpty, isTrue);
      final s = suggestion(plan: WeeklyPlan.empty);
      expect(s.heading, 'Suggested activity');
    });

    test('a planned day shows the first one not yet done', () {
      final plan = planOn(2, ['yogaFlow', 'outdoorRun', 'stretching']);
      final s = suggestion(plan: plan);
      expect(s.heading, 'Planned today');
      expect(s.activityId, 'yogaFlow');
      expect(s.meta, startsWith('PLANNED · 1 OF 3'));
      expect(s.setsTarget, isFalse);

      // Done the first: the next one shows.
      final next = suggestion(
        plan: plan,
        today: [did('yogaFlow', tuesday.subtract(const Duration(hours: 2)))],
      );
      expect(next.activityId, 'outdoorRun');
      expect(next.meta, startsWith('PLANNED · 2 OF 3'));
    });

    test('no "1 OF 1" when only one is planned', () {
      final s = suggestion(plan: planOn(2, ['yogaFlow']));
      expect(s.meta, isNot(contains('OF')));
      expect(s.meta, startsWith('PLANNED · YOUR USUAL'));
    });

    test('unplanned practices do not count against the plan', () {
      final s = suggestion(
        plan: planOn(2, ['yogaFlow']),
        today: [did('swimming', tuesday.subtract(const Duration(hours: 1)))],
      );
      expect(s.activityId, 'yogaFlow');
    });

    test('a planned practice stays until done or 22:00', () {
      final plan = planOn(2, ['yogaFlow']);
      expect(
        suggestion(plan: plan, now: DateTime(2026, 11, 10, 21, 59)).heading,
        'Planned today',
      );
      // After 22:00 the evening wind-down takes over.
      final late = suggestion(plan: plan, now: DateTime(2026, 11, 10, 22, 1));
      expect(late.heading, 'Wind down');
    });

    test('an early trainer sees the plan from 05:00 instead', () {
      final plan = planOn(2, ['outdoorRun']);
      final morning = DateTime(2026, 11, 10, 7);
      // No history: the morning keeps its short practice.
      expect(suggestion(plan: plan, now: morning).heading,
          'Suggested practice');
      // Usually runs at 06:30 → the plan replaces it.
      final history = [
        for (var w = 1; w <= 3; w++)
          did('outdoorRun', DateTime(2026, 11, 10 - 7 * w, 6, 30)),
      ];
      final s =
          suggestion(plan: plan, now: morning, history: history);
      expect(s.heading, 'Planned today');
      expect(s.activityId, 'outdoorRun');
    });

    test('low readiness offers an alternative, never a silent swap', () {
      final s = suggestion(
        plan: planOn(2, ['outdoorRun']),
        readiness: 41,
        pins: const ['walk'],
      );
      // The plan still stands.
      expect(s.activityId, 'outdoorRun');
      expect(s.lowReadinessAlternative, 'walk');
    });

    test('a planned sport day pre-sets Perform', () {
      expect(
        plannedIntentFor(planOn(2, ['outdoorRun']), tuesday),
        DayIntent.perform,
      );
      // A gentle day leaves the weekday-history rule alone.
      expect(plannedIntentFor(planOn(2, ['bodyScan']), tuesday), isNull);
      expect(plannedIntentFor(WeeklyPlan.empty, tuesday), isNull);
    });

    test('the reminder fires at the usual start time, 18:00 if never done',
        () {
      final history = [
        for (final h in [7, 19, 18])
          did('outdoorRun', DateTime(2026, 11, 3, h)),
      ];
      expect(
        planReminderTimeFor(
          activityId: 'outdoorRun',
          day: DateTime(2026, 11, 10),
          history: history,
        ),
        DateTime(2026, 11, 10, 18),
      );
      expect(
        planReminderTimeFor(
          activityId: 'swimming',
          day: DateTime(2026, 11, 10),
          history: const [],
        ),
        DateTime(2026, 11, 10, kPlanReminderDefaultHour),
      );
    });

    test('at most three a day are planned; doing more is never blocked', () {
      expect(kWeeklyPlanMaxPerDay, 3);
      final rows = [
        for (var i = 1; i <= 5; i++)
          WeeklyPlanRow(
            weekday: 2,
            position: i,
            activityId: 'walk',
            createdAt: DateTime(2026, 11, 10),
          ),
      ];
      // The table's primary key keeps positions unique; the limit is applied
      // when writing a day (setWeeklyPlanDay) and read back as-is here.
      expect(WeeklyPlan.fromRows(rows).forWeekday(2).activityIds.length, 5);
    });
  });

  group('the suggestion changes through the day (bug 45)', () {
    SessionRow did(String activity, DateTime at, {int minutes = 30}) =>
        SessionRow(
          id: '$activity-${at.millisecondsSinceEpoch}',
          category: activityById(activity)?.cat ?? 'mind',
          vyanaActivityType: activity,
          ringSportType: 0,
          startedAt: at,
          endedAt: at.add(Duration(minutes: minutes)),
          phoneLocationEnabled: false,
        );

    final morning = DateTime(2026, 11, 10, 8);
    final afternoon = DateTime(2026, 11, 10, 14);
    final evening = DateTime(2026, 11, 10, 19);
    final state = WellnessState.empty();

    HomeSuggestion at(
      DateTime now, {
      DayIntent intent = DayIntent.recover,
      int? readiness = 70,
      List<String> pins = const [],
      List<SessionRow> history = const [],
      List<SessionRow> today = const [],
    }) =>
        homeSuggestionFor(
          intent: intent,
          state: state,
          readiness: readiness,
          moment: homeMomentAt(now),
          now: now,
          pins: pins,
          history: history,
          todaysFinished: today,
        );

    test('the morning is unchanged: a short practice, 4 minutes or less', () {
      final s = at(morning);
      expect(s.heading, 'Suggested practice');
      expect(s.minutes, lessThanOrEqualTo(kSuggestedMaxMinutes));
      expect(s.setsTarget, isTrue);
    });

    test('the day suggests a pin that fits the intent', () {
      final s = at(
        afternoon,
        intent: DayIntent.perform,
        pins: const ['bodyScan', 'outdoorRun'],
        history: [did('outdoorRun', afternoon.subtract(const Duration(days: 2)), minutes: 32)],
      );
      expect(s.heading, 'Suggested activity');
      // Body Scan is pinned first but is not a Perform practice.
      expect(s.activityId, 'outdoorRun');
      expect(s.meta, 'YOUR USUAL · 32 MIN');
      // Opens with no target set — "your usual" describes, it does not set.
      expect(s.setsTarget, isFalse);
      expect(s.offerPin, isFalse);
      // No 4-minute cap outside the morning.
      expect(s.minutes, 32);
    });

    test('low readiness means gentle only, whatever the chip says', () {
      final s = at(
        afternoon,
        intent: DayIntent.perform,
        readiness: 42,
        pins: const ['outdoorRun', 'walk'],
      );
      expect(s.activityId, 'walk');
    });

    test('a practice already done today is skipped', () {
      final s = at(
        afternoon,
        pins: const ['walk', 'stretching'],
        today: [did('walk', afternoon.subtract(const Duration(hours: 3)))],
      );
      expect(s.activityId, 'stretching');
    });

    test('with no pin that fits, something done before — and "Pin it"', () {
      final s = at(
        afternoon,
        pins: const ['outdoorRun'],
        history: [
          did('swimming', afternoon.subtract(const Duration(days: 1))),
          did('mobility', afternoon.subtract(const Duration(days: 9))),
        ],
      );
      expect(s.activityId, 'swimming');
      expect(s.offerPin, isTrue);
    });

    test('with no history at all, a mindfulness practice at its own length',
        () {
      expect(at(afternoon, intent: DayIntent.recover).activityId, 'bodyScan');
      expect(
        at(afternoon, intent: DayIntent.perform).activityId,
        'hrvBreathing',
      );
      expect(at(afternoon, intent: DayIntent.settle).activityId, 'walkingMed');
      final s = at(afternoon, intent: DayIntent.settle);
      expect(s.offerPin, isTrue);
      expect(s.minutes, activityById('walkingMed')!.dur);
    });

    test('the evening winds down, rotating day by day', () {
      final s = at(evening);
      expect(s.heading, 'Wind down');
      expect(s.reason, 'Helps your body and mind settle before sleep');
      expect(kWindDownRotation, contains(s.activityId));
      expect(s.minutes, activityById(s.activityId)!.dur);
      // Three consecutive evenings are three different practices.
      final ids = {
        for (var d = 0; d < 3; d++)
          windDownFor(DateTime(2026, 11, 10 + d, 19)),
      };
      expect(ids.length, 3);
    });

    test('after 21:00 Lucid Dreaming comes round on alternate nights', () {
      // 2026-11-10 → 20261110, even.
      expect(windDownFor(DateTime(2026, 11, 10, 21, 30)), kLucidDreamingId);
      expect(
        windDownFor(DateTime(2026, 11, 11, 21, 30)),
        isNot(kLucidDreamingId),
      );
      // Before 21:00 it is never suggested — it is a pre-sleep practice.
      expect(
        windDownFor(DateTime(2026, 11, 10, 19)),
        isNot(kLucidDreamingId),
      );
    });

    test('"your usual" is the median of the last five, not the catalogue', () {
      final history = [
        for (final m in [20, 40, 30, 35, 25])
          did('walk', afternoon.subtract(Duration(days: m)), minutes: m),
      ];
      expect(usualMinutesFor('walk', history), 30);
      // Never done it: the catalogue length stands in.
      expect(usualMinutesFor('walk', const []), activityById('walk')!.dur);
    });
  });

  group("Nova's own voice — the only voice", () {
    test('the picker offers Nova, or nothing at all', () {
      // The phone's own text-to-speech used to follow Nova in this list as
      // a fallback. It is gone: flutter_tts is only ever as good as the
      // engine the phone happens to have, and on a phone without Google
      // services that is a flat screen-reader voice. The dApp Store build
      // cannot assume otherwise.
      expect(GuideVoiceOption.nova.isNovaVoice, isTrue);
      expect(GuideVoiceOption.nova.identifier,
          GuideVoiceOption.kNovaIdentifier);
    });

    test('not having the voice says what to do about it', () {
      // Silence that explains itself, rather than a worse voice.
      final message = GuideVoiceService.novaVoiceUnavailableMessage;
      expect(message, isNotEmpty);
      if (novaVoiceConfigured) {
        expect(message, contains(novaVoiceApproxSizeLabel));
      }
    });

    test('the pin names a build sherpa-onnx actually publishes', () {
      // There is no kokoro-v0.19-int8 upstream: v0.19 ships fp32 only, and
      // the int8 builds are the multi-lang packs. Naming a build that does
      // not exist is how a packaging step gets attempted and abandoned.
      expect(kNovaVoiceVersion, 'kokoro-en-v0_19');
      expect(kNovaVoiceModelFile, 'model.onnx');
    });

    test('the install prompt states the real size, in MB', () {
      // 355 MB, not the 90 MB an int8 build would have been. "0.35 GB"
      // reads as a rounding error, so anything under a gigabyte is MB.
      expect(kNovaVoiceApproxBytes, greaterThan(300 * 1024 * 1024));
      expect(novaVoiceApproxSizeLabel, '355 MB');
    });

    test('the voice is only fetched from our own host, by digest', () {
      expect(kNovaVoiceHost, 'cdn.seeknirvana.app');
      expect(novaVoiceConfigured, kNovaVoiceFiles.isNotEmpty);
      for (final asset in kNovaVoiceFiles) {
        final uri = Uri.parse(asset.url);
        expect(uri.scheme, 'https');
        expect(uri.host, kNovaVoiceHost);
        expect(asset.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(asset.bytes, greaterThan(0));
      }
    });
  });

  group('ring screen title (bug 49)', () {
    SavedPranaRing ring({String? deviceType, String? name}) => SavedPranaRing(
          name: name,
          address: 'AA:BB:CC:DD:EE:FF',
          macAddress: null,
          deviceIdentifier: null,
          deviceId: null,
          deviceType: deviceType,
          rssi: null,
          batteryPower: 80,
          batteryStatus: 'normal',
          firmwareVersion: null,
          lastSeenAt: null,
          lastConnectedAt: null,
        );

    test('the SDK device category is never shown as a model', () {
      // What this SDK actually reports — it made the title "Ring ring".
      expect(ring(deviceType: 'Ring').modelName, 'PRANA');
      expect(ring(deviceType: 'SmartRing').modelName, 'PRANA');
      expect(ring(deviceType: null).modelName, 'PRANA');
      // A rename is not a model either.
      expect(ring(name: 'LEENA 03BE').modelName, 'PRANA');
    });

    test('a model we ship is used as-is', () {
      expect(kRingModels, contains('PRANA'));
      expect(ring(deviceType: 'PRANA').modelName, 'PRANA');
      expect(ring(deviceType: 'prana').modelName, 'PRANA');
    });

    test('the raw type is kept for Diagnostics', () {
      expect(ring(deviceType: 'Ring').rawDeviceType, 'Ring');
      expect(ring(deviceType: null).rawDeviceType, isNull);
    });
  });

  group('the ring on its charger (bug 43)', () {
    test('the SDK statuses that mean charging', () {
      for (final raw in ['2', 'charging', 'charge', 'CHARGING']) {
        expect(normalizedBatteryStatus(raw), 'charging', reason: raw);
      }
      expect(normalizedBatteryStatus('0'), 'normal');
      expect(normalizedBatteryStatus('full'), 'full');
      expect(normalizedBatteryStatus(null), '-');
    });

    test('charging survives the trip to the service isolate', () {
      final charging = RingAlertSnapshot.fromJson(
        RingAlertSnapshot(
          at: DateTime.now(),
          hasRingContext: true,
          paired: true,
          connected: false,
          batteryPercent: 8,
          batteryReadAt: DateTime.now(),
          lastSyncedAt: DateTime.now(),
          lastConnectionConfirmedAt: DateTime.now(),
          restingHr: null,
          spo2: null,
          hrBandLow: 50,
          hrBandHigh: 80,
          charging: true,
        ).toJson(),
      )!;
      // 8% and out of reach, but on the charger on purpose — neither the
      // low-battery nor the two-hour offline alert has anything to say.
      expect(charging.charging, isTrue);
    });
  });

  group('glucose is an estimate, not a test (bug 39)', () {
    test('the range is the typical day, not the fasting window', () {
      expect(kGlucoseRange.low, 4.0);
      expect(kGlucoseRange.high, 7.8);
      expect(kGlucoseRange.caption, 'TYPICAL 4–7.8 MMOL/L · RING ESTIMATE');
      expect(kGlucoseRange.caption, isNot(contains('FASTING')));
    });

    test('no verdict colour, in range or out', () {
      for (final value in [3.2, 4.0, 5.4, 7.8, 11.0]) {
        expect(
          vitalVerdict(
            kind: VitalsMetricKind.glucose,
            range: kGlucoseRange,
            value: value,
          ).quality,
          'level',
          reason: '$value mmol/L must be grey',
        );
      }
    });
  });

  group('background ring alerts (bug 44)', () {
    RingAlertSnapshot snap({
      int? battery,
      Duration batteryAge = Duration.zero,
      bool connected = true,
      bool charging = false,
    }) =>
        RingAlertSnapshot(
          charging: charging,
          at: DateTime.now(),
          hasRingContext: true,
          paired: true,
          connected: connected,
          batteryPercent: battery,
          batteryReadAt:
              battery == null ? null : DateTime.now().subtract(batteryAge),
          lastSyncedAt: DateTime.now(),
          lastConnectionConfirmedAt: DateTime.now(),
          restingHr: null,
          spo2: null,
          hrBandLow: 50,
          hrBandHigh: 80,
        );

    test('a battery reading older than 30 minutes is not a reading', () {
      expect(snap(battery: 12).batteryIsCurrent, isTrue);
      expect(
        snap(battery: 12, batteryAge: const Duration(minutes: 29))
            .batteryIsCurrent,
        isTrue,
      );
      expect(
        snap(battery: 12, batteryAge: const Duration(minutes: 31))
            .batteryIsCurrent,
        isFalse,
      );
      // No reading at all can never stand in for a current one.
      expect(snap().batteryIsCurrent, isFalse);
    });

    test('the snapshot survives a round trip through storage', () {
      final original = snap(battery: 23, connected: false);
      final restored = RingAlertSnapshot.fromJson(original.toJson())!;
      expect(restored.batteryPercent, 23);
      expect(restored.connected, isFalse);
      expect(restored.paired, isTrue);
      expect(restored.hrBandHigh, 80);
      expect(
        restored.batteryReadAt!.millisecondsSinceEpoch,
        original.batteryReadAt!.millisecondsSinceEpoch,
      );
    });

    test('the evening check leaves margin for the night', () {
      // About 10–15% goes overnight, so the floor is well above the old 15%.
      expect(kOvernightBatteryMin, greaterThan(kLowBatteryPercent));
      expect(kOvernightBatteryMin, 30);
      expect(kEveningBatteryCheckFromHour, 19);
      expect(kEveningBatteryCheckToHour, 22);
      expect(kBatteryFreshFor, const Duration(minutes: 30));
    });
  });

  group('a reading from another day (bug 40)', () {
    final today = DateTime(2026, 10, 14); // a Wednesday

    test('the weekday inside a week, the date beyond it', () {
      expect(earlierDayLabel(DateTime(2026, 10, 13), now: today), 'Tue');
      expect(earlierDayLabel(DateTime(2026, 10, 9), now: today), 'Fri');
      // Seven days back is the same weekday name, so it needs the date.
      expect(earlierDayLabel(DateTime(2026, 10, 7), now: today), '7 Oct');
      expect(earlierDayLabel(DateTime(2026, 9, 28), now: today), '28 Sep');
    });
  });

  group('period end prompt (bug 34)', () {
    CycleDayRow day(int d, {bool confirmed = false}) => CycleDayRow(
          day: DateTime(2026, 10, d),
          endConfirmed: confirmed,
          createdAt: DateTime(2026, 10, d),
        );
    // Two days past the run's last day, so the question is due.
    final today = DateTime(2026, 10, 14);

    test('the question names a day the run can be confirmed on', () {
      // Started on the 7th, corrected back to the 6th in the calendar and
      // logged through the 11th. The assumed length alone would propose the
      // 10th — a day inside the run, which could never finish it.
      final rows = [for (var d = 6; d <= 11; d++) day(d)];
      final status = cycleStatusFrom(rows, now: today);
      expect(status.runs.first.start, DateTime(2026, 10, 6));
      expect(status.runs.first.end, DateTime(2026, 10, 11));
      expect(status.proposedEnd, DateTime(2026, 10, 11));
      expect(status.shouldAskEnd, isTrue);
    });

    test("confirming the run's last day ends the question for good", () {
      // What Done in the calendar (and Yes on the prompt) now writes.
      final rows = [
        for (var d = 6; d <= 10; d++) day(d),
        day(11, confirmed: true),
      ];
      final status = cycleStatusFrom(rows, now: today);
      expect(status.runs.first.endConfirmed, isTrue);
      expect(status.proposedEnd, isNull);
      expect(status.shouldAskEnd, isFalse);
      // And the real length is recorded, not the assumed five days.
      expect(status.averagePeriodLength, 6);
    });

    test('a run still reaching today is never asked about', () {
      final rows = [for (var d = 12; d <= 14; d++) day(d)];
      final status = cycleStatusFrom(rows, now: today);
      expect(status.periodInProgress, isTrue);
      expect(status.shouldAskEnd, isFalse);
    });
  });

  group('Ring data — the two intervals on one screen', () {
    // Sync and Health monitoring looked like the same setting and were not.
    // Merged, the subtitle has to say which battery each one spends.
    test('both intervals read as a pair', () {
      expect(
        ringDataSubtitle(
          supportsMonitoring: true,
          monitoringOn: true,
          monitoringMinutes: 30,
          collectMinutes: 20,
          background: false,
        ),
        'Ring measures every 30 min · Vyana collects every 20 min',
      );
    });

    test('monitoring off says so rather than dropping the ring half', () {
      expect(
        ringDataSubtitle(
          supportsMonitoring: true,
          monitoringOn: false,
          monitoringMinutes: 30,
          collectMinutes: 20,
          background: false,
        ),
        'Ring not measuring · Vyana collects every 20 min',
      );
    });

    test('a ring without monitoring shows only the half it has', () {
      expect(
        ringDataSubtitle(
          supportsMonitoring: false,
          monitoringOn: false,
          monitoringMinutes: 30,
          collectMinutes: 20,
          background: false,
        ),
        'Vyana collects every 20 min',
      );
    });

    test('the background service is named on the row, not hidden', () {
      expect(
        ringDataSubtitle(
          supportsMonitoring: true,
          monitoringOn: true,
          monitoringMinutes: 5,
          collectMinutes: 60,
          background: true,
        ),
        'Ring measures every 5 min · Vyana collects every 60 min · '
        'in the background',
      );
    });

    test('each side keeps its own range — they are different devices', () {
      expect(clampHealthMonitoringInterval(0), kHealthMonitoringMinInterval);
      expect(clampHealthMonitoringInterval(999), kHealthMonitoringMaxInterval);
      expect(
        clampPeriodicSyncIntervalMinutes(0),
        kPeriodicSyncMinIntervalMinutes,
      );
      expect(
        clampPeriodicSyncIntervalMinutes(999),
        kPeriodicSyncMaxIntervalMinutes,
      );
    });
  });

  group('ring setup is remembered per ring, not per phone', () {
    SavedPranaRing ring({
      String? mac,
      String? deviceId,
      String? identifier,
      String? address,
    }) =>
        SavedPranaRing(
          name: 'PRANA',
          address: address,
          macAddress: mac,
          deviceIdentifier: identifier,
          deviceId: deviceId,
          deviceType: null,
          rssi: null,
          batteryPower: null,
          batteryStatus: null,
          firmwareVersion: null,
          lastSeenAt: null,
          lastConnectedAt: null,
        );

    test('the same ring keys the same however the MAC is punctuated', () {
      expect(
        ring(mac: 'AA:BB:CC:DD:0C:4A').identityKey,
        ring(mac: 'aabbccdd0c4a').identityKey,
      );
    });

    test('two rings never share a key', () {
      expect(
        ring(mac: 'AA:BB:CC:DD:0C:4A').identityKey,
        isNot(ring(mac: 'AA:BB:CC:DD:1F:9E').identityKey),
      );
    });

    test('the MAC wins over the per-session address', () {
      // iOS hands out a fresh `address` each pairing; keying on it would
      // treat one ring as a new ring every time.
      final first = ring(mac: 'AABBCCDD0C4A', address: 'session-1');
      final second = ring(mac: 'AABBCCDD0C4A', address: 'session-2');
      expect(first.identityKey, second.identityKey);
    });

    test('a ring with no durable identity has no key', () {
      // Callers must then fall back to asking rather than assume.
      expect(ring().identityKey, isNull);
      expect(ring(mac: '  ').identityKey, isNull);
    });

    test('identity falls back through the fields the SDK may fill', () {
      expect(ring(deviceId: 'DEV-7').identityKey, 'DEV7');
      expect(ring(identifier: 'id-9').identityKey, 'ID9');
      expect(ring(address: 'addr-3').identityKey, 'ADDR3');
    });
  });

  group('signal strength tells the truth about not knowing', () {
    test('a real reading is a negative number', () {
      expect(usableRssi(-55), -55);
      expect(usableRssi(-91), -91);
    });

    test('0 is the SDK saying "already connected", not a perfect signal', () {
      // YcProductPluginDevice writes rssiValue: 0 on the connected-device
      // event. Taken at face value it is the strongest possible reading.
      expect(usableRssi(0), isNull);
      expect(rssiDisplayText(0), '—');
    });

    test('-999 is our own "the SDK gave us nothing"', () {
      expect(usableRssi(-999), isNull);
      expect(signalWord(-999), isNull);
    });

    test('an unknown signal is never called Weak', () {
      // The bug: -999 is below every threshold, so every ring the SDK
      // withheld an RSSI for was listed as a weak one.
      expect(signalWord(null), isNull);
      expect(signalWord(0), isNull);
      expect(signalWord(-60), 'Strong');
      expect(signalWord(-70), 'Strong');
      expect(signalWord(-71), 'Weak');
    });

    test('a connected ring keeps the reading taken when it was scanned', () {
      SavedPranaRing withRssi(int? rssi) => SavedPranaRing(
            name: 'PRANA',
            address: null,
            macAddress: 'AABBCCDD0C4A',
            deviceIdentifier: null,
            deviceId: null,
            deviceType: null,
            rssi: rssi,
            batteryPower: null,
            batteryStatus: null,
            firmwareVersion: null,
            lastSeenAt: null,
            lastConnectedAt: null,
          );
      final scanned = withRssi(-58);
      // What the connected-device event carries.
      final connected = SavedPranaRing.fromDevice(
        {'macAddress': 'AABBCCDD0C4A', 'rssiValue': 0},
        previous: scanned,
      );
      expect(connected.rssi, -58);
      expect(rssiDisplayText(connected.rssi), '-58 dBm');
    });
  });


  group('where Nova thinks', () {
    group('an address is read for what it is, not what it claims', () {
      test('the phone itself', () {
        expect(reachForHost('localhost'), EndpointReach.onThisPhone);
        expect(reachForHost('127.0.0.1'), EndpointReach.onThisPhone);
        expect(reachForHost('::1'), EndpointReach.onThisPhone);
      });

      test('a machine on your own network', () {
        for (final host in [
          '10.0.0.5',
          '172.16.3.1',
          '172.31.255.254',
          '192.168.1.20',
          '169.254.1.1',
          'my-nas.local',
        ]) {
          expect(reachForHost(host), EndpointReach.onYourNetwork,
              reason: host);
        }
      });

      test('anything else leaves your network', () {
        for (final host in [
          'example.com',
          '8.8.8.8',
          '172.32.0.1', // just outside the private block
          '172.15.0.1',
          '11.0.0.1',
        ]) {
          expect(reachForHost(host), EndpointReach.overTheInternet,
              reason: host);
        }
      });

      test('only the private ones are private', () {
        expect(EndpointReach.onThisPhone.isPrivate, isTrue);
        expect(EndpointReach.onYourNetwork.isPrivate, isTrue);
        expect(EndpointReach.overTheInternet.isPrivate, isFalse);
      });
    });

    group('cleartext is allowed close to home and nowhere else', () {
      test('http to the phone or the LAN is fine', () {
        // Ollama and LM Studio serve exactly this; demanding https would
        // make the feature unusable for the people it is for.
        expect(validateEndpoint('http://localhost:11434/v1').host,
            'localhost');
        expect(validateEndpoint('http://192.168.1.20:11434/v1').port, 11434);
      });

      test('http across the internet is refused', () {
        // The conversation carries health figures. In the clear, every hop
        // in between can read them.
        expect(
          () => validateEndpoint('http://example.com/v1'),
          throwsA(isA<EndpointRejected>()),
        );
      });

      test('https is fine anywhere', () {
        expect(validateEndpoint('https://example.com/v1').scheme, 'https');
      });

      test('nonsense is refused before anything is sent', () {
        for (final raw in ['', '   ', 'not a url', 'ftp://host/v1', 'http://']) {
          expect(() => validateEndpoint(raw), throwsA(isA<EndpointRejected>()),
              reason: raw);
        }
      });
    });

    group('the stream is read the way servers actually write it', () {
      test('a delta chunk yields its text', () {
        expect(
          CloudInferenceClient.deltaFromLine(
            'data: {"choices":[{"delta":{"content":"Hel"}}]}',
          ),
          'Hel',
        );
      });

      test('a whole-message chunk is read too', () {
        // A few servers send `message` per chunk rather than `delta`.
        expect(
          CloudInferenceClient.deltaFromLine(
            'data: {"choices":[{"message":{"content":"lo"}}]}',
          ),
          'lo',
        );
      });

      test('the terminator and the keep-alives yield nothing', () {
        expect(CloudInferenceClient.deltaFromLine('data: [DONE]'), isNull);
        expect(CloudInferenceClient.deltaFromLine('data:'), isNull);
        expect(CloudInferenceClient.deltaFromLine(''), isNull);
        expect(CloudInferenceClient.deltaFromLine(': ping'), isNull);
      });

      test('a malformed line never takes the stream down', () {
        // Half a frame is normal at a chunk boundary; throwing here would
        // end a reply mid-sentence.
        expect(CloudInferenceClient.deltaFromLine('data: {"choices":'), isNull);
        expect(CloudInferenceClient.deltaFromLine('data: {}'), isNull);
        expect(
          CloudInferenceClient.deltaFromLine('data: {"choices":[]}'),
          isNull,
        );
      });
    });

    test('an endpoint is only complete with both parts', () {
      expect(CloudEndpoint.empty.isComplete, isFalse);
      expect(
        const CloudEndpoint(baseUrl: 'http://localhost:11434/v1', model: '')
            .isComplete,
        isFalse,
      );
      const full = CloudEndpoint(
        baseUrl: 'http://192.168.1.20:11434/v1',
        model: 'llama3.1:8b',
      );
      expect(full.isComplete, isTrue);
      expect(full.reach, EndpointReach.onYourNetwork);
    });
  });
}
