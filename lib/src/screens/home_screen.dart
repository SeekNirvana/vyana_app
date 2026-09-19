part of '../../main.dart';

/// Home answers "how am I today" — one read, three metrics, one suggested
/// action. Not a catalogue and not a dashboard.
///
/// There is a split here that matters more than any layout decision:
/// everything above the intent row is *measured* (what your body did, which
/// you did not choose) and everything below is *chosen* (what you intend to
/// do about it). Intent colour never touches the score.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        unawaited(ref.read(dayIntentProvider.notifier).ensureToday());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(ringControllerProvider);
    final dashboard = HomeDashboard.from(controller);
    final state = controller.currentWellnessState();
    final hasRing = controller.hasRingContext;
    final moment = homeMomentAt(DateTime.now());
    final intentState = ref.watch(dayIntentProvider);
    final intent = intentState.intent ?? DayIntent.recover;
    final stale =
        ringUiStateOf(controller) == RingUiState.stale ||
        ringUiStateOf(controller) == RingUiState.disconnected;

    // Re-derive the pre-set once ring history lands (the first build may run
    // before the cache hydrates).
    ref.listen<RingController>(ringControllerProvider, (prev, next) {
      if (prev?.history.totalRecords != next.history.totalRecords) {
        unawaited(ref.read(dayIntentProvider.notifier).ensureToday());
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 176),
      children: [
        _HomeHeader(controller: controller),
        if (!hasRing) ...[
          const SizedBox(height: 6),
          _DiscoverRingPanel(controller: controller),
          const SizedBox(height: 18),
        ],
        // ── Measured ───────────────────────────────────────────────────────
        // "Check vitals" runs the hands-off Monitor-all-vitals pass (the
        // eyebrow shows progress); Metrics is one tap away on the nav.
        QuietHeading(
          "Today's read",
          action: !hasRing
              ? null
              : controller.allVitalsRunning
              ? 'Checking…'
              : 'Check vitals',
          onAction: controller.allVitalsRunning
              ? null
              : () => unawaited(controller.runAllVitals()),
        ),
        const SizedBox(height: 14),
        _ReadinessRead(
          controller: controller,
          dashboard: dashboard,
          state: state,
          intent: intent,
          stale: stale,
          hasRing: hasRing,
        ),
        const SizedBox(height: 16),
        _MetricCards(
          controller: controller,
          dashboard: dashboard,
          stale: stale,
          hasRing: hasRing,
        ),
        // ── Chosen ─────────────────────────────────────────────────────────
        const SizedBox(height: 22),
        const IntentRow(),
        const SizedBox(height: 22),
        _SuggestedPractice(
          intent: intent,
          state: state,
          readiness: dashboard.readinessScore,
          moment: moment,
        ),
      ],
    );
  }
}

enum HomeMoment { morning, day, night }

HomeMoment homeMomentAt(DateTime time) {
  if (time.hour >= 5 && time.hour < 12) return HomeMoment.morning;
  if (time.hour >= 18 || time.hour < 5) return HomeMoment.night;
  return HomeMoment.day;
}

// ── Header ──────────────────────────────────────────────────────────────────

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.controller});
  final RingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final c = controller;
    final greeting = ref
        .watch(userProfileProvider)
        .maybeWhen(data: (p) => p.homeGreeting, orElse: () => 'Welcome');
    var eyebrow = ringEyebrowFor(c, t);
    if (c.allVitalsRunning) {
      final total = c.allVitalsTotal;
      final done = c.allVitalsDone;
      final label = c.allVitalsCurrentLabel;
      eyebrow = (
        text: total == 0
            ? 'READING YOUR VITALS'
            : 'READING${label == null ? '' : ' $label'} · $done OF $total',
        color: t.gold,
        pulse: true,
      );
    }
    final battery = c.batteryPercent;
    final uiState = ringUiStateOf(c);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => openScanner(context, c),
            child: const Seal(size: 34),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    RingStatusDot(color: eyebrow.color, pulse: eyebrow.pulse),
                    const SizedBox(width: 7),
                    Flexible(
                      child: MonoEyebrow(
                        eyebrow.text,
                        color: eyebrow.color,
                        size: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.label.copyWith(
                    color: t.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (c.hasRingContext)
            _RingPill(
              state: uiState,
              battery: battery,
              live: c.isConnected,
              onTap: () => switch (uiState) {
                RingUiState.disconnected => unawaited(
                  c.reconnectSavedRing(force: true),
                ),
                RingUiState.stale => unawaited(
                  syncRingWithFeedback(context, c),
                ),
                _ => openScanner(context, c),
              },
            ),
        ],
      ),
    );
  }
}

/// Battery pill with a live status dot; becomes SYNC / CONNECT when the ring
/// needs it, so the fix lives in the header too.
class _RingPill extends StatelessWidget {
  const _RingPill({
    required this.state,
    required this.battery,
    required this.live,
    required this.onTap,
  });

  final RingUiState state;
  final int? battery;

  /// Connected right now — the dot is green and pulsing only then; a
  /// last-known battery while out of reach shows with a grey dot.
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final (label, tone, filled, icon) = switch (state) {
      RingUiState.stale => ('SYNC', t.gold, true, 'refresh'),
      RingUiState.disconnected => ('CONNECT', t.qPoor, true, 'bluetooth'),
      RingUiState.syncing => (
        battery == null ? 'SYNCING' : '$battery%',
        t.gold,
        false,
        'refresh',
      ),
      _ => (
        battery == null ? 'RING' : '$battery%',
        live ? t.textSec : t.mutedInk,
        false,
        null,
      ),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          decoration: BoxDecoration(
            color: filled ? tone.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: filled ? tone : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                VyanaIcon(icon, size: 13, color: tone),
                const SizedBox(width: 5),
              ] else ...[
                RingStatusDot(color: live ? t.qGood : t.mutedInk, pulse: live),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: VyanaType.mono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Readiness ───────────────────────────────────────────────────────────────

/// 104px arc around a 38px score, state word beside it, then one sentence
/// describing the day. Unboxed — nothing competes with it.
class _ReadinessRead extends StatelessWidget {
  const _ReadinessRead({
    required this.controller,
    required this.dashboard,
    required this.state,
    required this.intent,
    required this.stale,
    required this.hasRing,
  });

  final RingController controller;
  final HomeDashboard dashboard;
  final WellnessState state;
  final DayIntent intent;
  final bool stale;
  final bool hasRing;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final score = dashboard.readinessScore;
    final look = scoreLook(score, t);
    final series = readinessSeries(controller.history, 30);
    final avg = series.isEmpty
        ? null
        : (series.map((e) => e.score).reduce((a, b) => a + b) / series.length)
              .round();
    final String note;
    final Color noteColor;
    if (stale) {
      note = 'LAST READING';
      noteColor = t.textMuted;
    } else if (score != null && avg != null) {
      final d = score - avg;
      note = d == 0
          ? 'ON YOUR AVERAGE'
          : '${d > 0 ? '+' : '−'}${d.abs()} ON YOUR AVERAGE';
      noteColor = look.soft;
    } else {
      note = look.word == '—' ? 'SYNC TO READ' : look.word;
      noteColor = look.soft;
    }
    final sentence = hasRing
        ? readSentenceFor(intent, state, dashboard)
        : 'Explore breath, movement and rest. Add a ring when you are ready '
              'for sleep, HRV and daily readiness.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProgressRing(
              value: (score ?? 0).toDouble(),
              size: 100,
              stroke: 6,
              color: look.hue,
              track: t.mutedInk.withValues(alpha: 0.16),
              child: SizedBox(
                width: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    score == null ? '—' : '$score',
                    style: TextStyle(
                      fontFamily: VyanaType.sans,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: look.hue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    look.state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VyanaType.serif,
                      fontSize: 31,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: look.hue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MonoEyebrow(note, size: 9.5, spacing: 0.8, color: noteColor),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          sentence,
          style: VyanaType.caption.copyWith(
            color: t.textSec,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

// ── Metric cards ────────────────────────────────────────────────────────────

class HomeMetricCardData {
  const HomeMetricCardData({
    required this.kind,
    required this.label,
    required this.icon,
    required this.ink,
    required this.value,
    required this.unit,
    required this.verdict,
    required this.quality,
    required this.direction,
  });

  final VitalsMetricKind kind;
  final String label;
  final String icon;
  final Color ink;
  final String? value;
  final String unit;
  final String verdict;

  /// `good` · `level` · `poor` · `none`
  final String quality;

  /// `up` · `down` · `flat` · null (no data)
  final String? direction;
}

String _dirFor(double? today, double? base) {
  if (today == null || base == null) return 'flat';
  final d = today - base;
  if (d.abs() < base * 0.03) return 'flat';
  return d > 0 ? 'up' : 'down';
}

/// Three fixed slots — HRV, Sleep, Resting HR — that always render, with an
/// explicit no-data state per slot rather than a vital silently sliding in
/// to replace a missing one.
List<HomeMetricCardData> homeMetricCards(
  RingController c,
  HomeDashboard dashboard,
  VyanaColors t,
) {
  final history = c.history;
  final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
  final hrv =
      c.vitals.hrv?.toDouble() ??
      (hrvPoints.isEmpty ? null : hrvPoints.last.value);
  final hrvBase = _baseline(hrvPoints, 30);
  final hrvVerdict = hrv == null
      ? 'No reading'
      : hrv >= 55
      ? 'Recovered'
      : hrv >= 35
      ? 'Balanced'
      : 'Take it easy';
  final hrvQ = hrv == null
      ? 'none'
      : hrv >= 55
      ? 'good'
      : hrv >= 35
      ? 'level'
      : 'poor';

  final nights = sleepDaySummaries(history.sleep);
  final night = nights.isEmpty ? null : nights.first;
  final sleepHours = night == null
      ? null
      : night.breakdown.asleepSeconds / 3600;
  final sleepBase = nights.length > 1
      ? nights
                .skip(1)
                .take(30)
                .map((n) => n.breakdown.asleepSeconds / 3600)
                .reduce((a, b) => a + b) /
            math.min(30, nights.length - 1)
      : null;
  // Sleep reads Good / Fair / Poor from its own score — not HRV's string.
  final sleepScore = night?.score;
  final sleepVerdict = sleepScore == null
      ? 'No sleep yet'
      : sleepScore >= 80
      ? 'Good'
      : sleepScore >= 65
      ? 'Fair'
      : 'Poor';
  final sleepQ = sleepScore == null
      ? 'none'
      : sleepScore >= 80
      ? 'good'
      : sleepScore >= 65
      ? 'level'
      : 'poor';

  final hrPoints = vitalHistoryPoints(history, VitalsMetricKind.heartRate);
  final hr =
      c.vitals.heartRate?.toDouble() ??
      (hrPoints.isEmpty ? null : hrPoints.last.value);
  final hrBase = _baseline(hrPoints, 30);
  final hrVerdict = hr == null
      ? 'No reading'
      : hr < 55
      ? 'Resting'
      : hr <= 70
      ? 'Typical'
      : 'Elevated';
  final hrQ = hr == null
      ? 'none'
      : hr <= 70
      ? (hr < 55 ? 'good' : 'level')
      : hr <= 85
      ? 'level'
      : 'poor';

  return [
    HomeMetricCardData(
      kind: VitalsMetricKind.hrv,
      label: 'HRV',
      icon: 'pulse',
      ink: t.idHrv,
      value: hrv == null ? null : '${hrv.round()}',
      unit: ' ms',
      verdict: hrvVerdict,
      quality: hrvQ,
      direction: hrv == null ? null : _dirFor(hrv, hrvBase),
    ),
    HomeMetricCardData(
      kind: VitalsMetricKind.sleep,
      label: 'SLEEP',
      icon: 'moon',
      ink: t.idSleep,
      value: sleepHours == null ? null : _fmtHours(sleepHours),
      unit: '',
      verdict: sleepVerdict,
      quality: sleepQ,
      direction: sleepHours == null ? null : _dirFor(sleepHours, sleepBase),
    ),
    HomeMetricCardData(
      kind: VitalsMetricKind.heartRate,
      label: 'REST HR',
      icon: 'heart',
      ink: t.idRestHr,
      value: hr == null ? null : '${hr.round()}',
      unit: ' bpm',
      verdict: hrVerdict,
      quality: hrQ,
      direction: hr == null ? null : _dirFor(hr, hrBase),
    ),
  ];
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({
    required this.controller,
    required this.dashboard,
    required this.stale,
    required this.hasRing,
  });

  final RingController controller;
  final HomeDashboard dashboard;
  final bool stale;
  final bool hasRing;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final cards = homeMetricCards(controller, dashboard, t);
    Widget card(int i) => _MetricCard(
      data: cards[i],
      stale: stale,
      onTap: hasRing
          ? () => openVitalDetail(context, controller, cards[i].kind)
          : null,
    );
    // Three across while a column can still hold a word like "Recovered";
    // at large text or on a narrow screen the cards stack instead.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 330 * scale) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                card(i),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: card(i)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.data,
    required this.stale,
    required this.onTap,
  });

  final HomeMetricCardData data;
  final bool stale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final q = switch (data.quality) {
      'good' => t.qGoodSoft,
      'poor' => t.qPoorSoft,
      'level' => t.qLevelSoft,
      _ => t.mutedInk,
    };
    final arrow = switch (data.direction) {
      'up' => 'arrowUp',
      'down' => 'arrowDown',
      'flat' => 'minus',
      _ => null,
    };
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      opacity: stale ? 0.5 : 1,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              VyanaIcon(data.icon, size: 14, color: data.ink),
              const SizedBox(width: 5),
              Flexible(
                child: MonoEyebrow(data.label, size: 10.5, spacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: data.value ?? '—',
              children: [
                if (data.value != null && data.unit.isNotEmpty)
                  TextSpan(
                    text: data.unit,
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyanaType.label.copyWith(
              color: t.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (arrow != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: VyanaIcon(arrow, size: 13, color: q),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  stale && data.value != null ? 'Last reading' : data.verdict,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.caption.copyWith(
                    color: stale ? t.mutedInk : q,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
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

// ── Suggested practice ──────────────────────────────────────────────────────

/// Shared by Home and Practice: heading + one-line reason, then the card with
/// the identity tile, name, duration and the filled play button — the only
/// filled control on the screen. Intent colour on tile and play only.
class SuggestedPracticeBlock extends StatelessWidget {
  const SuggestedPracticeBlock({
    super.key,
    required this.intent,
    required this.activity,
    required this.reason,
    this.compact = false,
  });

  final DayIntent intent;
  final Activity activity;
  final String reason;

  /// Practice's form: no heading, and `2 MIN · reason` inside the card under
  /// the name, so the duration scans first.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final hue = intent.hue(t);
    final soft = t.isDark ? intent.soft(t) : hue;
    final minutes = suggestedMinutesFor(intent, activity);
    final card = HairlineCard(
      padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
      onTap: () => openActivityDetail(context, activity, minutes: minutes),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: VyanaIcon(activity.icon, size: 20, color: soft),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.label.copyWith(
                    color: t.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    MonoEyebrow(
                      '$minutes MIN',
                      size: 11,
                      spacing: 0.8,
                      color: t.heading,
                    ),
                    if (compact) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: t.mutedInk,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: VyanaType.caption.copyWith(
                            color: t.mutedInk,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
            child: Center(
              child: VyanaIcon(
                'play',
                size: 18,
                color: t.isDark ? const Color(0xFF071211) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (compact) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested practice',
          style: VyanaType.label.copyWith(color: t.heading, fontSize: 16.5),
        ),
        const SizedBox(height: 3),
        Text(
          reason,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 13.5),
        ),
        const SizedBox(height: 10),
        card,
      ],
    );
  }
}

class _SuggestedPractice extends StatelessWidget {
  const _SuggestedPractice({
    required this.intent,
    required this.state,
    required this.readiness,
    required this.moment,
  });

  final DayIntent intent;
  final WellnessState state;
  final int? readiness;
  final HomeMoment moment;

  @override
  Widget build(BuildContext context) {
    final id = suggestedPracticeFor(intent, state, readiness, moment);
    final activity = activityById(id) ?? activityById('breathwork')!;
    return SuggestedPracticeBlock(
      intent: intent,
      activity: activity,
      reason: suggestedReasonFor(intent, readiness),
    );
  }
}

// ── No ring ─────────────────────────────────────────────────────────────────

class _DiscoverRingPanel extends StatelessWidget {
  const _DiscoverRingPanel({required this.controller});
  final RingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      grad: true,
      pad: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoEyebrow('PRANA RING', size: 9.5),
          const SizedBox(height: 6),
          Text(
            'Wear your vitals.',
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Heart rate, sleep and readiness unlock when you wear the ring. '
            'Black · sizes 7–13 · ships in 30 days.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
          ),
          const SizedBox(height: 14),
          Cta(
            label: 'Buy PRANA ring',
            icon: 'ring',
            onTap: () => openRingOrder(context),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: controller.isReady
                  ? () => openScanner(context, controller)
                  : null,
              child: Text(
                'Already have a ring? Pair now',
                style: VyanaType.label.copyWith(color: t.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kept for the tests and the widget service: today's suggestion from the
/// wellness signals alone, before intent is applied.
String suggestedPracticeId(
  WellnessState state,
  int? readinessScore,
  HomeMoment moment,
) {
  final tense = state.signals.any(
    (signal) => signal.label == 'Calm' && signal.tone == WellnessTone.watch,
  );
  if (tense) return 'breathwork';
  if (readinessScore != null && readinessScore < 50) return 'recovery';
  if (state.tone == WellnessTone.watch) return 'recovery';
  if (readinessScore != null && readinessScore >= 75) {
    return switch (moment) {
      HomeMoment.morning => 'sunSalutation',
      HomeMoment.day => 'walk',
      HomeMoment.night => 'pranayama',
    };
  }
  return 'breathwork';
}
