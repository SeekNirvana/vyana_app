import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/modal/i_appkit_modal_impl.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../brand/wallet_branding.dart';
import 'wallet_controller.dart';
import 'wallet_platform.dart';

/// One-shot Reown AppKit bootstrap for iOS / standard Android.
class ReownWalletState {
  const ReownWalletState({
    this.modal,
    this.phase = ReownWalletPhase.idle,
    this.error,
  });

  final ReownAppKitModal? modal;
  final ReownWalletPhase phase;
  final String? error;

  bool get isReady => phase == ReownWalletPhase.ready && modal != null;

  bool get isInitializing => phase == ReownWalletPhase.initializing;

  ReownWalletState copyWith({
    ReownAppKitModal? modal,
    ReownWalletPhase? phase,
    String? error,
    bool clearError = false,
  }) {
    return ReownWalletState(
      modal: modal ?? this.modal,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

enum ReownWalletPhase { idle, initializing, ready, error, skipped }

class ReownWalletService extends StateNotifier<ReownWalletState> {
  ReownWalletService() : super(const ReownWalletState());

  bool _initStarted = false;

  static const _solanaChainId = '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp';
  static const _ethChainId = '1';

  static final _featuresConfig = FeaturesConfig(
    socials: [
      AppKitSocialOption.Email,
      AppKitSocialOption.Google,
      AppKitSocialOption.Apple,
      AppKitSocialOption.Discord,
      AppKitSocialOption.X,
    ],
    showMainWallets: true,
  );

  static void _configureVyanaNetworks() {
    ReownAppKitModalNetworks.removeSupportedNetworks(NetworkUtils.eip155);
    ReownAppKitModalNetworks.addSupportedNetworks(
      NetworkUtils.eip155,
      const [
        ReownAppKitModalNetworkInfo(
          name: 'Ethereum',
          chainId: _ethChainId,
          currency: 'ETH',
          rpcUrl: 'https://ethereum-rpc.publicnode.com',
          explorerUrl: 'https://etherscan.io',
        ),
      ],
    );
    ReownAppKitModalNetworks.removeTestNetworks();
  }

  static ReownAppKitModalNetworkInfo? networkFor(WalletChain chain) {
    return switch (chain) {
      WalletChain.solana => ReownAppKitModalNetworks.getNetworkInfo(
          NetworkUtils.solana,
          _solanaChainId,
        ),
      WalletChain.ethereum => ReownAppKitModalNetworks.getNetworkInfo(
          NetworkUtils.eip155,
          _ethChainId,
        ),
    };
  }

  Future<void> initIfNeeded(BuildContext context) async {
    if (_initStarted) return;
    _initStarted = true;

    if (await isSolanaMobileDevice()) {
      state = const ReownWalletState(phase: ReownWalletPhase.skipped);
      return;
    }
    if (kReownProjectId.isEmpty) {
      state = const ReownWalletState(
        phase: ReownWalletPhase.error,
        error: 'Set REOWN_PROJECT_ID in .env (see .env.example).',
      );
      return;
    }

    state =
        state.copyWith(phase: ReownWalletPhase.initializing, clearError: true);
    if (!context.mounted) {
      state = state.copyWith(phase: ReownWalletPhase.idle);
      _initStarted = false;
      return;
    }
    final hostContext = context;
    try {
      _configureVyanaNetworks();
      final iconUri = await vyanaWalletIconDataUri();
      final modal = ReownAppKitModal(
        context: hostContext,
        projectId: kReownProjectId,
        featuresConfig: _featuresConfig,
        metadata: PairingMetadata(
          name: kVyanaWalletIdentityName,
          description: 'Sovereign wellness · optional Solana wallet',
          url: kVyanaWalletIdentityUri,
          icons: [iconUri],
          redirect: const Redirect(
            native: 'vyana://',
            universal: kVyanaWalletIdentityUri,
            linkMode: false,
          ),
        ),
        disconnectOnDispose: false,
        logLevel: LogLevel.nothing,
      );
      await modal.init();
      if (modal.status == ReownAppKitModalStatus.error) {
        state = const ReownWalletState(
          phase: ReownWalletPhase.error,
          error: 'Reown could not initialize. Check project ID and network.',
        );
        modal.dispose();
        return;
      }
      final solana = networkFor(WalletChain.solana);
      if (solana != null) {
        await modal.selectChain(solana);
      }
      state = ReownWalletState(modal: modal, phase: ReownWalletPhase.ready);
    } on Object catch (error) {
      state = ReownWalletState(
        phase: ReownWalletPhase.error,
        error: '$error',
      );
    }
  }

  Future<void> openConnect({WalletChain chain = WalletChain.solana}) async {
    final modal = state.modal;
    if (modal == null) return;
    final network = networkFor(chain);
    if (network != null) {
      await modal.selectChain(network);
    }
    await modal.openModalView();
  }

  Future<void> selectChain(WalletChain chain) async {
    final modal = state.modal;
    final network = networkFor(chain);
    if (modal == null || network == null) return;
    await modal.selectChain(
      network,
      switchChain: modal.isConnected,
    );
  }

  String? addressForChain(ReownAppKitModal modal, WalletChain chain) {
    if (!modal.isConnected) return null;
    final namespace = switch (chain) {
      WalletChain.solana => NetworkUtils.solana,
      WalletChain.ethereum => NetworkUtils.eip155,
    };
    final address = modal.session?.getAddress(namespace);
    if (address == null || address.isEmpty) return null;
    return address;
  }

  ReownWalletAddresses readAddresses(ReownAppKitModal modal) {
    return ReownWalletAddresses(
      solana: addressForChain(modal, WalletChain.solana),
      ethereum: addressForChain(modal, WalletChain.ethereum),
    );
  }

  @override
  void dispose() {
    state.modal?.dispose();
    super.dispose();
  }
}

class ReownWalletAddresses {
  const ReownWalletAddresses({this.solana, this.ethereum});
  final String? solana;
  final String? ethereum;
}

final reownWalletProvider =
    StateNotifierProvider<ReownWalletService, ReownWalletState>(
  (ref) => ReownWalletService(),
);