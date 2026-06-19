part of '../../main.dart';

Future<void> openHealthMonitoring(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => HealthMonitoringScreen(controller: c),
    ),
  );
}

/// Configure automatic ring-side health checks (SDK interval 1–60 minutes).
class HealthMonitoringScreen extends StatefulWidget {
  const HealthMonitoringScreen({super.key, required this.controller});

  final RingController controller;

  @override
  State<HealthMonitoringScreen> createState() => _HealthMonitoringScreenState();
}

class _HealthMonitoringScreenState extends State<HealthMonitoringScreen> {
  late bool _enabled;
  late int _interval;
  String? _feedback;
  bool? _feedbackOk;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.healthMonitoring;
    _enabled = settings.enabled;
    _interval = settings.intervalMinutes;
    _feedback = settings.lastMessage;
    _feedbackOk = settings.ringAcknowledged ? true : null;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || !_applying) return;
    setState(() {
      _applying = widget.controller.healthMonitoringApplying;
      if (!_applying) {
        final settings = widget.controller.healthMonitoring;
        _enabled = settings.enabled;
        _interval = settings.intervalMinutes;
        _feedback = settings.lastMessage;
        _feedbackOk = settings.ringAcknowledged;
      }
    });
  }

  bool get _canApply =>
      widget.controller.isConnected &&
      !_applying &&
      (_enabled != widget.controller.healthMonitoring.enabled ||
          _interval != widget.controller.healthMonitoring.intervalMinutes ||
          !widget.controller.healthMonitoring.ringAcknowledged);

  Future<void> _apply() async {
    if (!widget.controller.isConnected || _applying) return;

    setState(() {
      _applying = true;
      _feedback = null;
      _feedbackOk = null;
    });

    final result = await widget.controller.applyHealthMonitoring(
      enabled: _enabled,
      intervalMinutes: _interval,
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
      _enabled = result.settings.enabled;
      _interval = result.settings.intervalMinutes;
      _feedback = result.message;
      _feedbackOk = false;
    });
  }

  void _setInterval(int minutes) {
    setState(() {
      _interval = clampHealthMonitoringInterval(minutes);
      _feedback = null;
      _feedbackOk = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final connected = widget.controller.isConnected;

    return _EditorScaffold(
      title: 'Health monitoring',
      sub: 'Your ring',
      ctaLabel: _applying ? 'Applying…' : 'Apply to ring',
      ctaIcon: 'check',
      canSave: _canApply && connected,
      onSave: _apply,
      children: [
        Text(
          'Smart rings monitor vitals in the background by default. Adjust the '
          'interval here and apply when connected — readings sync later via '
          'Data log. This does not start a live Vyana session.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
        const SizedBox(height: 16),
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
                on: _enabled,
                onTap: () => setState(() {
                  _enabled = !_enabled;
                  _feedback = null;
                  _feedbackOk = null;
                }),
              ),
            ],
          ),
        ),
        if (_enabled) ...[
          const SizedBox(height: 16),
          Text(
            'Check interval',
            style: VyanaType.label.copyWith(color: t.textSec),
          ),
          const SizedBox(height: 8),
          Panel(
            pad: 14,
            child: Row(
              children: [
                IconBtn(
                  icon: 'minus',
                  onTap: _interval > kHealthMonitoringMinInterval
                      ? () => _setInterval(_interval - 1)
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
                        '$_interval min',
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
                  onTap: _interval < kHealthMonitoringMaxInterval
                      ? () => _setInterval(_interval + 1)
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
                  active: _interval == preset,
                  onTap: () => _setInterval(preset),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (!connected)
          Panel(
            pad: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon('bluetooth', size: 18, color: t.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connect your PRANA ring to apply this setting.',
                    style: VyanaType.body.copyWith(color: t.textSec, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else if (_feedback != null)
          Panel(
            pad: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon(
                  _feedbackOk == true ? 'checkCircle' : 'info',
                  size: 18,
                  color: _feedbackOk == true ? t.green : t.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _feedback!,
                    style: VyanaType.body.copyWith(
                      color: _feedbackOk == true ? t.green : t.textSec,
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
}