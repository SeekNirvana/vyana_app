part of '../../main.dart';

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
                _LocalBackendPanel(manager: manager)
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
            ],
          ),
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

class _LocalBackendPanel extends StatelessWidget {
  const _LocalBackendPanel({required this.manager});

  final GuideModelManager manager;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
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
                    'Nova runs here. Nothing she is told, and nothing she is '
                    'shown, leaves this phone.',
                    style: VyanaType.body
                        .copyWith(color: t.textSec, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // "What is this costing me on disk" belongs next to the choice
          // that costs it, not on a row in You that now opens this screen.
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
        Text(
          'The model is a one-time $kGuideModelSizeLabel download. After '
          'that Nova works with no network at all.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
        const SizedBox(height: 12),
        Cta(
          label: 'Install the model · $kGuideModelSizeLabel',
          icon: 'download',
          onTap: () => openGuideStore(context),
        ),
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
