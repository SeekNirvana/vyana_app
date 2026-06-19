import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';

import '../brand/wallet_branding.dart';
import 'wallet_controller.dart';

/// A wallet app that speaks Solana Mobile Wallet Adapter on this device.
class MwaWalletOption {
  const MwaWalletOption({required this.package, required this.label});

  final String package;
  final String label;

  static const seedVaultPackage = 'com.solanamobile.wallet';
}

/// Native MWA connection on Solana Mobile Stack devices (Seeker, Saga).
class SolanaMobileWalletService {
  SolanaMobileWalletService._();

  static const _channel = MethodChannel('vyana/solana_mobile_wallet');

  static Future<bool> isAvailable() async {
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<MwaWalletOption>> listInstalledWallets() async {
    try {
      final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listWallets',
      );
      if (result == null) return const [];
      return result
          .map((entry) {
            final package = entry['package'] as String?;
            final label = entry['label'] as String?;
            if (package == null || label == null) return null;
            return MwaWalletOption(package: package, label: label);
          })
          .whereType<MwaWalletOption>()
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  static Future<SolanaMobileAuthResult> authorize({
    String? walletPackage,
    Uri? identityUri,
    Uri? iconUri,
    String identityName = kVyanaWalletIdentityName,
    String cluster = 'mainnet-beta',
  }) async {
    identityUri ??= Uri.parse(kVyanaWalletIdentityUri);
    iconUri ??= Uri.parse(kVyanaWalletIconRelative);
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'authorize',
      {
        if (walletPackage != null) 'walletPackage': walletPackage,
        'identityUri': identityUri.toString(),
        'iconUri': iconUri.toString(),
        'identityName': identityName,
        'cluster': cluster,
      },
    );
    if (result == null) {
      throw const SolanaMobileWalletException('Wallet authorization returned no data.');
    }
    final publicKey = result['publicKey'];
    final authToken = result['authToken'] as String?;
    if (publicKey is! List || authToken == null || authToken.isEmpty) {
      throw const SolanaMobileWalletException('Wallet authorization was incomplete.');
    }
    return SolanaMobileAuthResult(
      authToken: authToken,
      publicKey: List<int>.from(publicKey),
      accountLabel: result['accountLabel'] as String?,
      walletUriBase: result['walletUriBase'] as String?,
      walletPackage: result['walletPackage'] as String? ?? walletPackage,
    );
  }

  static Future<void> deauthorize({
    required String authToken,
    String? walletPackage,
  }) async {
    await _channel.invokeMethod<void>('deauthorize', {
      'authToken': authToken,
      if (walletPackage != null) 'walletPackage': walletPackage,
    });
  }

  /// Sign and send transactions via the connected MWA wallet (Phantom, Seed Vault, …).
  static Future<SolanaMobileSignResult> signAndSendTransactions({
    required String authToken,
    String? walletPackage,
    required List<Uint8List> transactions,
    Duration timeout = const Duration(seconds: 20),
    Uri? identityUri,
    Uri? iconUri,
    String identityName = kVyanaWalletIdentityName,
    String cluster = 'mainnet-beta',
  }) async {
    identityUri ??= Uri.parse(kVyanaWalletIdentityUri);
    iconUri ??= Uri.parse(kVyanaWalletIconRelative);
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>(
            'signAndSendTransactions',
            {
              'authToken': authToken,
              if (walletPackage != null) 'walletPackage': walletPackage,
              'transactions':
                  transactions.map((tx) => base64Encode(tx)).toList(growable: false),
              'identityUri': identityUri.toString(),
              'iconUri': iconUri.toString(),
              'identityName': identityName,
              'cluster': cluster,
              'timeoutMs': timeout.inMilliseconds,
            },
          )
          .timeout(timeout + const Duration(seconds: 8));

      final raw = result?['signatures'];
      if (raw is! List || raw.isEmpty) {
        throw const SolanaMobileWalletException(
          'Wallet did not complete the payment.',
        );
      }

      final signatures = raw
          .map((entry) {
            if (entry is! String || entry.isEmpty) return null;
            return Uint8List.fromList(base64Decode(entry));
          })
          .whereType<Uint8List>()
          .toList(growable: false);

      final refreshedToken = result?['authToken'] as String?;
      final authRefreshed = result?['authRefreshed'] == true;

      return SolanaMobileSignResult(
        signatures: signatures,
        refreshedAuthToken:
            authRefreshed && refreshedToken != null && refreshedToken.isNotEmpty
                ? refreshedToken
                : null,
        walletPackage: result?['walletPackage'] as String? ?? walletPackage,
      );
    } on TimeoutException {
      throw const SolanaMobileWalletException(
        'Wallet did not respond in time. Open your wallet app and try again.',
      );
    } on PlatformException catch (error) {
      final detail = error.message?.trim();
      throw SolanaMobileWalletException(
        _friendlyWalletError(error.code, detail),
      );
    }
  }

  static String _friendlyWalletError(String code, String? detail) {
    if (code == 'MWA_AUTH_FAILED') {
      return 'Wallet authorization expired. Disconnect, reconnect your wallet, '
          'then try again.';
    }
    if (detail != null && detail.isNotEmpty) {
      if (detail.toLowerCase().contains('authorization')) {
        return 'Wallet authorization expired. Disconnect, reconnect your wallet, '
            'then try again.';
      }
      return detail;
    }
    return switch (code) {
      'MWA_TIMEOUT' =>
        'Wallet did not respond in time. Open your wallet app and try again.',
      'MWA_CANCELLED' => 'Payment was cancelled in your wallet.',
      'MWA_EMPTY_SIGNATURE' => 'Wallet did not complete the payment.',
      _ => 'Payment failed in wallet ($code).',
    };
  }
}

class SolanaMobileSignResult {
  const SolanaMobileSignResult({
    required this.signatures,
    this.refreshedAuthToken,
    this.walletPackage,
  });

  final List<Uint8List> signatures;
  final String? refreshedAuthToken;
  final String? walletPackage;
}

class SolanaMobileAuthResult {
  const SolanaMobileAuthResult({
    required this.authToken,
    required this.publicKey,
    this.accountLabel,
    this.walletUriBase,
    this.walletPackage,
  });

  final String authToken;
  final List<int> publicKey;
  final String? accountLabel;
  final String? walletUriBase;
  final String? walletPackage;
}

class SolanaMobileWalletException implements Exception {
  const SolanaMobileWalletException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MwaSelectedWalletNotifier extends StateNotifier<String?> {
  MwaSelectedWalletNotifier() : super(null) {
    _load();
  }

  static const _prefsKey = 'vyana.wallet.mwa_package';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefsKey) ?? MwaWalletOption.seedVaultPackage;
  }

  Future<void> select(String package) async {
    state = package;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, package);
  }
}

final mwaSelectedWalletProvider =
    StateNotifierProvider<MwaSelectedWalletNotifier, String?>(
  (ref) => MwaSelectedWalletNotifier(),
);

final mwaInstalledWalletsProvider = FutureProvider<List<MwaWalletOption>>(
  (ref) => SolanaMobileWalletService.listInstalledWallets(),
);

/// Connect / disconnect via the native MWA bridge.
class SolanaMobileWalletController {
  Future<void> connect(
    WalletController wallet, {
    String? walletPackage,
  }) async {
    wallet.setConnecting(true);
    try {
      final available = await SolanaMobileWalletService.isAvailable();
      if (!available) {
        wallet.setError(
          'No MWA wallet found. Install Seed Vault, Phantom, or Solflare.',
        );
        return;
      }
      final result = await SolanaMobileWalletService.authorize(
        walletPackage: walletPackage,
      );
      final address = Ed25519HDPublicKey(result.publicKey).toBase58();
      await wallet.setConnected(
        address: address,
        backend: WalletBackend.solanaMobile,
        solanaAuthToken: result.authToken,
        solanaWalletPackage: result.walletPackage ?? walletPackage,
        chain: WalletChain.solana,
      );
    } on PlatformException catch (error) {
      final detail = error.message?.trim();
      wallet.setError(
        detail != null && detail.isNotEmpty
            ? detail
            : 'Wallet connection failed (${error.code}).',
      );
    } on SolanaMobileWalletException catch (error) {
      wallet.setError(error.message);
    } on Object catch (error) {
      wallet.setError('$error');
    }
  }

  /// Clears the local Vyana wallet session only. Skips native MWA deauthorize
  /// because it launches the wallet app and is brittle when the user dismisses it.
  Future<void> disconnect(WalletController wallet) async {
    await wallet.clearSolanaAuthToken();
    await wallet.clearSolanaWalletPackage();
    await wallet.disconnect();
  }
}

final solanaMobileWalletControllerProvider = Provider<SolanaMobileWalletController>(
  (ref) => SolanaMobileWalletController(),
);