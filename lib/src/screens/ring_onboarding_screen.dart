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
/// Whether "Erase what the ring stored" should start switched on.
///
/// Item 60: it used to start on, always. On a first pairing that erases the
/// ring's own stored history — which, after a reinstall, is the only copy of
/// it left anywhere — because the main button happened to be labelled "Wipe
/// ring data" and the switch was already set. Nobody chose that.
///
/// Replacing a ring is the one case where erasing is the point: two rings'
/// readings in one chart is the wrongness nobody goes looking for.
bool wipeRingDefaultFor({required int previousRingRows}) {
  return previousRingRows > 0;
}

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

  /// Set when a rename came back unsuccessful, so the way out appears only
  /// once there is something to get out of.
  bool _renameFailed = false;

  // Step 3: start fresh
  String? _wipeMessage;
  bool _wipeSuccess = false;
  bool _wipeRing = wipeRingDefaultFor(previousRingRows: 0);
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
      _wipeRing = wipeRingDefaultFor(previousRingRows: rows);
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

  /// Item 60: this used to decide whether the rename had worked by looking
  /// for words in the controller's status string — "Ring renamed",
  /// "required", "characters", "only contain". Any failure phrased some
  /// other way read as success, and the step moved on from work it had not
  /// done. [renameRing] returns its result now, so there is nothing left to
  /// infer; this just keeps the screen in step with the ring.
  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _validateName(String value) {
    final clean = normalizeRingName(value);
    setState(() {
      _name = clean ?? '';
      _nameError = validateRingName(value);
    });
  }

  /// Whether setup shows the "Keep Vyana running" step.
  ///
  /// Item 75: Android only. The step promises that vitals keep syncing in
  /// the background and points at an Android foreground-service setting,
  /// neither of which exists on iPhone — so on iOS it was a promise the app
  /// could not keep, next to a switch that did nothing.
  bool get _hasForegroundStep => !kIsWeb && Platform.isAndroid;

  int get _pageCount => _hasForegroundStep ? 4 : 3;

  /// Where leaving the wipe step goes. On iPhone the wipe step is the last
  /// one, so leaving it ends setup — four separate `_goTo(3)` calls used to
  /// say "past the wipe step" and there is no page 3 to go to now.
  void _afterWipe() {
    if (_hasForegroundStep) {
      _goTo(3);
    } else {
      unawaited(_onFinish());
    }
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
    // Item 60: the result, not the status string. Reading status for the
    // word "failed" meant a failure with any other wording looked like a
    // success, and a ring that was not connected looked like one too.
    final result = await widget.controller.renameRing(_name);
    if (!mounted) return;
    setState(() {
      _nameBusy = false;
      _nameError = result.successful ? null : result.message;
      _renameFailed = !result.successful;
    });
    if (result.successful) _goTo(1);
  }

  /// Leaves the ring called whatever it is already called.
  ///
  /// The name is a convenience, not a requirement — nothing else in setup
  /// depends on it — so a ring that will not accept one must not be able to
  /// hold a person on the first screen of a flow they cannot back out of.
  void _skipRename() {
    setState(() {
      _nameError = null;
      _renameFailed = false;
    });
    _goTo(1);
  }

  Future<void> _onMonitorContinue() async {
    if (_monitorBusy) return;
    setState(() {
      _monitorBusy = true;
      _monitorMessage = null;
    });
    final result = await widget.controller.applyHealthMonitoring(
      enabled: _monitorEnabled,
      intervalMinutes: _monitorInterval,
    );
    if (!mounted) return;
    setState(() {
      _monitorBusy = false;
      // A ring that will not confirm used to leave "Working…" on screen
      // with nothing to tap and no way back — setup became a dead end on
      // the second of four steps. Say what happened and let them past; the
      // interval is changeable any time in You › Ring data.
      //
      // The reason comes from the returned result, not from the
      // controller: when the ring is not connected applyHealthMonitoring
      // returns early with "Connect your ring first." without writing it to
      // _healthMonitoring, so reading the controller there gave a stale
      // message — or none at all, leaving the step silent about why it had
      // not moved on.
      _monitorMessage = result.successful ? null : result.message;
    });
    if (result.successful) _goTo(2);
  }

  Future<void> _onWipeContinue() async {
    if (_wipeBusy || _wipeDone) return;
    if (!_wipeRing && !_wipeApp) {
      _afterWipe();
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
    if (ok) _afterWipe();
  }

  Future<void> _onFinish() async {
    if (_finishBusy) return;
    setState(() => _finishBusy = true);
    await widget.controller.completeRingOnboarding(
      // Item 75/76: false where there is no foreground step, so the switch
      // that was never shown cannot stand for an answer — and so pairing
      // takes the branch that asks iOS for notification permission.
      enableForegroundService: _hasForegroundStep && _foregroundEnabled,
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
              : 'Optional, and usually not what you want: erase the health '
                  'data stored on the ring itself. Vyana has already synced '
                  'it, but the ring\'s copy is the only other one — so if '
                  'you reinstall, this is what you would be restoring from.',
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
                          if (_hasForegroundStep) _buildForegroundStep(t),
                        ])
                          SingleChildScrollView(child: step),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dots(_pageCount, _page, t),
                  const SizedBox(height: 24),
                  if (_page == 0)
                    _continueButton(t, 'Continue', _onRenameContinue, busy: _nameBusy)
                  else if (_page == 1)
                    _continueButton(t, 'Continue', _onMonitorContinue, busy: _monitorBusy)
                  else if (_page == 2)
                    _continueButton(
                      t,
                      _wipeDone || (!_wipeRing && !_wipeApp)
                          ? (_hasForegroundStep ? 'Continue' : "Let's Go!")
                          : 'Wipe ring data',
                      _wipeDone ? _afterWipe : _onWipeContinue,
                      busy: _wipeBusy || _finishBusy,
                    )
                  else
                    _continueButton(t, "Let's Go!", _onFinish, busy: _finishBusy),
                  const SizedBox(height: 10),
                  // Item 60: setup cannot be backed out of (canPop is
                  // false), so a step that can fail needs a door. A ring
                  // that will not take a name keeps the one it has.
                  if (_page == 0 && _renameFailed && !_nameBusy)
                    TextButton(
                      onPressed: _skipRename,
                      child: Text(
                        'Skip, keep current name',
                        style: VyanaType.label.copyWith(color: t.textSec),
                      ),
                    ),
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
                      onPressed: _wipeBusy ? null : _afterWipe,
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
