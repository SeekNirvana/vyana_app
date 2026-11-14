part of '../../main.dart';

/// Whether Nova can answer right now — on the backend the user chose, not
/// on whichever one happens to be installed.
///
/// The Nova pill worked this out for itself and the chat screen worked it
/// out differently, reading `modelReady` alone. With an endpoint configured
/// and tested, the pill said "Ask Nova" and the screen behind it offered a
/// 2.6 GB download instead of a conversation, so the endpoint could be set up
/// and never used. One function, two callers, no room to disagree.
bool novaCanAnswer({
  required AiBackend backend,
  required bool cloudReady,
  required bool localReady,
}) =>
    backend == AiBackend.cloud ? cloudReady : localReady;

/// What the chat's app bar says under Nova's name.
String novaChatSubtitle({
  required AiBackend backend,
  required CloudEndpoint endpoint,
  required String role,
}) {
  if (backend == AiBackend.cloud && endpoint.isComplete) {
    return 'your endpoint · $role';
  }
  return 'on-device · $role';
}

/// The line under the guide store header, which used to promise on-device
/// thinking regardless of what the user had picked.
String guideStorePrivacyNote(AiBackend backend) {
  if (backend == AiBackend.cloud) {
    return 'Nova is thinking on the endpoint you chose. The voice and the '
        'listening model still run here, and your journal never leaves this '
        'phone.';
  }
  return 'Nova and the voice model run on-device. Your conversations and '
      'journal never leave your phone.';
}

/// What the You row says Nova is thinking with.
///
/// Pure, and in one place, because the same answer is needed on the row,
/// in the footprint screen and in Diagnostics — and they used to disagree,
/// all three claiming the on-device model regardless of what was chosen.
String novaThinkingSubtitle({
  required AiBackend backend,
  required CloudEndpoint endpoint,
  required bool localReady,
}) {
  if (backend == AiBackend.cloud) {
    if (!endpoint.isComplete) return 'Endpoint not set up yet';
    return '${endpoint.model} · ${endpoint.reach.summary.toLowerCase()}';
  }
  return localReady
      ? 'On this phone · nothing leaves it'
      : 'Not installed · tap to set up';
}

/// The mono label on the right of that row.
String novaThinkingTrailing({
  required AiBackend backend,
  required CloudEndpoint endpoint,
  required bool localReady,
  required String localStatus,
}) {
  if (backend == AiBackend.cloud) {
    return endpoint.isComplete ? 'ENDPOINT' : 'NOT SET';
  }
  return localReady ? 'ON DEVICE' : localStatus.toUpperCase();
}

Future<void> openAiSetup(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const AiSetupScreen()),
  );
}

/// "Your AI" — where Nova thinks.
///
/// Two answers, and the choice is the whole screen. On this phone is the
/// Gemma bundle, downloaded once. Your own endpoint is anything that speaks
/// the OpenAI chat protocol: Ollama or LM Studio on a laptop, llama.cpp or
/// vLLM on a server the user runs.
///
/// There are deliberately no named providers here. Vyana does not hold a
/// relationship with whoever answers — the user does. What this screen owes
/// them instead is to be exact about where their address points, which is
/// the line under the field.
class AiSetupScreen extends ConsumerStatefulWidget {
  const AiSetupScreen({super.key});

  @override
  ConsumerState<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends ConsumerState<AiSetupScreen> {
  int? _ramMb;
  final _url = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  bool _prefilled = false;
  bool _showKey = false;

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_readRam());
  }

  /// Measured once so a model row can say "this phone has 4 GB" rather than
  /// the screen opening with a warning about a phone nobody mentioned.
  Future<void> _readRam() async {
    final mb = await DeviceCapabilityService.instance.physicalRamMb();
    if (mounted) setState(() => _ramMb = mb);
  }

  void _prefill(CloudEndpoint endpoint) {
    if (_prefilled || !endpoint.isComplete) return;
    _prefilled = true;
    _url.text = endpoint.baseUrl;
    _model.text = endpoint.model;
  }

  Future<void> _save(AiBackendController ai) async {
    final ok = await ai.saveEndpoint(
      baseUrl: _url.text,
      model: _model.text,
      apiKey: _key.text,
    );
    if (!mounted) return;
    if (ok) {
      await ai.setBackend(AiBackend.cloud);
      if (!mounted) return;
      _key.clear();
      showVyanaSnackBar(
        context,
        message: ai.lastSuccess ?? 'Endpoint saved.',
        icon: 'checkCircle',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ai = ref.watch(aiBackendProvider);
    final manager = ref.watch(guideModelManagerProvider);
    _prefill(ai.endpoint);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              Row(
                children: [
                  IconBtn(
                    icon: 'chevL',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOVA',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        Text('Your AI',
                            style: VyanaType.appBarSerif
                                .copyWith(color: t.text)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Nova needs a model to think with. Run one on this phone, or '
                'point her at one you already run yourself.',
                style: VyanaType.caption.copyWith(
                  color: t.textSec,
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),

              _BackendChoice(
                selected: ai.backend == AiBackend.local,
                icon: 'brain',
                title: 'On this phone',
                caption: manager.modelReady
                    ? 'Installed and ready'
                    : 'A $kGuideModelSizeLabel download, then it works offline',
                onTap: () => unawaited(ai.setBackend(AiBackend.local)),
              ),
              const SizedBox(height: 10),
              _BackendChoice(
                selected: ai.backend == AiBackend.cloud,
                icon: 'cloud',
                title: 'Your own endpoint',
                caption: ai.endpoint.isComplete
                    ? '${ai.endpoint.model} · ${ai.endpoint.reach.summary}'
                    : 'Ollama, LM Studio, llama.cpp, vLLM — anything that '
                        'speaks the OpenAI chat protocol',
                onTap: () => unawaited(ai.setBackend(AiBackend.cloud)),
              ),
              const SizedBox(height: 20),

              if (ai.backend == AiBackend.local)
                _LocalBackendPanel(manager: manager, ramMb: _ramMb)
              else
                _EndpointForm(
                  url: _url,
                  model: _model,
                  apiKey: _key,
                  showKey: _showKey,
                  onToggleKey: () => setState(() => _showKey = !_showKey),
                  ai: ai,
                  onSave: () => unawaited(_save(ai)),
                  onForget: () => unawaited(ai.forgetEndpoint()),
                  onChanged: () => setState(() {}),
                ),

              const SizedBox(height: 26),
              Text('Her voice',
                  style: VyanaType.label.copyWith(color: t.text)),
              const SizedBox(height: 3),
              Text(
                'Optional, and separate from thinking. Listening is your '
                'voice becoming text; speaking is hers.',
                style: VyanaType.caption
                    .copyWith(color: t.textSec, height: 1.4),
              ),
              const SizedBox(height: 10),
              const _SpeechRows(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Listening and speaking as two plain rows — the two models, their sizes
/// and their states.
///
/// They used to be one card called "Vani Voice" that named both and
/// downloaded one, which is why installing it produced no audio and no
/// explanation.
class _SpeechRows extends ConsumerWidget {
  const _SpeechRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final voice = ref.watch(guideVoiceServiceProvider);

    return Column(
      children: [
        _SpeechRow(
          icon: 'waveform',
          title: 'Listening',
          detail: 'Whisper · your voice to text',
          state: voice.isPreparingWhisperModel
              ? 'INSTALLING'
              : (voice.whisperModelReady ? 'INSTALLED' : '74 MB'),
          done: voice.whisperModelReady,
          onTap: voice.whisperModelReady
              ? null
              : () => unawaited(voice.preloadWhisperModel()),
        ),
        const SizedBox(height: 8),
        _SpeechRow(
          icon: 'speaker',
          title: 'Speaking',
          detail: voice.novaVoiceAvailableToInstall
              ? 'Kokoro · her own voice'
              : 'Not in this build yet · replies stay on screen',
          state: voice.isDownloadingNovaVoice
              ? 'INSTALLING'
              : (voice.novaVoiceReady
                  ? 'INSTALLED'
                  : (voice.novaVoiceAvailableToInstall
                      ? voice.novaVoiceDownloadSize.toUpperCase()
                      : 'UNAVAILABLE')),
          done: voice.novaVoiceReady,
          onTap: voice.novaVoiceAvailableToInstall && !voice.novaVoiceReady
              ? () => unawaited(voice.downloadNovaVoiceModel())
              : null,
        ),
        if (voice.lastError != null) ...[
          const SizedBox(height: 10),
          Text(
            voice.lastError!,
            style: VyanaType.caption.copyWith(color: t.gold, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _SpeechRow extends StatelessWidget {
  const _SpeechRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.state,
    required this.done,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String detail;
  final String state;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Panel(
        pad: 13,
        child: Row(
          children: [
            VyanaIconBadge(name: icon, color: done ? t.green : t.textSec),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: VyanaType.label.copyWith(color: t.text)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: VyanaType.caption
                          .copyWith(color: t.textSec, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              state,
              style: VyanaType.mono10
                  .copyWith(color: done ? t.green : t.textMuted),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              VyanaIcon('download', size: 15, color: t.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackendChoice extends StatelessWidget {
  const _BackendChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final bool selected;
  final String icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Panel(
        pad: 14,
        accent: selected ? t.heading : null,
        child: Row(
          children: [
            VyanaIconBadge(
              name: icon,
              color: selected ? t.heading : t.textSec,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: VyanaType.label.copyWith(
                      color: t.text,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            VyanaIcon(
              selected ? 'checkCircle' : 'circle',
              size: 19,
              color: selected ? t.green : t.mutedInk,
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2a — which model, then install it here.
///
/// The picker only exists once "on this phone" is chosen, and the install
/// button names what it installs, so there is never a button whose subject
/// is a radio two rows up. The RAM note sits on the row it is about: it
/// used to be a banner above the whole screen, shown even to people running
/// an endpoint, for whom this phone's memory is beside the point.
class _LocalBackendPanel extends ConsumerWidget {
  const _LocalBackendPanel({
    required this.manager,
    required this.ramMb,
  });

  final GuideModelManager manager;
  final int? ramMb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final selected = ref.watch(onDeviceModelProvider);
    final downloading = manager.downloadingState;

    if (downloading != null) {
      final pct = (downloading.progress * 100).clamp(0, 100).round();
      return _ProgressPanel(
        progress: downloading.progress,
        label: downloading.status == GuideModelStatus.verifying
            ? 'Checking the download…'
            : 'Downloading ${selected.label} · $pct%',
      );
    }

    if (manager.modelReady) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel(
            pad: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon('checkCircle', size: 18, color: t.green),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    '${activeOnDeviceModel.label} is installed. Nothing Nova '
                    'is told, and nothing she is shown, leaves this phone.',
                    style: VyanaType.body
                        .copyWith(color: t.textSec, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          BorderedPill(
            label: 'What it uses on disk',
            onTap: () => openNovaFootprint(context),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Which model?', style: VyanaType.label.copyWith(color: t.textSec)),
        const SizedBox(height: 8),
        for (final model in kOnDeviceModels) ...[
          _ModelRow(
            model: model,
            selected: model.id == selected.id,
            ramMb: ramMb,
            onTap: () => unawaited(
              ref.read(onDeviceModelProvider.notifier).select(model),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        Cta(
          label: 'Install ${selected.label} · '
              '${formatDownloadSize(selected.bytes)}',
          icon: 'download',
          onTap: () => unawaited(manager.downloadModel(GuideKind.nova)),
        ),
        const SizedBox(height: 8),
        Text(
          'A one-time download. After it, Nova works with no network at all.',
          style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.4),
        ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.selected,
    required this.ramMb,
    required this.onTap,
  });

  final OnDeviceModel model;
  final bool selected;
  final int? ramMb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final tight = !model.fitsIn(ramMb);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Panel(
        pad: 13,
        accent: selected ? t.heading : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.label,
                    style: VyanaType.label.copyWith(
                      color: t.text,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  formatDownloadSize(model.bytes),
                  style: VyanaType.mono10.copyWith(color: t.textMuted),
                ),
                const SizedBox(width: 10),
                VyanaIcon(
                  selected ? 'checkCircle' : 'circle',
                  size: 18,
                  color: selected ? t.green : t.mutedInk,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              model.blurb,
              style:
                  VyanaType.caption.copyWith(color: t.textSec, height: 1.35),
            ),
            if (tight) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VyanaIcon('alert', size: 14, color: t.gold),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Wants ${(model.wantsRamMb / 1024).round()} GB of '
                      'memory; this phone has '
                      '${((ramMb ?? 0) / 1024).round()} GB. Replies may be '
                      'slow or stop.',
                      style: VyanaType.caption
                          .copyWith(color: t.gold, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progress <= 0 ? null : progress,
            minHeight: 7,
            backgroundColor: t.mutedInk.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(t.heading),
          ),
        ),
        const SizedBox(height: 9),
        Text(label, style: VyanaType.mono10.copyWith(color: t.textSec)),
      ],
    );
  }
}

class _EndpointForm extends StatelessWidget {
  const _EndpointForm({
    required this.url,
    required this.model,
    required this.apiKey,
    required this.showKey,
    required this.onToggleKey,
    required this.ai,
    required this.onSave,
    required this.onForget,
    required this.onChanged,
  });

  final TextEditingController url;
  final TextEditingController model;
  final TextEditingController apiKey;
  final bool showKey;
  final VoidCallback onToggleKey;
  final AiBackendController ai;
  final VoidCallback onSave;
  final VoidCallback onForget;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final typed = url.text.trim();
    final reach = typed.isEmpty
        ? null
        : reachForHost(Uri.tryParse(typed)?.host ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Address', style: VyanaType.label.copyWith(color: t.textSec)),
        const SizedBox(height: 7),
        _FieldBox(
          child: TextField(
            controller: url,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: VyanaType.body.copyWith(color: t.text),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'http://192.168.1.20:11434/v1',
              hintStyle: VyanaType.body.copyWith(color: t.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          // The honest part: what their address means, not what we promise.
          reach == null
              ? 'Most servers want /v1 on the end.'
              : reach.detail,
          style: VyanaType.caption.copyWith(
            color: reach == EndpointReach.overTheInternet
                ? t.gold
                : t.textMuted,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 16),
        Text('Model', style: VyanaType.label.copyWith(color: t.textSec)),
        const SizedBox(height: 7),
        _FieldBox(
          child: TextField(
            controller: model,
            onChanged: (_) => onChanged(),
            autocorrect: false,
            style: VyanaType.body.copyWith(color: t.text),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'llama3.1:8b',
              hintStyle: VyanaType.body.copyWith(color: t.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'The name your server knows it by.',
          style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.4),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Key',
                  style: VyanaType.label.copyWith(color: t.textSec)),
            ),
            Text(
              ai.endpoint.hasKey ? 'SAVED' : 'OPTIONAL',
              style: VyanaType.mono10.copyWith(
                color: ai.endpoint.hasKey ? t.green : t.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _FieldBox(
          child: TextField(
            controller: apiKey,
            obscureText: !showKey,
            autocorrect: false,
            enableSuggestions: false,
            style: VyanaType.body.copyWith(color: t.text),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: ai.endpoint.hasKey ? 'Saved — type to replace' : '',
              hintStyle: VyanaType.body.copyWith(color: t.textMuted),
              suffixIcon: IconButton(
                onPressed: onToggleKey,
                icon: VyanaIcon(
                  showKey ? 'eyeOff' : 'eye',
                  size: 17,
                  color: t.textMuted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Most self-hosted servers need none. Stored in the phone\'s '
          'keystore, never beside the rest of the settings.',
          style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.4),
        ),

        if (ai.lastError != null) ...[
          const SizedBox(height: 14),
          Panel(
            pad: 13,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon('alert', size: 17, color: t.vit('hr')),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    ai.lastError!,
                    style: VyanaType.body.copyWith(
                      color: t.textSec,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        Cta(
          label: ai.isTesting ? 'Testing…' : 'Test and save',
          icon: ai.isTesting ? 'refresh' : 'check',
          onTap: ai.isTesting ? null : onSave,
        ),
        if (ai.endpoint.isComplete) ...[
          const SizedBox(height: 10),
          BorderedPill(label: 'Forget this endpoint', onTap: onForget),
        ],
      ],
    );
  }
}
