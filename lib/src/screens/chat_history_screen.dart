part of '../../main.dart';

/// Conversations — what was said to Nova, kept to read back.
///
/// Reached from the chat's own app bar, which is where somebody looks for the
/// thing they asked yesterday. Each row is the question they opened with;
/// opening one shows the transcript as it was on screen.
///
/// A transcript is for reading, and says so at the end rather than offering a
/// "continue" that could not work: the model holds 1,024 tokens on Android
/// (512 on iOS) for the system prompt, the user's own numbers, the question
/// and the reply together, so replaying a stored conversation into it would
/// cost the room the next answer needs.
Future<void> openChatHistory(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
  );
}

Future<void> openChatTranscript(BuildContext context, StoredChat chat) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ChatTranscriptScreen(chat: chat)),
  );
}

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final chats = ref.watch(storedChatsProvider).valueOrNull;
    final live = ref.watch(chatHistoryProvider).liveSessionId;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(
                children: [
                  IconBtn(
                      icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text('Conversations',
                        style: VyanaType.appBarSerif.copyWith(color: t.text)),
                  ),
                  if (chats != null && chats.isNotEmpty)
                    IconBtn(
                      icon: 'trash',
                      onTap: () => _clearAll(context, ref, chats.length),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 14),
                child: Text(
                  'Kept on this phone, like everything else.',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
              ),
              // Starting fresh belongs with the list of what came before,
              // and it is the one action that needs the model told as well.
              _NewConversationButton(),
              const SizedBox(height: 16),
              if (chats == null)
                const SizedBox.shrink()
              else if (chats.isEmpty)
                EmptyState(
                  icon: Icons.forum_rounded,
                  text: 'Nothing yet. Ask Nova something and it will be here '
                      'afterwards.',
                )
              else
                for (final chat in chats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _ChatRow(chat: chat, isLive: chat.id == live),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref, int count) async {
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Delete every conversation?',
      message: count == 1
          ? 'The one stored conversation is removed from your vault. This '
              'cannot be undone.'
          : 'All $count stored conversations are removed from your vault. '
              'This cannot be undone.',
      confirmLabel: 'Delete all',
      destructive: true,
    );
    if (confirmed != true) return;
    await ref.read(chatHistoryProvider).deleteAll();
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.isLive});

  final StoredChat chat;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final guide = guideById(chat.personaId);
    final ac = guide == null ? t.green : t.vit(guide.accent);
    return Panel(
      pad: 14,
      onTap: () => openChatTranscript(context, chat),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: VyanaIcon(guide?.icon ?? 'sparkles', size: 20, color: ac),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      VyanaType.label.copyWith(color: t.text, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  isLive
                      ? 'Open now'
                      : '${chatWhenLabel(chat.updatedAt)} · ${chat.answeredBy}',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          VyanaIcon('chevR', size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}

/// When a conversation was last spoken to, in the shape the rest of the app
/// uses: the clock for today and yesterday, the date before that.
String chatWhenLabel(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  final time = '${at.hour.toString().padLeft(2, '0')}'
      ':${at.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return 'Today $time';
  if (diff == 1) return 'Yesterday $time';
  return '${at.day}/${at.month} $time';
}

/// One stored conversation, as it looked on screen.
class ChatTranscriptScreen extends ConsumerWidget {
  const ChatTranscriptScreen({super.key, required this.chat});

  final StoredChat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final guide = guideById(chat.personaId);
    final ac = guide == null ? t.green : t.vit(guide.accent);
    final turns = ref.watch(storedChatTranscriptProvider(chat.id)).valueOrNull;
    final isLive = ref.watch(chatHistoryProvider).liveSessionId == chat.id;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VAppBar(
                  title: guide?.name ?? 'Nova',
                  sub: '${chatWhenLabel(chat.startedAt)} · ${chat.answeredBy}',
                  leading: IconBtn(
                      icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                ),
              ),
              if (turns == null)
                const SizedBox.shrink()
              else ...[
                for (final turn in turns)
                  _Bubble(
                    fromUser: turn.fromUser,
                    accent: ac,
                    text: turn.body,
                  ),
                const SizedBox(height: 10),
                // Where a "continue" button would go, and why there isn't
                // one — except for the conversation that is still open,
                // which she does remember and must not be told she doesn't.
                Text(
                  isLive
                      ? 'This is the conversation open in the chat. Anything '
                          'said there appears here too.'
                      : 'Nova does not remember this conversation — her memory '
                          'is small enough that carrying it back would crowd '
                          'out your next answer. Ask again in the chat to pick '
                          'the thread up.',
                  style:
                      VyanaType.caption.copyWith(color: t.textMuted, height: 1.5),
                ),
                const SizedBox(height: 16),
                Cta(
                  label: 'Delete this conversation',
                  icon: 'trash',
                  solid: false,
                  onTap: () => _delete(context, ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Delete this conversation?',
      message: 'It is removed from your vault. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed != true) return;
    await ref.read(chatHistoryProvider).delete(chat.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Ends the live conversation — on screen and in the model's own history,
/// which is the half that used to carry on regardless.
class _NewConversationButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeGuideIdProvider);
    final guide = guideById(activeId) ?? kActiveGuides.first;
    final live = ref.watch(chatHistoryProvider);
    return Cta(
      label: 'New conversation',
      icon: 'plus',
      solid: false,
      // Dimmed rather than inert when the chat is already empty: a button
      // that looks live and does nothing is the worse of the two.
      disabled: !live.hasConversation,
      onTap: () async {
        await ref.read(chatHistoryProvider).startFresh(
              personaId: guide.id,
              starter: guideDefinitionFor(guide).starterMessage,
              runtime: ref.read(guideRuntimeServiceProvider),
            );
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
