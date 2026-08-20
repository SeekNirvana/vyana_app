part of '../../main.dart';

Future<void> openPactFriends(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const PactFriendsScreen()));

Future<void> openPactCircle(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const PactCircleScreen()));

Future<void> openPactBoard(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const PactBoardScreen()));

Future<void> openPactBacking(BuildContext context) => openPactFriends(context);

Future<void> openPactJoin(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => const _JoinPactSheet(),
);

class _PactSubpage extends StatelessWidget {
  const _PactSubpage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    IconBtn(
                      icon: 'chevL',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        style: VyanaType.appBarSerif.copyWith(color: t.text),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class PactFriendsScreen extends ConsumerWidget {
  const PactFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    return _PactSubpage(
      title: 'Friends',
      child: RefreshIndicator(
        color: t.gold,
        onRefresh: () => ref.read(pactControllerProvider.notifier).refresh(),
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: PactFriendsBody(),
        ),
      ),
    );
  }
}

class PactFriendsBody extends ConsumerStatefulWidget {
  const PactFriendsBody({super.key});

  @override
  ConsumerState<PactFriendsBody> createState() => _PactFriendsBodyState();
}

class _PactFriendsBodyState extends ConsumerState<PactFriendsBody> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _join = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _join.dispose();
    super.dispose();
  }

  List<_FriendPactRow> _theirPacts(PactState state) {
    final seen = <String>{};
    for (final row in state.backing) {
      seen.add('${row.pact.id}:${row.participantId}');
    }
    final rows = <_FriendPactRow>[];
    for (final row in state.backable) {
      final key = '${row.pact.id}:${row.participantId}';
      seen.add(key);
      rows.add(
        _FriendPactRow(
          pact: row.pact,
          person: row.person,
          participantId: row.participantId,
          canBack: true,
        ),
      );
    }
    for (final item in state.feed) {
      final id = item.participant.participantId ?? '';
      final key = '${item.pact.id}:$id';
      if (seen.contains(key)) continue;
      seen.add(key);
      rows.add(
        _FriendPactRow(
          pact: item.pact,
          person: item.participant,
          participantId: id,
          canBack: state.canBack(item.pact.id, id),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final state = ref.watch(pactControllerProvider);
    final actions = ref.read(pactControllerProvider.notifier);
    final theirPacts = _theirPacts(state);
    final board = state.friendsBoard?.entries ?? const <PactProfile>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.friendRequests.incoming.isNotEmpty) ...[
          const SectionHead(eyebrow: 'Waiting', title: 'They asked'),
          for (final req in state.friendRequests.incoming) ...[
            Panel(
              pad: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      req.profile.displayName,
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                  ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => actions.respondFriend(req.id, 'accept'),
                    child: Text(
                      'Accept',
                      style: VyanaType.caption.copyWith(color: t.green),
                    ),
                  ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => actions.respondFriend(req.id, 'decline'),
                    child: Text(
                      'Decline',
                      style: VyanaType.caption.copyWith(color: t.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SectionHead(eyebrow: 'Add', title: 'Find someone'),
        Panel(
          pad: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBox(
                child: TextField(
                  controller: _email,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.emailAddress,
                  style: VyanaType.body.copyWith(color: t.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Email',
                    hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Cta(
                label: 'Send request',
                icon: 'send',
                disabled: state.busy || _email.text.trim().isEmpty,
                onTap: () {
                  actions.addFriend(email: _email.text.trim());
                  _email.clear();
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _FieldBox(
                child: TextField(
                  controller: _code,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  style: VyanaType.body.copyWith(color: t.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Friend invite code',
                    hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Cta(
                label: 'Use code',
                icon: 'key',
                solid: false,
                disabled: state.busy || _code.text.trim().isEmpty,
                onTap: () {
                  actions.addFriend(inviteCode: _code.text.trim());
                  _code.clear();
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              Cta(
                label: 'Mint a friend code',
                icon: 'plus',
                solid: false,
                disabled: state.busy,
                onTap: () async {
                  final invite = await actions.mintFriendInvite();
                  if (invite == null || !context.mounted) return;
                  await Clipboard.setData(ClipboardData(text: invite.code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied ${invite.code}',
                        style: VyanaType.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHead(eyebrow: 'Join', title: 'A pact already running'),
        Panel(
          pad: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBox(
                child: TextField(
                  controller: _join,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  style: VyanaType.body.copyWith(color: t.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Share code',
                    hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Cta(
                label: 'Join',
                icon: 'arrowR',
                disabled: state.busy || _join.text.trim().isEmpty,
                onTap: () async {
                  final ok = await actions.joinPact(
                    shareCode: _join.text.trim(),
                  );
                  if (ok) {
                    _join.clear();
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
        if (state.backing.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHead(eyebrow: 'Yours', title: "You're backing"),
          for (final row in state.backing) ...[
            Panel(
              pad: 16,
              accent: t.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.person.displayName,
                    style: VyanaType.titleSerif.copyWith(
                      color: t.text,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.pact.title} · ${row.person.done}/${row.person.required}',
                    style: VyanaType.caption.copyWith(color: t.textSec),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    row.backing?.item.isNotEmpty == true
                        ? 'You pledged ${row.backing!.item}'
                        : 'You backed them',
                    style: VyanaType.label.copyWith(color: t.gold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 8),
        const SectionHead(eyebrow: 'Keeping', title: 'Their pacts'),
        if (theirPacts.isEmpty)
          Panel(
            pad: 16,
            child: Text(
              'When a friend starts a pact you can see, it lands here. '
              'Back them from this list — no coffee or lunch filter.',
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
            ),
          )
        else
          for (final row in theirPacts) ...[
            Panel(
              pad: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.person.displayName,
                    style: VyanaType.titleSerif.copyWith(
                      color: t.text,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.pact.title} · ${row.person.done}/${row.person.required}',
                    style: VyanaType.caption.copyWith(color: t.textSec),
                  ),
                  if (row.canBack) ...[
                    const SizedBox(height: 12),
                    Cta(
                      label: 'Back them',
                      icon: 'heart',
                      disabled: state.busy,
                      onTap: () => actions.backSomeone(
                        pactId: row.pact.id,
                        participantId: row.participantId,
                        itemLabel: 'Backing',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 8),
        const SectionHead(eyebrow: 'This week', title: 'Your people'),
        if (state.friends.isEmpty)
          Panel(
            pad: 16,
            child: Text(
              'No friends yet. Send an email or share a code.',
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
            ),
          )
        else
          for (final friend in state.friends) ...[
            Panel(
              pad: 14,
              child: Row(
                children: [
                  VyanaIconBadge(
                    name: 'user',
                    color: t.gold,
                    size: 38,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName,
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${friend.weeklyPactXp} XP this week · '
                          '${friend.pactsCompleted} kept',
                          style: VyanaType.caption.copyWith(color: t.textSec),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        if (board.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionHead(eyebrow: 'Board', title: 'This week'),
          for (final row in board) ...[
            Panel(
              pad: 14,
              accent: row.isYou ? t.gold : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${row.rank}',
                      style: VyanaType.mono10.copyWith(
                        color: row.isYou ? t.gold : t.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.isYou ? '${row.displayName} · you' : row.displayName,
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                  ),
                  Text(
                    '${row.weeklyPactXp} XP',
                    style: VyanaType.caption.copyWith(
                      color: row.isYou ? t.gold : t.textSec,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _FriendPactRow {
  const _FriendPactRow({
    required this.pact,
    required this.person,
    required this.participantId,
    required this.canBack,
  });

  final PactRecord pact;
  final PactOther person;
  final String participantId;
  final bool canBack;
}

class PactBoardScreen extends ConsumerStatefulWidget {
  const PactBoardScreen({super.key});

  @override
  ConsumerState<PactBoardScreen> createState() => _PactBoardScreenState();
}

class _PactBoardScreenState extends ConsumerState<PactBoardScreen> {
  String _scope = 'friends';
  String? _communityId;
  PactLeaderboard? _board;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final board = await ref
          .read(pactClientProvider)
          .leaderboard(scope: _scope, communityId: _communityId);
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
        _error = null;
      });
    } on PactException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pactErrorMessage(error.error);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach Seek Nirvana.';
        _loading = false;
      });
    }
  }

  void _select(String scope, {String? communityId}) {
    setState(() {
      _scope = scope;
      _communityId = communityId;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final entries = _board?.entries ?? const <PactProfile>[];
    final communities = ref
        .watch(pactControllerProvider)
        .communities
        .where((c) => !c.isInvited)
        .toList();
    final scopes = _board?.availableScopes.isNotEmpty == true
        ? _board!.availableScopes
        : const ['friends', 'members'];
    return _PactSubpage(
      title: 'Board',
      child: RefreshIndicator(
        color: t.gold,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            Text(
              'This week’s pact XP. A new week is always winnable.',
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (scopes.contains('friends'))
                  Pill(
                    label: 'friends',
                    active: _scope == 'friends',
                    onTap: () => _select('friends'),
                  ),
                if (scopes.contains('community'))
                  for (final circle in communities)
                    Pill(
                      label: circle.name,
                      active:
                          _scope == 'community' && _communityId == circle.id,
                      onTap: () => _select('community', communityId: circle.id),
                    ),
                if (scopes.contains('members'))
                  Pill(
                    label: 'members',
                    active: _scope == 'members',
                    onTap: () => _select('members'),
                  ),
                if (scopes.contains('global'))
                  Pill(
                    label: 'global',
                    active: _scope == 'global',
                    onTap: () => _select('global'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.gold,
                  ),
                ),
              )
            else if (_error != null)
              Panel(
                pad: 16,
                child: Text(
                  _error!,
                  style: VyanaType.bodySm.copyWith(color: t.textSec),
                ),
              )
            else if (_board?.isPercentile == true)
              Panel(
                pad: 18,
                accent: t.gold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _board!.rank != null
                          ? '#${_board!.rank}'
                          : 'Top ${_board!.percentile ?? 0}%',
                      style: VyanaType.appBarSerif.copyWith(
                        color: t.gold,
                        fontSize: 32,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _board!.rank != null
                          ? 'You are in the top slice this week · ${_board!.weeklyPactXp} XP'
                          : '${_board!.weeklyPactXp} XP this week · ${_board!.population} people on the board',
                      style: VyanaType.bodySm.copyWith(
                        color: t.textSec,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              )
            else if (entries.isEmpty)
              Panel(
                pad: 16,
                child: Text(
                  _scope == 'friends'
                      ? 'No friends on the board this week yet.'
                      : _scope == 'community'
                      ? 'Nobody in this circle has earned pact XP this week yet.'
                      : 'Nobody has earned pact XP this week yet.',
                  style: VyanaType.bodySm.copyWith(
                    color: t.textSec,
                    height: 1.45,
                  ),
                ),
              )
            else
              for (final row in entries) ...[
                Panel(
                  pad: 14,
                  accent: row.isYou ? t.gold : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${row.rank}',
                          style: VyanaType.mono10.copyWith(
                            color: row.isYou ? t.gold : t.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.isYou
                              ? '${row.displayName} · you'
                              : row.displayName,
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                      ),
                      Text(
                        '${row.weeklyPactXp} XP',
                        style: VyanaType.caption.copyWith(
                          color: row.isYou ? t.gold : t.textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _JoinPactSheet extends ConsumerStatefulWidget {
  const _JoinPactSheet();

  @override
  ConsumerState<_JoinPactSheet> createState() => _JoinPactSheetState();
}

class _JoinPactSheetState extends ConsumerState<_JoinPactSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final busy = ref.watch(pactControllerProvider).busy;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join a Pact',
                style: VyanaType.titleSerif.copyWith(
                  color: t.text,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste a share code. You can join while a window is still running.',
                style: VyanaType.bodySm.copyWith(
                  color: t.textSec,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              _FieldBox(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  style: VyanaType.body.copyWith(color: t.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Share code',
                    hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Cta(
                label: 'Join',
                icon: 'arrowR',
                disabled: busy || _code.text.trim().isEmpty,
                onTap: () async {
                  final ok = await ref
                      .read(pactControllerProvider.notifier)
                      .joinPact(shareCode: _code.text.trim());
                  if (ok && context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PactCircleScreen extends ConsumerWidget {
  const PactCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    return _PactSubpage(
      title: 'Circle',
      child: RefreshIndicator(
        color: t.gold,
        onRefresh: () => ref.read(pactControllerProvider.notifier).refresh(),
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: PactCircleBody(),
        ),
      ),
    );
  }
}

class PactCircleBody extends ConsumerStatefulWidget {
  const PactCircleBody({super.key});

  @override
  ConsumerState<PactCircleBody> createState() => _PactCircleBodyState();
}

class _PactCircleBodyState extends ConsumerState<PactCircleBody> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final state = ref.watch(pactControllerProvider);
    final actions = ref.read(pactControllerProvider.notifier);
    final unlocks = state.unlocks;
    final invited = state.communities.where((c) => c.isInvited).toList();
    final mine = state.communities.where((c) => !c.isInvited).toList();
    final canCreate = (unlocks?.canCircles ?? false) && !state.ownsCircle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (invited.isNotEmpty) ...[
          const SectionHead(eyebrow: 'Waiting', title: 'You were asked'),
          for (final circle in invited) ...[
            Panel(
              pad: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      circle.name,
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                  ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => actions.joinCircle(circle.id),
                    child: Text(
                      'Accept',
                      style: VyanaType.caption.copyWith(color: t.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (canCreate) ...[
          const SectionHead(eyebrow: 'Start', title: 'A circle of twelve'),
          Panel(
            pad: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite people you already know. A circle stays small so the board is still winnable.',
                  style: VyanaType.bodySm.copyWith(
                    color: t.textSec,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                _FieldBox(
                  child: TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                    style: VyanaType.body.copyWith(color: t.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Name',
                      hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Cta(
                  label: 'Create circle',
                  icon: 'users',
                  disabled: state.busy || _name.text.trim().length < 2,
                  onTap: () {
                    actions.createCircle(name: _name.text.trim());
                    _name.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (unlocks != null && !unlocks.canCircles) ...[
          const SectionHead(eyebrow: 'Circle', title: 'Still ahead'),
          _LockHint(message: unlocks.circlesLockHint, color: t.gold),
          const SizedBox(height: 16),
        ],
        const SectionHead(eyebrow: 'Yours', title: 'Rooms'),
        if (mine.isEmpty)
          Panel(
            pad: 16,
            child: Text(
              'A circle is twelve people, tops. Finish 7 pacts to start one, or wait for an invite.',
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
            ),
          )
        else
          for (final circle in mine) ...[
            Panel(
              pad: 16,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => PactCircleDetailScreen(id: circle.id),
                ),
              ),
              child: Row(
                children: [
                  VyanaIconBadge(
                    name: 'users',
                    color: t.gold,
                    size: 38,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          circle.name,
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${circle.seats}'
                          '${circle.hasWave ? ' · wave live' : ''}'
                          '${circle.isOwner ? ' · you own' : ''}',
                          style: VyanaType.caption.copyWith(color: t.textSec),
                        ),
                      ],
                    ),
                  ),
                  VyanaIcon('chevR', size: 17, color: t.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class PactCircleDetailScreen extends ConsumerStatefulWidget {
  const PactCircleDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<PactCircleDetailScreen> createState() =>
      _PactCircleDetailScreenState();
}

class _PactCircleDetailScreenState
    extends ConsumerState<PactCircleDetailScreen> {
  PactCommunity? _circle;
  bool _loading = true;
  final _title = TextEditingController();
  final _rule = TextEditingController();
  final _join = TextEditingController();
  final Set<String> _invitees = {};
  int _window = 7;
  int _required = 5;
  String? _stake;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _title.dispose();
    _rule.dispose();
    _join.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final circle = await ref
        .read(pactControllerProvider.notifier)
        .loadCircle(widget.id);
    if (!mounted) return;
    setState(() {
      _circle = circle;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final state = ref.watch(pactControllerProvider);
    final actions = ref.read(pactControllerProvider.notifier);
    final circle = _circle;
    final unlocks = state.unlocks;
    final memberIds = {
      for (final m in circle?.members ?? const []) m.profileId,
    };
    final inviteable = state.friends
        .where((f) => !memberIds.contains(f.profileId))
        .toList();
    final windows =
        unlocks?.windowTiers.where((w) => w.unlocked).toList() ??
        const <PactWindowTier>[];

    return _PactSubpage(
      title: circle?.name ?? 'Circle',
      child: RefreshIndicator(
        color: t.gold,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            if (_loading)
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.gold,
                  ),
                ),
              )
            else if (circle == null)
              Panel(
                pad: 16,
                child: Text(
                  'That circle is gone.',
                  style: VyanaType.bodySm.copyWith(color: t.textSec),
                ),
              )
            else ...[
              Text(
                '${circle.seats} · ${circle.kind}'
                '${circle.hasWave ? ' · a wave is live' : ''}',
                style: VyanaType.bodySm.copyWith(
                  color: t.textSec,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              const SectionHead(eyebrow: 'This week', title: 'People'),
              if (circle.members.isEmpty)
                Panel(
                  pad: 16,
                  child: Text(
                    'No one here yet.',
                    style: VyanaType.bodySm.copyWith(color: t.textSec),
                  ),
                )
              else
                for (final row in circle.members) ...[
                  Panel(
                    pad: 14,
                    accent: row.isYou ? t.gold : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.isYou
                                ? '${row.displayName} · you'
                                : row.displayName,
                            style: VyanaType.label.copyWith(color: t.text),
                          ),
                        ),
                        Text(
                          row.status == 'invited'
                              ? 'invited'
                              : '${row.weeklyPactXp} XP',
                          style: VyanaType.caption.copyWith(color: t.textSec),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              if (circle.isOwner) ...[
                const SizedBox(height: 8),
                const SectionHead(eyebrow: 'Invite', title: 'Friends only'),
                if (inviteable.isEmpty)
                  Panel(
                    pad: 16,
                    child: Text(
                      'Add a friend first, then invite them in.',
                      style: VyanaType.bodySm.copyWith(
                        color: t.textSec,
                        height: 1.45,
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final friend in inviteable)
                        Pill(
                          label: friend.displayName,
                          active: _invitees.contains(friend.profileId),
                          onTap: () => setState(() {
                            if (_invitees.contains(friend.profileId)) {
                              _invitees.remove(friend.profileId);
                            } else {
                              _invitees.add(friend.profileId);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Cta(
                    label: 'Send invites',
                    icon: 'send',
                    disabled: state.busy || _invitees.isEmpty,
                    onTap: () async {
                      final ok = await actions.inviteToCircle(
                        widget.id,
                        _invitees.toList(),
                      );
                      if (ok) {
                        _invitees.clear();
                        await _reload();
                      }
                    },
                  ),
                ],
                if (!circle.hasWave) ...[
                  const SizedBox(height: 16),
                  const SectionHead(eyebrow: 'Wave', title: 'Start one'),
                  Panel(
                    pad: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldBox(
                          child: TextField(
                            controller: _title,
                            onChanged: (_) => setState(() {}),
                            textCapitalization: TextCapitalization.sentences,
                            style: VyanaType.body.copyWith(color: t.text),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Title',
                              hintStyle: VyanaType.body.copyWith(
                                color: t.textMuted,
                              ),
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
                              hintStyle: VyanaType.body.copyWith(
                                color: t.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tier in windows)
                              Pill(
                                label: tier.shortLabel,
                                active: _window == tier.days,
                                onTap: () => setState(() {
                                  _window = tier.days;
                                  if (_required > _window) _required = _window;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Pill(
                              label: 'no stake',
                              active: _stake == null,
                              onTap: () => setState(() => _stake = null),
                            ),
                            for (final stake
                                in unlocks?.stakes ?? const <String>[])
                              Pill(
                                label: stake,
                                active: _stake == stake,
                                onTap: () => setState(() => _stake = stake),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Cta(
                          label: 'Start the wave',
                          icon: 'target',
                          disabled:
                              state.busy ||
                              _title.text.trim().isEmpty ||
                              _rule.text.trim().isEmpty,
                          onTap: () async {
                            final days = windows.any((w) => w.days == _window)
                                ? _window
                                : (windows.isEmpty ? 3 : windows.first.days);
                            final need = _required > days ? days : _required;
                            final pact = await actions.startCirclePact(
                              widget.id,
                              PactCreateInput(
                                title: _title.text.trim(),
                                ruleText: _rule.text.trim(),
                                category: 'mindfulness',
                                windowDays: days,
                                requiredDays: need,
                                mode: 'friends',
                                stakeCatalog: _stake,
                                visibility: 'friends',
                              ),
                            );
                            if (pact == null || !context.mounted) return;
                            await Clipboard.setData(
                              ClipboardData(text: pact.shareCode),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Copied ${pact.shareCode}',
                                  style: VyanaType.caption.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                            await _reload();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (circle.hasWave && !circle.isOwner) ...[
                const SizedBox(height: 16),
                const SectionHead(eyebrow: 'Wave', title: 'Join with a code'),
                Panel(
                  pad: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The owner has a share code. You can join while the window is still running.',
                        style: VyanaType.bodySm.copyWith(
                          color: t.textSec,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FieldBox(
                        child: TextField(
                          controller: _join,
                          onChanged: (_) => setState(() {}),
                          textCapitalization: TextCapitalization.characters,
                          style: VyanaType.body.copyWith(color: t.text),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Share code',
                            hintStyle: VyanaType.body.copyWith(
                              color: t.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Cta(
                        label: 'Join the wave',
                        icon: 'arrowR',
                        disabled: state.busy || _join.text.trim().isEmpty,
                        onTap: () async {
                          final ok = await actions.joinPact(
                            shareCode: _join.text.trim(),
                          );
                          if (ok && context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Cta(
                label: circle.isOwner ? 'Close this circle' : 'Leave',
                icon: 'x',
                solid: false,
                disabled: state.busy,
                onTap: () async {
                  final ok = await actions.leaveCircle(widget.id);
                  if (ok && context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
