import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_config.dart';
import 'wallet_platform.dart';

/// How the wallet was connected — keeps Solana Mobile and Reown paths separate.
enum WalletBackend {
  none,
  reown,
  solanaMobile,
}

/// Primary Solana · secondary Ethereum on Reown-connected devices.
enum WalletChain {
  solana('Solana', 'SOL'),
  ethereum('Ethereum', 'ETH');

  const WalletChain(this.label, this.currency);
  final String label;
  final String currency;

  static WalletChain fromName(String? value) {
    return switch (value) {
      'ethereum' => WalletChain.ethereum,
      _ => WalletChain.solana,
    };
  }

  String get storageName => name;
}

class WalletState {
  const WalletState({
    this.solanaAddress,
    this.ethAddress,
    this.activeChain = WalletChain.solana,
    this.backend = WalletBackend.none,
    this.connecting = false,
    this.error,
    this.loaded = false,
  });

  final String? solanaAddress;
  final String? ethAddress;
  final WalletChain activeChain;
  final WalletBackend backend;
  final bool connecting;
  final String? error;
  final bool loaded;

  String? get address => switch (activeChain) {
        WalletChain.solana => solanaAddress,
        WalletChain.ethereum => ethAddress,
      };

  bool get isConnected =>
      (solanaAddress != null && solanaAddress!.isNotEmpty) ||
      (ethAddress != null && ethAddress!.isNotEmpty);

  bool get hasActiveAddress {
    final a = address;
    return a != null && a.isNotEmpty;
  }

  String shortAddress([String? value]) {
    final a = value ?? address;
    if (a == null || a.length < 10) return a ?? '';
    return '${a.substring(0, 4)}…${a.substring(a.length - 4)}';
  }

  WalletState copyWith({
    String? solanaAddress,
    String? ethAddress,
    bool clearSolanaAddress = false,
    bool clearEthAddress = false,
    WalletChain? activeChain,
    WalletBackend? backend,
    bool? connecting,
    String? error,
    bool clearError = false,
    bool? loaded,
  }) {
    return WalletState(
      solanaAddress:
          clearSolanaAddress ? null : (solanaAddress ?? this.solanaAddress),
      ethAddress: clearEthAddress ? null : (ethAddress ?? this.ethAddress),
      activeChain: activeChain ?? this.activeChain,
      backend: backend ?? this.backend,
      connecting: connecting ?? this.connecting,
      error: clearError ? null : (error ?? this.error),
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Reown project id — loaded from `.env` or `--dart-define=REOWN_PROJECT_ID=…`.
String get kReownProjectId => EnvConfig.reownProjectId;

class WalletController extends StateNotifier<WalletState> {
  WalletController() : super(const WalletState()) {
    _load();
  }

  static const _solanaKey = 'vyana.wallet.solana';
  static const _ethKey = 'vyana.wallet.eth';
  static const _chainKey = 'vyana.wallet.chain';
  static const _backendKey = 'vyana.wallet.backend';
  static const _authTokenKey = 'vyana.wallet.solana_auth_token';
  static const _solanaWalletPackageKey = 'vyana.wallet.solana_package';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = WalletState(
      solanaAddress: prefs.getString(_solanaKey),
      ethAddress: prefs.getString(_ethKey),
      activeChain: WalletChain.fromName(prefs.getString(_chainKey)),
      backend: _backendFromName(prefs.getString(_backendKey)),
      loaded: true,
    );
  }

  static WalletBackend _backendFromName(String? name) {
    return switch (name) {
      'reown' => WalletBackend.reown,
      'solanaMobile' => WalletBackend.solanaMobile,
      _ => WalletBackend.none,
    };
  }

  static String _backendName(WalletBackend backend) => switch (backend) {
        WalletBackend.reown => 'reown',
        WalletBackend.solanaMobile => 'solanaMobile',
        WalletBackend.none => '',
      };

  Future<void> setActiveChain(WalletChain chain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chainKey, chain.storageName);
    state = state.copyWith(activeChain: chain);
  }

  Future<void> setReownAddresses({
    String? solana,
    String? ethereum,
    WalletChain? activeChain,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (solana != null) await prefs.setString(_solanaKey, solana);
    if (ethereum != null) await prefs.setString(_ethKey, ethereum);
    await prefs.setString(_backendKey, _backendName(WalletBackend.reown));
    if (activeChain != null) {
      await prefs.setString(_chainKey, activeChain.storageName);
    }
    state = state.copyWith(
      solanaAddress: solana ?? state.solanaAddress,
      ethAddress: ethereum ?? state.ethAddress,
      activeChain: activeChain,
      backend: WalletBackend.reown,
      connecting: false,
      clearError: true,
    );
  }

  Future<void> setConnected({
    required String address,
    required WalletBackend backend,
    String? solanaAuthToken,
    String? solanaWalletPackage,
    WalletChain chain = WalletChain.solana,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendKey, _backendName(backend));
    await prefs.setString(_chainKey, chain.storageName);
    if (backend == WalletBackend.solanaMobile || chain == WalletChain.solana) {
      await prefs.setString(_solanaKey, address);
    }
    if (backend == WalletBackend.reown && chain == WalletChain.ethereum) {
      await prefs.setString(_ethKey, address);
    }
    if (solanaAuthToken != null) {
      await prefs.setString(_authTokenKey, solanaAuthToken);
    }
    if (solanaWalletPackage != null) {
      await prefs.setString(_solanaWalletPackageKey, solanaWalletPackage);
    }
    state = state.copyWith(
      solanaAddress:
          chain == WalletChain.solana ? address : state.solanaAddress,
      ethAddress: chain == WalletChain.ethereum ? address : state.ethAddress,
      activeChain: chain,
      backend: backend,
      connecting: false,
      clearError: true,
    );
  }

  Future<String?> loadSolanaAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  Future<void> saveSolanaAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  Future<void> clearSolanaAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }

  Future<String?> loadSolanaWalletPackage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_solanaWalletPackageKey);
  }

  Future<void> clearSolanaWalletPackage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_solanaWalletPackageKey);
  }

  void setConnecting(bool value) {
    state = state.copyWith(connecting: value, clearError: true);
  }

  void setError(String message) {
    state = state.copyWith(connecting: false, error: message);
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_solanaKey);
    await prefs.remove(_ethKey);
    await prefs.remove(_backendKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_solanaWalletPackageKey);
    final chain = WalletChain.fromName(prefs.getString(_chainKey));
    state = WalletState(activeChain: chain, loaded: true);
  }
}

final walletControllerProvider =
    StateNotifierProvider<WalletController, WalletState>(
  (ref) => WalletController(),
);

/// True on Solana Mobile Stack devices (Seeker, Saga, etc.).
final solanaMobileDeviceProvider = FutureProvider<bool>((ref) async {
  return isSolanaMobileDevice();
});