part of '../../main.dart';

Future<void> openRingOnboarding(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RingOnboardingScreen(controller: c),
    ),
  );
}

/// How big the ring art may be given [space], the height left for the whole
/// step — chrome included.
///
/// The chrome around each step (ring, dots, buttons) is a fixed height and
/// the keyboard takes half the screen on the first step; at the Large
/// display size on a 360dp phone that overflowed the column by 37px. The
/// ring is the decoration, so it is what gives way. 0 means draw none.
double onboardingRingBox(double space) {
  if (space < 420) return 0;
  if (space < 560) return 84;
  return 132;
}

/// Post-scan first-time setup for a PRANA ring.
///
/// Runs once per ring, not once per phone: [RingController]
/// .currentRingNeedsOnboarding decides, so re-pairing a ring you already
/// named comes straight back to You, while a ring this phone has not seen
/// gets its own setup.
class RingOnboardingScreen extends ConsumerStatefulWidget {
  const RingOnboardingScreen({super.key, required this.controller});

  final RingController controller;

  @override
  ConsumerState<RingOnboardingScreen> createState() =>
      _RingOnboardingScreenState();
}

class _RingOnboardingScreenState extends ConsumerState<RingOnboardingScreen>
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
  String? _monitorMessage;

  // Step 3: start fresh
  String? _wipeMessage;
  bool _wipeSuccess = false;
  bool _wipeRing = true;
  bool _wipeApp = false;
  int _previousRingRows = 0;

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
    unawaited(_loadPreviousRingData());
  }

  /// A different ring means the vitals, ECGs and patterns already in the
  /// vault belong to the ring being replaced. Offer to clear them — on by
  /// default, because leaving two rings' readings in one chart is the
  /// wrongness nobody goes looking for — but only when there is something
  /// to clear and only for data the ring recorded.
  Future<void> _loadPreviousRingData() async {
    if (!widget.controller.isReplacingAnotherRing) return;
    final rows = await ref.read(databaseProvider).countRingRecordedRows();
    if (!mounted) return;
    setState(() {
      _previousRingRows = rows;
      _wipeApp = rows > 0;
    });
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
    setState(() {
      _monitorBusy = true;
      _monitorMessage = null;
    });
    await widget.controller.applyHealthMonitoring(
      enabled: _monitorEnabled,
      intervalMinutes: _monitorInterval,
    );
    if (!mounted) return;
    final result = widget.controller.healthMonitoring;
    final ok = result.ringAcknowledged ||
        widget.controller.status.contains('confirmed');
    setState(() {
      _monitorBusy = false;
      // A ring that will not confirm used to leave "Working…" on screen
      // with nothing to tap and no way back — setup became a dead end on
      // the second of four steps. Say what happened and let them past; the
      // interval is changeable any time in You › Ring data.
      _monitorMessage = ok ? null : result.lastMessage;
    });
    if (ok) _goTo(2);
  }

  Future<void> _onWipeContinue() async {
    if (_wipeBusy || _wipeDone) return;
    if (!_wipeRing && !_wipeApp) {
      _goTo(3);
      return;
    }
    setState(() {
      _wipeBusy = true;
      _wipeMessage = null;
    });

    var ok = true;
    final done = <String>[];
    String? failure;

    if (_wipeRing) {
      final result = await widget.controller.deleteRingHealthData();
      if (!mounted) return;
      ok = result.success;
      if (result.success) {
        done.add('the ring');
      } else {
        failure = result.message;
      }
    }

    // The ring-side wipe needs the ring; this half never does, so a ring
    // that would not confirm does not strand the user's own clean start.
    if (_wipeApp) {
      await ref.read(databaseProvider).clearRingRecordedData();
      await widget.controller.forgetPreviousRingData();
      if (!mounted) return;
      done.add('Vyana');
    }

    setState(() {
      _wipeBusy = false;
      _wipeDone = ok;
      _wipeSuccess = ok;
      _wipeMessage = ok
          ? 'Cleared on ${done.join(' and ')}. Your journal, practices and '
              'cycle are untouched.'
          : failure;
    });
    if (ok) _goTo(3);
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

  /// [box] shrinks with the space left for it — see the LayoutBuilder in
  /// build(). The three discs and the glyph keep their proportions.
  Widget _ringIcon(VyanaColors t, {double box = 132}) {
    final disc = box * 120 / 132;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final v = _pulseAnimation.value;
        final scale1 = 1.0 + (v - 0.96) * 3.0;
        final scale2 = 1.0 + (v - 0.96) * 5.0;
        final opacity1 = (0.18 - (v - 0.96) * 1.8).clamp(0.0, 1.0);
        final opacity2 = (0.10 - (v - 0.96) * 1.0).clamp(0.0, 1.0);
        return SizedBox(
          width: box,
          height: box,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: opacity2,
                child: Transform.scale(
                  scale: scale2,
                  child: Container(
                    width: disc,
                    height: disc,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.gold.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: opacity1,
                child: Transform.scale(
                  scale: scale1,
                  child: Container(
                    width: disc,
                    height: disc,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.gold.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
              Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: t.cardGradient,
                  border: Border.all(
                    color: t.gold.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.gold.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                    ...t.shadowSoft,
                  ],
                ),
                child: Center(
                  child: VyanaIcon(
                    'ring',
                    size: disc * 64 / 120,
                    color: t.gold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stepTitle(String title, VyanaColors t) {
    return Text(
      title,
      style: VyanaType.titleSerif.copyWith(
        color: t.text,
        fontSize: 28,
        height: 1.05,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _stepCaption(String caption, VyanaColors t) {
    return Text(
      caption,
      style: VyanaType.body.copyWith(color: t.textSec, height: 1.5),
      textAlign: TextAlign.center,
    );
  }

  Widget _dots(int count, int active, VyanaColors t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
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
          pad: 0,
          radius: 22,
          child: TextField(
            controller: _nameController,
            style: VyanaType.body.copyWith(color: t.text),
            maxLength: kRingNameMaxLength,
            autofocus: true,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: t.surface,
              labelText: 'Ring name',
              suffixText: '· $suffix',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: t.gold, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: t.vit('hr'), width: 1.5),
              ),
              labelStyle: VyanaType.label.copyWith(color: t.textMuted),
              floatingLabelStyle: VyanaType.label.copyWith(color: t.gold),
              suffixStyle: VyanaType.caption.copyWith(color: t.textMuted),
              errorStyle: VyanaType.caption.copyWith(color: t.vit('hr')),
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
          grad: true,
          child: Row(
            children: [
              VyanaIconBadge(name: 'activity', color: t.green),
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
                color: t.green,
                onTap: () => setState(() => _monitorEnabled = !_monitorEnabled),
              ),
            ],
          ),
        ),
        if (_monitorMessage != null) ...[
          const SizedBox(height: 14),
          Panel(
            pad: 14,
            grad: true,
            accent: t.gold,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon('info', size: 20, color: t.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$_monitorMessage You can set this later in '
                    'You › Ring data.',
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
        if (_monitorEnabled) ...[
          const SizedBox(height: 16),
          Text(
            'Check interval',
            style: VyanaType.label.copyWith(color: t.textSec),
          ),
          const SizedBox(height: 8),
          Panel(
            pad: 14,
            grad: true,
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
    final replacing = _previousRingRows > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(replacing ? 'Start fresh' : 'Wipe old ring data', t),
        const SizedBox(height: 10),
        _stepCaption(
          replacing
              ? 'This is not the ring Vyana was using. Choose what to clear '
                  'so one chart does not end up holding two rings\' readings. '
                  'Your journal, practices and cycle are never touched.'
              : 'Optional: erase any previous health data stored on the ring '
                  'so Vyana starts fresh from your first sync. If this is a '
                  'new ring, you can skip this and keep whatever it already '
                  'recorded.',
          t,
        ),
        const SizedBox(height: 24),
        _wipeChoice(
          t,
          icon: 'ring',
          color: t.gold,
          title: 'Erase what the ring stored',
          caption: 'The readings still held on the ring itself',
          on: _wipeRing,
          onTap: () => setState(() {
            _wipeRing = !_wipeRing;
            _wipeMessage = null;
          }),
        ),
        if (replacing) ...[
          const SizedBox(height: 12),
          _wipeChoice(
            t,
            icon: 'activity',
            color: t.vit('hr'),
            title: 'Erase the last ring\'s data in Vyana',
            caption: '$_previousRingRows '
                '${_previousRingRows == 1 ? 'record' : 'records'} — vitals '
                'history, ECGs and patterns. Journal, practices and cycle '
                'are kept.',
            on: _wipeApp,
            onTap: () => setState(() {
              _wipeApp = !_wipeApp;
              _wipeMessage = null;
            }),
          ),
        ],
        const SizedBox(height: 16),
        if (_wipeMessage != null)
          Panel(
            pad: 14,
            grad: true,
            accent: _wipeSuccess ? t.green : t.gold,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon(
                  _wipeSuccess ? 'checkCircle' : 'info',
                  size: 20,
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

  Widget _wipeChoice(
    VyanaColors t, {
    required String icon,
    required Color color,
    required String title,
    required String caption,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Panel(
      pad: 14,
      grad: true,
      child: Row(
        children: [
          VyanaIconBadge(name: icon, color: color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: VyanaType.label.copyWith(color: t.text)),
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
          VSwitch(on: on, color: color, onTap: onTap),
        ],
      ),
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
          grad: true,
          child: Row(
            children: [
              VyanaIconBadge(name: 'bell', color: t.gold),
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
                color: t.gold,
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
              child: LayoutBuilder(builder: (context, constraints) {
                final ringBox = onboardingRingBox(constraints.maxHeight);
                return Column(
                children: [
                  if (ringBox > 0) ...[
                    _ringIcon(t, box: ringBox),
                    SizedBox(height: ringBox >= 132 ? 28 : 14),
                  ] else
                    const SizedBox(height: 4),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (p) => setState(() => _page = p),
                      // The PageView's height is whatever is left after the
                      // icon, dots and buttons, and on a 1080×1920 screen two
                      // of these steps are taller than that — "Vitals
                      // monitoring" by 76px, and "Name your ring" by 115px
                      // once the keyboard halves the space. Each step
                      // scrolls rather than overflowing; the Expanded inside
                      // them are all in Rows, so vertical scrolling is safe.
                      children: [
                        for (final step in [
                          _buildRenameStep(t),
                          _buildHealthMonitoringStep(t),
                          _buildWipeStep(t),
                          _buildForegroundStep(t),
                        ])
                          SingleChildScrollView(child: step),
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
                      _wipeDone || (!_wipeRing && !_wipeApp)
                          ? 'Continue'
                          : 'Wipe ring data',
                      _wipeDone ? () => _goTo(3) : _onWipeContinue,
                      busy: _wipeBusy,
                    )
                  else
                    _continueButton(t, "Let's Go!", _onFinish, busy: _finishBusy),
                  const SizedBox(height: 10),
                  if (_page == 1 && !_monitorBusy)
                    TextButton(
                      onPressed: () => _goTo(2),
                      child: Text(
                        'Skip — set this later',
                        style: VyanaType.label.copyWith(color: t.textSec),
                      ),
                    ),
                  if (_page == 2 && !_wipeDone && (_wipeRing || _wipeApp))
                    TextButton(
                      onPressed: _wipeBusy ? null : () => _goTo(3),
                      child: Text(
                        'Skip — keep existing data',
                        style: VyanaType.label.copyWith(color: t.textSec),
                      ),
                    ),
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _goTo(_page - 1),
                      child: Text(
                        'Back',
                        style: VyanaType.label.copyWith(color: t.textMuted),
                      ),
                    ),
                ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
