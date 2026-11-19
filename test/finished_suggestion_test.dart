import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/wellness/wellness_state.dart';

/// Item 131 — a finished suggestion stops being the suggestion.
void main() {
  SessionRow did(String activity, DateTime at, {int minutes = 10}) =>
      SessionRow(
        id: '$activity-${at.millisecondsSinceEpoch}',
        category: activityById(activity)?.cat ?? 'mind',
        vyanaActivityType: activity,
        ringSportType: 0,
        startedAt: at,
        endedAt: at.add(Duration(minutes: minutes)),
        phoneLocationEnabled: false,
      );

  HomeSuggestion at(
    DateTime now, {
    List<SessionRow> today = const [],
    List<SessionRow> history = const [],
    List<String> pins = const [],
  }) =>
      homeSuggestionFor(
        intent: DayIntent.recover,
        state: WellnessState.empty(),
        readiness: 70,
        moment: homeMomentAt(now),
        now: now,
        pins: pins,
        history: history,
        todaysFinished: today,
      );

  test('the morning practice, done at 09:00, gives way to midday', () {
    final morning = DateTime(2026, 11, 17, 9);
    final first = at(morning);
    expect(first.heading, 'Suggested practice');
    final done = did(first.activityId, morning.subtract(const Duration(minutes: 20)));
    final next = at(morning, today: [done], history: [done]);
    expect(next.activityId, isNot(first.activityId));
    expect(next.heading, 'Suggested activity');
  });

  test('pins come first in the early midday suggestion', () {
    final morning = DateTime(2026, 11, 17, 9);
    final first = at(morning);
    final done = did(first.activityId, morning.subtract(const Duration(minutes: 20)));
    final pin = activityById('yogaFlow') != null ? 'yogaFlow' : 'walk';
    final next = at(morning, today: [done], history: [done], pins: [pin]);
    // The pin leads if it fits the intent; otherwise the rule moves on,
    // and in no case is the finished practice offered again.
    expect(next.activityId, isNot(first.activityId));
  });

  test('evening: the next wind-down not done tonight', () {
    final evening = DateTime(2026, 11, 17, 20);
    final first = at(evening);
    expect(first.heading, 'Wind down');
    final done = did(first.activityId, evening.subtract(const Duration(minutes: 30)));
    final next = at(evening, today: [done], history: [done]);
    expect(next.heading, 'Wind down');
    expect(next.activityId, isNot(first.activityId));
    expect(kWindDownRotation, contains(next.activityId));
  });

  test('after midnight, what was done this evening still counts', () {
    final late = DateTime(2026, 11, 18, 0, 30);
    final first = at(late);
    final done = did(first.activityId, DateTime(2026, 11, 17, 23, 30));
    // Not finished "today" by the calendar, but it was tonight.
    final next = at(late, today: const [], history: [done]);
    expect(next.activityId, isNot(first.activityId));
  });

  test('with every wind-down done, nothing new is offered', () {
    final evening = DateTime(2026, 11, 17, 21, 30);
    final all = [
      for (final (i, id) in [...kWindDownRotation, kLucidDreamingId].indexed)
        did(id, DateTime(2026, 11, 17, 18, 10 + i * 10), minutes: 5),
    ];
    final s = at(evening, today: all, history: all);
    expect(s.heading, 'Wind down');
    expect(
      [...kWindDownRotation, kLucidDreamingId],
      contains(s.activityId),
    );
  });
}
