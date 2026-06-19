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
}