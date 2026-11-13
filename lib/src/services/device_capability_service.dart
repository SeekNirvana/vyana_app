import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Cached device facts used for soft capability warnings (e.g. on-device LLM RAM).
class DeviceCapabilityService {
  DeviceCapabilityService._();

  static final DeviceCapabilityService instance = DeviceCapabilityService._();

  static const int lowRamThresholdMb = 6 * 1024;

  int? _physicalRamMb;

  Future<int?> physicalRamMb() async {
    if (_physicalRamMb != null) return _physicalRamMb;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        _physicalRamMb = (await plugin.androidInfo).physicalRamSize;
      } else if (Platform.isIOS) {
        _physicalRamMb = (await plugin.iosInfo).physicalRamSize;
      }
    } on Object {
      // Unknown RAM — do not show a false warning.
    }
    return _physicalRamMb;
  }

  Future<bool> isLowRam() async {
    final mb = await physicalRamMb();
    if (mb == null) return false;
    return mb < lowRamThresholdMb;
  }

  String? _manufacturer;

  /// Lower-case manufacturer, for the OEM-specific background-app steps
  /// (bug 44 (b)). Empty string when it cannot be read, so the generic card
  /// still shows.
  Future<String> manufacturer() async {
    final cached = _manufacturer;
    if (cached != null) return cached;
    var name = '';
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        name = '${info.manufacturer} ${info.brand}'.toLowerCase();
      }
    } on Object {
      // Unknown make — the generic steps are still correct.
    }
    _manufacturer = name;
    return name;
  }
}

/// The steps that stop a given phone's battery manager closing Vyana.
/// Android gives no API for any of this, so the honest fix is to tell the
/// user where the switch is on their own phone (bug 44 (b)).
class OemBackgroundSteps {
  const OemBackgroundSteps({required this.heading, required this.steps});

  final String heading;
  final List<String> steps;

  /// dontkillmyapp.com is the reference; these are the makes we have seen
  /// stop Vyana overnight.
  static OemBackgroundSteps? forManufacturer(String make) {
    if (make.contains('honor') || make.contains('huawei')) {
      // Confirmed on a Honor 200 Pro (MagicOS): with "Manage automatically"
      // on, the service was gone with the app closed; with these three
      // switches on, the service notification stays.
      return const OemBackgroundSteps(
        heading: 'Honor and Huawei phones close background apps',
        steps: [
          'Settings → Apps → App launch → Vyana',
          'Turn off "Manage automatically"',
          'Turn on Auto-launch, Secondary launch and Run in background',
        ],
      );
    }
    if (make.contains('samsung')) {
      return const OemBackgroundSteps(
        heading: 'Samsung puts unused apps to sleep',
        steps: [
          'Settings → Battery → Background usage limits',
          'Remove Vyana from "Sleeping apps" and "Deep sleeping apps"',
          'Settings → Apps → Vyana → Battery → Unrestricted',
        ],
      );
    }
    if (make.contains('xiaomi') ||
        make.contains('redmi') ||
        make.contains('poco')) {
      return const OemBackgroundSteps(
        heading: 'Xiaomi phones block autostart',
        steps: [
          'Settings → Apps → Permissions → Autostart → turn Vyana on',
          'Recents → hold Vyana → lock it',
          'Settings → Apps → Vyana → Battery saver → No restrictions',
        ],
      );
    }
    if (make.contains('oneplus') ||
        make.contains('oppo') ||
        make.contains('realme')) {
      return const OemBackgroundSteps(
        heading: 'This phone sleeps background apps',
        steps: [
          'Settings → Battery → Battery optimisation → Vyana → Don\'t optimise',
          'Settings → Apps → Vyana → Allow background activity',
        ],
      );
    }
    return null;
  }
}