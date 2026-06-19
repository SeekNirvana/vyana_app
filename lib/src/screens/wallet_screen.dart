part of '../../main.dart';

Future<void> openWallet(BuildContext context) => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    );

/// Sovereign wallet vault — Solana primary, Ethereum secondary, Reown on mobile.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await isSolanaMobileDevice()) return;
      if (!mounted) return;
      ref.read(reownWalletProvider.notifier).initIfNeeded(context);
      _attachReownListeners();
    });
  }

  void _attachReownListeners() {
    final modal = ref.read(reownWalletProvider).modal;
    if (modal == null) return;
    modal.onModalConnect.subscribe(_onReownConnected);
    modal.onModalDisconnect.subscribe(_onReownDisconnected);
    modal.onModalNetworkChange.subscribe(_onReownNetworkChange);
    _syncReownSession(modal);
  }

  @override
  void dispose() {
    final modal = ref.read(reownWalletProvider).modal;
    modal?.onModalConnect.unsubscribe(_onReownConnected);
    modal?.onModalDisconnect.unsubscribe(_onReownDisconnected);
    modal?.onModalNetworkChange.unsubscribe(_onReownNetworkChange);
    super.dispose();
  }

  void _onReownConnected(ModalConnect? event) {
    final modal = ref.read(reownWalletProvider).modal;
    if (modal == null) return;
    _syncReownSession(modal);
  }

  void _onReownDisconnected(ModalDisconnect? event) {
    ref.read(walletControllerProvider.notifier).disconnect();
  }

  void _onReownNetworkChange(ModalNetworkChange? event) {
    final modal = ref.read(reownWalletProvider).modal;
    if (modal == null) return;
    _syncReownSession(modal);
  }

  void _syncReownSession(ReownAppKitModal modal) {
    final addresses = ref.read(reownWalletProvider.notifier).readAddresses(modal);
    if (addresses.solana == null && addresses.ethereum == null) return;
    ref.read(walletControllerProvider.notifier).setReownAddresses(
          solana: addresses.solana,
          ethereum: addresses.ethereum,
          activeChain: ref.read(walletControllerProvider).activeChain,
        );
  }

  Future<void> _switchChain(WalletChain chain, bool isSms) async {
    await ref.read(walletControllerProvider.notifier).setActiveChain(chain);
    if (isSms) return;
    await ref.read(reownWalletProvider.notifier).selectChain(chain);
    final modal = ref.read(reownWalletProvider).modal;
    if (modal != null) _syncReownSession(modal);
  }

  Future<void> _connectReown(WalletChain chain) async {
    ref.read(walletControllerProvider.notifier).setConnecting(true);
    try {
      await ref.read(reownWalletProvider.notifier).openConnect(chain: chain);
      final modal = ref.read(reownWalletProvider).modal;
      if (modal != null) _syncReownSession(modal);
    } on Object catch (error) {
      ref.read(walletControllerProvider.notifier).setError('$error');
    } finally {
      ref.read(walletControllerProvider.notifier).setConnecting(false);
    }
  }

  Future<void> _promptAndConnectSolanaMobile() async {
    await ensureSolanaMobileWalletConnected(context: context, ref: ref);
  }

  Future<void> _disconnect(WalletState wallet) async {
    if (wallet.backend == WalletBackend.reown) {
      await ref.read(reownWalletProvider).modal?.disconnect();
      await ref.read(walletControllerProvider.notifier).disconnect();
      return;
    }
    if (wallet.backend == WalletBackend.solanaMobile) {
      await ref.read(solanaMobileWalletControllerProvider).disconnect(
            ref.read(walletControllerProvider.notifier),
          );
      return;
    }
    await ref.read(walletControllerProvider.notifier).disconnect();
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final wallet = ref.watch(walletControllerProvider);
    final smsAsync = ref.watch(solanaMobileDeviceProvider);
    final reown = ref.watch(reownWalletProvider);

    ref.listen<ReownWalletState>(reownWalletProvider, (previous, next) {
      if (next.isReady && previous?.isReady != true) {
        _attachReownListeners();
      }
    });

    final isSms = smsAsync.valueOrNull ?? false;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                children: [
                  IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ON-CHAIN VAULT',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        Text('Wallet',
                            style: VyanaType.appBarSerif
                                .copyWith(color: t.text, fontSize: 28)),
                      ],
                    ),
                  ),
                  if (!isSms) ...[
                    _SubtleChainToggle(
                      active: wallet.activeChain,
                      onChanged: (chain) => _switchChain(chain, isSms),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Seal(size: 38),
                ],
              ),
              const SizedBox(height: 18),
              smsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) =>
                    _walletContent(context, wallet, reown, false),
                data: (isSms) => _walletContent(context, wallet, reown, isSms),
              ),
              if (!isSms && reown.error != null) ...[
                const SizedBox(height: 12),
                _WalletNotice(text: reown.error!, tone: _NoticeTone.error),
              ],
              if (wallet.error != null) ...[
                const SizedBox(height: 12),
                _WalletNotice(text: wallet.error!, tone: _NoticeTone.error),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _walletContent(
    BuildContext context,
    WalletState wallet,
    ReownWalletState reown,
    bool isSms,
  ) {
    if (!wallet.loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wallet.isConnected)
          _ConnectedWalletView(
            wallet: wallet,
            reown: reown,
            isSms: isSms,
            onCopy: _copyAddress,
            onDisconnect: () => _disconnect(wallet),
          )
        else
          _DisconnectedWalletView(
            wallet: wallet,
            reown: reown,
            isSms: isSms,
            onConnect: isSms
                ? _promptAndConnectSolanaMobile
                : () => _connectReown(wallet.activeChain),
          ),
      ],
    );
  }
}

/// Whisper-quiet SOL / ETH switch beside the Vyana seal.
class _SubtleChainToggle extends StatelessWidget {
  const _SubtleChainToggle({
    required this.active,
    required this.onChanged,
  });

  final WalletChain active;
  final ValueChanged<WalletChain> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.card.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: t.borderSoft.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final chain in WalletChain.values) ...[
            if (chain != WalletChain.solana)
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                color: t.borderSoft.withValues(alpha: 0.5),
              ),
            _SubtleChainDot(
              label: chain.currency,
              selected: active == chain,
              onTap: () => onChanged(chain),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubtleChainDot extends StatelessWidget {
  const _SubtleChainDot({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: selected
                ? t.textMuted.withValues(alpha: t.isDark ? 0.14 : 0.1)
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: VyanaType.mono10.copyWith(
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? t.textSec.withValues(alpha: 0.72)
                  : t.textMuted.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedWalletView extends StatelessWidget {
  const _ConnectedWalletView({
    required this.wallet,
    required this.reown,
    required this.isSms,
    required this.onCopy,
    required this.onDisconnect,
  });

  final WalletState wallet;
  final ReownWalletState reown;
  final bool isSms;
  final ValueChanged<String> onCopy;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final chain = wallet.activeChain;
    final address = wallet.address;
    final accent = chain == WalletChain.solana ? t.cyan : t.gold;
    final modal = reown.modal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          grad: true,
          pad: 20,
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.35),
                          accent.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: VyanaIcon('wallet', size: 22, color: accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connected',
                            style: VyanaType.eyebrow.copyWith(color: accent)),
                        Text(
                          '${chain.label} wallet',
                          style: VyanaType.titleSerif
                              .copyWith(color: t.text, fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: t.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: t.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Live',
                            style: VyanaType.mono10.copyWith(
                                color: t.green, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (modal != null && !isSms)
                ValueListenableBuilder<String>(
                  valueListenable: modal.balanceNotifier,
                  builder: (context, balance, _) {
                    return _WalletStatRow(
                      label: 'Balance',
                      value: balance == '-.--' ? '— ${chain.currency}' : balance,
                      hint: 'On-chain fetch',
                    );
                  },
                )
              else
                _WalletStatRow(
                  label: 'Balance',
                  value: '— ${chain.currency}',
                  hint: 'Coming soon',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (address != null)
          Panel(
            pad: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Your address',
                        style: VyanaType.label.copyWith(color: t.textSec)),
                    const Spacer(),
                    Pill(
                      label: chain.currency,
                      active: true,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  address,
                  style: VyanaType.mono10.copyWith(
                    color: t.text,
                    fontSize: 13,
                    height: 1.55,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Cta(
                        label: 'Copy address',
                        solid: false,
                        onTap: () => onCopy(address),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          _WalletNotice(
            text:
                'Connected, but no ${chain.label} address on this session. Switch chain or reconnect.',
            tone: _NoticeTone.warn,
          ),
        const SizedBox(height: 12),
        _WalletFutureTile(
          icon: 'award',
          title: 'Collectibles',
          subtitle: 'NFT gallery for your ${chain.currency} wallet',
          badge: 'Soon',
        ),
        const SizedBox(height: 10),
        Text(
          isSms ? 'Solana Mobile Wallet Adapter' : 'Reown · ${chain.label}',
          style: VyanaType.caption.copyWith(color: t.textMuted),
        ),
        const SizedBox(height: 14),
        Cta(
          label: 'Disconnect',
          icon: 'x',
          solid: false,
          onTap: onDisconnect,
        ),
      ],
    );
  }
}

class _DisconnectedWalletView extends ConsumerWidget {
  const _DisconnectedWalletView({
    required this.wallet,
    required this.reown,
    required this.isSms,
    required this.onConnect,
  });

  final WalletState wallet;
  final ReownWalletState reown;
  final bool isSms;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final chain = wallet.activeChain;
    final accent = chain == WalletChain.solana ? t.cyan : t.gold;
    final reownReady = reown.isReady;
    final reownInitializing = reown.isInitializing;
    final canConnect = isSms || reownReady;
    final connectLabel = wallet.connecting
        ? 'Connecting…'
        : isSms
            ? 'Connect wallet'
            : reownInitializing
                ? 'Preparing…'
                : 'Connect ${chain.currency} wallet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          grad: true,
          pad: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSms ? 'Connect wallet' : 'Connect ${chain.label}',
                style: VyanaType.titleSerif
                    .copyWith(color: t.text, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                isSms
                    ? 'Authorize Vyana with any wallet app installed on this device.'
                    : chain == WalletChain.solana
                        ? 'Default network. Email or social login — no wallet app required.'
                        : 'Secondary EVM network. Use when you need Ethereum assets.',
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
              ),
              if (!isSms) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _SocialChip(label: 'Email'),
                    _SocialChip(label: 'Google'),
                    _SocialChip(label: 'Apple'),
                    _SocialChip(label: 'Discord'),
                    _SocialChip(label: 'X'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WalletFutureTile(
          icon: 'sparkles',
          title: 'Rewards & quests',
          subtitle: 'On-chain attestations tied to your wellness journey',
          badge: 'Preview',
          accent: accent,
        ),
        const SizedBox(height: 12),
        if (!isSms && reownInitializing) ...[
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 10),
          Text(
            'Preparing Reown on ${chain.label}…',
            textAlign: TextAlign.center,
            style: VyanaType.caption.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: 14),
        ],
        Cta(
          label: connectLabel,
          icon: 'wallet',
          disabled: !canConnect || wallet.connecting || (!isSms && reownInitializing),
          onTap: onConnect,
        ),
      ],
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.border),
      ),
      child: Text(label, style: VyanaType.caption.copyWith(color: t.textSec)),
    );
  }
}

class _WalletStatRow extends StatelessWidget {
  const _WalletStatRow({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: VyanaType.caption.copyWith(color: t.textMuted)),
              const SizedBox(height: 2),
              Text(value,
                  style: VyanaType.titleSerif
                      .copyWith(color: t.text, fontSize: 26)),
            ],
          ),
        ),
        Text(hint, style: VyanaType.mono10.copyWith(color: t.textMuted)),
      ],
    );
  }
}

class _WalletFutureTile extends StatelessWidget {
  const _WalletFutureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.accent,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = accent ?? t.gold;
    return Panel(
      pad: 14,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ac.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ac.withValues(alpha: 0.25)),
            ),
            child: Center(child: VyanaIcon(icon, size: 18, color: ac)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: VyanaType.label.copyWith(color: t.text)),
                Text(subtitle,
                    style: VyanaType.caption
                        .copyWith(color: t.textSec, height: 1.35)),
              ],
            ),
          ),
          Pill(label: badge, active: false, onTap: () {}),
        ],
      ),
    );
  }
}

enum _NoticeTone { error, warn }

class _WalletNotice extends StatelessWidget {
  const _WalletNotice({required this.text, required this.tone});
  final String text;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final color = tone == _NoticeTone.error ? t.vit('hr') : t.gold;
    return Panel(
      pad: 12,
      accent: color,
      child: Text(text, style: VyanaType.caption.copyWith(color: t.textSec)),
    );
  }
}