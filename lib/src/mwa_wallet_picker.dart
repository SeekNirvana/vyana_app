part of '../main.dart';

/// Shows the in-app MWA wallet picker and returns the selected package id.
Future<String?> showMwaWalletPickerSheet(
  BuildContext context,
  List<MwaWalletOption> wallets,
) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => MwaWalletPickerSheet(wallets: wallets),
  );
}

/// Connect via MWA when needed. Skips the picker if a Solana mobile session
/// is already active.
Future<bool> ensureSolanaMobileWalletConnected({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final wallet = ref.read(walletControllerProvider);
  if (wallet.connecting) return false;

  if (wallet.hasActiveAddress &&
      wallet.solanaAddress != null &&
      wallet.backend == WalletBackend.solanaMobile) {
    return true;
  }

  final wallets = await ref.read(mwaInstalledWalletsProvider.future);
  if (!context.mounted) return false;

  if (wallets.isEmpty) {
    ref.read(walletControllerProvider.notifier).setError(
          'No wallet apps found. Install Seed Vault, Phantom, or Solflare.',
        );
    return false;
  }

  final selectedPackage = await showMwaWalletPickerSheet(context, wallets);
  if (selectedPackage == null || !context.mounted) return false;

  await ref.read(mwaSelectedWalletProvider.notifier).select(selectedPackage);
  await ref.read(solanaMobileWalletControllerProvider).connect(
        ref.read(walletControllerProvider.notifier),
        walletPackage: selectedPackage,
      );

  if (!context.mounted) return false;
  final connected = ref.read(walletControllerProvider);
  return connected.hasActiveAddress && connected.solanaAddress != null;
}

class MwaWalletPickerSheet extends StatelessWidget {
  const MwaWalletPickerSheet({super.key, required this.wallets});

  final List<MwaWalletOption> wallets;

  Color _accentFor(MwaWalletOption wallet, VyanaColors t) {
    return switch (wallet.package) {
      MwaWalletOption.seedVaultPackage => t.cyan,
      'app.phantom' => t.vit('hr'),
      'com.solflare.mobile' => t.gold,
      _ => t.green,
    };
  }

  String _subtitleFor(MwaWalletOption wallet) {
    return switch (wallet.package) {
      MwaWalletOption.seedVaultPackage => 'Native wallet on this device',
      'app.phantom' => 'Self-custody wallet',
      'com.solflare.mobile' => 'Self-custody wallet',
      _ => 'Mobile Wallet Adapter',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Panel(
        pad: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: t.borderSoft,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Text(
              'Choose wallet',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Vyana will ask the app you pick to approve the connection.',
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < wallets.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              MwaWalletPickerRow(
                wallet: wallets[i],
                accent: _accentFor(wallets[i], t),
                subtitle: _subtitleFor(wallets[i]),
                onTap: () => Navigator.of(context).pop(wallets[i].package),
              ),
            ],
            const SizedBox(height: 14),
            Cta(
              label: 'Cancel',
              icon: 'x',
              solid: false,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class MwaWalletPickerRow extends StatelessWidget {
  const MwaWalletPickerRow({
    super.key,
    required this.wallet,
    required this.accent,
    required this.subtitle,
    required this.onTap,
  });

  final MwaWalletOption wallet;
  final Color accent;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: t.card.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.borderSoft.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.34),
                      accent.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: VyanaIcon('wallet', size: 20, color: accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.label,
                      style: VyanaType.label.copyWith(color: t.text),
                    ),
                    Text(
                      subtitle,
                      style: VyanaType.caption
                          .copyWith(color: t.textSec, height: 1.3),
                    ),
                  ],
                ),
              ),
              VyanaIcon('chevR', size: 16, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}