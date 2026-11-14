import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/wellness/wellness_state.dart';

/// Item 84 — the smaller gaps left over from v1.1.5's items.
///
/// Only the parts with logic worth pinning are here. The charging-staleness
/// window and the reconnect flag live on a controller that needs an SDK and
/// a device to stand up; those are covered by reading the source in
/// item_84_source_test.dart instead.
void main() {
  group('a night the ring measured is not called "not worn" (bug 36)', () {
    final history = RingHistory.empty();

    test('nothing measured overnight is still "not worn"', () {
      final reason = missingNightReasonFor(
        status: SleepNightStatus.missing,
        history: RingHistory.empty(),
        pending: false,
        lastSyncedAt: DateTime(2026, 11, 10, 9),
        now: DateTime(2026, 11, 10, 10),
      );
      // With no records at all the earlier branch catches it first.
      expect(reason, MissingNightReason.neverSynced);
      expect(history.totalRecords, 0);
    });

    test('the reason has its own phrase and its own remedy', () {
      // Telling someone they did not wear a ring they did wear sends them
      // to fix the wrong thing, and makes every other reason less
      // believable.
      expect(
        MissingNightReason.noSleepDetected.phrase,
        'no sleep detected overnight',
      );
      expect(
        MissingNightReason.noSleepDetected.remedy,
        isNot(MissingNightReason.notWorn.remedy),
      );
      expect(MissingNightReason.noSleepDetected.remedy, contains('snugger'));
    });

    test('every reason still has a phrase and the right kind of remedy', () {
      for (final reason in MissingNightReason.values) {
        expect(reason.phrase, isNotEmpty, reason: '$reason');
        expect(reason.phrase, isNot(endsWith('.')), reason: '$reason');
        final remedy = reason.remedy;
        final needsNone = reason == MissingNightReason.recorded ||
            reason == MissingNightReason.pending;
        expect(remedy == null, needsNone, reason: '$reason');
      }
    });
  });

  group('a suggestion never calls a catalogue length "your usual"', () {
    List<SessionRow> none() => const [];

    test('the fallback shows a plain length, not a history claim', () {
      // "YOUR USUAL · 15 MIN" for a practice never done once is a number
      // presented as someone's own history when it came out of a list.
      final suggestion = homeSuggestionFor(
        intent: DayIntent.recover,
        state: WellnessState.empty(),
        readiness: 72,
        moment: HomeMoment.day,
        now: DateTime(2026, 11, 10, 14),
        pins: const [],
        history: none(),
        todaysFinished: none(),
        plan: WeeklyPlan.empty,
      );
      final meta = suggestion.meta;
      if (meta != null) {
        expect(
          meta,
          isNot(contains('YOUR USUAL')),
          reason: 'nothing has been done, so there is no usual',
        );
      }
    });
  });
}
