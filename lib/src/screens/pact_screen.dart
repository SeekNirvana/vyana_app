part of '../../main.dart';

Future<void> openPact(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const PactScreen()));

// ---------------------------------------------------------------------------
// Pact logic (pure — the only parts with real rules while the UI is a preview)
// ---------------------------------------------------------------------------

/// Where a Pact stands right now. Drives the status chip and its colour.
enum PactStatus { secured, onTrack, atRisk, missed }

/// Status of a Pact from its counts alone.
///
/// [done] days already proven, [required] days needed to succeed,
/// [elapsed] days of the window that have passed, [total] window length.
PactStatus pactStatus({
  required int done,
  required int required,
  required int elapsed,
  required int total,
}) {
  if (done >= required) return PactStatus.secured;
  final needed = required - done;
  final remaining = total - elapsed;
  if (needed > remaining) return PactStatus.missed;
  if (needed == remaining) return PactStatus.atRisk;
  return PactStatus.onTrack;
}

String pactStatusLabel(PactStatus status) => switch (status) {
      PactStatus.secured => 'Secured',
      PactStatus.onTrack => 'On track',
      PactStatus.atRisk => 'No days to spare',
      PactStatus.missed => 'Missed',
    };

/// Friends-pool settlement (business doc §4.2): finishers get their own stake
/// back plus an equal share of the stakes left by those who did not finish.
/// Everyone finishing means everyone simply gets their stake back.
double pactPoolPayout({
  required double stake,
  required int participants,
  required int finishers,
}) {
  if (finishers <= 0) return 0;
  final forfeited = stake * (participants - finishers);
  return stake + forfeited / finishers;
}

// ---------------------------------------------------------------------------
// Mock data — mirrors HomeSeed. Replaced by real Pacts when the layer lands.
// ---------------------------------------------------------------------------

class PactMode {
  const PactMode(this.id, this.title, this.blurb, this.icon, this.accent);
  final String id;
  final String title;
  final String blurb;
  final String icon;
  final String accent;
}

class PactProgram {
  const PactProgram(this.title, this.category, this.window, this.by, this.icon,
      this.accent);
  final String title;
  final String category;
  final String window;
  final String by;
  final String icon;
  final String accent;
}

class PactFriend {
  const PactFriend(this.name, this.pact, this.done, this.required, this.backers);
  final String name;
  final String pact;
  final int done;
  final int required;
  final int backers;
}

class PactBacker {
  const PactBacker(this.name, this.pledge);
  final String name;
  final String pledge;
}

class PactSeed {
  PactSeed._();

  // The user's one live Pact.
  static const activeTitle = '7-Day Earlier Night';
  static const activeRule = 'In bed before 11:45 PM';
  static const activeDone = 4;
  static const activeRequired = 5;
  static const activeElapsed = 5;
  static const activeTotal = 7;
  static const activeStake = '\$25 + coffee from Dev';

  /// Per-day proof for the active window; `null` = day not reached yet.
  static const activeDays = <bool?>[true, true, false, true, true, null, null];

  static const backers = <PactBacker>[
    PactBacker('Dev', 'Coffee'),
    PactBacker('Meera', '\$20'),
    PactBacker('Work', '\$50 wellness credit'),
  ];

  static const modes = <PactMode>[
    PactMode('just_me', 'Just Me',
        'A promise to yourself. Stake something or nothing.', 'target', 'readiness'),
    PactMode('friends', 'With Friends',
        'Same commitment, together. Finishers split what quitters left.', 'user', 'hrv'),
    PactMode('challenge', 'Challenge Someone',
        'Same goal, friendly stakes. Coffee, pizza, bragging rights.', 'flame', 'stress'),
    PactMode('back', 'Back Someone',
        "Put something behind someone you believe in.", 'award', 'bp'),
  ];

  static const programs = <PactProgram>[
    PactProgram('21-Day Sleep Reset', 'Sleep', '21 days · 17 required',
        'Seek Nirvana expert', 'moon', 'sleep'),
    PactProgram('30-Day Meditation', 'Mindfulness', '30 days · 24 required',
        'Community', 'meditate', 'readiness'),
    PactProgram('Morning Walk Pact', 'Movement', '14 days · 11 required',
        'Community', 'walk', 'steps'),
    PactProgram('No Phone After 10 PM', 'Digital wellbeing', '30 days · 25 required',
        'Seek Nirvana', 'moon', 'luna'),
    PactProgram('Hydration Pact', 'Nutrition', '14 days · 12 required',
        'Community', 'drop', 'spo2'),
  ];

  static const friends = <PactFriend>[
    PactFriend('Shachindra', '21 days of meditation', 11, 17, 7),
    PactFriend('Anna', 'In bed before 11 PM', 18, 24, 3),
  ];

  // Friends-pool example rendered on the "With Friends" explainer.
  static const poolStake = 10.0;
  static const poolParticipants = 5;
  static const poolFinishers = 4;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Pact — the commitment layer. Preview build: the whole surface renders from
/// [PactSeed] and every action opens the "coming soon" sheet. Nothing here
/// creates, settles, or shares a real Pact yet.
class PactScreen extends StatelessWidget {
  const PactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
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
                  const _PreviewBadge(),
                ],
              ),
              const SizedBox(height: 14),
              const _PactHero(),
              const SizedBox(height: 18),
              const SectionHead(eyebrow: 'Your Pact', title: 'In progress'),
              const _ActivePactCard(),
              const SizedBox(height: 10),
              const _BackersCard(),
              const SizedBox(height: 18),
              const SectionHead(
                  eyebrow: 'Start one', title: 'Four ways to commit'),
              for (final mode in PactSeed.modes) ...[
                _ModeCard(mode: mode),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const SectionHead(
                  eyebrow: 'From your signals', title: 'Suggested by Vyana'),
              const _SuggestedPactCard(),
              const SizedBox(height: 18),
              const SectionHead(
                  eyebrow: 'Explore', title: 'Commitment programs'),
              const _ProgramRail(),
              const SizedBox(height: 18),
              const SectionHead(eyebrow: 'People', title: 'Back someone'),
              for (final friend in PactSeed.friends) ...[
                _FriendPactCard(friend: friend),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const _PrivacyNote(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every action in this preview lands here, so nothing looks broken or fakes
/// a result. Names the feature and says what it will do.
void pactComingSoon(BuildContext context, String feature, String detail) {
  final t = context.vyana;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom),
      child: Panel(
        pad: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VyanaIconBadge(name: 'timer', color: t.gold, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('COMING SOON',
                          style: VyanaType.eyebrow.copyWith(color: t.gold)),
                      const SizedBox(height: 3),
                      Text(feature,
                          style: VyanaType.titleSerif
                              .copyWith(color: t.text, fontSize: 20)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(detail,
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5)),
            const SizedBox(height: 18),
            Cta(
              label: 'Got it',
              icon: 'check',
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Home-tab entry: the live Pact at a glance, or the invitation to make one.
/// Progress only — never a vital.
class _PactHomeCard extends StatelessWidget {
  const _PactHomeCard();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final status = pactStatus(
      done: PactSeed.activeDone,
      required: PactSeed.activeRequired,
      elapsed: PactSeed.activeElapsed,
      total: PactSeed.activeTotal,
    );
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
                Row(
                  children: [
                    Flexible(
                      child: Text(PactSeed.activeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VyanaType.titleSerif
                              .copyWith(color: t.text, fontSize: 17)),
                    ),
                    const SizedBox(width: 8),
                    const _PreviewBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${PactSeed.activeDone}/${PactSeed.activeRequired} days · '
                  '${pactStatusLabel(status)}',
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

/// Honest label so a preview screen is never mistaken for a live feature.
class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.gold.withValues(alpha: t.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.gold.withValues(alpha: 0.45)),
      ),
      child: Text('PREVIEW',
          style: VyanaType.mono10.copyWith(color: t.gold, letterSpacing: 0.6)),
    );
  }
}

class _PactHero extends StatelessWidget {
  const _PactHero();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      grad: true,
      pad: 20,
      accent: t.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bet on the person you want to become.',
              style: VyanaType.titleSerif
                  .copyWith(color: t.text, fontSize: 23, height: 1.25)),
          const SizedBox(height: 10),
          Text(
            'Vyana helps you know what to change. Pact helps you actually do '
            'it — a commitment with something behind it. Money, coffee, or '
            'simply your word.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
          ),
          const SizedBox(height: 16),
          Cta(
            label: 'Make a Pact',
            icon: 'target',
            onTap: () => pactComingSoon(
              context,
              'Making a Pact',
              'Pact creation is in build. You will choose the commitment, the '
                  'window, what counts as a day, who joins, and what — if '
                  'anything — is at stake.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePactCard extends StatelessWidget {
  const _ActivePactCard();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    const done = PactSeed.activeDone;
    const required = PactSeed.activeRequired;
    final status = pactStatus(
      done: done,
      required: required,
      elapsed: PactSeed.activeElapsed,
      total: PactSeed.activeTotal,
    );
    final c = switch (status) {
      PactStatus.secured => t.green,
      PactStatus.onTrack => t.green,
      PactStatus.atRisk => t.gold,
      PactStatus.missed => t.vit('hr'),
    };

    return Panel(
      pad: 16,
      accent: c,
      onTap: () => pactComingSoon(
        context,
        'Pact detail',
        'The full Pact view — day-by-day proof, participants, stakes and '
            'settlement — arrives with the commitment layer.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: done.toDouble(),
                max: required.toDouble(),
                size: 58,
                stroke: 5,
                color: c,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$done/$required',
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
                    Text(PactSeed.activeTitle,
                        style: VyanaType.titleSerif
                            .copyWith(color: t.text, fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      '${PactSeed.activeRule} · '
                      '${PactSeed.activeTotal - PactSeed.activeElapsed} days left',
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
          const _DayDots(days: PactSeed.activeDays),
          const SizedBox(height: 14),
          Row(
            children: [
              VyanaIcon('wallet', size: 15, color: t.gold),
              const SizedBox(width: 7),
              Expanded(
                child: Text('At stake · ${PactSeed.activeStake}',
                    style: VyanaType.caption.copyWith(color: t.textSec)),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                  child: Text(
                    "Today's commitment completed",
                    style: VyanaType.label.copyWith(color: t.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven dots — proven, missed, or still ahead. Reads at a glance without
/// exposing a single number from the night behind it.
class _DayDots extends StatelessWidget {
  const _DayDots({required this.days});

  final List<bool?> days;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: switch (days[i]) {
                      true => t.green.withValues(alpha: t.isDark ? 0.24 : 0.16),
                      false => t.vit('hr').withValues(alpha: t.isDark ? 0.2 : 0.12),
                      null => Colors.transparent,
                    },
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: switch (days[i]) {
                        true => t.green.withValues(alpha: 0.5),
                        false => t.vit('hr').withValues(alpha: 0.4),
                        null => t.border,
                      },
                    ),
                  ),
                  child: Center(
                    child: days[i] == null
                        ? Text('${i + 1}',
                            style: VyanaType.mono10.copyWith(color: t.textMuted))
                        : VyanaIcon(
                            days[i]! ? 'check' : 'x',
                            size: 13,
                            color: days[i]! ? t.green : t.vit('hr'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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

class _BackersCard extends StatelessWidget {
  const _BackersCard();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VyanaIconBadge(name: 'award', color: t.gold, size: 34, iconSize: 17),
              const SizedBox(width: 11),
              Expanded(
                child: Text('${PactSeed.backers.length} people backing you',
                    style: VyanaType.label.copyWith(color: t.text, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final backer in PactSeed.backers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: t.gold.withValues(alpha: t.isDark ? 0.2 : 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(backer.name.characters.first,
                          style: VyanaType.mono10.copyWith(color: t.gold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(backer.name,
                        style: VyanaType.bodySm.copyWith(color: t.textSec)),
                  ),
                  Text(backer.pledge,
                      style: VyanaType.label.copyWith(color: t.gold)),
                ],
              ),
            ),
          Text(
            'Pledges unlock only if you finish. Nothing moves until then.',
            style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final PactMode mode;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = t.vit(mode.accent);
    final extra = mode.id == 'friends'
        ? '5 friends × \$10 · 4 finish → '
            '\$${pactPoolPayout(
              stake: PactSeed.poolStake,
              participants: PactSeed.poolParticipants,
              finishers: PactSeed.poolFinishers,
            ).toStringAsFixed(2)} each'
        : null;

    return Panel(
      pad: 14,
      radius: 20,
      onTap: () => pactComingSoon(
        context,
        mode.title,
        '${mode.blurb} This mode is designed and in build — creation, invites '
            'and settlement are not live yet.',
      ),
      child: Row(
        children: [
          VyanaIconBadge(
              name: mode.icon, color: c, size: 44, iconSize: 21, borderRadius: 14),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mode.title,
                    style: VyanaType.label.copyWith(color: t.text, fontSize: 15)),
                const SizedBox(height: 3),
                Text(mode.blurb,
                    style: VyanaType.caption
                        .copyWith(color: t.textSec, height: 1.4)),
                if (extra != null) ...[
                  const SizedBox(height: 6),
                  Text(extra, style: VyanaType.mono10.copyWith(color: c)),
                ],
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

/// The loop from the business doc: a Vyana signal becomes a commitment.
class _SuggestedPactCard extends StatelessWidget {
  const _SuggestedPactCard();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 16,
      accent: t.vit('sleep'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VyanaIconBadge(
                  name: 'moon', color: t.vit('sleep'), size: 34, iconSize: 17),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Your bedtime moved about 45 minutes later over the past two '
                  'weeks.',
                  style:
                      VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('7-Day Earlier Night',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 19)),
          const SizedBox(height: 4),
          Text('Be in bed before 11:45 PM on at least 5 of the next 7 nights.',
              style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45)),
          const SizedBox(height: 14),
          Cta(
            label: 'Make this a Pact',
            icon: 'target',
            onTap: () => pactComingSoon(
              context,
              'Suggested Pacts',
              'Vyana will turn a pattern it notices into a ready-made Pact you '
                  'can accept in one tap. Your signals never leave the phone — '
                  'the Pact only carries whether the day counted.',
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Cta(
                  label: 'Invite a friend',
                  icon: 'user',
                  solid: false,
                  onTap: () => pactComingSoon(
                    context,
                    'Invites',
                    'Invite links that bring a friend into the same commitment '
                        'are part of the social layer, still in build.',
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Cta(
                  label: 'Ask to be backed',
                  icon: 'award',
                  solid: false,
                  onTap: () => pactComingSoon(
                    context,
                    'Backing',
                    'Friends, family or your employer will be able to put '
                        'something behind your Pact that you unlock by '
                        'finishing.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramRail extends StatelessWidget {
  const _ProgramRail();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: PactSeed.programs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = PactSeed.programs[i];
          final c = t.vit(p.accent);
          return SizedBox(
            width: 208,
            child: Panel(
              pad: 14,
              radius: 20,
              onTap: () => pactComingSoon(
                context,
                p.title,
                'Expert, community and sponsored programs will be joinable '
                    'here, with an optional Pact attached to keep you in it.',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VyanaIconBadge(
                      name: p.icon, color: c, size: 38, iconSize: 19),
                  const SizedBox(height: 12),
                  Text(p.category.toUpperCase(),
                      style: VyanaType.eyebrow.copyWith(color: c)),
                  const SizedBox(height: 5),
                  Text(p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.label
                          .copyWith(color: t.text, fontSize: 15, height: 1.3)),
                  const Spacer(),
                  Text(p.window,
                      style: VyanaType.caption.copyWith(color: t.textSec)),
                  const SizedBox(height: 2),
                  Text(p.by,
                      style: VyanaType.mono10.copyWith(color: t.textMuted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FriendPactCard extends StatelessWidget {
  const _FriendPactCard({required this.friend});

  final PactFriend friend;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.green.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(friend.name.characters.first,
                      style: VyanaType.label.copyWith(color: t.green)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${friend.name} started a Pact',
                        style: VyanaType.label.copyWith(color: t.text)),
                    const SizedBox(height: 3),
                    Text(
                      '${friend.pact} · day ${friend.done}/${friend.required} '
                      '· ${friend.backers} backing',
                      style: VyanaType.caption.copyWith(color: t.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Cta(
                  label: 'Back them',
                  icon: 'award',
                  onTap: () => pactComingSoon(
                    context,
                    'Backing ${friend.name}',
                    'Pledging a coffee, a reward or a stake behind someone '
                        "else's Pact is next up after Pact creation.",
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Cta(
                  label: 'Encourage',
                  icon: 'send',
                  solid: false,
                  onTap: () => pactComingSoon(
                    context,
                    'Encouragement',
                    'Short notes of support — no feed, no comments, no metrics '
                        'shared.',
                  ),
                ),
              ),
            ],
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
                  'Your phone decides whether a day counted. Everyone else — '
                  'friends, sponsors, your employer — sees only “completed ✓”. '
                  'Sleep, HRV, resting heart rate and bedtimes stay on this '
                  'device.',
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
