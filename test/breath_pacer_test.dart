import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 130 — the breath pacer is timed from the clock.
void main() {
  const hrv = [5, 0, 5, 0];
  const box = [4, 4, 4, 4];
  const relax = [4, 7, 8, 0];

  Duration s(num seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  test('counts 5, 4, 3, 2, 1 then changes phase', () {
    expect(breathPacerAt(hrv, s(0)).remaining, 5);
    expect(breathPacerAt(hrv, s(0.5)).remaining, 5);
    expect(breathPacerAt(hrv, s(1)).remaining, 4);
    expect(breathPacerAt(hrv, s(4.9)).remaining, 1);
    final out = breathPacerAt(hrv, s(5));
    expect(out.phase, 2);
    expect(out.remaining, 5);
  });

  test('zero-length holds are skipped', () {
    expect(breathPacerAt(hrv, s(7)).phase, 2);
    expect(breathPacerAt(hrv, s(10)).phase, 0);
    expect(breathPacerAt(relax, s(19)).phase, 0);
  });

  test('every phase is counted once, so each gets one cue', () {
    expect(breathPacerAt(box, s(0)).phasesBegun, 1);
    expect(breathPacerAt(box, s(4)).phasesBegun, 2);
    expect(breathPacerAt(box, s(16)).phasesBegun, 5);
    expect(breathPacerAt(hrv, s(10)).phasesBegun, 3);
  });

  test('five minutes in, it has not drifted at all', () {
    // 300 s of 5-in/5-out is exactly 30 breaths: back at the start of an
    // inhale, with 5 seconds to go. Tick counting lost a little on every
    // stalled tick and never got it back.
    final at = breathPacerAt(hrv, s(300));
    expect(at.phase, 0);
    expect(at.remaining, 5);
    expect(at.phasesBegun, 61);
  });

  test('a stall jumps to the right place rather than falling behind', () {
    // Read at 12.4 s after a 2-second stall: where 12.4 s says, not 10.4.
    final at = breathPacerAt(hrv, s(12.4));
    expect(at.phase, 0);
    expect(at.remaining, 3);
  });
}
