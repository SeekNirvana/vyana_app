part of '../../main.dart';

Future<void> openSyncSettings(BuildContext context, RingController c) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RingSyncSettingsScreen(controller: c),
    ),
  );
}

/// Configure how often the app fetches fresh ring history while it is open.
class RingSyncSettingsScreen extends StatefulWidget {
  const RingSyncSettingsScreen({super.key, required this.controller});

  final RingController controller;

  @override
  State<RingSyncSettingsScreen> createState() => _RingSyncSettingsScreenState();
}

class _RingSyncSettingsScreenState extends State<RingSyncSettingsScreen> {
  late int _interval;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _interval = widget.controller.periodicSyncIntervalMinutes;
  }

  void _setInterval(int minutes) {
    setState(() {
      _interval = clampPeriodicSyncIntervalMinutes(minutes);
      _saved = false;
    });
  }

  Future<void> _save() async {
    await widget.controller.applyPeriodicSyncInterval(_interval);
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final changed = _interval != widget.controller.periodicSyncIntervalMinutes;

    return _EditorScaffold(
      title: 'Ring sync interval',
      sub: 'App',
      ctaLabel: 'Save',
      ctaIcon: 'check',
      canSave: changed,
      onSave: _save,
      children: [
        Text(
          'How often Vyana fetches new history from the ring while the app is open. '
          'This is separate from the ring\'s own health monitoring interval.',
          style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
        ),
        const SizedBox(height: 16),
        Text(
          'Sync interval',
          style: VyanaType.label.copyWith(color: t.textSec),
        ),
        const SizedBox(height: 8),
        Panel(
          pad: 14,
          child: Row(
            children: [
              IconBtn(
                icon: 'minus',
                onTap: _interval > kPeriodicSyncMinIntervalMinutes
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
                      '$kPeriodicSyncMinIntervalMinutes–$kPeriodicSyncMaxIntervalMinutes min allowed',
                      style: VyanaType.caption.copyWith(color: t.textMuted),
                    ),
                  ],
                ),
              ),
              IconBtn(
                icon: 'plus',
                onTap: _interval < kPeriodicSyncMaxIntervalMinutes
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
            for (final preset in kPeriodicSyncPresetIntervals)
              Pill(
                label: '${preset}m',
                active: _interval == preset,
                onTap: () => _setInterval(preset),
              ),
          ],
        ),
        if (_saved) ...[
          const SizedBox(height: 16),
          Panel(
            pad: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VyanaIcon('checkCircle', size: 18, color: t.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sync interval saved.',
                    style: VyanaType.body.copyWith(
                      color: t.green,
                      height: 1.4,
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
