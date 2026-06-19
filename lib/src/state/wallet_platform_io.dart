import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

Future<bool> isSolanaMobileDevice() async {
  if (!Platform.isAndroid) return false;
  final info = await DeviceInfoPlugin().androidInfo;
  final manufacturer = info.manufacturer.toLowerCase();
  final brand = info.brand.toLowerCase();
  final model = info.model.toLowerCase();
  final product = info.product.toLowerCase();
  return manufacturer.contains('solana') ||
      brand.contains('solana') ||
      model.contains('saga') ||
      model.contains('seeker') ||
      product.contains('saga') ||
      product.contains('seeker');
}