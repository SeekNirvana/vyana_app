part of '../../main.dart';

/// Kind-specific live-session bodies (M4). Each reads the shared
/// [SessionController] for elapsed/HR and adds its own guidance state
/// (breath phase, set/rest FSM, pose/round, safety timer). Decorative motion is
/// gated on the platform reduced-motion preference.

Widget liveSessionBody(SessionController controller, Color accent) {
  final kind = controller.activity?.kind ?? 'indoor';
  switch (kind) {
    case 'breath':
      return BreathBody(controller: controller, accent: accent);
    case 'audio':
      return AudioBody(controller: controller, accent: accent);
    case 'sequence':
      return SequenceBody(controller: controller, accent: accent);
    case 'strength':
      return StrengthBody(controller: controller, accent: accent);
    case 'recovery':
      return RecoveryBody(controller: controller, accent: accent);
    case 'gps':
      return GpsBody(controller: controller, accent: accent);
    case 'indoor':
    default:
      return IndoorBody(controller: controller, accent: accent);
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

/// HR training zone 0–4 (Z1–Z5) from a coarse threshold model. -1 when unknown.
int hrZoneIndex(int? hr) {
  if (hr == null || hr <= 0) return -1;
  if (hr < 100) return 0;
  if (hr < 120) return 1;
  if (hr < 140) return 2;
  if (hr < 160) return 3;
  return 4;
}

const kZoneLabels = ['Z1 Easy', 'Z2 Steady', 'Z3 Aerobic', 'Z4 Hard', 'Z5 Max'];

class HrZoneBar extends StatelessWidget {
  const HrZoneBar({super.key, required this.hr});
  final int? hr;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final zone = hrZoneIndex(hr);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i <= zone && zone >= 0
                        ? t.hrZones[i]
                        : t.hrZones[i].withValues(alpha: 0.18),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          zone < 0 ? 'Waiting for heart rate…' : kZoneLabels[zone],
          style: VyanaType.caption.copyWith(
            color: zone < 0 ? t.textMuted : t.hrZones[zone],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class LiveHrReadout extends StatelessWidget {
  const LiveHrReadout({super.key, required this.hr, this.big = false});
  final int? hr;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        VyanaIcon('heart', size: big ? 22 : 16, color: t.vit('hr')),
        const SizedBox(width: 8),
        Text(hr == null ? '—' : '$hr',
            style: VyanaType.titleSerif.copyWith(
                color: t.text, fontSize: big ? 40 : 24)),
        const SizedBox(width: 4),
        Text('bpm', style: VyanaType.caption.copyWith(color: t.textMuted)),
      ],
    );
  }
}

class MetricTrio extends StatelessWidget {
  const MetricTrio({super.key, required this.items});
  final List<(String, String)> items; // (value, label)

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  Text(it.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.titleSerif.copyWith(
                          color: t.text, fontSize: 19)),
                  const SizedBox(height: 2),
                  Text(it.$2,
                      style: VyanaType.caption.copyWith(color: t.textSec)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ── Indoor (generic) ────────────────────────────────────────────────────────
class IndoorBody extends StatelessWidget {
  const IndoorBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final v = controller.heartRate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_fmtDuration(controller.elapsed),
              style: VyanaType.displaySerif.copyWith(
                  color: t.text, fontSize: 68, height: 1)),
          const SizedBox(height: 6),
          LiveHrReadout(hr: v, big: true),
          const SizedBox(height: 24),
          HrZoneBar(hr: v),
          const SizedBox(height: 20),
          if (controller.hrSeries.length > 1)
            Sparkline(
              data: controller.hrSeries.map((e) => e.toDouble()).toList(),
              color: t.vit('hr'),
              width: MediaQuery.of(context).size.width - 64,
              height: 56,
            ),
          const SizedBox(height: 16),
          Text('${controller.sampleCount} samples',
              style: VyanaType.caption.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

// ── GPS (outdoor) — striped map placeholder; route polyline lands in M5 ──────
class GpsBody extends StatelessWidget {
  const GpsBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final v = controller.heartRate;
    final route = controller.route;
    final km = controller.distanceMeters / 1000;
    final paceLabel = _paceLabel(controller.elapsed, controller.distanceMeters);
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _StripePainter(t.border, t.surface),
              child: route.length < 2
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VyanaIcon('mapPin', size: 26, color: t.textMuted),
                          const SizedBox(height: 8),
                          Text('Acquiring GPS · phone',
                              style: VyanaType.caption.copyWith(color: t.textMuted)),
                        ],
                      ),
                    )
                  : CustomPaint(
                      painter: _RoutePainter(route, accent),
                      size: Size.infinite,
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MetricTrio(items: [
            (km.toStringAsFixed(2), 'km'),
            (paceLabel, 'pace /km'),
            ('${controller.elevationGain.round()}', 'elev m'),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MetricTrio(items: [
            (_fmtDuration(controller.elapsed), 'Time'),
            (v == null ? '—' : '$v', 'HR bpm'),
            ('${controller.sampleCount}', 'Samples'),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HrZoneBar(hr: v),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static String _paceLabel(Duration elapsed, double meters) {
    if (meters < 20) return '—';
    final secPerKm = elapsed.inSeconds / (meters / 1000);
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Draws the captured GPS route auto-scaled to the box (no tile provider — the
/// striped placeholder is the backdrop, per the design).
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.route, this.color);
  final List<({double lat, double lng})> route;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    var minLat = route.first.lat, maxLat = route.first.lat;
    var minLng = route.first.lng, maxLng = route.first.lng;
    for (final p in route) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    const pad = 24.0;
    final spanLat = (maxLat - minLat).abs() < 1e-6 ? 1e-6 : (maxLat - minLat);
    final spanLng = (maxLng - minLng).abs() < 1e-6 ? 1e-6 : (maxLng - minLng);
    Offset project(({double lat, double lng}) p) {
      final x = pad + (p.lng - minLng) / spanLng * (size.width - pad * 2);
      // Invert latitude so north is up.
      final y = pad + (maxLat - p.lat) / spanLat * (size.height - pad * 2);
      return Offset(x, y);
    }

    final path = Path()..moveTo(project(route.first).dx, project(route.first).dy);
    for (final p in route.skip(1)) {
      final o = project(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawCircle(project(route.first), 5, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawCircle(project(route.last), 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route.length != route.length;
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.line, this.bg);
  final Color line;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final paint = Paint()
      ..color = line.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    for (var x = -size.height; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}

// ── Strength (work/rest FSM) ─────────────────────────────────────────────────
class StrengthBody extends StatefulWidget {
  const StrengthBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  State<StrengthBody> createState() => _StrengthBodyState();
}

class _StrengthBodyState extends State<StrengthBody> {
  static const _restSeconds = 60;
  bool _resting = false;
  int _sets = 0;
  int _restRemaining = _restSeconds;
  int? _hrAtSetEnd;
  int? _hrRecovered;
  Timer? _restTimer;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _logSet() {
    setState(() {
      _sets++;
      _resting = true;
      _restRemaining = _restSeconds;
      _hrAtSetEnd = widget.controller.heartRate;
      _hrRecovered = null;
    });
    widget.controller.emitCue('Set $_sets complete. Rest for one minute.');
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) {
          _hrRecovered = widget.controller.heartRate;
          _resting = false;
          timer.cancel();
          widget.controller.emitCue('Rest complete. Ready for set ${_sets + 1}.');
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _hrRecovered = widget.controller.heartRate;
      _resting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final hr = widget.controller.heartRate;
    final recovery = (_hrAtSetEnd != null && _hrRecovered != null)
        ? (_hrAtSetEnd! - _hrRecovered!)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_resting ? 'REST' : 'SET ${_sets + 1}',
              style: VyanaType.eyebrow.copyWith(color: widget.accent)),
          const SizedBox(height: 10),
          Text(
            _resting
                ? '0:${_restRemaining.toString().padLeft(2, '0')}'
                : _fmtDuration(widget.controller.elapsed),
            style: VyanaType.displaySerif.copyWith(
                color: t.text, fontSize: 64, height: 1),
          ),
          const SizedBox(height: 10),
          LiveHrReadout(hr: hr),
          if (recovery != null && recovery > 0) ...[
            const SizedBox(height: 6),
            Text('Recovered $recovery bpm last rest',
                style: VyanaType.caption.copyWith(color: t.green)),
          ],
          const SizedBox(height: 24),
          if (_resting)
            Cta(label: 'Skip rest', icon: 'play', solid: false, onTap: _skipRest)
          else
            Cta(label: 'Log set · start rest', icon: 'check', onTap: _logSet),
          const SizedBox(height: 12),
          Text('$_sets sets logged',
              style: VyanaType.caption.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

// ── Recovery (safety timer) ──────────────────────────────────────────────────
class RecoveryBody extends StatefulWidget {
  const RecoveryBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  State<RecoveryBody> createState() => _RecoveryBodyState();
}

class _RecoveryBodyState extends State<RecoveryBody> {
  int? _baselineHr;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final hr = widget.controller.heartRate;
    _baselineHr ??= hr;
    final isCold = widget.controller.activity?.id == 'coldPlunge';
    final threshold = isCold ? 30 : 40;
    final overThreshold =
        _baselineHr != null && hr != null && (hr - _baselineHr!) > threshold;
    final totalSec = (widget.controller.activity?.dur ?? 10) * 60;
    final progress = (widget.controller.elapsed.inSeconds / totalSec).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProgressRing(
            value: progress * 100,
            size: 200,
            stroke: 12,
            color: overThreshold ? t.vit('hr') : widget.accent,
            track: t.border,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_fmtDuration(widget.controller.elapsed),
                    style: VyanaType.displaySerif.copyWith(
                        color: t.text, fontSize: 40, height: 1)),
                Text('safety timer',
                    style: VyanaType.mono10.copyWith(color: t.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MetricTrio(items: [
            (_baselineHr == null ? '—' : '$_baselineHr', 'Baseline HR'),
            (hr == null ? '—' : '$hr', 'Now HR'),
            (overThreshold ? 'High' : 'Steady', 'Status'),
          ]),
          const SizedBox(height: 16),
          if (overThreshold)
            Panel(
              pad: 14,
              accent: t.vit('hr'),
              child: Row(
                children: [
                  VyanaIcon('flame', size: 18, color: t.vit('hr')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isCold
                          ? 'Heart rate climbing — breathe slow, step out if needed.'
                          : 'Heart rate high — consider stepping out to cool down.',
                      style: VyanaType.bodySm.copyWith(color: t.text),
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

// ── Breath (animated orb) ────────────────────────────────────────────────────
const _breathPatterns = <String, List<int>>{
  // [inhale, hold-in, exhale, hold-out] seconds
  'breathwork': [4, 7, 8, 0],
  'pranayama': [4, 4, 4, 4],
  'hrvBreathing': [5, 0, 5, 0],
};
const _breathPhaseLabels = ['Breathe in', 'Hold', 'Breathe out', 'Hold'];

class BreathBody extends StatefulWidget {
  const BreathBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  State<BreathBody> createState() => _BreathBodyState();
}

class _BreathBodyState extends State<BreathBody> {
  late final List<int> _pattern =
      _breathPatterns[widget.controller.activity?.id] ?? const [4, 4, 4, 4];
  int _phase = 0;
  int _remaining = 0;
  int _coherence = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _pattern[0];
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.emitCue(_breathPhaseLabels[_phase]);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _remaining--;
      if (_remaining <= 0) {
        _coherence = (_coherence + 4).clamp(0, 100);
        var next = (_phase + 1) % 4;
        var guard = 0;
        while (_pattern[next] == 0 && guard < 4) {
          next = (next + 1) % 4;
          guard++;
        }
        _phase = next;
        _remaining = _pattern[_phase];
        widget.controller.emitCue(_breathPhaseLabels[_phase]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final inhaling = _phase == 0;
    final exhaling = _phase == 2;
    // Orb scale: large on inhale/hold-in, small on exhale/hold-out.
    final target = inhaling ? 1.0 : (exhaling ? 0.55 : (_phase == 1 ? 1.0 : 0.55));
    final reduce = _reduceMotion(context);
    final phaseSeconds = _pattern[_phase].clamp(1, 60);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 240,
            child: Center(
              child: AnimatedContainer(
                duration: reduce
                    ? const Duration(milliseconds: 200)
                    : Duration(seconds: phaseSeconds),
                curve: Curves.easeInOut,
                width: 90 + 140 * target,
                height: 90 + 140 * target,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    widget.accent.withValues(alpha: 0.45),
                    widget.accent.withValues(alpha: 0.08),
                  ]),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.6)),
                ),
                child: Center(
                  child: Text('$_remaining',
                      style: VyanaType.displaySerif.copyWith(
                          color: t.text, fontSize: 44)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(_breathPhaseLabels[_phase],
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24)),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Coherence',
                  style: VyanaType.caption.copyWith(color: t.textSec)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: _coherence / 100,
                    minHeight: 8,
                    backgroundColor: t.border,
                    valueColor: AlwaysStoppedAnimation(widget.accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiveHrReadout(hr: widget.controller.heartRate),
          const SizedBox(height: 10),
          Text('Elapsed ${_fmtDuration(widget.controller.elapsed)}',
              style: VyanaType.mono12.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

// ── Audio (guided script) ────────────────────────────────────────────────────
const _audioScript = [
  'Settle into a comfortable position.',
  'Let your shoulders soften and your jaw release.',
  'Notice the breath, without changing it.',
  'There is nothing to do here but rest.',
  'If the mind wanders, gently return to the breath.',
  'Let each exhale carry a little more tension away.',
  'Stay with this quiet for a while longer.',
  'You are settled. You are restored.',
];

class AudioBody extends StatefulWidget {
  const AudioBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  State<AudioBody> createState() => _AudioBodyState();
}

class _AudioBodyState extends State<AudioBody> {
  int _line = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.emitCue(_audioScript[_line]);
    });
    _timer = Timer.periodic(const Duration(seconds: 18), (_) {
      if (!mounted) return;
      final next = (_line + 1) % _audioScript.length;
      setState(() => _line = next);
      widget.controller.emitCue(_audioScript[next]);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final totalSec = (widget.controller.activity?.dur ?? 15) * 60;
    final progress =
        (widget.controller.elapsed.inSeconds / totalSec).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                widget.accent.withValues(alpha: 0.4),
                widget.accent.withValues(alpha: 0.05),
              ]),
            ),
            child: Center(
              child: VyanaIcon('speaker', size: 40, color: widget.accent),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Text(
              _audioScript[_line],
              key: ValueKey(_line),
              textAlign: TextAlign.center,
              style: VyanaType.titleSerif.copyWith(
                  color: t.text, fontSize: 22, height: 1.3),
            ),
          ),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: t.border,
              valueColor: AlwaysStoppedAnimation(widget.accent),
            ),
          ),
          const SizedBox(height: 10),
          Text(_fmtDuration(widget.controller.elapsed),
              style: VyanaType.caption.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

// ── Sequence (pose-by-pose) ──────────────────────────────────────────────────
const _sunPoses = [
  'Mountain', 'Upward Salute', 'Forward Fold', 'Half Lift', 'Plank',
  'Low Plank', 'Upward Dog', 'Downward Dog', 'Half Lift', 'Forward Fold',
  'Upward Salute', 'Mountain',
];
const _flowPoses = [
  'Child\'s Pose', 'Cat–Cow', 'Downward Dog', 'Low Lunge', 'Warrior II',
  'Triangle', 'Forward Fold', 'Bridge',
];

class SequenceBody extends StatefulWidget {
  const SequenceBody({super.key, required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  State<SequenceBody> createState() => _SequenceBodyState();
}

class _SequenceBodyState extends State<SequenceBody> {
  static const _poseSeconds = 6;
  late final List<String> _poses =
      widget.controller.activity?.id == 'sunSalutation' ? _sunPoses : _flowPoses;
  int _pose = 0;
  int _round = 1;
  int _remaining = _poseSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _remaining--;
      if (_remaining <= 0) {
        _remaining = _poseSeconds;
        _pose++;
        if (_pose >= _poses.length) {
          _pose = 0;
          _round++;
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ROUND $_round',
              style: VyanaType.eyebrow.copyWith(color: widget.accent)),
          const SizedBox(height: 16),
          ProgressRing(
            value: (_poseSeconds - _remaining) / _poseSeconds * 100,
            size: 190,
            stroke: 10,
            color: widget.accent,
            track: t.border,
            child: Text('$_remaining',
                style: VyanaType.displaySerif.copyWith(
                    color: t.text, fontSize: 48)),
          ),
          const SizedBox(height: 18),
          Text(_poses[_pose],
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _poses.length; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _pose
                        ? widget.accent
                        : t.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LiveHrReadout(hr: widget.controller.heartRate),
          const SizedBox(height: 10),
          Text('Elapsed ${_fmtDuration(widget.controller.elapsed)}',
              style: VyanaType.mono12.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}
