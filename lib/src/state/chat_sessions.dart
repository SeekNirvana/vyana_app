part of '../../main.dart';

/// Conversations with Nova, kept.
///
/// Until now the chat lived in the chat screen's own `State`. Leaving the
/// screen dropped every word of it — and dropped only the visible half: the
/// model's `InferenceChat` keeps its own history and is not rebuilt on the way
/// back in, so the screen showed a fresh greeting to a model that still
/// remembered the previous conversation. Two records of the same thing, one of
/// them invisible, disagreeing.
///
/// So this does two jobs at once. The conversation is written to the vault as
/// it happens, which is the part that was asked for. And the live conversation
/// now has an explicit beginning and end, which is what the model's history
/// can be held to: [ChatHistoryController.startFresh] clears both together.
///
/// What is deliberately *not* offered is picking a stored conversation back
/// up. The whole context window is 1,024 tokens on Android and 512 on iOS —
/// the system prompt and the DATA block of the user's own numbers come out of
/// that same budget — so replaying a conversation of any length into the model
/// would push out the thing being asked. A reopened conversation is therefore
/// something to read, and says so, rather than a chat that looks live and
/// answers as though the last ten minutes never happened.

/// The longest a generated title runs before it is cut.
const int kChatTitleMaxChars = 68;

/// A conversation in the history list, with enough to draw a row.
@immutable
class StoredChat {
  const StoredChat({
    required this.id,
    required this.personaId,
    required this.title,
    required this.backend,
    required this.modelLabel,
    required this.startedAt,
    required this.updatedAt,
  });

  factory StoredChat.fromRow(ChatSessionRow row) => StoredChat(
        id: row.id,
        personaId: row.personaId,
        title: row.title,
        backend: row.backend,
        modelLabel: row.modelLabel,
        startedAt: row.startedAt,
        updatedAt: row.updatedAt,
      );

  final String id;
  final String personaId;
  final String title;

  /// `device` | `cloud`.
  final String backend;
  final String? modelLabel;
  final DateTime startedAt;
  final DateTime updatedAt;

  /// Who answered, in one short line. The model's name when there is one,
  /// because "which model said this" is the first question about a reply that
  /// reads oddly.
  String get answeredBy {
    final label = modelLabel;
    if (label != null && label.trim().isNotEmpty) return label.trim();
    return backend == 'cloud' ? 'Your own endpoint' : 'On this phone';
  }
}

/// A conversation's title, from the first thing the user said.
///
/// Their own words, cut at a word boundary. Not a summary: summarising would
/// mean another generation, and a list of the questions somebody actually
/// asked is easier to search by eye than a list of paraphrases.
String chatTitleFrom(String firstMessage) {
  final collapsed = firstMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return 'Conversation';
  if (collapsed.length <= kChatTitleMaxChars) return collapsed;
  final cut = collapsed.substring(0, kChatTitleMaxChars);
  final lastSpace = cut.lastIndexOf(' ');
  final stem = lastSpace > kChatTitleMaxChars ~/ 2
      ? cut.substring(0, lastSpace)
      : cut;
  return '${stem.trimRight()}…';
}

/// The live conversation, and the writing of it to the vault.
///
/// Lives as long as the app process, which is also how long the model's own
/// history lives — so the screen and the model agree about where the
/// conversation starts, which they did not before.
class ChatHistoryController extends ChangeNotifier {
  ChatHistoryController(this._db);

  final VyanaDatabase _db;

  final List<GuideMessage> _messages = [];
  String? _sessionId;
  String? _personaId;
  int _ordinal = 0;

  /// Row id of the reply currently arriving, so the finished text lands on
  /// the row the empty bubble came from.
  String? _pendingReplyId;

  /// What the chat screen draws.
  List<GuideMessage> get messages => List.unmodifiable(_messages);

  /// The stored row for the live conversation, or null while nothing has been
  /// said in it. The history list uses this to mark the one in progress.
  String? get liveSessionId => _sessionId;

  /// Whether anything beyond the greeting has been said.
  bool get hasConversation => _messages.length > 1;

  /// Opens [personaId]'s conversation, starting it with [starter] when there
  /// is nothing to come back to.
  ///
  /// Called on every build of the chat screen, so it must be idempotent and
  /// must not notify when nothing changed — the alternative is a rebuild loop.
  void resume({required String personaId, required String starter}) {
    if (_personaId == personaId && _messages.isNotEmpty) return;
    _personaId = personaId;
    _sessionId = null;
    _ordinal = 0;
    _pendingReplyId = null;
    _messages
      ..clear()
      ..add(GuideMessage(fromUser: false, text: starter));
    // Called from build; the listeners are mid-frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Ends the live conversation and begins one the model has no memory of
  /// either. Both halves matter: clearing only the screen would leave the
  /// model answering from a conversation nobody can see any more.
  Future<void> startFresh({
    required String personaId,
    required String starter,
    required GuideRuntimeService runtime,
  }) async {
    _personaId = personaId;
    _sessionId = null;
    _ordinal = 0;
    _pendingReplyId = null;
    _messages
      ..clear()
      ..add(GuideMessage(fromUser: false, text: starter));
    notifyListeners();
    await runtime.forgetConversation();
  }

  /// Records what the user said, creating the stored conversation if this is
  /// the first thing in it, and adds the empty bubble the reply streams into.
  ///
  /// Returns the index of that reply bubble.
  Future<int> addUserTurn({
    required String personaId,
    required String text,
    required String backend,
    String? modelLabel,
  }) async {
    final now = DateTime.now();
    _personaId = personaId;

    final replyIndex = _messages.length + 1;
    _messages.add(GuideMessage(fromUser: true, text: text));
    _messages.add(const GuideMessage(fromUser: false, text: ''));
    notifyListeners();

    try {
      var sessionId = _sessionId;
      if (sessionId == null) {
        sessionId = 'chat_${now.microsecondsSinceEpoch}';
        await _db.insertChatSession(
          id: sessionId,
          personaId: personaId,
          title: chatTitleFrom(text),
          backend: backend,
          modelLabel: modelLabel,
          startedAt: now,
        );
        _sessionId = sessionId;
        // The greeting was on screen before the row existed. Store it too, so
        // the transcript reads the way the conversation looked.
        final greeting = _messages.first;
        if (!greeting.fromUser && greeting.text.trim().isNotEmpty) {
          await _writeMessage(
            sessionId: sessionId,
            fromUser: false,
            body: greeting.text,
            at: now,
          );
        }
      } else {
        await _db.touchChatSession(sessionId, at: now);
      }

      await _writeMessage(
        sessionId: sessionId,
        fromUser: true,
        body: text,
        at: now,
      );
      _pendingReplyId = null;
    } on Object catch (error) {
      // A conversation that cannot be written down is still a conversation.
      // The screen keeps working; only the record is lost.
      debugPrint('[ChatHistory] Could not store the question: $error');
    }
    return replyIndex;
  }

  /// Updates the reply bubble as text arrives. In memory only — a token-by-
  /// token write would be hundreds of writes per answer to a row nothing
  /// reads until the conversation is over.
  void updateReply(int index, String text) {
    if (index < 0 || index >= _messages.length) return;
    _messages[index] = GuideMessage(fromUser: false, text: text);
    notifyListeners();
  }

  /// Writes the finished reply, whatever it says.
  ///
  /// Including the apology the screen shows when generation failed: the
  /// transcript is a record of what happened, and a conversation that read as
  /// an unanswered question would be a different and less useful record.
  Future<void> finishReply(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final body = _messages[index].text;
    final sessionId = _sessionId;
    if (sessionId == null || body.trim().isEmpty) return;
    final now = DateTime.now();
    try {
      final pending = _pendingReplyId;
      if (pending != null) {
        await _db.updateChatMessageBody(pending, body);
      } else {
        _pendingReplyId = await _writeMessage(
          sessionId: sessionId,
          fromUser: false,
          body: body,
          at: now,
        );
      }
      await _db.touchChatSession(sessionId, at: now);
    } on Object catch (error) {
      debugPrint('[ChatHistory] Could not store the reply: $error');
    }
    _pendingReplyId = null;
  }

  Future<String> _writeMessage({
    required String sessionId,
    required bool fromUser,
    required String body,
    required DateTime at,
  }) async {
    final ordinal = _ordinal++;
    final id = '${sessionId}_$ordinal';
    await _db.insertChatMessage(
      id: id,
      sessionId: sessionId,
      ordinal: ordinal,
      fromUser: fromUser,
      body: body,
      createdAt: at,
    );
    return id;
  }

  /// Forgets a stored conversation. When it is the live one, the screen is
  /// left alone — deleting the record of what is on screen should not wipe
  /// the screen — but it will be stored afresh from the next message on.
  Future<void> delete(String id) async {
    await _db.deleteChatSession(id);
    if (_sessionId == id) {
      _sessionId = null;
      _ordinal = 0;
      _pendingReplyId = null;
    }
  }

  Future<void> deleteAll() async {
    await _db.deleteAllChatSessions();
    _sessionId = null;
    _ordinal = 0;
    _pendingReplyId = null;
  }
}

/// What the stored conversations occupy, for the footprint screen.
@immutable
class ChatFootprint {
  const ChatFootprint({required this.count, required this.bytes});

  final int count;
  final int bytes;

  bool get isEmpty => count == 0;

  /// "4 conversations · 12 KB" — the count first, because the count is what
  /// somebody is deciding about and the size never amounts to much.
  String get label {
    final plural = count == 1 ? 'conversation' : 'conversations';
    return '$count $plural · ${_size()}';
  }

  String _size() {
    if (bytes < 1024) return '$bytes bytes';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.round()} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// Re-read whenever a conversation is added or removed, so the footprint
/// cannot sit at a number that was true a screen ago.
final chatFootprintProvider = FutureProvider<ChatFootprint>((ref) async {
  final db = ref.watch(databaseProvider);
  final sessions = await ref.watch(storedChatsProvider.future);
  return ChatFootprint(
    count: sessions.length,
    bytes: await db.chatHistoryBytes(),
  );
});

final chatHistoryProvider = ChangeNotifierProvider<ChatHistoryController>(
  (ref) => ChatHistoryController(ref.watch(databaseProvider)),
);

/// Every stored conversation, most recently spoken to first.
final storedChatsProvider = StreamProvider<List<StoredChat>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchChatSessions()
      .map((rows) => rows.map(StoredChat.fromRow).toList(growable: false));
});

/// One stored conversation's turns, for the transcript.
final storedChatTranscriptProvider =
    StreamProvider.family<List<ChatMessageRow>, String>((ref, id) {
  return ref.watch(databaseProvider).watchChatMessagesFor(id);
});
