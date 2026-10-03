part of '../../main.dart';

/// The active bottom-tab index. Screens use this to switch tabs
/// (e.g. Home's "Choose a practice" jumps to the Practice tab).
final tabIndexProvider = StateProvider<int>((_) => 0);

/// Root navigation shell: Home · Metrics · Practice · Journal · You — five
/// identical tab items (Practice sits centre for thumb reach) and Nova as a
/// right-aligned pill above the nav on every tab. Pushed sub-screens (scan, measurements, session,
/// editors, Nova's chat) use the root navigator and cover the bar.
class VyanaShell extends ConsumerStatefulWidget {
  const VyanaShell({super.key});

  @override
  ConsumerState<VyanaShell> createState() => _VyanaShellState();
}

class _VyanaShellState extends ConsumerState<VyanaShell>
    with WidgetsBindingObserver {
  bool _profilePromptShown = false;
  bool _cycleSheetShown = false;
  StreamSubscription<Uri?>? _widgetClickSub;

  static const _tabs = <Widget>[
    HomeScreen(),
    MetricsScreen(),
    PracticeScreen(),
    JournalScreen(),
    YouScreen(),
  ];

  /// Tab indices, so screens deep-link by name rather than by number.
  static const homeTab = 0;
  static const metricsTab = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await isSolanaMobileDevice()) return;
      if (!mounted) return;
      ref.read(reownWalletProvider.notifier).initIfNeeded(context);
    });
    _listenForWidgetLaunch();
  }

  /// The action home-screen widget launches Vyana with a deep link; when we see
  /// it (either on cold start or while running) we jump to Home and kick off a
  /// hands-off Monitor-all-vitals run.
  void _listenForWidgetLaunch() {
    _widgetClickSub = HomeWidgetService.instance.clicks.listen(
      _handleWidgetUri,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = await HomeWidgetService.instance.initialLaunchUri();
      _handleWidgetUri(uri);
    });
  }

  void _handleWidgetUri(Uri? uri) {
    if (!mounted) return;
    if (!HomeWidgetService.instance.isMonitorAllUri(uri)) return;
    ref.read(tabIndexProvider.notifier).state = 0;
    unawaited(ref.read(ringControllerProvider).runAllVitals());
  }

  void _showProfileLaunchSheet() {
    if (!mounted || _profilePromptShown) return;
    _profilePromptShown = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProfileLaunchSheet(
        onSetUp: () {
          Navigator.of(sheetContext).pop();
          openProfileEditor(context);
        },
        onLater: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(ringControllerProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile>>(userProfileProvider, (previous, next) {
      next.whenData((profile) {
        if (!_profilePromptShown && !profile.isWellnessReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showProfileLaunchSheet();
          });
          return;
        }
        // §14b: offered once, after the profile is saved with a female
        // gender. Never before the profile is complete, so it does not stack
        // on the set-up prompt.
        if (!_cycleSheetShown &&
            profile.isWellnessReady &&
            profile.shouldOfferCycleSheet) {
          _cycleSheetShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(offerCycleTracking(context, ref));
          });
        }
      });
    });

    // Push-worthy ring alerts (offline, stale, low battery, health) — evaluated
    // whenever the ring controller changes; each fires at most once per episode.
    ref.listen<RingController>(ringControllerProvider, (_, c) {
      unawaited(ref.read(ringAlertServiceProvider).evaluate(c));
      // §14: the learning phase counts from the oldest day the ring actually
      // covers, and the sleep score's duration target follows the user's own
      // nights once they have said a shorter night leaves them rested.
      final nights = sleepDaySummaries(c.history.sleep);
      if (nights.isNotEmpty) {
        final baselines = ref.read(personalBaselinesProvider.notifier);
        unawaited(baselines.noteDataStart(nights.last.day));
        baselines.applySleepTarget([
          for (final n in averageableNights(nights, history: c.history).take(14))
            n.breakdown.asleepSeconds,
        ]);
      }
    });

    final t = context.vyana;
    final index = ref.watch(tabIndexProvider);
    final ring = ref.watch(ringControllerProvider);
    final sessionRecording = ref.watch(sessionControllerProvider).active;
    // On Home the stale banner takes the pill's place above the nav, so the
    // user can fix the ring where they noticed it; elsewhere Nova stays.
    final showHomeBanner =
        index == homeTab &&
        (ringUiStateOf(ring) == RingUiState.stale ||
            ringUiStateOf(ring) == RingUiState.disconnected);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(
          confirmExitVyanaApp(context, sessionRecording: sessionRecording),
        );
      },
      child: Scaffold(
        extendBody: true,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: t.bgGradient),
          child: SafeArea(
            bottom: false,
            child: IndexedStack(index: index, children: _tabs),
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Right edge flush with the content's 16px margin; 14px of air
            // above the nav so the pill never reads as part of it.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: showHomeBanner
                  ? RingStaleBanner(controller: ring)
                  : const NovaPill(),
            ),
            const SessionResumeBar(),
            VTabBar(
              active: index,
              onTap: (i) => ref.read(tabIndexProvider.notifier).state = i,
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent "session in progress" bar shown above the tab bar whenever a
/// session is recording; tap to jump back into the live session screen.
class SessionResumeBar extends ConsumerWidget {
  const SessionResumeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final session = ref.watch(sessionControllerProvider);
    if (!session.active) return const SizedBox.shrink();
    final a = session.activity;
    final ac = a == null ? t.green : t.vit(a.accent);
    // §5: the same trigger that fires the push shows a banner here, so the
    // question is answerable without leaving the app.
    if (session.looksForgotten) {
      final settled = session.hrSettledAt;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: t.gold.withValues(alpha: t.isDark ? 0.16 : 0.1),
          border: Border(
            top: BorderSide(color: t.gold.withValues(alpha: 0.4)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Still on your ${(a?.name ?? 'session').toLowerCase()}?',
              style: VyanaType.label.copyWith(color: t.text),
            ),
            const SizedBox(height: 2),
            Text(
              settled == null
                  ? 'It has been running longer than usual.'
                  : 'Your heart rate settled '
                      '${DateTime.now().difference(settled).inMinutes} '
                      'minutes ago.',
              style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 13),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BorderedPill(
                  label: settled == null
                      ? 'End it'
                      : 'End at '
                          '${settled.hour.toString().padLeft(2, '0')}:'
                          '${settled.minute.toString().padLeft(2, '0')}',
                  color: t.gold,
                  onTap: () => unawaited(session.endAtSettled()),
                ),
                BorderedPill(
                  label: 'Still going',
                  onTap: session.snoozeForgotten,
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const LiveSessionScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ac.withValues(alpha: t.isDark ? 0.18 : 0.12),
            border: Border(top: BorderSide(color: ac.withValues(alpha: 0.4))),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: session.paused ? t.gold : ac,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${a?.name ?? 'Session'} · ${session.paused ? 'paused' : 'recording'} '
                  '${_fmtDuration(session.elapsed)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.label.copyWith(color: t.text),
                ),
              ),
              Text('Resume', style: VyanaType.label.copyWith(color: ac)),
              const SizedBox(width: 6),
              VyanaIcon('chevR', size: 16, color: ac),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.icon, this.label);
  final String icon;
  final String label;
}

class VTabBar extends StatelessWidget {
  const VTabBar({super.key, required this.active, required this.onTap});

  final int active;
  final ValueChanged<int> onTap;

  /// Practice glyph — the design uses the runner (`directions_run`); the
  /// meditation pose (`self_improvement`) reads as the whole catalogue rather
  /// than sport alone. Swap here.
  static const kPracticeTabIcon = 'meditate';

  static const _items = <_TabItem>[
    _TabItem('home', 'Home'),
    _TabItem('stats', 'Metrics'),
    _TabItem(kPracticeTabIcon, 'Practice'),
    _TabItem('book', 'Journal'),
    _TabItem('user', 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    // Only the real bottom inset (gesture bar / home indicator) goes under the
    // items; phones with hardware buttons get the same 8px as the top.
    final inset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(top: 8, bottom: 8 + inset),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: t.borderSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(child: _buildItem(context, i, _items[i])),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int i, _TabItem item) {
    final t = context.vyana;
    final on = active == i;
    // Five identical items: 36px icon box, 4px, label. Practice behaves like
    // the rest — green when selected, grey otherwise, no circle.
    return InkWell(
      onTap: () => onTap(i),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: VyanaIcon(
                  item.icon,
                  size: 24,
                  color: on ? t.green : t.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Scales down rather than overflowing at very large text sizes.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: VyanaType.caption.copyWith(
                  fontSize: 12.5,
                  height: 1.1,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? t.green : t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft launch prompt until first name and age are saved for wellness baselines.
class _ProfileLaunchSheet extends StatelessWidget {
  const _ProfileLaunchSheet({required this.onSetUp, required this.onLater});

  final VoidCallback onSetUp;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Panel(
        pad: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Vyana',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22),
            ),
            const SizedBox(height: 10),
            Text(
              'A quick profile helps baseline heart rate and SpO₂ for your age. '
              'Everything stays on this device.',
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
            ),
            const SizedBox(height: 18),
            Cta(label: 'Set up profile', icon: 'user', onTap: onSetUp),
            const SizedBox(height: 10),
            Cta(label: 'Not now', icon: 'chevR', solid: false, onTap: onLater),
          ],
        ),
      ),
    );
  }
}
