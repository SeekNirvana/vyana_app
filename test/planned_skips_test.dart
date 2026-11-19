import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/planned_skips.dart';

/// Item 94 — standing a planned practice down for today.
///
/// A planned practice stayed on Home until done or 22:00, and the only way
/// to change it was editing My week — which changes it every week. Someone
/// who simply could not run today had the choice of looking at it until
/// the evening or rewriting their week.
///
/// The thing these tests protect is that a skip is about *today*: the
/// question "do I run on Tuesdays" and the question "am I running today"
/// are different, and only the second is being answered.
void main() {
  group('the next practice on offer', () {
    const plan = ['walk', 'yogaFlow', 'bodyScan'];

    test('the first one not done and not skipped', () {
      expect(
        firstUnskippedPlanned(
          plannedIds: plan,
          done: const {},
          skipped: const {},
        ),
        'walk',
      );
    });

    test('skipping one moves to the next', () {
      expect(
        firstUnskippedPlanned(
          plannedIds: plan,
          done: const {},
          skipped: const {'walk'},
        ),
        'yogaFlow',
      );
    });

    test('done and skipped are both passed over', () {
      expect(
        firstUnskippedPlanned(
          plannedIds: plan,
          done: const {'walk'},
          skipped: const {'yogaFlow'},
        ),
        'bodyScan',
      );
    });

    test('a used-up plan gives nothing, so the day falls back', () {
      // Null is what sends Home to the ordinary suggestion for the time of
      // day, rather than leaving the card showing something declined.
      expect(
        firstUnskippedPlanned(
          plannedIds: plan,
          done: const {'walk'},
          skipped: const {'yogaFlow', 'bodyScan'},
        ),
        isNull,
      );
    });

    test('an empty plan gives nothing', () {
      expect(
        firstUnskippedPlanned(
          plannedIds: const [],
          done: const {},
          skipped: const {},
        ),
        isNull,
      );
    });
  });

  group('a skip belongs to one day', () {
    final today = DateTime(2026, 11, 10);

    test('the key is the date, so yesterday expires by not being read', () {
      expect(plannedSkipKeyFor(today), 'vyana.plan.skipped.2026-11-10');
      expect(
        plannedSkipKeyFor(DateTime(2026, 1, 2)),
        'vyana.plan.skipped.2026-01-02',
      );
    });

    test('it holds today and not tomorrow', () {
      final skips = PlannedSkips.none(today).plus('walk');
      expect(skips.holds('walk'), isTrue);
      expect(skips.appliesOn(DateTime(2026, 11, 10, 23, 59)), isTrue);
      // The app can be left open across midnight: a skip made at 23:50
      // must not still be holding at 00:10.
      expect(skips.appliesOn(DateTime(2026, 11, 11, 0, 10)), isFalse);
    });

    test('undo takes it back', () {
      final skips = PlannedSkips.none(today).plus('walk').plus('yogaFlow');
      final after = skips.minus('walk');
      expect(after.holds('walk'), isFalse);
      expect(after.holds('yogaFlow'), isTrue);
    });

    test('skipping twice is still one skip', () {
      final skips = PlannedSkips.none(today).plus('walk').plus('walk');
      expect(skips.activityIds, {'walk'});
    });

    test('a day with no skips holds nothing', () {
      expect(PlannedSkips.none(today).activityIds, isEmpty);
      expect(PlannedSkips.none(today).holds('walk'), isFalse);
    });
  });

  group('Nova is told', () {
    test('a skipped practice reads as skipped, not as ignored', () {
      expect(plannedSkippedPhrase('Walk'), 'Walk (skipped today)');
    });
  });

  group('item 103: the screens read the skips themselves', () {
    final day = DateTime(2026, 11, 17);
    test('today they are what was skipped', () {
      final skips = PlannedSkips(day: day, activityIds: {'walk'});
      expect(skips.skippedOn(DateTime(2026, 11, 17, 18)), {'walk'});
    });

    test('tomorrow they are nothing', () {
      final skips = PlannedSkips(day: day, activityIds: {'walk'});
      expect(skips.skippedOn(DateTime(2026, 11, 18, 0, 10)), isEmpty);
    });

    test('Home and Practice watch the state, not the notifier', () {
      for (final path in [
        'lib/src/screens/home_screen.dart',
        'lib/src/screens/practice_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('plannedSkipsProvider.notifier).today')));
        expect(source, contains('ref.watch(plannedSkipsProvider)'));
      }
    });

    test('the reminder passes over a practice skipped today', () {
      final source = File('lib/src/state/weekly_plan.dart').readAsStringSync();
      expect(source, contains('...skippedToday'));
    });
  });
}
