import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/data/db.dart';

/// Item 128 — typed messages get typed replies; spoken get spoken.
void main() {
  test('the default follows how the message was sent', () {
    expect(novaSpeaksReply(spoken: false), isFalse);
    expect(novaSpeaksReply(spoken: true), isTrue);
  });

  test('the speaker icon overrides either way', () {
    expect(novaSpeaksReply(spoken: false, override: true), isTrue);
    expect(novaSpeaksReply(spoken: true, override: false), isFalse);
  });

  group('in a conversation', () {
    late VyanaDatabase db;
    late ChatHistoryController history;

    setUp(() {
      db = VyanaDatabase(NativeDatabase.memory());
      history = ChatHistoryController(db)
        ..resume(personaId: 'nova', starter: 'Hi');
    });
    tearDown(() => db.close());

    test('typing, the icon turns voice on', () {
      history.noteInput(spoken: false);
      expect(history.repliesAloud, isFalse);
      history.toggleVoice();
      expect(history.repliesAloud, isTrue);
      // And it holds for the rest of the conversation, typed or spoken.
      history.noteInput(spoken: false);
      expect(history.repliesAloud, isTrue);
    });

    test('speaking, the icon turns voice off', () {
      history.noteInput(spoken: true);
      expect(history.repliesAloud, isTrue);
      history.toggleVoice();
      expect(history.repliesAloud, isFalse);
    });

    test('a new conversation starts from the default again', () {
      history
        ..noteInput(spoken: false)
        ..toggleVoice();
      history.resume(personaId: 'other', starter: 'Hi');
      expect(history.voiceOverride, isNull);
      expect(history.repliesAloud, isFalse);
    });
  });
}
