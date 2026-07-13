part of '../main.dart';

class RingHeroSection extends StatelessWidget {
  const RingHeroSection({
    required this.connected,
    required this.status,
    required this.basicInfo,
    required this.selectedDevice,
    required this.vitals,
    required this.measuring,
    required this.activeMeasurement,
    super.key,
  });

  final bool connected;
  final String status;
  final DeviceBasicSnapshot? basicInfo;
  final dynamic selectedDevice;
  final RingVitals vitals;
  final bool measuring;
  final String? activeMeasurement;

  @override
  Widget build(BuildContext context) {
    final ringName = selectedDevice == null
        ? connected
              ? 'Connected ring'
              : 'No ring connected'
        : deviceLabel(selectedDevice);
    final deviceId = selectedDevice == null
        ? basicInfo?.deviceId ?? '-'
        : deviceAddress(selectedDevice);
    final batteryLevel = vitals.battery ?? basicInfo?.batteryPower;
    final batteryStatus = basicInfo?.batteryStatus;
    final displayStatus = measuring && activeMeasurement != null
        ? '$activeMeasurement measurement in progress'
        : status;
    final statusColor = connected
        ? const Color(0xFF3DDC97)
        : const Color(0xFFFFC857);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102B2F), Color(0xFF173B3D)],
        ),
        border: Border.all(color: const Color(0xFF2C5658)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ringName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    deviceId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFB7CBCD),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (measuring)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox.square(
                            dimension: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFC857),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          displayStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFE7F4F3)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF214A4E),
                    border: Border.all(color: const Color(0xFF4B7779)),
                  ),
                  child: const Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1E4448),
                    border: Border.all(color: const Color(0xFF3E686B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        batteryIcon(batteryLevel, status: batteryStatus),
                        size: 15,
                        color: const Color(0xFFBFE7E4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        batteryDisplayText(batteryLevel, batteryStatus),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DevicePanel extends StatelessWidget {
  const DevicePanel({
    required this.devices,
    required this.selectedDevice,
    required this.basicInfo,
    required this.vitals,
    required this.isConnecting,
    required this.isScanning,
    required this.scanHint,
    required this.onScan,
    required this.onConnect,
    super.key,
  });

  final List<dynamic> devices;
  final dynamic selectedDevice;
  final DeviceBasicSnapshot? basicInfo;
  final RingVitals vitals;
  final bool isConnecting;
  final bool isScanning;
  final String scanHint;
  final VoidCallback onScan;
  final Future<void> Function(dynamic device) onConnect;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 14,
      grad: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nearby rings',
                  style: VyanaType.label.copyWith(color: t.text, fontSize: 15),
                ),
              ),
              if (isScanning)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.green),
                )
              else
                TextButton(
                  onPressed: onScan,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Scan', style: VyanaType.label.copyWith(color: t.green)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            _ScanEmptyState(text: scanHint)
          else
            ...devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DeviceTile(
                  device: device,
                  selected: sameDevice(device, selectedDevice),
                  busy: isConnecting && sameDevice(device, selectedDevice),
                  basicInfo: basicInfo,
                  vitals: vitals,
                  onTap: () => onConnect(device),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanEmptyState extends StatelessWidget {
  const _ScanEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VyanaIcon('ring', size: 18, color: t.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5)),
        ),
      ],
    );
  }
}

class PairedPranaPanel extends StatelessWidget {
  const PairedPranaPanel({
    required this.ring,
    required this.connected,
    required this.basicInfo,
    required this.vitals,
    required this.busy,
    required this.reconnecting,
    required this.onReconnect,
    required this.onUnpair,
    super.key,
  });

  final SavedPranaRing ring;
  final bool connected;
  final DeviceBasicSnapshot? basicInfo;
  final RingVitals vitals;
  final bool busy;
  final bool reconnecting;
  final VoidCallback onReconnect;
  final VoidCallback onUnpair;

  @override
  Widget build(BuildContext context) {
    final batteryLevel =
        vitals.battery ?? basicInfo?.batteryPower ?? ring.batteryPower;
    final batteryStatus = basicInfo?.batteryStatus ?? ring.batteryStatus ?? '-';
    final basicFirmware = basicInfo?.firmwareVersion;
    final firmware =
        basicFirmware != null &&
            basicFirmware.isNotEmpty &&
            basicFirmware != '-'
        ? basicFirmware
        : ring.firmwareVersion;
    final metrics = [
      SmallMetric(label: 'Status', value: connected ? 'Connected' : 'Saved'),
      SmallMetric(
        label: 'Battery',
        value: batteryDisplayText(batteryLevel, batteryStatus),
      ),
      if (firmware != null && firmware.isNotEmpty)
        SmallMetric(label: 'Firmware', value: firmware),
      if (ring.rssi != null) SmallMetric(label: 'RSSI', value: '${ring.rssi}'),
    ];

    final t = context.vyana;
    final ac = connected ? t.green : t.gold;
    return Panel(
      pad: 14,
      grad: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VyanaIconBadge(
                name: connected ? 'ring' : 'bluetooth',
                color: ac,
                size: 42,
                iconSize: 20,
                borderRadius: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ring.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.label.copyWith(color: t.text, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ring.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.mono10.copyWith(color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: metrics),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Cta(
                  label: reconnecting ? 'Reconnecting…' : 'Reconnect',
                  icon: 'refresh',
                  solid: false,
                  disabled: connected || busy,
                  onTap: onReconnect,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Cta(
                  label: 'Unpair',
                  icon: 'x',
                  solid: false,
                  disabled: busy,
                  onTap: onUnpair,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Other PRANA rings are hidden until this ring is unpaired.',
            style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    required this.device,
    required this.selected,
    required this.busy,
    required this.basicInfo,
    required this.vitals,
    required this.onTap,
    super.key,
  });

  final dynamic device;
  final bool selected;
  final bool busy;
  final DeviceBasicSnapshot? basicInfo;
  final RingVitals vitals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final batteryLevel = deviceBatteryLevel(device, basicInfo, vitals);
    final batteryStatus = deviceBatteryStatus(device, basicInfo);
    final battery = batteryDisplayText(batteryLevel, batteryStatus);
    final firmware = deviceFirmware(device, basicInfo);
    final showConnectedDetails =
        selected && (battery != '-' || firmware != '-');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? t.green : t.border),
            color: selected
                ? t.green.withValues(alpha: t.isDark ? 0.12 : 0.08)
                : t.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 38,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.green,
                        ),
                      ),
                    ),
                  )
                else
                  VyanaIconBadge(
                    name: 'bluetooth',
                    color: t.green,
                    size: 38,
                    iconSize: 18,
                    borderRadius: 12,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceLabel(device),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VyanaType.label.copyWith(color: t.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        deviceAddress(device),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VyanaType.mono10.copyWith(color: t.textMuted),
                      ),
                    if (showConnectedDetails) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          SmallMetric(label: 'Battery', value: battery),
                          SmallMetric(label: 'Firmware', value: firmware),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SmallMetric(label: 'RSSI', value: '${deviceRssi(device)}'),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class VitalsGrid extends StatelessWidget {
  const VitalsGrid({
    required this.vitals,
    required this.basicInfo,
    required this.features,
    required this.onSleepTap,
    required this.onMeasurementsTap,
    super.key,
  });

  final RingVitals vitals;
  final DeviceBasicSnapshot? basicInfo;
  final DeviceFeatureSnapshot? features;
  final VoidCallback onSleepTap;
  final VoidCallback onMeasurementsTap;

  @override
  Widget build(BuildContext context) {
    final feature = features;
    final batteryLevel = vitals.battery ?? basicInfo?.batteryPower;
    final batteryStatus = basicInfo?.batteryStatus;
    final items = [
      VitalItem(
        'Heart',
        valueOrDash(vitals.heartRate),
        'bpm',
        Icons.favorite,
        feature == null ||
            feature.supportsAny(const [
              'isSupportHeartRate',
              'isSupportStartHeartRateMeasurement',
            ]),
        onMeasurementsTap,
      ),
      VitalItem(
        'SpO2',
        valueOrDash(vitals.bloodOxygen),
        '%',
        Icons.bloodtype,
        feature == null ||
            feature.supportsAny(const [
              'isSupportBloodOxygen',
              'isSupportStartBloodOxygenMeasurement',
            ]),
        onMeasurementsTap,
      ),
      VitalItem(
        'Blood pressure',
        vitals.bloodPressure ?? '-',
        'mmHg',
        Icons.speed,
        feature == null ||
            feature.supportsAny(const [
              'isSupportBloodPressure',
              'isSupportStartBloodPressureMeasurement',
            ]),
        onMeasurementsTap,
      ),
      VitalItem(
        'Temperature',
        doubleOrDash(vitals.temperature, 1),
        'C',
        Icons.thermostat,
        feature == null ||
            feature.supportsAny(const [
              'isSupportTemperature',
              'isSupportStartBodyTemperatureMeasurement',
            ]),
        onMeasurementsTap,
      ),
      VitalItem(
        'HRV',
        valueOrDash(vitals.hrv),
        'ms',
        Icons.timeline,
        feature == null ||
            feature.supportsAny(const [
              'isSupportHRV',
              'isSupportStartHRVMeasurement',
            ]),
        onMeasurementsTap,
      ),
      VitalItem(
        'Steps',
        valueOrDash(vitals.steps),
        'steps',
        Icons.directions_walk,
        feature == null || feature.supports('isSupportStep'),
      ),
      VitalItem(
        'Sleep',
        vitals.sleepSummary ?? '-',
        '',
        Icons.bedtime,
        feature == null || feature.supports('isSupportSleep'),
        onSleepTap,
      ),
      VitalItem(
        'Battery',
        batteryDisplayText(batteryLevel, batteryStatus),
        '',
        batteryIcon(batteryLevel, status: batteryStatus),
        true,
      ),
      VitalItem(
        'Glucose',
        doubleOrDash(vitals.bloodGlucose, 1),
        'mmol/L',
        Icons.water_drop,
        feature == null ||
            feature.supportsAny(const [
              'isSupportBloodGlucose',
              'isSupportStartBloodGlucoseMeasurement',
            ]),
        onMeasurementsTap,
      ),
      VitalItem(
        'Uric acid',
        valueOrDash(vitals.uricAcid),
        'umol/L',
        Icons.science,
        feature == null || feature.supports('isSupportUricAcid'),
      ),
      VitalItem(
        'Cholesterol',
        doubleOrDash(vitals.totalCholesterol, 1),
        'mmol/L',
        Icons.biotech,
        feature == null || feature.supports('isSupportBloodFat'),
      ),
    ].where((item) => item.supported).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vitals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  vitals.updatedAt == null
                      ? 'No sync yet'
                      : timeLabel(vitals.updatedAt!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.favorite,
                text:
                    'Connect and sync to load supported vitals from the ring.',
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  mainAxisExtent: 112,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) => VitalCard(item: items[index]),
              ),
          ],
        ),
      ),
    );
  }
}

class VitalItem {
  const VitalItem(
    this.label,
    this.value,
    this.unit,
    this.icon,
    this.supported, [
    this.onTap,
  ]);

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final bool supported;
  final VoidCallback? onTap;
}

class VitalCard extends StatelessWidget {
  const VitalCard({required this.item, super.key});

  final VitalItem item;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (item.unit.isNotEmpty)
            Text(item.unit, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );

    if (item.onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E7ED)),
          color: const Color(0xFFFBFCFD),
        ),
        child: content,
      );
    }

    return Material(
      color: const Color(0xFFFBFCFD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE1E7ED)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: item.onTap,
        child: content,
      ),
    );
  }
}
