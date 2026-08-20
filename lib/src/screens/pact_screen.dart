part of '../../main.dart';

Future<void> openPact(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const PactScreen()));

/// Pact hub — live promises, XP run, and a Friends tab for the social layer.
class PactScreen extends ConsumerStatefulWidget {
  const PactScreen({super.key});

  @override
  ConsumerState<PactScreen> createState() => _PactScreenState();
}

class _PactScreenState extends ConsumerState<PactScreen> {
  String _tab = 'mine';

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final state = ref.watch(pactControllerProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: t.gold,
            onRefresh: () => ref.read(pactControllerProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PACT',
                              style: VyanaType.eyebrow.copyWith(color: t.gold)),
                          Text('Keep your word',
                              style: VyanaType.appBarSerif.copyWith(color: t.text)),
                        ],
                      ),
                    ),
                    if (state.signedIn) ...[
                      const SizedBox(width: 8),
                      _XpChip(xp: state.unlocks?.xpBalance ?? 0),
                    ],
                  ],
                ),
                if (state.signedIn) ...[
                  const SizedBox(height: 14),
                  const _PactRunHud(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PactTab(
                          label: 'Mine',
                          icon: 'target',
                          active: _tab == 'mine',
                          onTap: () => setState(() => _tab = 'mine'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PactTab(
                          label: 'Friends',
                          icon: 'user',
                          active: _tab == 'friends',
                          badge: state.friendRequests.incoming.length,
                          onTap: () => setState(() => _tab = 'friends'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  _PactError(message: state.error!),
                ],
                if (state.loading) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.gold,
                      ),
                    ),
                  ),
                ] else if (!state.signedIn) ...[
                  const SizedBox(height: 18),
                  const _SessionGate(),
                ] else if (_tab == 'friends') ...[
                  const SizedBox(height: 18),
                  const PactFriendsBody(),
                ] else ...[
                  const SizedBox(height: 18),
                  if (state.active.isNotEmpty) ...[
                    SectionHead(
                      eyebrow: state.active.length == 1 ? 'Live' : 'Live pacts',
                      title: state.active.length == 1
                          ? 'In play'
                          : '${state.active.length} in play',
                    ),
                    for (final row in state.active) ...[
                      _ActivePactCard(snapshot: row, busy: state.busy),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (state.unlocks?.canCreate ?? false) ...[
                    SectionHead(
                      eyebrow: state.active.isEmpty ? 'Start one' : 'Start another',
                      title: 'Just Me, Versus, Friends',
                    ),
                    _CreatePactCard(
                      unlocks: state.unlocks!,
                      friends: state.friends,
                    ),
                    const SizedBox(height: 10),
                  ] else if (state.active.isEmpty) ...[
                    const SectionHead(eyebrow: 'Your Pacts', title: 'Slot full'),
                    const _CapNote(),
                    const SizedBox(height: 10),
                  ],
                  if (state.unfinished.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const SectionHead(eyebrow: 'Unfinished', title: 'Still yours'),
                    for (final row in state.unfinished) ...[
                      _EndedPactCard(snapshot: row),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (state.past.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const SectionHead(eyebrow: 'Kept', title: 'Finished'),
                    for (final row in state.past.take(5)) ...[
                      _EndedPactCard(snapshot: row, succeeded: true),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
                if (_tab == 'mine') ...[
                  const SizedBox(height: 8),
                  const _PrivacyNote(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PactError extends StatelessWidget {
  const _PactError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 14,
      accent: t.gold,
      child: Text(message,
          style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45)),
    );
  }
}

class _PactTab extends StatelessWidget {
  const _PactTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Material(
      color: active ? t.gold.withValues(alpha: t.isDark ? 0.2 : 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? t.gold : t.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              VyanaIcon(icon, size: 15, color: active ? t.gold : t.textSec),
              const SizedBox(width: 7),
              Text(label,
                  style: VyanaType.label
                      .copyWith(color: active ? t.gold : t.textSec)),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.gold,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('$badge',
                      style: VyanaType.mono10.copyWith(color: t.bg)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PactRunHud extends ConsumerWidget {
  const _PactRunHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final state = ref.watch(pactControllerProvider);
    final unlocks = state.unlocks;
    final xp = unlocks?.xpBalance ?? 0;
    final streak = unlocks?.currentStreak ?? 0;
    final kept = unlocks?.completed ?? 0;
    final used = unlocks?.slotsUsed ?? state.active.length;
    final cap = unlocks?.cap ?? 3;
    final next = unlocks?.nextLockedTier;
    final progress = next == null || next.unlockAt <= 0
        ? 1.0
        : (kept / next.unlockAt).clamp(0.0, 1.0);

    return Panel(
      grad: true,
      pad: 18,
      accent: t.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$xp',
                        style: VyanaType.appBarSerif
                            .copyWith(color: t.gold, fontSize: 36, height: 1)),
                    const SizedBox(height: 4),
                    Text('XP',
                        style: VyanaType.eyebrow.copyWith(color: t.gold)),
                  ],
                ),
              ),
              _HudStat(label: 'streak', value: '$streak'),
              const SizedBox(width: 16),
              _HudStat(label: 'kept', value: '$kept'),
              const SizedBox(width: 16),
              _HudStat(label: 'live', value: '$used/$cap'),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Next · ${next.label}',
                      style: VyanaType.caption.copyWith(color: t.textSec)),
                ),
                Text(
                  '${(next.unlockAt - kept).clamp(0, next.unlockAt)} more',
                  style: VyanaType.mono10.copyWith(color: t.gold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: t.gold.withValues(alpha: t.isDark ? 0.16 : 0.12),
                color: t.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: VyanaType.mono10.copyWith(color: t.textMuted)),
      ],
    );
  }
}

/// Home-tab entry: live Pact at a glance, or the invitation to make one.
class _PactHomeCard extends ConsumerWidget {
  const _PactHomeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final state = ref.watch(pactControllerProvider);
    final active = state.primary;
    final status = active?.me.standing;
    return Panel(
      pad: 14,
      radius: 20,
      onTap: () => openPact(context),
      child: Row(
        children: [
          VyanaIconBadge(
              name: 'target', color: t.gold, size: 44, iconSize: 21, borderRadius: 16),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active?.pact.title ?? 'Pact',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.titleSerif
                      .copyWith(color: t.text, fontSize: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  active == null
                      ? (state.signedIn
                          ? 'Make a 3-day promise to yourself'
                          : 'Keep your word')
                      : state.active.length > 1
                          ? '${state.active.length} live · ${active.me.done}/${active.me.required} on ${active.pact.title}'
                          : '${active.me.done}/${active.me.required} days · '
                              '${pactStatusLabel(status!)}',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          VyanaIcon('chevR', size: 17, color: t.textMuted),
        ],
      ),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _access = TextEditingController();
  final _refresh = TextEditingController();

  @override
  void dispose() {
    _access.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect your Seek Nirvana session',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 19)),
          const SizedBox(height: 8),
          Text(
            'Pacts live on your account. Paste the access token (and refresh '
            'token, so it lasts) from a signed-in seeknirvana.com session, or '
            'set them in .env.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
          ),
          const SizedBox(height: 14),
          _FieldBox(
            child: TextField(
              controller: _access,
              onChanged: (_) => setState(() {}),
              obscureText: true,
              style: VyanaType.body.copyWith(color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Access token',
                hintStyle: VyanaType.body.copyWith(color: t.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FieldBox(
            child: TextField(
              controller: _refresh,
              onChanged: (_) => setState(() {}),
              obscureText: true,
              style: VyanaType.body.copyWith(color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Refresh token (optional)',
                hintStyle: VyanaType.body.copyWith(color: t.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Consumer(
            builder: (context, ref, _) => Cta(
              label: 'Connect',
              icon: 'key',
              disabled: _access.text.trim().isEmpty && _refresh.text.trim().isEmpty,
              onTap: () {
                final access = _access.text.trim();
                final refresh = _refresh.text.trim();
                if (access.isEmpty && refresh.isEmpty) return;
                ref.read(pactControllerProvider.notifier).saveSession(
                      accessToken: access,
                      refreshToken: refresh.isEmpty ? null : refresh,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePactCard extends ConsumerWidget {
  const _ActivePactCard({required this.snapshot, required this.busy});

  final PactSnapshot snapshot;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final me = snapshot.me;
    final status = me.standing;
    final c = switch (status) {
      PactStatus.secured => t.green,
      PactStatus.onTrack => t.green,
      PactStatus.atRisk => t.gold,
      PactStatus.missed => t.textMuted,
    };
    final daysLeft = (me.total - me.elapsed).clamp(0, me.total);
    final actions = ref.read(pactControllerProvider.notifier);
    final social = snapshot.pact.isSocial;

    return Panel(
      pad: 16,
      accent: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: me.done.toDouble(),
                max: me.required <= 0 ? 1 : me.required.toDouble(),
                size: 58,
                stroke: 5,
                color: c,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${me.done}/${me.required}',
                        style: VyanaType.label.copyWith(color: t.text)),
                    Text('days',
                        style: VyanaType.mono10.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.pact.title,
                        style: VyanaType.titleSerif
                            .copyWith(color: t.text, fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      '${snapshot.pact.ruleText} · $daysLeft days left'
                      '${social ? ' · ${_pactModeLabel(snapshot.pact.mode)}' : ''}',
                      style: VyanaType.caption.copyWith(color: t.textSec),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(label: pactStatusLabel(status), color: c),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DayDots(days: me.days),
          if (social && snapshot.pact.shareCode.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ShareCodeRow(code: snapshot.pact.shareCode),
          ],
          if (snapshot.others.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('With them',
                style: VyanaType.caption.copyWith(color: t.textMuted)),
            const SizedBox(height: 8),
            for (final other in snapshot.others) ...[
              _OtherRow(
                other: other,
                busy: busy,
                onEncourage: other.participantId == null
                    ? null
                    : () => _encourage(context, ref, snapshot, other),
              ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 14),
          if (snapshot.todayDone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: t.green.withValues(alpha: t.isDark ? 0.14 : 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  VyanaIcon('checkCircle', size: 16, color: t.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Today's commitment completed",
                        style: VyanaType.label.copyWith(color: t.green)),
                  ),
                ],
              ),
            )
          else
            Cta(
              label: snapshot.autoSatisfied == true
                  ? 'Vyana can prove today — confirm'
                  : 'Mark today complete',
              icon: 'check',
              disabled: busy || !snapshot.canProve,
              onTap: () => actions.proveToday(snapshot, satisfied: true),
            ),
          if (snapshot.todayDone) ...[
            const SizedBox(height: 9),
            Cta(
              label: 'Undo today',
              icon: 'x',
              solid: false,
              disabled: busy,
              onTap: () => actions.proveToday(snapshot, satisfied: false),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Cta(
                  label: 'Freeze',
                  icon: 'snow',
                  solid: false,
                  disabled: busy || me.freezesRemaining <= 0,
                  onTap: () => actions.freezeToday(snapshot),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Cta(
                  label: 'Restore',
                  icon: 'repeat',
                  solid: false,
                  disabled: busy || me.restoresRemaining <= 0,
                  onTap: () => actions.restoreStreak(snapshot),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${me.currentStreak} streak · ${me.freezesRemaining} freeze · '
            '${me.restoresRemaining} restore',
            style: VyanaType.caption.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : () => actions.leaveActive(snapshot),
              child: Text('Leave this Pact',
                  style: VyanaType.caption.copyWith(color: t.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _encourage(
    BuildContext context,
    WidgetRef ref,
    PactSnapshot snapshot,
    PactOther other,
  ) async {
    final id = other.participantId;
    if (id == null) return;
    final note = TextEditingController(text: 'Keep going.');
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = context.vyana;
        return AlertDialog(
          backgroundColor: t.card,
          title: Text('Encourage ${other.displayName}',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 20)),
          content: _FieldBox(
            child: TextField(
              controller: note,
              autofocus: true,
              maxLength: 200,
              style: VyanaType.body.copyWith(color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'A short note',
                hintStyle: VyanaType.body.copyWith(color: t.textMuted),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: VyanaType.label.copyWith(color: t.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Send', style: VyanaType.label.copyWith(color: t.gold)),
            ),
          ],
        );
      },
    );
    final message = note.text.trim();
    note.dispose();
    if (sent != true || message.isEmpty || !context.mounted) return;
    await ref.read(pactControllerProvider.notifier).encourage(
          snapshot,
          participantId: id,
          message: message,
        );
  }
}

class _DayDots extends StatelessWidget {
  const _DayDots({required this.days});

  final List<PactDay> days;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    if (days.isEmpty) {
      return Text('No days yet',
          style: VyanaType.caption.copyWith(color: t.textMuted));
    }
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(child: _DayCell(day: days[i])),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});
  final PactDay day;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final (Color fill, Color border, String? icon, Color? iconColor) =
        switch (day.status) {
      PactDayStatus.done => (
          t.green.withValues(alpha: t.isDark ? 0.24 : 0.16),
          t.green.withValues(alpha: 0.5),
          'check',
          t.green,
        ),
      PactDayStatus.freeze => (
          t.gold.withValues(alpha: t.isDark ? 0.2 : 0.12),
          t.gold.withValues(alpha: 0.5),
          'snow',
          t.gold,
        ),
      PactDayStatus.restore => (
          t.gold.withValues(alpha: t.isDark ? 0.2 : 0.12),
          t.gold.withValues(alpha: 0.5),
          'repeat',
          t.gold,
        ),
      PactDayStatus.missed => (
          Colors.transparent,
          t.border,
          null,
          null,
        ),
      PactDayStatus.today => (
          t.gold.withValues(alpha: t.isDark ? 0.12 : 0.08),
          t.gold.withValues(alpha: 0.55),
          null,
          null,
        ),
      PactDayStatus.future => (
          Colors.transparent,
          t.border,
          null,
          null,
        ),
    };

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Center(
        child: icon == null
            ? Text('${day.dayNumber}',
                style: VyanaType.mono10.copyWith(
                  color: day.status == PactDayStatus.today ? t.gold : t.textMuted,
                ))
            : VyanaIcon(icon, size: 13, color: iconColor),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: VyanaType.mono10.copyWith(color: color, letterSpacing: 0.4)),
    );
  }
}

class _CreatePactCard extends ConsumerStatefulWidget {
  const _CreatePactCard({required this.unlocks, this.friends = const []});
  final PactUnlocks unlocks;
  final List<PactProfile> friends;

  @override
  ConsumerState<_CreatePactCard> createState() => _CreatePactCardState();
}

class _CreatePactCardState extends ConsumerState<_CreatePactCard> {
  final _title = TextEditingController();
  final _rule = TextEditingController();
  String _category = 'mindfulness';
  String _mode = 'just_me';
  String? _stake;
  final Set<String> _invitees = {};
  late int _window = _firstUnlockedDays(widget.unlocks);
  late int _required = _window;

  List<PactWindowTier> get _tiers => widget.unlocks.windowTiers.isNotEmpty
      ? widget.unlocks.windowTiers
      : pactWindowTiersFor(
          completed: widget.unlocks.completed,
          unlockedDays: widget.unlocks.windowDays,
        );

  bool get _social => _mode != 'just_me';

  bool get _modeLocked => widget.unlocks.modeLockHint(_mode).isNotEmpty;

  bool get _stakeLocked =>
      _stake != null && !widget.unlocks.stakes.contains(_stake);

  PactWindowTier get _selected => _tiers.firstWhere(
        (t) => t.days == _window,
        orElse: () => _tiers.first,
      );

  static int _firstUnlockedDays(PactUnlocks unlocks) {
    final tiers = unlocks.windowTiers.isNotEmpty
        ? unlocks.windowTiers
        : pactWindowTiersFor(
            completed: unlocks.completed,
            unlockedDays: unlocks.windowDays,
          );
    return tiers
        .where((t) => t.unlocked)
        .map((t) => t.days)
        .followedBy(unlocks.windowDays)
        .followedBy(const [3])
        .first;
  }

  @override
  void didUpdateWidget(covariant _CreatePactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final days = _tiers.map((t) => t.days).toList();
    if (!days.contains(_window)) {
      _window = _firstUnlockedDays(widget.unlocks);
      if (_required > _window) _required = _window;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _rule.dispose();
    super.dispose();
  }

  void _pickWindow(int days) {
    setState(() {
      _window = days;
      if (_required > days) _required = days;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final selected = _selected;
    final accent = _pactWindowColor(t, selected.days);
    final canSave = _title.text.trim().isNotEmpty && _rule.text.trim().isNotEmpty;
    final busy = ref.watch(pactControllerProvider).busy;
    final locked = !selected.unlocked;

    return Panel(
      pad: 16,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _social
                ? 'A promise with someone. The stake is an IOU — coffee, not money.'
                : 'A promise to yourself. No stake, no audience.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
          ),
          const SizedBox(height: 14),
          _FieldBox(
            child: TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: VyanaType.body.copyWith(color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Title',
                hintStyle: VyanaType.body.copyWith(color: t.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FieldBox(
            child: TextField(
              controller: _rule,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: VyanaType.body.copyWith(color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'What counts as a day',
                hintStyle: VyanaType.body.copyWith(color: t.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in pactCategories)
                Pill(
                  label: category,
                  active: _category == category,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in const ['just_me', 'challenge', 'friends'])
                Pill(
                  label: _pactModeLabel(mode),
                  icon: widget.unlocks.modeLockHint(mode).isEmpty ? null : 'lock',
                  active: _mode == mode,
                  onTap: () => setState(() {
                    _mode = mode;
                    if (!_social) {
                      _stake = null;
                      _invitees.clear();
                    }
                  }),
                ),
            ],
          ),
          if (_modeLocked) ...[
            const SizedBox(height: 10),
            _LockHint(
              message: widget.unlocks.modeLockHint(_mode),
              color: t.gold,
            ),
          ],
          const SizedBox(height: 16),
          Text('How long',
              style: VyanaType.caption.copyWith(color: t.textMuted)),
          const SizedBox(height: 6),
          Text(selected.label,
              style: VyanaType.titleSerif.copyWith(color: accent, fontSize: 22)),
          const SizedBox(height: 10),
          _DurationRail(
            tiers: _tiers,
            selectedDays: _window,
            onSelect: _pickWindow,
          ),
          if (locked) ...[
            const SizedBox(height: 10),
            _LockHint(message: selected.lockHint, color: accent),
          ],
          if (_social) ...[
            const SizedBox(height: 14),
            Text('Stake',
                style: VyanaType.caption.copyWith(color: t.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  label: 'none',
                  active: _stake == null,
                  onTap: () => setState(() => _stake = null),
                ),
                for (final stake in pactStakes)
                  Pill(
                    label: stake,
                    icon: widget.unlocks.stakes.contains(stake) ? null : 'lock',
                    active: _stake == stake,
                    onTap: () => setState(() => _stake = stake),
                  ),
              ],
            ),
            if (_stakeLocked) ...[
              const SizedBox(height: 10),
              _LockHint(message: _stakeLockHint(_stake!), color: t.gold),
            ],
            const SizedBox(height: 14),
            Text('Invite',
                style: VyanaType.caption.copyWith(color: t.textMuted)),
            const SizedBox(height: 8),
            if (widget.friends.isEmpty)
              Text(
                'Add a friend first, or start and share the code.',
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.4),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final friend in widget.friends)
                    Pill(
                      label: friend.displayName,
                      active: _invitees.contains(friend.profileId),
                      onTap: () => setState(() {
                        if (_invitees.contains(friend.profileId)) {
                          _invitees.remove(friend.profileId);
                        } else if (_mode == 'challenge') {
                          _invitees
                            ..clear()
                            ..add(friend.profileId);
                        } else if (_invitees.length < 3) {
                          _invitees.add(friend.profileId);
                        }
                      }),
                    ),
                ],
              ),
          ],
          const SizedBox(height: 12),
          Text('Need $_required of $_window days',
              style: VyanaType.caption.copyWith(color: t.textSec)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: accent.withValues(alpha: t.isDark ? 0.22 : 0.16),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.16),
              valueIndicatorColor: accent,
            ),
            child: Slider(
              value: _required.toDouble().clamp(1, _window.toDouble()),
              min: 1,
              max: _window.toDouble(),
              divisions: _window - 1,
              label: '$_required',
              onChanged: (value) => setState(() => _required = value.round()),
            ),
          ),
          Cta(
            label: 'Start this Pact',
            icon: locked || _modeLocked || _stakeLocked ? 'lock' : 'target',
            disabled: busy || !canSave || locked || _modeLocked || _stakeLocked,
            onTap: () {
              if (locked || _modeLocked || _stakeLocked) return;
              ref.read(pactControllerProvider.notifier).create(
                    PactCreateInput(
                      title: _title.text.trim(),
                      ruleText: _rule.text.trim(),
                      category: _category,
                      windowDays: _window,
                      requiredDays: _required,
                      mode: _mode,
                      stakeCatalog: _social ? _stake : null,
                      visibility: _social ? 'friends' : 'private',
                      maxParticipants: _mode == 'challenge'
                          ? 2
                          : _mode == 'friends'
                              ? 4
                              : 1,
                    ),
                    invitees: _invitees.toList(),
                  );
            },
          ),
        ],
      ),
    );
  }
}

Color _pactWindowColor(VyanaColors t, int days) => switch (days) {
      3 => t.green,
      5 => t.gold,
      7 => t.vit('sleep'),
      14 => t.vit('spo2'),
      30 => t.vit('luna'),
      _ => t.gold,
    };

String _pactModeLabel(String mode) => switch (mode) {
      'challenge' => 'Versus',
      'friends' => 'Friends',
      _ => 'Just Me',
    };

String _stakeLockHint(String stake) {
  final n = switch (stake) {
    'coffee' => 2,
    'dinner' || 'custom' => 5,
    _ => 3,
  };
  return 'Unlock after $n successful pacts';
}

class _ShareCodeRow extends StatelessWidget {
  const _ShareCodeRow({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $code',
                style: VyanaType.caption.copyWith(color: Colors.white)),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: t.gold.withValues(alpha: t.isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            VyanaIcon('key', size: 14, color: t.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Code $code · tap to copy',
                  style: VyanaType.label.copyWith(color: t.gold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtherRow extends StatelessWidget {
  const _OtherRow({required this.other, required this.busy, this.onEncourage});

  final PactOther other;
  final bool busy;
  final VoidCallback? onEncourage;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${other.displayName} · ${other.done}/${other.required}',
            style: VyanaType.label.copyWith(color: t.text),
          ),
        ),
        if (onEncourage != null)
          TextButton(
            onPressed: busy ? null : onEncourage,
            child: Text('Encourage',
                style: VyanaType.caption.copyWith(color: t.gold)),
          ),
      ],
    );
  }
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.gold.withValues(alpha: t.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VyanaIcon('sparkles', size: 14, color: t.gold),
          const SizedBox(width: 6),
          Text('$xp XP',
              style: VyanaType.mono10.copyWith(color: t.gold, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _LockHint extends StatelessWidget {
  const _LockHint({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          VyanaIcon('lock', size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: VyanaType.label.copyWith(color: color, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Draggable duration rail. Locked stops stay reachable so the lock copy can
/// fire; Start stays disabled until that stop is earned.
class _DurationRail extends StatelessWidget {
  const _DurationRail({
    required this.tiers,
    required this.selectedDays,
    required this.onSelect,
  });

  final List<PactWindowTier> tiers;
  final int selectedDays;
  final ValueChanged<int> onSelect;

  int get _index {
    final i = tiers.indexWhere((t) => t.days == selectedDays);
    return i < 0 ? 0 : i;
  }

  void _selectFromDx(double dx, double width) {
    if (tiers.isEmpty || width <= 0) return;
    final t = ((dx / width) * tiers.length).floor().clamp(0, tiers.length - 1);
    final next = tiers[t].days;
    if (next != selectedDays) onSelect(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _selectFromDx(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) =>
                  _selectFromDx(d.localPosition.dx, width),
              child: SizedBox(
                height: 36,
                width: width,
                child: CustomPaint(
                  painter: _DurationRailPainter(
                    colors: [
                      for (final tier in tiers) _pactWindowColor(t, tier.days)
                    ],
                    unlocked: [for (final tier in tiers) tier.unlocked],
                    selected: _index,
                    track: t.border,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < tiers.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(tiers[i].days),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Text(
                        tiers[i].shortLabel,
                        textAlign: TextAlign.center,
                        style: VyanaType.mono10.copyWith(
                          color: i == _index
                              ? _pactWindowColor(t, tiers[i].days)
                              : t.textMuted,
                        ),
                      ),
                      if (!tiers[i].unlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: VyanaIcon('lock',
                              size: 10,
                              color: i == _index
                                  ? _pactWindowColor(t, tiers[i].days)
                                  : t.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DurationRailPainter extends CustomPainter {
  _DurationRailPainter({
    required this.colors,
    required this.unlocked,
    required this.selected,
    required this.track,
  });

  final List<Color> colors;
  final List<bool> unlocked;
  final int selected;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    const gap = 4.0;
    const radius = 7.0;
    final n = colors.length;
    final segW = (size.width - gap * (n - 1)) / n;
    final cy = size.height / 2;
    const barH = 10.0;

    for (var i = 0; i < n; i++) {
      final x = i * (segW + gap);
      final color = colors[i];
      final open = unlocked[i];
      final rrect = RRect.fromLTRBR(
        x,
        cy - barH / 2,
        x + segW,
        cy + barH / 2,
        const Radius.circular(radius),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: open ? (i == selected ? 0.95 : 0.55) : 0.22),
      );
      if (!open) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: 0.45),
        );
      }
    }

    final thumbX = selected * (segW + gap) + segW / 2;
    final thumbColor = colors[selected.clamp(0, n - 1)];
    canvas.drawCircle(
      Offset(thumbX, cy),
      11,
      Paint()..color = thumbColor.withValues(alpha: 0.22),
    );
    canvas.drawCircle(Offset(thumbX, cy), 8, Paint()..color = thumbColor);
    canvas.drawCircle(
      Offset(thumbX, cy),
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_DurationRailPainter old) =>
      old.selected != selected ||
      old.colors != colors ||
      old.unlocked != unlocked ||
      old.track != track;
}

class _CapNote extends StatelessWidget {
  const _CapNote();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 16,
      child: Text(
        'Three live Pacts at once is the cap. Leave one, or wait until a '
        'window settles, to start another.',
        style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
      ),
    );
  }
}

class _EndedPactCard extends StatelessWidget {
  const _EndedPactCard({required this.snapshot, this.succeeded = false});

  final PactSnapshot snapshot;
  final bool succeeded;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 14,
      child: Row(
        children: [
          VyanaIconBadge(
            name: succeeded ? 'checkCircle' : 'target',
            color: succeeded ? t.green : t.textMuted,
            size: 38,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snapshot.pact.title,
                    style: VyanaType.label.copyWith(color: t.text)),
                const SizedBox(height: 3),
                Text(
                  succeeded
                      ? '${snapshot.me.done}/${snapshot.me.required} days · kept'
                      : '${snapshot.me.done}/${snapshot.me.required} days · this Pact ended',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VyanaIconBadge(name: 'shield', color: t.green, size: 34, iconSize: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A Pact proves completion, not your data',
                    style: VyanaType.label.copyWith(color: t.text)),
                const SizedBox(height: 6),
                Text(
                  'Only whether the day counted is stored. Sleep, HRV, resting '
                  'heart rate and bedtimes stay on this device.',
                  style:
                      VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
