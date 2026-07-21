import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/wellness/wellness_state.dart';

void main() {
  test('home metrics appear only in morning and night windows', () {
    expect(homeMomentAt(DateTime(2026, 7, 21, 5)), HomeMoment.morning);
    expect(homeMomentAt(DateTime(2026, 7, 21, 11, 59)), HomeMoment.morning);
    expect(homeMomentAt(DateTime(2026, 7, 21, 12)), HomeMoment.day);
    expect(homeMomentAt(DateTime(2026, 7, 21, 18)), HomeMoment.night);
    expect(homeMomentAt(DateTime(2026, 7, 21, 4, 59)), HomeMoment.night);
  });

  test('active minutes use only sessions from the requested day', () {
    int at(int day, int hour) =>
        DateTime(2026, 7, day, hour).millisecondsSinceEpoch ~/ 1000;
    final records = [
      {'startTimeStamp': at(21, 8), 'sportTime': 1800},
      {'startTimeStamp': at(21, 18), 'sportTime': 900},
      {'startTimeStamp': at(20, 18), 'sportTime': 7200},
    ];

    expect(activeMinutesForDay(records, DateTime(2026, 7, 21)), 45);
  });

  test('suggested practice follows current wellness signals', () {
    final tense = WellnessState.from(stressIndex: 72, readinessScore: 82);
    final recovering = WellnessState.from(readinessScore: 42);
    final ready = WellnessState.from(readinessScore: 84);

    expect(suggestedPracticeId(tense, 82, HomeMoment.day), 'breathwork');
    expect(suggestedPracticeId(recovering, 42, HomeMoment.day), 'recovery');
    expect(suggestedPracticeId(ready, 84, HomeMoment.morning), 'sunSalutation');
    expect(suggestedPracticeId(ready, 84, HomeMoment.day), 'walk');
    expect(suggestedPracticeId(ready, 84, HomeMoment.night), 'pranayama');
  });
}
