part of '../../main.dart';

/// Guides — on-device LLM chat. Persona replies are generated fully on-device by
/// [GuideRuntimeService] (flutter_gemma / Gemma E2B). Chat is gated until the
/// shared model bundle is downloaded; voice prompts use the offline Vani Voice
/// speech model. Switch among installed personas; "+" opens the library.
class GuidesScreen extends ConsumerStatefulWidget {
  const GuidesScreen({super.key});

  @override
  ConsumerState<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends ConsumerState<GuidesScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<GuideMessage> _messages = [];
  bool _sending = false;
  String? _greetedFor;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ensureGreeting(GuidePersona guide) {
    if (_greetedFor == guide.id) return;
    _greetedFor = guide.id;
    _messages
      ..clear()
      ..add(GuideMessage(
        fromUser: false,
        text: guideDefinitionFor(guide).starterMessage,
      ));
  }

  Future<void> _send(GuidePersona guide, {String? text}) async {
    final prompt = (text ?? _input.text).trim();
    if (prompt.isEmpty || _sending) return;

    final kind = guideKindForPersona(guide);
    final runtime = ref.read(guideRuntimeServiceProvider);
    final manager = ref.read(guideModelManagerProvider);
    final voice = ref.read(guideVoiceServiceProvider);

    // user bubble + empty guide bubble (rendered as a typing indicator).
    final replyIndex = _messages.length + 1;
    setState(() {
      _messages.add(GuideMessage(fromUser: true, text: prompt));
      _messages.add(const GuideMessage(fromUser: false, text: ''));
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      if (manager.streamingEnabled) {
        var spokenUpTo = 0;
        final sentenceEnd = RegExp(r'[.!?]\s+');
        await for (final partial
            in runtime.streamResponse(guide: kind, prompt: prompt)) {
          if (!mounted) return;
          setState(() => _messages[replyIndex] =
              GuideMessage(fromUser: false, text: partial));
          if (voice.voiceResponsesEnabled) {
            final unspoken = partial.substring(spokenUpTo);
            final matches = sentenceEnd.allMatches(unspoken);
            if (matches.isNotEmpty) {
              final speakable = stripGuideMarkdown(
                unspoken.substring(0, matches.last.end).trim(),
              );
              if (speakable.isNotEmpty) {
                spokenUpTo += matches.last.end;
                voice.queueSpeak(speakable);
              }
            }
          }
          _scrollToEnd();
        }
        if (voice.voiceResponsesEnabled) {
          final remaining = stripGuideMarkdown(
            _messages[replyIndex].text.substring(spokenUpTo).trim(),
          );
          if (remaining.isNotEmpty) voice.queueSpeak(remaining);
        }
      } else {
        final reply =
            await runtime.generateResponse(guide: kind, prompt: prompt);
        if (!mounted) return;
        setState(() => _messages[replyIndex] =
            GuideMessage(fromUser: false, text: reply));
        if (voice.voiceResponsesEnabled && reply.trim().isNotEmpty) {
          unawaited(voice.speak(stripGuideMarkdown(reply)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages[replyIndex] = GuideMessage(
            fromUser: false,
            text: 'I couldn\'t finish that just now. Please try again.\n\n($e)',
          ));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _onVoice(GuidePersona guide) async {
    final voice = ref.read(guideVoiceServiceProvider);

    try {
      if (voice.isRecording) {
        final transcript = await voice.stopRecordingAndTranscribe();
        if (transcript.trim().isNotEmpty) {
          await _send(guide, text: transcript.trim());
        }
      } else {
        if (!voice.whisperModelReady && !voice.isPreparingWhisperModel) {
          unawaited(voice.preloadWhisperModel());
        }
        await voice.startRecording();
      }
    } catch (e) {
      if (!mounted) return;
      final message = voice.lastError ?? e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Voice error: $message')));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final manager = ref.watch(guideModelManagerProvider);
    final voice = ref.watch(guideVoiceServiceProvider);
    final installed = ref.watch(installedGuidesProvider);
    final activeId = ref.watch(activeGuideIdProvider);
    final guide = guideById(activeId) ?? kActiveGuides.first;
    final ac = t.vit(guide.accent);
    final modelReady = manager.modelReady;
    _ensureGreeting(guide);

    final installedGuides = [
      ...kActiveGuides,
      ...kGuideStore,
    ].where((g) => installed.contains(g.id)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: VAppBar(
            title: guide.name,
            sub: 'on-device · ${guide.role}',
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: VyanaIcon(guide.icon, size: 21, color: ac)),
            ),
            actions: [
              if (modelReady)
                IconBtn(
                  icon: 'settings',
                  onTap: () => openGuidePersonaSettings(context, guide),
                ),
              if (modelReady)
                IconBtn(
                  icon: 'speaker',
                  active: voice.voiceResponsesEnabled,
                  onTap: () => voice
                      .setVoiceResponsesEnabled(!voice.voiceResponsesEnabled),
                ),
              IconBtn(icon: 'plus', onTap: () => openGuideStore(context)),
            ],
          ),
        ),
        if (modelReady && installedGuides.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final g in installedGuides)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pill(
                      label: g.name,
                      icon: g.icon,
                      active: g.id == activeId,
                      accent: t.vit(g.accent),
                      onTap: () =>
                          ref.read(activeGuideIdProvider.notifier).state = g.id,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: modelReady
              ? _buildChat(guide, ac)
              : _GuideDownloadGate(guide: guide),
        ),
        if (modelReady)
          _Composer(
            controller: _input,
            accent: ac,
            sending: _sending,
            recording: voice.isRecording,
            transcribing: voice.isTranscribing,
            voiceReady: true,
            onSend: () => _send(guide),
            onVoice: () => _onVoice(guide),
          ),
      ],
    );
  }

  Widget _buildChat(GuidePersona guide, Color ac) {
    final showQuickPrompts = _messages.length <= 1 && !_sending;
    final quickPrompts = guideDefinitionFor(guide).quickPrompts;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length + (showQuickPrompts ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _messages.length) {
          return _QuickPrompts(
            prompts: quickPrompts,
            accent: ac,
            onTap: (p) => _send(guide, text: p),
          );
        }
        final m = _messages[i];
        final pending = !m.fromUser && m.text.isEmpty;
        return _Bubble(
          fromUser: m.fromUser,
          accent: ac,
          text: pending ? '…' : m.text,
        );
      },
    );
  }
}

/// Model-not-downloaded state shown inside the chat tab. Lets the user pull the
/// shared guide model without leaving the screen, with live progress.
class _GuideDownloadGate extends ConsumerWidget {
  const _GuideDownloadGate({required this.guide});
  final GuidePersona guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ac = t.vit(guide.accent);
    final manager = ref.watch(guideModelManagerProvider);
    final kind = guideKindForPersona(guide);
    final state = manager.stateFor(kind);
    final downloading = manager.downloadingState;
    final isDownloading = downloading != null;
    final failed = state.status == GuideModelStatus.failed;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(child: VyanaIcon(guide.icon, size: 34, color: ac)),
          ),
          const SizedBox(height: 16),
          Text('Bring ${guide.name} on-device',
              textAlign: TextAlign.center,
              style: VyanaType.titleSerif.copyWith(color: t.text)),
          const SizedBox(height: 8),
          Text(
            guideDefinitionFor(guide).shortDescription,
            textAlign: TextAlign.center,
            style: VyanaType.body.copyWith(color: t.textSec, height: 1.5),
          ),
          const SizedBox(height: 18),
          Panel(
            pad: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VyanaIcon('db', size: 18, color: t.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Gemma E2B · runs fully on your phone',
                          style:
                              VyanaType.label.copyWith(color: t.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'One private model powers every guide. Download it once and '
                  'all your guides work offline — no account, no servers.',
                  style:
                      VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
                ),
                const SizedBox(height: 14),
                if (isDownloading)
                  _ProgressBlock(
                    progress: downloading.progress,
                    accent: ac,
                    label: downloading.status == GuideModelStatus.verifying
                        ? 'Verifying…'
                        : 'Downloading the guide model…',
                  )
                else ...[
                  Cta(
                    label: failed ? 'Retry download' : 'Download guide model',
                    icon: 'download',
                    onTap: () => manager.downloadModel(kind),
                  ),
                  if (failed && state.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(state.errorMessage!,
                        style:
                            VyanaType.mono10.copyWith(color: t.vit('hr'))),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => openGuideStore(context),
            child: Text('Browse the full guide library',
                style: VyanaType.label.copyWith(color: t.green)),
          ),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.progress,
    required this.accent,
    required this.label,
  });
  final double progress;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
            minHeight: 8,
            backgroundColor: t.border,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progress > 0
              ? '$label ${(progress * 100).clamp(0, 100).round()}%'
              : label,
          style: VyanaType.mono10.copyWith(color: t.textMuted),
        ),
      ],
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({
    required this.prompts,
    required this.accent,
    required this.onTap,
  });
  final List<String> prompts;
  final Color accent;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRY ASKING',
              style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 8),
          for (final p in prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onTap(p),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      VyanaIcon('sparkles', size: 16, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p,
                            style: VyanaType.bodySm
                                .copyWith(color: t.textSec, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.fromUser, required this.text, required this.accent});
  final bool fromUser;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: fromUser ? accent.withValues(alpha: t.isDark ? 0.2 : 0.13) : t.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
          border: Border.all(color: fromUser ? Colors.transparent : t.border),
        ),
        child: GuideFormattedText(
          text: text,
          style: VyanaType.body.copyWith(color: t.text, height: 1.45),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.accent,
    required this.sending,
    required this.recording,
    required this.transcribing,
    required this.voiceReady,
    required this.onSend,
    required this.onVoice,
  });

  final TextEditingController controller;
  final Color accent;
  final bool sending;
  final bool recording;
  final bool transcribing;
  final bool voiceReady;
  final VoidCallback onSend;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final micColor = recording ? t.vit('hr') : (voiceReady ? accent : t.textSec);
    // The shell uses extendBody:true, so this composer sits behind the floating
    // tab bar. Pad by the bottom inset (tab bar + gesture area) so the input row
    // clears it instead of hiding underneath.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 10),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: t.borderSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recording || transcribing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  VyanaIcon(recording ? 'waveform' : 'refresh',
                      size: 15, color: t.vit('hr')),
                  const SizedBox(width: 8),
                  Text(
                    recording
                        ? 'Listening… tap the mic to send'
                        : 'Transcribing your voice…',
                    style: VyanaType.mono10.copyWith(color: t.textMuted),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: transcribing ? null : onVoice,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recording
                        ? t.vit('hr').withValues(alpha: 0.14)
                        : t.card,
                    border: Border.all(
                        color: recording ? t.vit('hr') : t.border),
                  ),
                  child: Center(
                    child: transcribing
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: t.textSec),
                          )
                        : VyanaIcon(recording ? 'stop' : 'mic',
                            size: 19, color: micColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: t.border),
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !sending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: VyanaType.body.copyWith(color: t.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Ask your guide…',
                      hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: sending ? null : onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.7)]),
                  ),
                  child: Center(
                    child: sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const VyanaIcon('send', size: 19, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
