import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/ai_backend_service.dart';

/// Item 69 — what Nova sends to someone's own server, and what they are
/// told about it.
///
/// Three faults, one theme: the endpoint was trusted with more than it had
/// been granted. It received the DATA block of someone's vitals with none
/// of Nova's instructions, it received the previous server's API key when
/// the address was edited, and the person was never told any of it was
/// leaving the phone.
void main() {
  group('what identifies a server', () {
    test('the path and the trailing slash are not part of it', () {
      // Re-saving to change the model must not count as a new server, or
      // every model change would drop the key and re-ask the notice.
      expect(
        endpointOrigin('http://192.168.1.20:11434/v1'),
        endpointOrigin('http://192.168.1.20:11434/v1/'),
      );
      expect(
        endpointOrigin('http://192.168.1.20:11434/v1'),
        endpointOrigin('http://192.168.1.20:11434/'),
      );
    });

    test('the default port is filled in, so the two spellings agree', () {
      expect(endpointOrigin('https://ai.example.com'),
          endpointOrigin('https://ai.example.com:443'));
      expect(endpointOrigin('http://box.local'),
          endpointOrigin('http://box.local:80'));
    });

    test('host case does not make a new server', () {
      expect(endpointOrigin('https://AI.Example.com/v1'),
          endpointOrigin('https://ai.example.com/v1'));
    });

    test('a different port or scheme is a different server', () {
      expect(endpointOrigin('http://box.local:11434'),
          isNot(endpointOrigin('http://box.local:8080')));
      expect(endpointOrigin('http://box.local'),
          isNot(endpointOrigin('https://box.local')));
    });

    test('something that is not an address has no origin', () {
      for (final junk in ['', '   ', 'box.local', 'not a url', '/v1']) {
        expect(endpointOrigin(junk), isNull, reason: 'origin of "$junk"');
      }
    });
  });

  group('an API key does not follow the address', () {
    test('the same server keeps its key', () {
      expect(
        keyTravelsTo(
          from: 'http://192.168.1.20:11434/v1',
          to: 'http://192.168.1.20:11434/v1',
        ),
        isTrue,
      );
      // Changing only the path is the same server.
      expect(
        keyTravelsTo(
          from: 'http://192.168.1.20:11434/v1',
          to: 'http://192.168.1.20:11434/v1/',
        ),
        isTrue,
      );
    });

    test('a new host does not inherit the old key', () {
      // The fault as reported: edit the address, leave the key field empty,
      // and the previous server's secret went to the new host — during the
      // connection test, before anyone could see where it had gone.
      expect(
        keyTravelsTo(
          from: 'https://api.openai.com/v1',
          to: 'http://192.168.1.50:11434/v1',
        ),
        isFalse,
      );
      expect(
        keyTravelsTo(
          from: 'https://api.openai.com/v1',
          to: 'https://not-openai.example.com/v1',
        ),
        isFalse,
      );
    });

    test('a port change is enough to withhold it', () {
      // A different port is a different process, which may be anyone's.
      expect(
        keyTravelsTo(
          from: 'http://box.local:11434/v1',
          to: 'http://box.local:9999/v1',
        ),
        isFalse,
      );
    });

    test('an unusable address never inherits a key', () {
      expect(keyTravelsTo(from: '', to: 'https://ai.example.com'), isFalse);
      expect(keyTravelsTo(from: 'https://ai.example.com', to: ''), isFalse);
      // Both unparseable must not come out "equal" on two nulls.
      expect(keyTravelsTo(from: '', to: ''), isFalse);
    });
  });

  group('the notice is owed per server', () {
    test('a server not yet seen is owed one', () {
      expect(
        needsEndpointNotice(baseUrl: 'http://box.local:11434/v1', told: const []),
        isTrue,
      );
    });

    test('a server already agreed to is not asked again', () {
      final told = [endpointOrigin('http://box.local:11434/v1')!];
      expect(
        needsEndpointNotice(baseUrl: 'http://box.local:11434/v1', told: told),
        isFalse,
      );
      // Same server, different path — still agreed.
      expect(
        needsEndpointNotice(baseUrl: 'http://box.local:11434/', told: told),
        isFalse,
      );
    });

    test('agreeing to one server is not agreeing to the next', () {
      final told = [endpointOrigin('http://box.local:11434/v1')!];
      expect(
        needsEndpointNotice(
          baseUrl: 'https://someone-elses-ai.example.com/v1',
          told: told,
        ),
        isTrue,
        reason: 'The data is going somewhere new, so the disclosure is new.',
      );
    });

    test('an unusable address is not a server to warn about', () {
      // Nothing can be sent there, so there is nothing to disclose; the
      // save screen is what rejects it.
      expect(needsEndpointNotice(baseUrl: '', told: const []), isFalse);
    });
  });

  group('the notice says what actually travels', () {
    test('it names the ring data, not just the message', () {
      final body = endpointNoticeBody('http://192.168.1.20:11434/v1');
      // The surprising half is not the question someone typed.
      expect(body, contains('ring data'));
      expect(body, contains('messages'));
      expect(body, contains('192.168.1.20:11434'));
    });

    test('it does not claim the phone is answering', () {
      final body = endpointNoticeBody('https://ai.example.com/v1');
      expect(body, contains('not on this phone'));
    });
  });

  group('the endpoint is sent Nova, not just the question', () {
    test('the system turn comes first', () {
      final messages = endpointMessages(
        prompt: 'How did I sleep?',
        systemPrompt: 'You are Nova.',
      );
      expect(messages.length, 2);
      expect(messages.first['role'], 'system');
      expect(messages.first['content'], 'You are Nova.');
      expect(messages.last['role'], 'user');
      expect(messages.last['content'], 'How did I sleep?');
    });

    test('no system turn is sent when there is nothing to say', () {
      // An empty or blank prompt must not become an empty system message,
      // which some servers reject outright.
      for (final empty in [null, '', '   ', '\n']) {
        final messages =
            endpointMessages(prompt: 'hello', systemPrompt: empty);
        expect(messages.length, 1, reason: 'systemPrompt: "$empty"');
        expect(messages.single['role'], 'user');
      }
    });

    test('the user turn is never dropped or rewritten', () {
      final messages = endpointMessages(prompt: '  keep  my  spacing  ');
      expect(messages.single['content'], '  keep  my  spacing  ');
    });
  });
}
