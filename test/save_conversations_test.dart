import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';

/// Item 127 — keep or delete a conversation, and a setting to stop saving.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VyanaDatabase db;
  late ChatHistoryController history;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = VyanaDatabase(NativeDatabase.memory());
    history = ChatHistoryController(db);
    history.resume(personaId: 'nova', starter: 'Hi');
  });
  tearDown(() => db.close());

  Future<void> say(String text, String reply) async {
    final i = await history.addUserTurn(
      personaId: 'nova',
      text: text,
      backend: 'device',
    );
    history.updateReply(i, reply);
    await history.finishReply(i);
  }

  test('saving is on by default', () async {
    expect(await history.loadSaveConversations(), isTrue);
    await say('Hey', 'Hello.');
    expect((await db.watchChatSessions().first).length, 1);
  });

  test('with saving off, nothing reaches the vault', () async {
    await history.setSaveConversations(false);
    await say('Hey', 'Hello.');
    expect(history.liveSessionId, isNull);
    expect((await db.watchChatSessions().first), isEmpty);
    // The conversation still works on screen.
    expect(history.messages.last.text, 'Hello.');
  });

  test('the setting is remembered', () async {
    await history.setSaveConversations(false);
    final again = ChatHistoryController(db);
    expect(await again.loadSaveConversations(), isFalse);
  });

  test('Delete on ending removes the live conversation only', () async {
    await say('First', 'One.');
    final kept = history.liveSessionId;
    // A second conversation (switching persona starts one without the
    // model, which this test has none of).
    history.resume(personaId: 'other', starter: 'Hi');
    await say('Second', 'Two.');
    await history.discardLive();
    final rows = await db.watchChatSessions().first;
    expect(rows.map((r) => r.id), [kept]);
  });
}
