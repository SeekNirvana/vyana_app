part of '../../main.dart';

/// The active bottom-tab index. Screens use this to switch tabs
/// (e.g. Home's "Choose a practice" jumps to the Practice tab).
final tabIndexProvider = StateProvider<int>((_) => 0);

/// Root navigation shell: five persistent tabs with the elevated lotus
/// "Practice" button in the centre, per the handoff's TabBar. Pushed
/// sub-screens (scan, measurements, session, editors) use the root navigator
/// and cover the bar.
class VyanaShell extends ConsumerStatefulWidget {
  const VyanaShell({super.key});

  @override
  ConsumerState<VyanaShell> createState() => _VyanaShellState();
}

class _VyanaShellState extends ConsumerState<VyanaShell>
    with WidgetsBindingObserver {
  bool _profilePromptShown = false;

  static const _tabs = <Widget>[
    HomeScreen(),
    JournalScreen(),
    PracticeScreen(),
    GuidesScreen(),
    YouScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await isSolanaMobileDevice()) return;
      if (!mounted) return;
      ref.read(reownWalletProvider.notifier).initIfNeeded(context);
    });
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
      if (_profilePromptShown) return;
      next.whenData((profile) {
        if (!profile.isWellnessReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showProfileLaunchSheet();
          });
        }
      });
    });

    final t = context.vyana;
    final index = ref.watch(tabIndexProvider);
    return Scaffold(
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
          const SessionResumeBar(),
          VTabBar(
            active: index,
            onTap: (i) => ref.read(tabIndexProvider.notifier).state = i,
          ),
        ],
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
              Text('Resume',
                  style: VyanaType.label.copyWith(color: ac)),
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

  static const _items = <_TabItem>[
    _TabItem('home', 'Home'),
    _TabItem('book', 'Journal'),
    _TabItem('lotus', 'Practice'),
    _TabItem('sparkles', 'Guides'),
    _TabItem('user', 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 22),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: t.borderSoft)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            _buildItem(context, i, _items[i]),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int i, _TabItem item) {
    final t = context.vyana;
    final on = active == i;
    final isCenter = i == 2;
    return InkWell(
      onTap: () => onTap(i),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCenter)
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.green.withValues(alpha: on ? 1 : 0.9),
                      t.greenDark.withValues(alpha: on ? 1 : 0.9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.green.withValues(alpha: on ? 0.45 : 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: VyanaIcon('lotus', size: 21, color: Colors.white, stroke: 1.7),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: VyanaIcon(
                  item.icon,
                  size: 22,
                  color: on ? t.green : t.textMuted,
                  stroke: on ? 2 : 1.7,
                ),
              ),
            Text(
              item.label,
              style: VyanaType.mono10.copyWith(
                fontFamily: VyanaType.sans,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? t.green : t.textMuted,
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
  const _ProfileLaunchSheet({
    required this.onSetUp,
    required this.onLater,
  });

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
            Text('Welcome to Vyana',
                style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22)),
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
