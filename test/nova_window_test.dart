import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/nova_budget.dart';

/// Item 126 — a long conversation makes room instead of running out.
void main() {
  test('a turn that fits with room for the reply is left alone', () {
    expect(
      novaWindowNeedsRoom(used: 900, prompt: 200, window: 2048),
      isFalse,
    );
  });

  test('a turn that leaves under ~400 tokens for the reply makes room', () {
    expect(
      novaWindowNeedsRoom(used: 1500, prompt: 200, window: 2048),
      isTrue,
    );
  });

  test('the fresh session keeps the last few turns that fit', () {
    // Instructions 150, next message with DATA 300, reply 400: 850 fixed.
    final keep = novaTurnsToKeep(
      turnTokens: [300, 300, 300, 300, 300],
      fixedTokens: 850,
      window: 2048,
    );
    expect(keep, 3);
  });

  test('never more than three, however much room there is', () {
    expect(
      novaTurnsToKeep(
        turnTokens: [10, 10, 10, 10, 10],
        fixedTokens: 100,
        window: 2048,
      ),
      kNovaKeepTurns,
    );
  });

  test('a long last turn is dropped rather than overflowing', () {
    expect(
      novaTurnsToKeep(
        turnTokens: [100, 1500],
        fixedTokens: 850,
        window: 1024,
      ),
      0,
    );
  });

  test('an estimate over-counts rather than under', () {
    expect(novaTokenEstimate(''), 0);
    expect(novaTokenEstimate('abcde'), 2);
  });
}
