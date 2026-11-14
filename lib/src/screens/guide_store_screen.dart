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
                            Text('ON-DEVICE GUIDE',
                                style: VyanaType.eyebrow.copyWith(color: t.gold)),
                            Text('Nova',
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
                              'This phone has less than 6 GB of RAM. Nova needs '
                              'more memory to run well on-device — downloads may '
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
                  const SectionHead(eyebrow: 'Guide', title: 'Nova'),
                  if (!modelReady)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Text(
                        'Download the model above and Nova is ready to talk.',
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
                  const SectionHead(
                      eyebrow: 'Speech', title: 'Listening and speaking'),
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
                            // Said whatever the user had chosen, so it was
                            // false for anyone on their own endpoint. The
                            // journal half is true either way; the thinking
                            // half depends on the backend.
                            guideStorePrivacyNote(
                              ref.watch(aiBackendProvider).backend,
                            ),
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
    // Read the model's name from its definition rather than typing it in:
    // this card said "Gemma E2B" regardless of which bundle the build
    // actually points at.
    final definition = guidePersonaDefinitions[kind]!;
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
                    Text('Nova\'s model',
                        style:
                            VyanaType.label.copyWith(color: t.text, fontSize: 15)),
                    Text('${definition.modelLabel} · runs Nova on-device',
                        style: VyanaType.caption.copyWith(color: t.textSec)),
                    Text('On-device LLM · ~$kGuideModelSizeLabel',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'One private model runs Nova. Download it once — inference '
            'happens entirely on your phone, fully offline.',
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
              label: failed ? 'Retry download' : 'Download Nova',
              icon: 'download',
              onTap: () async {
                await manager.downloadModel(kind);
                // Bug 42: the voice arrived in the same step, so pick it up
                // now rather than waiting for a restart.
                await ref.read(guideVoiceServiceProvider).refreshNovaVoice();
              },
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
      title: 'Remove Nova\'s model?',
      message:
          'This frees up storage and disables Nova until you download '
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

/// Listening — the Whisper speech-to-text model. Speaking is a different
/// model entirely ([_NovaVoiceBlock]) and lives in its own card below,
/// because naming them together is what made "I downloaded it and there is
/// no audio" the expected outcome.
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
                    Text('Listening',
                        style: VyanaType.label.copyWith(
                            color: t.text, fontSize: 15)),
                    Text('Whisper · your voice to text, on this phone',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            // This card was called "Vani Voice" and described listening and
            // speaking together, while the button downloaded only Whisper.
            // You installed it, listening started working, and nothing ever
            // spoke — with no way to tell why. They are two models doing
            // opposite jobs and they are two cards now.
            'Speak to Nova instead of typing. Whisper turns your voice into '
            'text on this phone — nothing is sent anywhere.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (preparing)
            _ProgressBlock(
              progress: voice.whisperDownloadProgress,
              accent: t.cyan,
              label: 'Downloading the listening model…',
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
            _NovaVoiceBlock(
              voice: voice,
              previewing: _previewing || voice.isSpeaking,
              onPreview: () => _previewVoice(voice),
              onInstall: () => _installNovaVoice(voice),
            ),
            const SizedBox(height: 12),
            Panel(
              pad: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Speak guide replies aloud',
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                        if (!voice.novaVoiceReady) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Needs Nova's voice installed",
                            style: VyanaType.mono10
                                .copyWith(color: t.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value:
                        voice.voiceResponsesEnabled && voice.novaVoiceReady,
                    activeThumbColor: t.cyan,
                    // Off and untouchable without the voice: there is
                    // nothing left to read the reply aloud with.
                    onChanged: voice.novaVoiceReady
                        ? voice.setVoiceResponsesEnabled
                        : null,
                  ),
                ],
              ),
            ),
          ] else
            Cta(
              label: 'Download listening · 74 MB',
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

  Future<void> _installNovaVoice(GuideVoiceService voice) async {
    await voice.downloadNovaVoiceModel();
    if (!mounted) return;
    if (voice.lastError != null) {
      showVyanaSnackBar(
        context,
        message: voice.lastError!,
        icon: 'alert',
      );
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

/// Nova's voice: install it, hear it, or remove it. There is no picker any
/// more — the phone's own text-to-speech is not offered as an alternative,
/// so this is the whole of the choice.
class _NovaVoiceBlock extends StatelessWidget {
  const _NovaVoiceBlock({
    required this.voice,
    required this.previewing,
    required this.onPreview,
    required this.onInstall,
  });

  final GuideVoiceService voice;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;

    if (voice.isDownloadingNovaVoice) {
      return _ProgressBlock(
        progress: voice.novaVoiceDownloadProgress,
        accent: t.cyan,
        label: "Downloading Nova's voice…",
      );
    }

    if (!voice.novaVoiceAvailableToInstall) {
      return Panel(
        pad: 12,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VyanaIcon('info', size: 18, color: t.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Nova's voice is not available in this build yet. Replies "
                'stay on screen until it is.',
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    if (!voice.novaVoiceReady) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Nova's own voice is a one-time download. Until then her replies "
            "stay on screen — Vyana will not read them in the phone's "
            'built-in voice.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
          ),
          const SizedBox(height: 10),
          Cta(
            label: "Download Nova's voice · ${voice.novaVoiceDownloadSize}",
            icon: 'download',
            onTap: onInstall,
          ),
        ],
      );
    }

    return Panel(
      pad: 12,
      child: Row(
        children: [
          VyanaIcon('checkCircle', size: 18, color: t.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Nova's voice",
                  style: VyanaType.label.copyWith(color: t.text),
                ),
                Text(
                  'Installed · ${voice.novaVoiceDownloadSize}',
                  style: VyanaType.mono10.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: previewing ? null : onPreview,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              previewing ? 'Playing…' : 'Preview',
              style: VyanaType.label.copyWith(color: t.cyan),
            ),
          ),
          TextButton(
            onPressed: () => unawaited(voice.deleteNovaVoiceModel()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Remove',
              style: VyanaType.label.copyWith(color: t.textSec),
            ),
          ),
        ],
      ),
    );
  }
}
