part of '../main.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({
    required this.repo,
    required this.selectedDevice,
    required this.pairedRing,
    required this.connected,
    required this.basicInfo,
    required this.vitals,
    required this.onConnect,
    required this.onReconnectPaired,
    required this.onUnpair,
    required this.onConnectedDeviceDetected,
    this.onRename,
    this.onFirstConnected,
    super.key,
  });

  final RingRepository repo;
  final dynamic selectedDevice;
  final SavedPranaRing? pairedRing;
  final bool connected;
  final DeviceBasicSnapshot? basicInfo;
  final RingVitals vitals;
  final Future<bool> Function(dynamic device) onConnect;
  final Future<bool> Function() onReconnectPaired;
  final Future<bool> Function() onUnpair;
  final ValueChanged<dynamic> onConnectedDeviceDetected;
  final Future<void> Function(String name)? onRename;
  final VoidCallback? onFirstConnected;

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isUnpairing = false;
  bool _isReconnecting = false;
  String _status = 'Ready to scan';
  String _scanHint = 'SDK scan results will appear here.';
  ScanAccess? _scanAccess;
  List<dynamic> _devices = [];
  dynamic _selectedDevice;
  SavedPranaRing? _pairedRing;
  late bool _connected;
  dynamic _busyDevice;
  DeviceBasicSnapshot? _basicInfo;
  late RingVitals _vitals;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  bool _syncUpToDate = false;

  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.selectedDevice;
    _pairedRing = widget.pairedRing;
    _connected = widget.connected;
    _basicInfo = widget.basicInfo;
    _vitals = widget.vitals;
    if (_pairedRing == null) {
      unawaited(_scan());
    } else {
      _status = _connected
          ? 'Connected to ${_pairedRing!.displayName}'
          : 'Paired with ${_pairedRing!.displayName}';
      _scanHint = 'Unpair this PRANA ring before scanning for another one.';
    }
  }

  Future<void> _scan() async {
    if (_isScanning) return;
    if (_pairedRing != null) {
      setState(() {
        _status = 'Unpair ${_pairedRing!.displayName} before scanning';
        _scanHint = 'Other PRANA rings stay hidden until unpair succeeds.';
        _scanAccess = null;
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Preparing PRANA scan';
      _scanHint = 'Checking Bluetooth scan access';
      _devices = [];
      _scanAccess = null;
    });

    try {
      final scanAccess = await widget.repo.ensureScanAccess();
      if (!scanAccess.granted) {
        if (!mounted) return;
        setState(() {
          _scanAccess = scanAccess;
          _status = scanAccess.denialTitle;
          _scanHint = scanAccess.denialHint;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _scanAccess = scanAccess;
        _status = 'Scanning for PRANA rings';
        _scanHint = 'Scanning for nearby PRANA-compatible rings';
      });

      final devices = await widget.repo.scanDevices(seconds: 8);
      dynamic connectedScanDevice;
      for (final device in devices) {
        if (deviceLooksSystemConnected(device)) {
          connectedScanDevice = device;
          break;
        }
      }
      final alreadyConnected =
          devices.isNotEmpty && await widget.repo.isConnected();
      connectedScanDevice = alreadyConnected
          ? connectedScanDevice ?? devices.first
          : null;
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (connectedScanDevice != null) {
          _selectedDevice = connectedScanDevice;
        }
        _status = connectedScanDevice != null
            ? 'Connected to ${deviceLabel(connectedScanDevice)}'
            : devices.isEmpty
            ? 'No PRANA rings found'
            : 'Found ${devices.length} ring${devices.length == 1 ? '' : 's'}';
        _scanHint = connectedScanDevice != null
            ? 'Ring connected. You can go back to the home screen.'
            : devices.isEmpty
            ? 'Keep the ring awake and close to the phone. Bluetooth, Nearby Devices, and Location access may need to be enabled depending on the phone. If the ring is connected in system Bluetooth settings, disconnect it there and scan again here.'
            : 'Tap a ring to connect.';
      });
      if (connectedScanDevice != null) {
        widget.onConnectedDeviceDetected(connectedScanDevice);
        unawaited(_syncConnectedDeviceDetails());
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'SDK scan failed: $error';
        _scanHint = 'SDK scan failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _openScanSettings() async {
    final access = _scanAccess;
    if (access == null) return;
    if (access.needsLocationSettings) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _connect(dynamic device) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _busyDevice = device;
      _selectedDevice = device;
      _status = 'Connecting to ${deviceLabel(device)}';
    });

    final connected = await widget.onConnect(device);
    if (!mounted) return;
    setState(() {
      _status = connected
          ? 'Connected to ${deviceLabel(device)}'
          : 'Connection failed';
      _scanHint = connected
          ? 'Ring connected. You can go back to the home screen.'
          : 'Connection failed. Try scanning again with the ring nearby.';
      _isConnecting = false;
      _busyDevice = null;
    });
    if (connected) {
      setState(() {
        _connected = true;
        _pairedRing = SavedPranaRing.fromDevice(
          device,
          basicInfo: _basicInfo,
          vitals: _vitals,
          previous: _pairedRing,
        );
      });
      await _syncConnectedDeviceDetails();
      if (!mounted) return;
      widget.onFirstConnected?.call();
    }
  }

  Future<void> _reconnectPaired() async {
    if (_isReconnecting || _isUnpairing) return;
    setState(() {
      _isReconnecting = true;
      _status = 'Reconnecting to ${_pairedRing?.displayName ?? 'PRANA ring'}';
    });

    final connected = await widget.onReconnectPaired();
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _status = connected
          ? 'Connected to ${_pairedRing?.displayName ?? 'PRANA ring'}'
          : 'Reconnect failed';
      _isReconnecting = false;
    });
    if (connected) {
      unawaited(_syncConnectedDeviceDetails());
    }
  }

  Future<void> _unpair() async {
    if (_isUnpairing || _isScanning) return;
    setState(() {
      _isUnpairing = true;
      _status = 'Unpairing ${_pairedRing?.displayName ?? 'PRANA ring'}';
      _scanHint = 'Waiting for PRANA unpair to finish';
    });

    final unpaired = await widget.onUnpair();
    if (!mounted) return;
    setState(() {
      _isUnpairing = false;
      if (unpaired) {
        _pairedRing = null;
        _connected = false;
        _selectedDevice = null;
        _devices = [];
        _status = 'PRANA ring unpaired';
        _scanHint = 'Scanning for available PRANA rings.';
      } else {
        _status = 'Unpair failed';
        _scanHint = 'Other PRANA rings stay hidden until unpair succeeds.';
      }
    });

    if (unpaired) {
      unawaited(_scan());
    }
  }


  /// Bug 26: "Last synced 06:41" under the status, so the Sync now button
  /// beside it has something to be about.
  String _syncLine() {
    if (_isSyncing) return 'Syncing your ring…';
    final at = _lastSyncedAt;
    if (at != null) return 'Last synced ${timeOfDayLabel(at)}';
    if (_syncUpToDate) return 'Up to date';
    return _scanHint;
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncUpToDate = false;
    });
    try {
      // A sync the user asked for always fetches sleep (bug 19).
      final result = await widget.repo.sync();
      if (!mounted) return;
      setState(() {
        _basicInfo = result.basicInfo ?? _basicInfo;
        _vitals = result.vitals.merge(_vitals);
        _lastSyncedAt = DateTime.now();
        _syncUpToDate = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _syncUpToDate = false);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Bug 26: switching rings. Scanning while a ring is paired is blocked on
  /// purpose today, and the SDK may only handle one ring at a time — that
  /// needs checking on a device before it is turned on, so until then the
  /// section says what to do instead of listing nothing.
  Future<void> _switchToRing(dynamic device) async {
    final paired = _pairedRing;
    if (paired == null) {
      await _connect(device);
      return;
    }
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Unpair ${paired.displayName} and connect to '
          '${deviceLabel(device)}?',
      message: 'Vyana pairs with one ring at a time.',
      confirmLabel: 'Switch',
    );
    if (confirmed != true) return;
    await _unpair();
    if (!mounted) return;
    await _connect(device);
  }

  /// Bug 26: renaming lives beside the name it changes.
  Future<void> _rename() async {
    final rename = widget.onRename;
    final paired = _pairedRing;
    if (rename == null || paired == null) return;
    var edited = paired.displayName;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename ring'),
        content: TextFormField(
          initialValue: edited,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ring name'),
          textInputAction: TextInputAction.done,
          onChanged: (value) => edited = value,
          onFieldSubmitted: (value) =>
              Navigator.of(dialogContext).pop(normalizeRingName(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(normalizeRingName(edited)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await rename(name);
    if (!mounted) return;
    setState(() => _pairedRing = _pairedRing?.copyWith(name: name));
  }

  Future<void> _syncConnectedDeviceDetails() async {
    try {
      final result = await widget.repo.sync();
      if (!mounted) return;
      setState(() {
        _basicInfo = result.basicInfo ?? _basicInfo;
        _vitals = result.vitals.merge(_vitals);
      });
    } on Object {
      // The dashboard still owns the main sync status; this detail refresh is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final accessDenied = _scanAccess != null && !_scanAccess!.granted;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(
                children: [
                  IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bug 26: the title says which of the two things
                        // this screen is. The model name comes from the
                        // paired ring, so a future model shows its own.
                        Text(
                          _pairedRing == null ? 'PAIR A RING' : 'YOUR RING',
                          style: VyanaType.eyebrow.copyWith(color: t.gold),
                        ),
                        Text(
                          _pairedRing == null
                              ? 'Vyana rings'
                              : '${_pairedRing!.modelName} ring',
                          style: VyanaType.appBarSerif.copyWith(color: t.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (accessDenied)
                AccessDeniedPanel(
                  title: _scanAccess!.denialTitle,
                  message: _scanAccess!.message,
                  icon: _scanAccess!.denialIcon,
                  hint: _scanAccess!.denialHint,
                  primaryLabel: _scanAccess!.needsLocationSettings
                      ? 'Open location settings'
                      : 'Open app settings',
                  onPrimary: () => unawaited(_openScanSettings()),
                  secondaryLabel: 'Try again',
                  onSecondary: _scan,
                )
              else
                Panel(
                  pad: 14,
                  grad: true,
                  child: Row(
                    children: [
                      VyanaIconBadge(
                        name: _isScanning ? 'refresh' : 'bluetooth',
                        color: t.green,
                        size: 40,
                        iconSize: 20,
                        borderRadius: 13,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _status,
                              style: VyanaType.label.copyWith(color: t.text),
                            ),
                            // Bug 26: "Sync now" existed only inside the
                            // stale banner, so when everything looked fine
                            // but the user doubted it there was nothing to
                            // tap. It belongs beside the sync time.
                            const SizedBox(height: 3),
                            Text(
                              _syncLine(),
                              style: VyanaType.mono10
                                  .copyWith(color: t.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (_isScanning)
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.green,
                          ),
                        )
                      else if (_pairedRing != null)
                        BorderedPill(
                          label: _isSyncing ? 'Syncing…' : 'Sync now',
                          color: t.green,
                          onTap: _isSyncing ? null : _syncNow,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_pairedRing != null)
                PairedPranaPanel(
                  ring: _pairedRing!,
                  connected: _connected,
                  basicInfo: _basicInfo,
                  vitals: _vitals,
                  busy: _isUnpairing || _isReconnecting,
                  reconnecting: _isReconnecting,
                  onReconnect: _reconnectPaired,
                  onUnpair: _unpair,
                  onRename: _rename,
                )
              else if (!accessDenied)
                DevicePanel(
                  devices: _devices,
                  selectedDevice: _busyDevice ?? _selectedDevice,
                  basicInfo: _basicInfo,
                  vitals: _vitals,
                  isConnecting: _isConnecting,
                  isScanning: _isScanning,
                  scanHint: _scanHint,
                  onScan: _scan,
                  onConnect: _connect,
                ),
              if (_pairedRing != null) ...[
                const SizedBox(height: 18),
                _NearbyRings(
                  devices: _devices,
                  pairedAddress: _pairedRing!.displayAddress,
                  pairedName: _pairedRing!.displayName,
                  scanning: _isScanning,
                  // Scanning while paired is blocked until the device check
                  // in bug 26 confirms it does not disturb the connection.
                  scanAllowed: kScanWhilePairedVerified,
                  onScan: _scan,
                  onUnpair: _unpair,
                  onPick: _switchToRing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
/// Bug 26: whether scanning while a ring is paired has been confirmed safe
/// on a device.
///
/// Today `_scan` returns early while paired, and the code never said why.
/// The reason is that the SDK may only handle one ring at a time, so a scan
/// could disturb the live connection, the vitals stream or a sync. That has
/// to be checked on real hardware, not reasoned about — so until someone
/// does, "PRANA rings near me" explains how to switch rings instead of
/// listing them. Flip this to true once the check passes; nothing else needs
/// to change.
const bool kScanWhilePairedVerified = false;

/// "PRANA rings near me" (mock 16a), under the ring card.
class _NearbyRings extends StatelessWidget {
  const _NearbyRings({
    required this.devices,
    required this.pairedAddress,
    required this.pairedName,
    required this.scanning,
    required this.scanAllowed,
    required this.onScan,
    required this.onUnpair,
    required this.onPick,
  });

  final List<dynamic> devices;
  final String pairedAddress;
  final String pairedName;
  final bool scanning;
  final bool scanAllowed;
  final VoidCallback onScan;
  final VoidCallback onUnpair;
  final ValueChanged<dynamic> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final others = [
      for (final d in devices)
        if (deviceAddress(d) != pairedAddress) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MonoEyebrow('PRANA RINGS NEAR ME', size: 10.5),
            ),
            if (scanAllowed)
              BorderedPill(
                label: scanning ? 'Scanning…' : 'Scan',
                onTap: scanning ? null : onScan,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!scanAllowed)
          Panel(
            pad: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unpair $pairedName to look for other rings.',
                  style: VyanaType.caption
                      .copyWith(color: t.textSec, height: 1.45),
                ),
                const SizedBox(height: 12),
                Cta(
                  label: 'Unpair',
                  icon: 'x',
                  solid: false,
                  onTap: onUnpair,
                ),
              ],
            ),
          )
        else if (others.isEmpty)
          Text(
            scanning
                ? 'Looking for rings nearby…'
                : 'No other rings found. Tap Scan to look again.',
            style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.45),
          )
        else
          for (final d in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HairlineCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                onTap: () => onPick(d),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            deviceLabel(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VyanaType.caption
                                .copyWith(color: t.text, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceAddress(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                VyanaType.mono10.copyWith(color: t.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Signal as a word: a dBm figure means nothing to
                    // someone deciding which ring is theirs.
                    Text(
                      deviceRssi(d) >= -70 ? 'Strong' : 'Weak',
                      style: VyanaType.mono12.copyWith(color: t.textSec),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
