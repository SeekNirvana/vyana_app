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
                        Text('YOUR RING',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        Text('PRANA rings',
                            style: VyanaType.appBarSerif.copyWith(color: t.text)),
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
                        child: Text(
                          _status,
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                      ),
                      if (_isScanning)
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.green,
                          ),
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
            ],
          ),
        ),
      ),
    );
  }
}