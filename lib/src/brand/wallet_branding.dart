import 'dart:convert';

import 'package:flutter/services.dart';

/// Bundled Vyana logo — shared by in-app UI and wallet connect metadata.
const kVyanaLogoAsset = 'assets/logo.png';

const kVyanaWalletIdentityUri = 'https://seeknirvana.com/vyana';
const kVyanaWalletIdentityName = 'Vyana';

/// Relative icon path when a wallet resolves against [kVyanaWalletIdentityUri].
const kVyanaWalletIconRelative = 'logo.png';

String? _cachedWalletIconDataUri;

/// Data URI for the bundled logo, used by Reown / WalletConnect metadata.
Future<String> vyanaWalletIconDataUri() async {
  final cached = _cachedWalletIconDataUri;
  if (cached != null) return cached;

  final bytes = await rootBundle.load(kVyanaLogoAsset);
  final encoded = base64Encode(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  final dataUri = 'data:image/png;base64,$encoded';
  _cachedWalletIconDataUri = dataUri;
  return dataUri;
}