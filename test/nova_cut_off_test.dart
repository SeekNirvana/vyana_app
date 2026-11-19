import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';
import 'package:vyana/src/services/nova_budget.dart';

/// Item 123 — Nova's replies stopping after a few words.
void main() {
  group('the repeat guard', () {
    test('empty and whitespace pieces never count as a repeat', () {
      final guard = NovaRepeatGuard(limit: 4);
      final pieces = ['Hello', '', ' ', '', ' ', '.', ' ', '', 'It', ' '];
      expect(pieces.any(guard.shouldStop), isFalse);
    });

    test('nor do they break a real loop', () {
      final guard = NovaRepeatGuard(limit: 4);
      final pieces = [' Roch', '', ' Roch', ' ', ' Roch', '', ' Roch'];
      expect(pieces.map(guard.shouldStop).toList().last, isTrue);
    });

    test('ordinary text never trips it', () {
      final guard = NovaRepeatGuard(limit: 4);
      final words = 'I hear you clearly. Your current readiness is steady.'
          .split(RegExp(r'(?<= )'));
      expect(words.any(guard.shouldStop), isFalse);
    });
  });

  test('only a finished reply is a whole answer', () {
    expect(NovaReplyEnd.finished.isCutOff, isFalse);
    for (final end in [
      NovaReplyEnd.guard,
      NovaReplyEnd.windowFull,
      NovaReplyEnd.error,
    ]) {
      expect(end.isCutOff, isTrue);
    }
  });

  group('a cut-off reply is not stored as an answer', () {
    late VyanaDatabase db;
    late ChatHistoryController history;

    setUp(() {
      db = VyanaDatabase(NativeDatabase.memory());
      history = ChatHistoryController(db);
      history.resume(personaId: 'nova', starter: 'Hi');
    });
    tearDown(() => db.close());

    Future<List<String>> stored() async {
      final sessionId = history.liveSessionId!;
      final rows = await db.chatMessagesFor(sessionId);
      return [for (final r in rows) r.body];
    }

    test('marked, shown, and left out of the transcript', () async {
      final i = await history.addUserTurn(
        personaId: 'nova',
        text: 'Hey',
        backend: 'device',
      );
      history.updateReply(i, 'Hello. It looks like you');
      history.markCutOff(i, 'Hello. It looks like you');
      await history.finishReply(i);

      expect(history.messages[i].cutOff, isTrue);
      expect(history.messages[i].text, 'Hello. It looks like you');
      expect(await stored(), isNot(contains('Hello. It looks like you')));
    });

    test('Try again answers the same question in the same bubble', () async {
      final i = await history.addUserTurn(
        personaId: 'nova',
        text: 'Hey',
        backend: 'device',
      );
      history.markCutOff(i, 'Hello. It');
      final question = history.resetReply(i);
      expect(question, 'Hey');
      expect(history.messages.length, i + 1);
      history.updateReply(i, 'Hello. It looks like you slept well.');
      await history.finishReply(i);
      final rows = await stored();
      expect(rows.where((b) => b == 'Hey').length, 1);
      expect(rows, contains('Hello. It looks like you slept well.'));
    });
  });
}
