import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';

/// Stored conversations: the rows, the cascade, and the title the history
/// list is read by.
void main() {
  group('the vault keeps a conversation', () {
    late VyanaDatabase db;

    setUp(() => db = VyanaDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> seed({
      required String id,
      required String title,
      String backend = 'device',
      String? modelLabel = 'Gemma E2B',
      DateTime? at,
    }) async {
      final when = at ?? DateTime(2026, 11, 14, 9, 30);
      await db.insertChatSession(
        id: id,
        personaId: 'nova',
        title: title,
        backend: backend,
        modelLabel: modelLabel,
        startedAt: when,
      );
      await db.insertChatMessage(
        id: '${id}_0',
        sessionId: id,
        ordinal: 0,
        fromUser: true,
        body: title,
        createdAt: when,
      );
    }

    test('a conversation and its turns come back in order', () async {
      await seed(id: 'chat_1', title: 'Why was my sleep score missing?');
      for (var i = 1; i <= 3; i++) {
        await db.insertChatMessage(
          id: 'chat_1_$i',
          sessionId: 'chat_1',
          ordinal: i,
          fromUser: i.isEven,
          body: 'turn $i',
          createdAt: DateTime(2026, 11, 14, 9, 30 + i),
        );
      }

      final turns = await db.chatMessagesFor('chat_1');
      expect(turns.map((t) => t.ordinal), [0, 1, 2, 3]);
      expect(turns.first.fromUser, isTrue);
      expect(turns.last.body, 'turn 3');
    });

    test('the history list is ordered by the last thing said', () async {
      await seed(
          id: 'older',
          title: 'Older',
          at: DateTime(2026, 11, 12, 8));
      await seed(
          id: 'newer',
          title: 'Newer',
          at: DateTime(2026, 11, 13, 8));

      expect((await db.allChatSessions()).map((s) => s.id), ['newer', 'older']);

      // Saying something in the older one moves it to the top: the list is
      // about when a conversation was last spoken to, not when it began.
      await db.touchChatSession('older', at: DateTime(2026, 11, 14, 8));
      expect((await db.allChatSessions()).map((s) => s.id), ['older', 'newer']);
    });

    test('a reply is written once, when it has finished arriving', () async {
      await seed(id: 'chat_1', title: 'Hello');
      await db.insertChatMessage(
        id: 'chat_1_1',
        sessionId: 'chat_1',
        ordinal: 1,
        fromUser: false,
        body: 'partial',
        createdAt: DateTime(2026, 11, 14, 9, 31),
      );
      await db.updateChatMessageBody('chat_1_1', 'the whole answer');

      final turns = await db.chatMessagesFor('chat_1');
      expect(turns, hasLength(2));
      expect(turns.last.body, 'the whole answer');
    });

    test('deleting a conversation takes its turns with it', () async {
      await seed(id: 'chat_1', title: 'One');
      await seed(id: 'chat_2', title: 'Two');
      expect(await db.chatMessagesCount(), 2);

      await db.deleteChatSession('chat_1');

      expect(await db.chatSessionsCount(), 1);
      // The cascade, not a second delete at the call site — an orphaned turn
      // would be invisible and would still be counted in the footprint.
      expect(await db.chatMessagesCount(), 1);
      expect(await db.chatMessagesFor('chat_1'), isEmpty);
    });

    test('clearing everything leaves no turns behind', () async {
      await seed(id: 'chat_1', title: 'One');
      await seed(id: 'chat_2', title: 'Two');

      await db.deleteAllChatSessions();

      expect(await db.chatSessionsCount(), 0);
      expect(await db.chatMessagesCount(), 0);
      expect(await db.chatHistoryBytes(), 0);
    });

    test('the footprint is the length of what was written', () async {
      expect(await db.chatHistoryBytes(), 0, reason: 'nothing stored yet');
      await seed(id: 'chat_1', title: 'abcde');
      expect(await db.chatHistoryBytes(), 5);
    });

    test('where a conversation was answered is kept with it', () async {
      await seed(
        id: 'chat_1',
        title: 'On my own server',
        backend: 'cloud',
        modelLabel: 'qwen3:8b',
      );
      final row = await db.getChatSession('chat_1');
      expect(row!.backend, 'cloud');
      expect(row.modelLabel, 'qwen3:8b');
    });

    test('a row with no model named still says where it ran', () async {
      await seed(id: 'chat_1', title: 'Untitled', modelLabel: null);
      final row = await db.getChatSession('chat_1');
      expect(row!.modelLabel, isNull);
      expect(row.backend, 'device');
    });
  });

  group('a conversation is titled by the question it opened with', () {
    test('short questions are kept whole', () {
      expect(chatTitleFrom('Why was my sleep score missing?'),
          'Why was my sleep score missing?');
    });

    test('whitespace and newlines collapse', () {
      expect(chatTitleFrom('  Help me\n\n  settle   down '),
          'Help me settle down');
    });

    test('a long question is cut at a word, not mid-word', () {
      final title = chatTitleFrom(
        'I have been waking up at three every night this week and I want to '
        'understand whether it is the late training or something else',
      );
      expect(title.length, lessThanOrEqualTo(kChatTitleMaxChars + 1));
      expect(title, endsWith('…'));
      expect(title, isNot(contains('  ')));
      // The cut lands on a space, so no half word is left standing.
      expect(title.substring(0, title.length - 1), isNot(endsWith(' ')));
      expect('I have been waking up at three every night this week and I want '
          'to understand whether it is the late training or something else',
          startsWith(title.substring(0, title.length - 1)));
    });

    test('an empty question still gets a name', () {
      expect(chatTitleFrom('   '), 'Conversation');
    });

    test('one very long word is cut rather than dropped', () {
      final title = chatTitleFrom('a' * 200);
      expect(title.length, kChatTitleMaxChars + 1);
      expect(title, endsWith('…'));
    });
  });
}
