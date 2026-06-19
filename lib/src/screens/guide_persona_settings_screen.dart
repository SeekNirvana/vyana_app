part of '../../main.dart';

Future<void> openGuidePersonaSettings(
  BuildContext context,
  GuidePersona guide,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => GuidePersonaSettingsScreen(guide: guide),
    ),
  );
}

/// Per-persona overrides: system prompt, response length, temperature.
class GuidePersonaSettingsScreen extends ConsumerStatefulWidget {
  const GuidePersonaSettingsScreen({super.key, required this.guide});

  final GuidePersona guide;

  @override
  ConsumerState<GuidePersonaSettingsScreen> createState() =>
      _GuidePersonaSettingsScreenState();
}

class _GuidePersonaSettingsScreenState
    extends ConsumerState<GuidePersonaSettingsScreen> {
  final _promptController = TextEditingController();
  GuideResponseLength _responseLength = GuideResponseLength.balanced;
  double? _temperatureOverride;
  bool _useCustomTemperature = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = t.vit(widget.guide.accent);
    final definition = guideDefinitionFor(widget.guide);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                child: Row(
                  children: [
                    IconBtn(
                      icon: 'chevL',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GUIDE SETTINGS',
                              style: VyanaType.eyebrow.copyWith(color: t.gold)),
                          Text(widget.guide.name,
                              style: VyanaType.appBarSerif
                                  .copyWith(color: t.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<GuidePersonaPrefRow?>(
                  stream: ref
                      .read(guidePersonaPrefsServiceProvider)
                      .watchPrefs(widget.guide.id),
                  builder: (context, snapshot) {
                    if (!_loaded &&
                        snapshot.connectionState != ConnectionState.waiting) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || _loaded) return;
                        _applyRow(snapshot.data, definition);
                        setState(() => _loaded = true);
                      });
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        Panel(
                          pad: 14,
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: ac.withValues(
                                      alpha: t.isDark ? 0.2 : 0.13),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Center(
                                  child: VyanaIcon(widget.guide.icon,
                                      size: 22, color: ac),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.guide.role,
                                        style: VyanaType.label
                                            .copyWith(color: t.text)),
                                    Text(
                                      'Overrides apply the next time you chat '
                                      'with ${widget.guide.name}.',
                                      style: VyanaType.bodySm.copyWith(
                                          color: t.textSec, height: 1.45),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('RESPONSE LENGTH',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        const SizedBox(height: 8),
                        _ResponseLengthPicker(
                          value: _responseLength,
                          accent: ac,
                          onChanged: (value) =>
                              setState(() => _responseLength = value),
                        ),
                        const SizedBox(height: 18),
                        Text('TEMPERATURE',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        const SizedBox(height: 8),
                        Panel(
                          pad: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _useCustomTemperature
                                          ? _temperatureOverride!
                                              .toStringAsFixed(2)
                                          : 'Default (${GuidePersonaPrefsService.defaultTemperature})',
                                      style: VyanaType.label
                                          .copyWith(color: t.text),
                                    ),
                                  ),
                                  Switch(
                                    value: _useCustomTemperature,
                                    activeThumbColor: ac,
                                    onChanged: (enabled) {
                                      setState(() {
                                        _useCustomTemperature = enabled;
                                        _temperatureOverride ??=
                                            GuidePersonaPrefsService
                                                .defaultTemperature;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_useCustomTemperature) ...[
                                Slider(
                                  value: _temperatureOverride ??
                                      GuidePersonaPrefsService
                                          .defaultTemperature,
                                  min: 0.2,
                                  max: 1.2,
                                  divisions: 20,
                                  activeColor: ac,
                                  label: _temperatureOverride!
                                      .toStringAsFixed(2),
                                  onChanged: (value) => setState(
                                    () => _temperatureOverride = value,
                                  ),
                                ),
                                Text(
                                  'Lower = steadier. Higher = more varied.',
                                  style: VyanaType.mono10
                                      .copyWith(color: t.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('SYSTEM PROMPT',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        const SizedBox(height: 8),
                        Panel(
                          pad: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Leave blank to use ${widget.guide.name}\'s '
                                'built-in persona prompt.',
                                style: VyanaType.bodySm.copyWith(
                                    color: t.textSec, height: 1.45),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _promptController,
                                minLines: 5,
                                maxLines: 10,
                                style: VyanaType.bodySm.copyWith(color: t.text),
                                decoration: InputDecoration(
                                  hintText: definition.systemPrompt,
                                  hintStyle: VyanaType.bodySm
                                      .copyWith(color: t.textMuted),
                                  filled: true,
                                  fillColor: t.bg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: t.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: t.border),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      _promptController.text = '',
                                  child: Text('Use default prompt',
                                      style: VyanaType.label
                                          .copyWith(color: t.textSec)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Cta(
                          label: _saving ? 'Saving…' : 'Save guide settings',
                          icon: 'check',
                          onTap: _saving ? null : _save,
                        ),
                        const SizedBox(height: 10),
                        Cta(
                          label: 'Reset to defaults',
                          icon: 'refresh',
                          solid: false,
                          onTap: _saving ? null : _reset,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyRow(
    GuidePersonaPrefRow? row,
    GuidePersonaDefinition definition,
  ) {
    _responseLength = GuideResponseLength.fromStorage(row?.responseLength);
    _promptController.text = row?.customSystemPrompt?.trim() ?? '';
    if (row?.temperatureOverride != null) {
      _useCustomTemperature = true;
      _temperatureOverride = row!.temperatureOverride!;
    } else {
      _useCustomTemperature = false;
      _temperatureOverride = null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = ref.read(guidePersonaPrefsServiceProvider);
      await prefs.savePrefs(
        personaId: widget.guide.id,
        customSystemPrompt: _promptController.text,
        responseLength: _responseLength,
        temperatureOverride:
            _useCustomTemperature ? _temperatureOverride : null,
      );
      ref.read(guideRuntimeServiceProvider).invalidatePrefs();
      if (!mounted) return;
      showVyanaSnackBar(
        context,
        message: '${widget.guide.name} settings saved.',
        icon: 'checkCircle',
        success: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(guidePersonaPrefsServiceProvider)
          .resetPrefs(widget.guide.id);
      ref.read(guideRuntimeServiceProvider).invalidatePrefs();
      _promptController.text = '';
      _responseLength = GuideResponseLength.balanced;
      _useCustomTemperature = false;
      _temperatureOverride = null;
      if (!mounted) return;
      showVyanaSnackBar(
        context,
        message: '${widget.guide.name} reset to defaults.',
        icon: 'refresh',
        success: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ResponseLengthPicker extends StatelessWidget {
  const _ResponseLengthPicker({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final GuideResponseLength value;
  final Color accent;
  final ValueChanged<GuideResponseLength> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      children: [
        for (final option in GuideResponseLength.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: value == option
                      ? accent.withValues(alpha: t.isDark ? 0.18 : 0.12)
                      : t.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: value == option ? accent : t.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label,
                        style: VyanaType.label.copyWith(color: t.text)),
                    const SizedBox(height: 4),
                    Text(option.description,
                        style: VyanaType.bodySm
                            .copyWith(color: t.textSec, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}