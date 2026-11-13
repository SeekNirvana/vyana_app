part of '../../main.dart';

Future<void> openRingData(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => RingDataScreen(controller: c)),
  );
}

/// "Ring data" — one screen for the two intervals that used to be two
/// screens ("Health monitoring" and "Sync").
///
/// They were never the same setting, but they looked identical: two "every N
/// minutes" steppers, one row apart, each needing a sentence to say it was
/// not the other one. Side by side under plain headings the contrast does
/// that work instead:
///
///  * the ring measures on its own — ring battery, keeps going out of range;
///  * Vyana collects what it recorded — phone battery, freshness only.
///
/// The ring side still needs a connection to take effect (it is written over
/// BLE); the phone side saves immediately.
class RingDataScreen extends StatefulWidget {
  const RingDataScreen({super.key, required this.controller});

  final RingController controller;

  @override
  State<RingDataScreen> createState() => _RingDataScreenState();
}

class _RingDataScreenState extends State<RingDataScreen> {
  // Ring side.
  late bool _monitorOn;
  late int _monitorInterval;
  String? _feedback;
  bool? _feedbackOk;
  bool _applying = false;

  // Phone side.
  late int _syncInterval;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.healthMonitoring;
    _monitorOn = settings.enabled;
    _monitorInterval = settings.intervalMinutes;
    _feedback = settings.lastMessage;
    _feedbackOk = settings.ringAcknowledged ? true : null;
    _syncInterval = widget.controller.periodicSyncIntervalMinutes;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!_applying) {
      // Keeps the connected / disconnected notes honest while the screen is
      // open, without stamping on a value the user is in the middle of
      // changing.
      setState(() {});
      return;
    }
    setState(() {
      _applying = widget.controller.healthMonitoringApplying;
      if (!_applying) {
        final settings = widget.controller.healthMonitoring;
        _monitorOn = settings.enabled;
        _monitorInterval = settings.intervalMinutes;
        _feedback = settings.lastMessage;
        _feedbackOk = settings.ringAcknowledged;
      }
    });
  }

  bool get _ringChanged {
    final settings = widget.controller.healthMonitoring;
    return _monitorOn != settings.enabled ||
        _monitorInterval != settings.intervalMinutes ||
        !settings.ringAcknowledged;
  }

  bool get _phoneChanged =>
      _syncInterval != widget.controller.periodicSyncIntervalMinutes;

  bool get _canSave {
    if (_applying) return false;
    if (_phoneChanged) return true;
    return _ringChanged &&
        widget.controller.supportsHealthMonitoring &&
        widget.controller.isConnected;
  }

  void _setMonitorInterval(int minutes) {
    setState(() {
      _monitorInterval = clampHealthMonitoringInterval(minutes);
      _feedback = null;
      _feedbackOk = null;
      _saved = false;
    });
  }

  void _setSyncInterval(int minutes) {
    setState(() {
      _syncInterval = clampPeriodicSyncIntervalMinutes(minutes);
      _saved = false;
    });
  }

  Future<void> _save() async {
    final c = widget.controller;
    final ringPending = _ringChanged && c.supportsHealthMonitoring;

    if (_phoneChanged) {
      await c.applyPeriodicSyncInterval(_syncInterval);
      if (!mounted) return;
    }

    if (ringPending && c.isConnected) {
      setState(() {
        _applying = true;
        _feedback = null;
        _feedbackOk = null;
      });
      final result = await c.applyHealthMonitoring(
        enabled: _monitorOn,
        intervalMinutes: _monitorInterval,
      );
      if (!mounted) return;
      if (result.successful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _applying = false;
        _monitorOn = result.settings.enabled;
        _monitorInterval = result.settings.intervalMinutes;
        _feedback = result.message;
        _feedbackOk = false;
      });
      return;
    }

    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = widget.controller;

    return _EditorScaffold(
      title: 'Ring data',
      sub: 'Ring',
      ctaLabel: _applying ? 'Applying…' : 'Save',
      ctaIcon: 'check',
      canSave: _canSave,
      onSave: () => unawaited(_save()),
      children: [
        Text(
          'Two intervals, two batteries. The ring measures you on its own; '
          'Vyana collects what it recorded.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
        if (c.supportsHealthMonitoring) ...[
          const SizedBox(height: 20),
          _RingDataSection(
            heading: 'How often the ring measures you',
            note: 'Spends ring battery. Keeps going out of range — those '
                'readings arrive on the next collection.',
          ),
          const SizedBox(height: 8),
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
                  on: _monitorOn,
                  onTap: () => setState(() {
                    _monitorOn = !_monitorOn;
                    _feedback = null;
                    _feedbackOk = null;
                    _saved = false;
                  }),
                ),
              ],
            ),
          ),
          if (_monitorOn) ...[
            const SizedBox(height: 12),
            RingIntervalStepper(
              minutes: _monitorInterval,
              min: kHealthMonitoringMinInterval,
              max: kHealthMonitoringMaxInterval,
              presets: kHealthMonitoringPresetIntervals,
              onChanged: _setMonitorInterval,
            ),
          ],
          const SizedBox(height: 12),
          if (!c.isConnected)
            _NotePanel(
              icon: 'bluetooth',
              color: t.gold,
              text: 'Connect your PRANA ring to change what it measures.',
            )
          else if (_feedback != null)
            _NotePanel(
              icon: _feedbackOk == true ? 'checkCircle' : 'info',
              color: _feedbackOk == true ? t.green : t.gold,
              text: _feedback!,
              textColor: _feedbackOk == true ? t.green : t.textSec,
            ),
        ],
        const SizedBox(height: 20),
        _RingDataSection(
          heading: 'How often Vyana collects it',
          note: 'Spends phone battery. Only changes how fresh what you see '
              'is — nothing is lost by collecting less often.',
        ),
        const SizedBox(height: 8),
        RingIntervalStepper(
          minutes: _syncInterval,
          min: kPeriodicSyncMinIntervalMinutes,
          max: kPeriodicSyncMaxIntervalMinutes,
          presets: kPeriodicSyncPresetIntervals,
          onChanged: _setSyncInterval,
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 16),
          Panel(
            pad: 14,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Keep collecting in the background',
                        style: VyanaType.label.copyWith(color: t.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // Bug 21 (4): calling the one switch that makes
                        // background alerts work "plumbing, not an alert"
                        // told users to leave it off.
                        'Keeps your ring connected, reconnects it, and '
                        'sends alerts while Vyana is closed. Shows a '
                        'small permanent notification.',
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
                  on: c.foregroundServiceEnabled,
                  onTap: c.foregroundServiceAllowed
                      ? () => unawaited(
                            c.setForegroundServiceEnabled(
                              !c.foregroundServiceEnabled,
                            ),
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],
        if (_saved) ...[
          const SizedBox(height: 16),
          _NotePanel(
            icon: 'checkCircle',
            color: t.green,
            text: 'Saved.',
            textColor: t.green,
          ),
        ],
      ],
    );
  }
}

/// A heading plus the one sentence that says which battery it spends. The
/// pair of them is what replaced the old "this is separate from…" disclaimer.
class _RingDataSection extends StatelessWidget {
  const _RingDataSection({required this.heading, required this.note});

  final String heading;
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: VyanaType.label.copyWith(color: t.text)),
        const SizedBox(height: 3),
        Text(
          note,
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
        ),
      ],
    );
  }
}

/// The "every N min" stepper with its presets — one widget now that both
/// intervals live on the same screen.
class RingIntervalStepper extends StatelessWidget {
  const RingIntervalStepper({
    super.key,
    required this.minutes,
    required this.min,
    required this.max,
    required this.presets,
    required this.onChanged,
  });

  final int minutes;
  final int min;
  final int max;
  final List<int> presets;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          pad: 14,
          child: Row(
            children: [
              IconBtn(
                icon: 'minus',
                onTap: minutes > min ? () => onChanged(minutes - 1) : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Every',
                      style: VyanaType.caption.copyWith(color: t.textMuted),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$minutes min',
                        maxLines: 1,
                        style: VyanaType.titleSerif.copyWith(
                          color: t.text,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    Text(
                      '$min–$max min allowed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.caption.copyWith(color: t.textMuted),
                    ),
                  ],
                ),
              ),
              IconBtn(
                icon: 'plus',
                onTap: minutes < max ? () => onChanged(minutes + 1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              Pill(
                label: '${preset}m',
                active: minutes == preset,
                onTap: () => onChanged(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({
    required this.icon,
    required this.color,
    required this.text,
    this.textColor,
  });

  final String icon;
  final Color color;
  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VyanaIcon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: VyanaType.body.copyWith(
                color: textColor ?? t.textSec,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The You row's subtitle: both intervals in one line, named by whose
/// battery each one spends. Plain values rather than the controller so it
/// can be read — and tested — on its own.
String ringDataSubtitle({
  required bool supportsMonitoring,
  required bool monitoringOn,
  required int monitoringMinutes,
  required int collectMinutes,
  required bool background,
}) {
  final parts = <String>[
    if (supportsMonitoring)
      monitoringOn
          ? 'Ring measures every $monitoringMinutes min'
          : 'Ring not measuring',
    'Vyana collects every $collectMinutes min',
    if (background) 'in the background',
  ];
  return parts.join(' · ');
}
