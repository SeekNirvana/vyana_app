part of '../../main.dart';

Future<void> openGuideStore(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const GuideStoreScreen()));

/// Guide library. One shared on-device model bundle (Gemma E2B) powers every
/// persona — download it once and all guides work offline. Vani Voice adds the
/// offline speech model for voice prompts. Everything runs on-device.
class GuideStoreScreen extends ConsumerStatefulWidget {
  const GuideStoreScreen({super.key});

  @override
  ConsumerState<GuideStoreScreen> createState() => _GuideStoreScreenState();
}

class _GuideStoreScreenState extends ConsumerState<GuideStoreScreen> {
  late final Future<bool> _lowRamFuture =
      DeviceCapabilityService.instance.isLowRam();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final manager = ref.watch(guideModelManagerProvider);
    final modelReady = manager.modelReady;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: FutureBuilder<bool>(
            future: _lowRamFuture,
            builder: (context, ramSnap) {
              final lowRam = ramSnap.data == true;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBtn(
                          icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GUIDE LIBRARY',
                                style: VyanaType.eyebrow.copyWith(color: t.gold)),
                            Text('Your on-device guides',
                                style:
                                    VyanaType.appBarSerif.copyWith(color: t.text)),
                          ],
                        ),
                      ),
                      if (lowRam) const LowRamBadge(),
                    ],
                  ),
                  if (lowRam) ...[
                    const SizedBox(height: 12),
                    Panel(
                      pad: 14,
                      accent: t.vit('hr'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VyanaIcon('alert', size: 18, color: t.vit('hr')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This phone has less than 6 GB of RAM. On-device '
                              'guides need more memory to run well — downloads may '
                              'finish but responses are likely to be slow, fail, '
                              'or freeze. Use a phone with more RAM for the best '
                              'experience.',
                              style: VyanaType.bodySm
                                  .copyWith(color: t.textSec, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const _GuideModelCard(),
                  const SizedBox(height: 18),
                  const SectionHead(
                      eyebrow: 'Personas', title: 'Choose your guide'),
                  if (!modelReady)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Text(
                        'Download the guide model above to unlock every persona.',
                        style: VyanaType.bodySm
                            .copyWith(color: t.textMuted, height: 1.5),
                      ),
                    ),
                  for (final g in [...kActiveGuides, ...kGuideStore])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _PersonaCard(guide: g),
                    ),
                  const SizedBox(height: 8),
                  const SectionHead(eyebrow: 'Speech', title: 'Vani Voice'),
                  const _VaniVoiceCard(),
                  const SizedBox(height: 14),
                  Panel(
                    pad: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VyanaIcon('lock', size: 18, color: t.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Every guide and voice model runs on-device. Your '
                            'conversations and journal never leave your phone.',
                            style: VyanaType.bodySm
                                .copyWith(color: t.textSec, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The single shared model bundle that powers every guide.
class _GuideModelCard extends ConsumerWidget {
  const _GuideModelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final manager = ref.watch(guideModelManagerProvider);
    final kind = activeGuideKinds.first;
    final downloading = manager.downloadingState;
    final ready = manager.modelReady;
    final failed = manager.stateFor(kind).status == GuideModelStatus.failed;

    return Panel(
      pad: 16,
      grad: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: t.gold.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: VyanaIcon('db', size: 22, color: t.gold)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Guide model',
                        style:
                            VyanaType.label.copyWith(color: t.text, fontSize: 15)),
                    Text('Gemma E2B · powers every guide',
                        style: VyanaType.caption.copyWith(color: t.textSec)),
                    Text('On-device LLM · ~3.1 GB',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'One private model runs all your guides. Download it once — '
            'inference happens entirely on your phone, fully offline.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (downloading != null)
            _ProgressBlock(
              progress: downloading.progress,
              accent: t.gold,
              label: downloading.status == GuideModelStatus.verifying
                  ? 'Verifying…'
                  : 'Downloading…',
            )
          else if (ready)
            Row(
              children: [
                VyanaIcon('checkCircle', size: 18, color: t.green),
                const SizedBox(width: 8),
                Text('Installed',
                    style: VyanaType.label.copyWith(color: t.green)),
                const Spacer(),
                TextButton(
                  onPressed: () => _confirmRemove(context, ref, kind),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Remove',
                      style: VyanaType.label.copyWith(color: t.textSec)),
                ),
              ],
            )
          else ...[
            Cta(
              label: failed ? 'Retry download' : 'Download guide model',
              icon: 'download',
              onTap: () => manager.downloadModel(kind),
            ),
            if (failed && manager.stateFor(kind).errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(manager.stateFor(kind).errorMessage!,
                  style: VyanaType.mono10.copyWith(color: t.vit('hr'))),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, GuideKind kind) async {
    final remove = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Remove guide model?',
      message:
          'This frees up storage and disables all guides until you download '
          'the model again.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (remove == true) {
      await ref.read(guideModelManagerProvider).deleteModel(kind);
    }
  }
}

/// A persona card: unlocked once the shared model is installed.
class _PersonaCard extends ConsumerWidget {
  const _PersonaCard({required this.guide});
  final GuidePersona guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ac = t.vit(guide.accent);
    final modelReady = ref.watch(guideModelReadyProvider);
    final active = ref.watch(activeGuideIdProvider) == guide.id;

    return Panel(
      pad: 14,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: VyanaIcon(guide.icon, size: 22, color: ac)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(guide.name,
                        style: VyanaType.label.copyWith(color: t.text, fontSize: 15)),
                    Text(guide.tagline,
                        style: VyanaType.caption.copyWith(color: t.textSec)),
                    Text(guide.role,
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
              if (!modelReady)
                VyanaIcon('lock', size: 16, color: t.textMuted),
            ],
          ),
          if (modelReady) ...[
            const SizedBox(height: 12),
            if (active)
              Row(
                children: [
                  VyanaIcon('checkCircle', size: 18, color: t.green),
                  const SizedBox(width: 8),
                  Text('Active guide',
                      style: VyanaType.label.copyWith(color: t.green)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        openGuidePersonaSettings(context, guide),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Customize',
                        style: VyanaType.label.copyWith(color: t.textSec)),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Cta(
                      label: 'Work with ${guide.name}',
                      icon: 'sparkles',
                      solid: false,
                      onTap: () {
                        ref.read(activeGuideIdProvider.notifier).state =
                            guide.id;
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: 'settings',
                    size: 44,
                    onTap: () => openGuidePersonaSettings(context, guide),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// Vani Voice — offline Whisper STT plus on-device TTS for spoken replies.
class _VaniVoiceCard extends ConsumerStatefulWidget {
  const _VaniVoiceCard();

  @override
  ConsumerState<_VaniVoiceCard> createState() => _VaniVoiceCardState();
}

class _VaniVoiceCardState extends ConsumerState<_VaniVoiceCard> {
  bool _previewing = false;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final voice = ref.watch(guideVoiceServiceProvider);
    final installed = voice.whisperModelReady;
    final preparing = voice.isPreparingWhisperModel;

    return Panel(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.cyan.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: VyanaIcon('speaker', size: 20, color: t.cyan)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Vani Voice',
                        style: VyanaType.label.copyWith(
                            color: t.text, fontSize: 15)),
                    Text('Offline STT (Whisper) + device TTS voices',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Talk with any guide, fully offline — Whisper transcribes your mic '
            'input on-device. Replies can be spoken with your phone\'s built-in '
            'text-to-speech voices.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (preparing)
            _ProgressBlock(
              progress: voice.whisperDownloadProgress,
              accent: t.cyan,
              label: 'Downloading Vani Voice…',
            )
          else if (installed) ...[
            Row(
              children: [
                VyanaIcon('checkCircle', size: 18, color: t.green),
                const SizedBox(width: 8),
                Text('Installed',
                    style: VyanaType.label.copyWith(color: t.green)),
                const Spacer(),
                TextButton(
                  onPressed: () => voice.deleteWhisperModel(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Remove',
                      style: VyanaType.label.copyWith(color: t.textSec)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _GuideVoicePicker(
              voices: voice.voices,
              selected: voice.selectedVoice,
              previewing: _previewing || voice.isSpeaking,
              onChanged: voice.setSelectedVoice,
              onPreview: () => _previewVoice(voice),
            ),
            const SizedBox(height: 12),
            Panel(
              pad: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Speak guide replies aloud',
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                  ),
                  Switch(
                    value: voice.voiceResponsesEnabled,
                    activeThumbColor: t.cyan,
                    onChanged: voice.setVoiceResponsesEnabled,
                  ),
                ],
              ),
            ),
          ] else
            Cta(
              label: 'Download Vani Voice',
              icon: 'download',
              onTap: () => _download(voice),
            ),
          if (voice.lastError != null && !preparing) ...[
            const SizedBox(height: 10),
            Text(voice.lastError!,
                style: VyanaType.mono10.copyWith(color: t.vit('hr'))),
          ],
        ],
      ),
    );
  }

  Future<void> _download(GuideVoiceService voice) async {
    try {
      await voice.preloadWhisperModel();
    } catch (_) {
      // Surfaced via voice.lastError in the rebuilt card.
    }
  }

  Future<void> _previewVoice(GuideVoiceService voice) async {
    setState(() => _previewing = true);
    try {
      await voice.previewVoice();
    } catch (e) {
      if (!mounted) return;
      showVyanaSnackBar(
        context,
        message: voice.lastError ?? 'Could not play voice preview.',
        icon: 'alert',
      );
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }
}

/// Device TTS voice picker grouped by locale / language.
class _GuideVoicePicker extends StatelessWidget {
  const _GuideVoicePicker({
    required this.voices,
    required this.selected,
    required this.previewing,
    required this.onChanged,
    required this.onPreview,
  });

  final List<GuideVoiceOption> voices;
  final GuideVoiceOption? selected;
  final bool previewing;
  final ValueChanged<GuideVoiceOption?> onChanged;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;

    if (voices.isEmpty) {
      return Text(
        'No device voices found. Install a language pack in system settings.',
        style: VyanaType.bodySm.copyWith(color: t.textMuted, height: 1.45),
      );
    }

    final sorted = [...voices]
      ..sort((a, b) {
        final localeCmp = a.locale.toLowerCase().compareTo(b.locale.toLowerCase());
        if (localeCmp != 0) return localeCmp;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    final selectedOption = selected == null
        ? null
        : sorted.cast<GuideVoiceOption?>().firstWhere(
              (voice) => voice?.stableId == selected!.stableId,
              orElse: () => null,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SPOKEN VOICE',
            style: VyanaType.eyebrow.copyWith(color: t.gold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GuideVoiceOption>(
              isExpanded: true,
              value: selectedOption,
              hint: Text('Choose a voice',
                  style: VyanaType.bodySm.copyWith(color: t.textMuted)),
              dropdownColor: t.card,
              borderRadius: BorderRadius.circular(14),
              icon: VyanaIcon('chevD', size: 16, color: t.textSec),
              style: VyanaType.bodySm.copyWith(color: t.text),
              items: [
                for (final option in sorted)
                  DropdownMenuItem<GuideVoiceOption>(
                    value: option,
                    child: Text(
                      option.label,
                      style: VyanaType.bodySm.copyWith(color: t.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Grouped by locale. The default English voice is pre-selected when '
          'available.',
          style: VyanaType.mono10.copyWith(color: t.textMuted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Cta(
          label: previewing ? 'Playing…' : 'Preview voice',
          icon: 'speaker',
          solid: false,
          onTap: previewing ? null : onPreview,
        ),
      ],
    );
  }
}
