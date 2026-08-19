import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

void main() {
  test('a Pact is secured once the required days are proven', () {
    expect(
      pactStatus(done: 5, required: 5, elapsed: 5, total: 7),
      PactStatus.secured,
    );
    // Still secured even if later days are skipped.
    expect(
      pactStatus(done: 5, required: 5, elapsed: 7, total: 7),
      PactStatus.secured,
    );
  });

  test('a Pact with slack left is on track, without slack it is at risk', () {
    // 4/5 done, 2 nights left for 1 needed day — one spare.
    expect(
      pactStatus(done: 4, required: 5, elapsed: 5, total: 7),
      PactStatus.onTrack,
    );
    // 3/5 done, 2 nights left for 2 needed days — no spare.
    expect(
      pactStatus(done: 3, required: 5, elapsed: 5, total: 7),
      PactStatus.atRisk,
    );
  });

  test('a Pact is missed once the remaining days cannot reach the target', () {
    expect(
      pactStatus(done: 2, required: 5, elapsed: 5, total: 7),
      PactStatus.missed,
    );
    expect(pactStatusLabel(PactStatus.missed), 'Missed');
  });

  test('friends pool splits forfeited stakes among finishers only', () {
    // 5 × $10, 4 finish: each finisher gets their $10 plus $10/4.
    expect(
      pactPoolPayout(stake: 10, participants: 5, finishers: 4),
      12.5,
    );
    // Everyone finishes — everyone simply gets their stake back.
    expect(
      pactPoolPayout(stake: 10, participants: 5, finishers: 5),
      10,
    );
    // Nobody finishes — nothing to pay out, and no division by zero.
    expect(
      pactPoolPayout(stake: 10, participants: 5, finishers: 0),
      0,
    );
  });

  test('the mocked active window matches its day-by-day proof', () {
    final proven =
        PactSeed.activeDays.where((day) => day == true).length;
    final reached =
        PactSeed.activeDays.where((day) => day != null).length;

    expect(proven, PactSeed.activeDone);
    expect(reached, PactSeed.activeElapsed);
    expect(PactSeed.activeDays.length, PactSeed.activeTotal);
  });
}
