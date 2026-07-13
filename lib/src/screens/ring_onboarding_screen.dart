part of '../../main.dart';

Future<void> openRingOnboarding(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RingOnboardingScreen(controller: c),
    ),
  );
}

/// Post-scan first-time setup for a PRANA ring.
class RingOnboardingScreen extends StatefulWidget {
  const RingOnboardingScreen({super.key, required this.controller});

  final RingController controller;

  @override
  State<RingOnboardingScreen> createState() => _RingOnboardingScreenState();
}

class _RingOnboardingScreenState extends State<RingOnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final _nameController = TextEditingController();

  int _page = 0;
  bool _nameBusy = false;
  bool _monitorBusy = false;
  bool _wipeBusy = false;
  bool _wipeDone = false;
  bool _finishBusy = false;

  // Step 1: rename
  String _name = '';
  String? _nameError;

  // Step 2: health monitoring
  bool _monitorEnabled = true;
  int _monitorInterval = kHealthMonitoringDefaultInterval;

  // Step 3: wipe data
  String? _wipeMessage;
  bool _wipeSuccess = false;

  // Step 4: foreground service
  bool _foregroundEnabled = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final initialName =
        widget.controller.pairedRing?.displayName ?? 'PRANA ring';
    _nameController.text = initialName;
    _name = initialName;
    _validateName(initialName);

    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final status = widget.controller.status;
    if (_nameBusy && (status.startsWith('Ring renamed') || status.contains('required') || status.contains('characters') || status.contains('only contain'))) {
      setState(() {
        _nameBusy = false;
        _nameError = (status.contains('required') ||
                status.contains('characters') ||
                status.contains('only contain'))
            ? status
            : null;
      });
    }
  }

  void _validateName(String value) {
    final clean = normalizeRingName(value);
    setState(() {
      _name = clean ?? '';
      _nameError = validateRingName(value);
    });
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onRenameContinue() async {
    if (_nameError != null || _name.isEmpty || _nameBusy) return;
    setState(() => _nameBusy = true);
    await widget.controller.renameRing(_name);
    if (!mounted) return;
    if (_nameError == null &&
        !widget.controller.status.contains('failed') &&
        !widget.controller.status.contains('unavailable')) {
      _goTo(1);
    }
    setState(() => _nameBusy = false);
  }

  Future<void> _onMonitorContinue() async {
    if (_monitorBusy) return;
    setState(() => _monitorBusy = true);
    await widget.controller.applyHealthMonitoring(
      enabled: _monitorEnabled,
      intervalMinutes: _monitorInterval,
    );
    if (!mounted) return;
    final result = widget.controller.healthMonitoring;
    if (result.ringAcknowledged ||
        widget.controller.status.contains('confirmed')) {
      _goTo(2);
    }
    setState(() => _monitorBusy = false);
  }

  Future<void> _onWipeContinue() async {
    if (_wipeBusy || _wipeDone) return;
    setState(() {
      _wipeBusy = true;
      _wipeMessage = null;
    });
    final result = await widget.controller.deleteRingHealthData();
    if (!mounted) return;
    setState(() {
      _wipeBusy = false;
      _wipeDone = result.success;
      _wipeSuccess = result.success;
      _wipeMessage = result.message;
    });
    if (result.success) {
      _goTo(3);
    }
  }

  Future<void> _onFinish() async {
    if (_finishBusy) return;
    setState(() => _finishBusy = true);
    await widget.controller.completeRingOnboarding(
      enableForegroundService: _foregroundEnabled,
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _ringIcon(VyanaColors t) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              boxShadow: [
                BoxShadow(
                  color: t.gold.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: VyanaIcon('ring', size: 58, color: t.gold),
            ),
          ),
        );
      },
    );
  }

  Widget _stepTitle(String title, VyanaColors t) {
    return Text(
      title,
      style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 26),
      textAlign: TextAlign.center,
    );
  }

  Widget _stepCaption(String caption, VyanaColors t) {
    return Text(
      caption,
      style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
      textAlign: TextAlign.center,
    );
  }

  Widget _dots(int count, int active, VyanaColors t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            width: i == active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? t.gold : t.borderSoft,
              borderRadius: BorderRadius.circular(3.5),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _continueButton(
    VyanaColors t,
    String label,
    VoidCallback? onTap, {
    bool busy = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Cta(
        label: busy ? 'Working…' : label,
        icon: busy ? 'refresh' : 'chevR',
        onTap: busy ? null : onTap,
      ),
    );
  }

  Widget _buildRenameStep(VyanaColors t) {
    final suffix = widget.controller.ringNameSuffix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle('Name your ring', t),
        const SizedBox(height: 10),
        _stepCaption(
          'Give your PRANA ring a friendly name. The last 4 characters of its '
          'identifier stay the same so you can always tell which ring it is.',
          t,
        ),
        const SizedBox(height: 28),
        Panel(
          pad: 14,
          child: TextField(
            controller: _nameController,
            style: VyanaType.body.copyWith(color: t.text),
            maxLength: kRingNameMaxLength,
            decoration: InputDecoration(
              counterText: '',
              labelText: 'Ring name',
              suffixText: '· $suffix',
              suffixStyle: VyanaType.caption.copyWith(color: t.textMuted),
              errorText: _nameError,
            ),
            onChanged: _validateName,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onRenameContinue(),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMonitoringStep(VyanaColors t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle('Vitals monitoring', t),
        const SizedBox(height: 10),
        _stepCaption(
          'Let the ring record your combined vitals every few minutes. '
          'This is how Vyana builds your stress and vitals charts.',
          t,
        ),
        const SizedBox(height: 24),
        Panel(
          pad: 14,
          child: Row(
            children: [
              VyanaIcon('activity', size: 19, color: t.green),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Automatic monitoring',
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                    Text(
                      'Periodic background checks on the ring',
                      style: VyanaType.caption.copyWith(
                        color: t.textSec,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              VSwitch(
                on: _monitorEnabled,
                onTap: () => setState(() => _monitorEnabled = !_monitorEnabled),
              ),
            ],
          ),
        ),
        if (_monitorEnabled) ...[
          const SizedBox(height: 16),
          Text(
            'Check interval',
            style: VyanaType.label.copyWith(color: t.textSec),
          ),
          const SizedBox(height: 8),
          Panel(
            pad: 14,
            child: Row(
              children: [
                IconBtn(
                  icon: 'minus',
                  onTap: _monitorInterval > kHealthMonitoringMinInterval
                      ? () => setState(() => _monitorInterval =
                          clampHealthMonitoringInterval(_monitorInterval - 1))
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Every',
                        style: VyanaType.caption.copyWith(color: t.textMuted),
                      ),
                      Text(
                        '$_monitorInterval min',
                        style: VyanaType.titleSerif.copyWith(
                          color: t.text,
                          fontSize: 28,
                        ),
                      ),
                      Text(
                        '$kHealthMonitoringMinInterval–$kHealthMonitoringMaxInterval min allowed',
                        style: VyanaType.caption.copyWith(color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                IconBtn(
                  icon: 'plus',
                  onTap: _monitorInterval < kHealthMonitoringMaxInterval
                      ? () => setState(() => _monitorInterval =
                          clampHealthMonitoringInterval(_monitorInterval + 1))
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in kHealthMonitoringPresetIntervals)
                Pill(
                  label: '${preset}m',
                  active: _monitorInterval == preset,
                  onTap: () => setState(
                      () => _monitorInterval = clampHealthMonitoringInterval(preset)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWipeStep(VyanaColors t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle('Wipe old ring data', t),
        const SizedBox(height: 10),
        _stepCaption(
          'Erase any previous health data stored on the ring so Vyana starts '
          'fresh from your first sync.',
          t,
        ),
        const SizedBox(height: 24),
        if (_wipeMessage != null)
          Panel(
            pad: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon(
                  _wipeSuccess ? 'checkCircle' : 'info',
                  size: 18,
                  color: _wipeSuccess ? t.green : t.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _wipeMessage!,
                    style: VyanaType.body.copyWith(
                      color: _wipeSuccess ? t.green : t.textSec,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildForegroundStep(VyanaColors t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle('Keep Vyana running', t),
        const SizedBox(height: 10),
        _stepCaption(
          'A foreground notification keeps the ring connected and your vitals '
          'syncing in the background. You can change this later in Settings.',
          t,
        ),
        const SizedBox(height: 24),
        Panel(
          pad: 14,
          child: Row(
            children: [
              VyanaIcon('bell', size: 19, color: t.gold),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Always-on service',
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                    Text(
                      'Android foreground notification',
                      style: VyanaType.caption.copyWith(
                        color: t.textSec,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              VSwitch(
                on: _foregroundEnabled,
                onTap: () => setState(() => _foregroundEnabled = !_foregroundEnabled),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: t.bgGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  _ringIcon(t),
                  const SizedBox(height: 28),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (p) => setState(() => _page = p),
                      children: [
                        _buildRenameStep(t),
                        _buildHealthMonitoringStep(t),
                        _buildWipeStep(t),
                        _buildForegroundStep(t),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dots(4, _page, t),
                  const SizedBox(height: 24),
                  if (_page == 0)
                    _continueButton(t, 'Continue', _onRenameContinue, busy: _nameBusy)
                  else if (_page == 1)
                    _continueButton(t, 'Continue', _onMonitorContinue, busy: _monitorBusy)
                  else if (_page == 2)
                    _continueButton(
                      t,
                      _wipeDone ? 'Continue' : 'Wipe ring data',
                      _wipeDone ? () => _goTo(3) : _onWipeContinue,
                      busy: _wipeBusy,
                    )
                  else
                    _continueButton(t, "Let's Go!", _onFinish, busy: _finishBusy),
                  const SizedBox(height: 10),
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _goTo(_page - 1),
                      child: Text(
                        'Back',
                        style: VyanaType.label.copyWith(color: t.textMuted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
