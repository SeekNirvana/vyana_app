part of '../../main.dart';

Future<void> openRingOrder(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const RingOrderScreen()));

Future<void> openRingOrders(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const RingOrdersScreen()));

class _RingGallerySlide {
  const _RingGallerySlide(this.asset, {required this.fit});
  final String asset;
  final BoxFit fit;
}

const _ringGalleryImages = [
  _RingGallerySlide('assets/ring_images/img1.jpeg', fit: BoxFit.cover),
  _RingGallerySlide('assets/ring_images/img2.jpeg', fit: BoxFit.contain),
  _RingGallerySlide('assets/ring_images/img3.jpeg', fit: BoxFit.contain),
];

const _whatsIncluded = [
  'Nirvana Ring (Black)',
  'USB-C Charging Cable',
  'Premium Carrying Case',
  'Meditation Audio Pack',
  'Quick Start Guide',
  '1-Year Warranty',
];

const _ringSizes = [7, 8, 9, 10, 11, 12, 13];

/// Hardware specs (from product sheet — not bundled as an image asset).
const _ringSpecs = [
  _RingSpec('Connectivity', 'Bluetooth 5.3 (BLE)'),
  _RingSpec('Memory', '64 KB RAM'),
  _RingSpec(
    'Battery',
    '15 mAh (sizes 7–8) · 20 mAh (sizes 9–13)',
  ),
  _RingSpec('Heart rate sensor', 'Goodix GH3228 + GPSE1602B'),
  _RingSpec('Motion sensor', 'SC-7A20H G-sensor'),
  _RingSpec('Working time', '7–10 days per charge'),
  _RingSpec('Water resistance', '5 ATM + IP68'),
  _RingSpec('Charging', 'Magnetic charging case (USB-C)'),
  _RingSpec('Material', 'Stainless steel + epoxy resin'),
  _RingSpec('Ring width', '8 mm'),
  _RingSpec('Sizes', '7–13 (Black)'),
  _RingSpec('Phone requirements', 'Android 9.0+ · iOS 10.0+'),
];

class _RingSpec {
  const _RingSpec(this.label, this.value);
  final String label;
  final String value;
}

Future<void> _showRingSpecsSheet(BuildContext context) {
  final t = context.vyana;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product parameters',
                              style: VyanaType.titleSerif.copyWith(
                                color: t.text,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PRANA Ring · technical specifications',
                              style: VyanaType.caption
                                  .copyWith(color: t.textSec),
                            ),
                          ],
                        ),
                      ),
                      IconBtn(
                        icon: 'x',
                        onTap: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      for (final spec in _ringSpecs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: t.gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      spec.label,
                                      style: VyanaType.label.copyWith(
                                        color: t.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      spec.value,
                                      style: VyanaType.bodySm.copyWith(
                                        color: t.textSec,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class RingOrderScreen extends ConsumerStatefulWidget {
  const RingOrderScreen({super.key});

  @override
  ConsumerState<RingOrderScreen> createState() => _RingOrderScreenState();
}

class _RingOrderScreenState extends ConsumerState<RingOrderScreen> {
  final _codeController = TextEditingController();
  final _countryController = TextEditingController();
  final _messageController = TextEditingController();
  final _pageController = PageController();
  int _galleryIndex = 0;
  int _size = 9;
  RingOrderPricing _pricing = RingOrderPricing.standard();
  String? _codeError;
  bool _paying = false;
  bool _awaitingWallet = false;
  String? _paymentError;
  int _paymentAttempt = 0;
  String? _payingWalletPackage;
  bool? _isSms;
  String? _orderCompleteSignature;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlatform());
  }

  Future<void> _loadPlatform() async {
    final sms = await isSolanaMobileDevice();
    if (!mounted) return;
    setState(() => _isSms = sms);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countryController.dispose();
    _messageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String? _validateCheckoutDetails() {
    if (_countryController.text.trim().isEmpty) {
      return 'Enter your shipping country.';
    }
    return null;
  }

  void _applyCode() {
    try {
      setState(() {
        _pricing = RingOrderPricing.fromReferralCode(_codeController.text);
        _codeError = null;
      });
    } on RingOrderPricingException catch (e) {
      setState(() {
        _pricing = RingOrderPricing.standard();
        _codeError = e.message;
      });
    }
  }

  Future<void> _connectWallet() async {
    await ensureSolanaMobileWalletConnected(context: context, ref: ref);
  }

  void _cancelPayment() {
    if (!_paying && !_awaitingWallet) return;
    setState(() {
      _paymentAttempt++;
      _paying = false;
      _awaitingWallet = false;
      _paymentError =
          'Payment cancelled. Open your wallet and tap Try again when ready.';
    });
  }

  String _walletLabel() {
    final package =
        _payingWalletPackage ?? ref.read(mwaSelectedWalletProvider);
    return switch (package) {
      MwaWalletOption.seedVaultPackage => 'Seed Vault',
      'app.phantom' => 'Phantom',
      'com.solflare.mobile' => 'Solflare',
      _ => 'your wallet',
    };
  }

  Future<void> _pay() async {
    final validationError = _validateCheckoutDetails();
    if (validationError != null) {
      showVyanaSnackBar(context, message: validationError, icon: 'alert');
      return;
    }

    final wallet = ref.read(walletControllerProvider);
    if (!wallet.hasActiveAddress || wallet.solanaAddress == null) {
      await _connectWallet();
    }
    final connected = ref.read(walletControllerProvider);
    if (!connected.hasActiveAddress || connected.solanaAddress == null) return;

    final walletNotifier = ref.read(walletControllerProvider.notifier);
    var authToken = await walletNotifier.loadSolanaAuthToken();
    final walletPackage = await walletNotifier.loadSolanaWalletPackage();
    final effectiveWalletPackage =
        walletPackage ?? ref.read(mwaSelectedWalletProvider);
    if (!mounted) return;
    if (authToken == null || authToken.isEmpty) {
      showVyanaSnackBar(
        context,
        message: 'Wallet session expired. Reconnect your wallet.',
        icon: 'alert',
      );
      return;
    }
    if (effectiveWalletPackage == null || effectiveWalletPackage.isEmpty) {
      showVyanaSnackBar(
        context,
        message: 'Select a wallet in Settings, then reconnect.',
        icon: 'alert',
      );
      return;
    }

    final shippingCountry = _countryController.text.trim();
    final orderMessage = _messageController.text.trim().isEmpty
        ? null
        : _messageController.text.trim();

    final attempt = _paymentAttempt + 1;
    setState(() {
      _paymentAttempt = attempt;
      _paying = true;
      _awaitingWallet = false;
      _paymentError = null;
      _payingWalletPackage = effectiveWalletPackage;
    });

    try {
      final payment = ref.read(ringUsdcPaymentServiceProvider);
      final orders = ref.read(ringOrderServiceProvider);

      if (mounted) {
        setState(() => _awaitingWallet = true);
      }

      final result = await payment.pay(
        walletAddress: connected.solanaAddress!,
        authToken: authToken,
        walletPackage: effectiveWalletPackage,
        pricing: _pricing,
        orderData: RingOrderTxData(
          orderType: _pricing.orderType,
          size: _size,
          country: shippingCountry,
          message: orderMessage,
        ),
      );

      if (!mounted || attempt != _paymentAttempt) return;

      if (result.refreshedAuthToken != null) {
        await walletNotifier.saveSolanaAuthToken(result.refreshedAuthToken!);
        authToken = result.refreshedAuthToken;
      }

      await orders.savePaidOrder(
        size: _size,
        pricing: _pricing,
        walletAddress: connected.solanaAddress!,
        txSignature: result.signature,
        shippingCountry: shippingCountry,
        orderMessage: orderMessage,
      );
      if (!mounted || attempt != _paymentAttempt) return;
      setState(() {
        _orderCompleteSignature = result.signature;
        _paymentError = null;
      });
      showVyanaSnackBar(
        context,
        message: _pricing.successMessage,
        icon: 'check',
        success: true,
      );
    } on RingUsdcPaymentException catch (e) {
      if (!mounted || attempt != _paymentAttempt) return;
      setState(() => _paymentError = e.message);
      showVyanaSnackBar(context, message: e.message, icon: 'alert');
      if (connected.solanaAddress != null) {
        await ref.read(ringOrderServiceProvider).saveFailedOrder(
              size: _size,
              pricing: _pricing,
              walletAddress: connected.solanaAddress!,
              errorMessage: e.message,
              shippingCountry: shippingCountry,
              orderMessage: orderMessage,
            );
      }
    } finally {
      if (mounted && attempt == _paymentAttempt) {
        setState(() {
          _paying = false;
          _awaitingWallet = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final wallet = ref.watch(walletControllerProvider);
    final sms = _isSms ?? false;
    final canCheckout = sms && _orderCompleteSignature == null;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBtn(
                    icon: 'chevL',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PRANA Ring',
                                style: VyanaType.displaySerif.copyWith(
                                  color: t.text,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            IconBtn(
                              icon: 'info',
                              size: 36,
                              onTap: () => _showRingSpecsSheet(context),
                            ),
                          ],
                        ),
                        Text(
                          'Black · sizes 7–13',
                          style: VyanaType.caption.copyWith(color: t.textSec),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _ringGalleryImages.length,
                    onPageChanged: (i) => setState(() => _galleryIndex = i),
                    itemBuilder: (_, i) {
                      final slide = _ringGalleryImages[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ColoredBox(
                          color: t.isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
                          child: Image.asset(
                            slide.asset,
                            fit: slide.fit,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _ringGalleryImages.length; i++)
                          Container(
                            width: i == _galleryIndex ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _galleryIndex
                                  ? t.text
                                  : t.textMuted.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _pricing.isRegisterInterest
                  ? 'Register interest'
                  : 'Buy PRANA ring',
              style: VyanaType.displaySerif.copyWith(color: t.text),
            ),
            const SizedBox(height: 6),
            Text(
              _pricing.displayLabel,
              style: VyanaType.bodySm.copyWith(
                color: t.textSec,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ships within ${RingOrderPricing.shippingEtaDays} days',
              style: VyanaType.caption.copyWith(color: t.textMuted),
            ),
            const SizedBox(height: 18),
            Text('Ring size',
                style: VyanaType.label.copyWith(color: t.text)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _ringSizes)
                  Pill(
                    label: '$s',
                    active: _size == s,
                    onTap: () => setState(() => _size = s),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const SectionHead(eyebrow: 'Delivery', title: 'Order details'),
            Panel(
              pad: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ring size · $_size · ${RingOrderPricing.color}',
                    style: VyanaType.bodySm.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 12),
                  Text('Shipping country',
                      style: VyanaType.caption.copyWith(color: t.textSec)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _countryController,
                    textCapitalization: TextCapitalization.words,
                    style: VyanaType.bodySm.copyWith(color: t.text),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'e.g. United States',
                      hintStyle:
                          VyanaType.bodySm.copyWith(color: t.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Message (optional)',
                      style: VyanaType.caption.copyWith(color: t.textSec)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    style: VyanaType.bodySm.copyWith(color: t.text, height: 1.45),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'Sizing notes, delivery preferences, or questions',
                      hintStyle:
                          VyanaType.bodySm.copyWith(color: t.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Referral code',
                style: VyanaType.label.copyWith(color: t.text)),
            const SizedBox(height: 8),
            Panel(
              pad: 0,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: VyanaType.bodySm.copyWith(color: t.text),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        hintText: 'Optional',
                        hintStyle:
                            VyanaType.bodySm.copyWith(color: t.textMuted),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _applyCode,
                    child: Text('Apply',
                        style: VyanaType.label.copyWith(color: t.gold)),
                  ),
                ],
              ),
            ),
            if (_codeError != null) ...[
              const SizedBox(height: 6),
              Text(_codeError!,
                  style: VyanaType.caption.copyWith(color: t.vit('hr'))),
            ],
            const SizedBox(height: 22),
            const SectionHead(eyebrow: 'In the box', title: "What's included"),
            Panel(
              pad: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in _whatsIncluded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VyanaIcon('check', size: 14, color: t.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item,
                                style: VyanaType.bodySm
                                    .copyWith(color: t.text, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_orderCompleteSignature != null) ...[
              Panel(
                pad: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pricing.isRegisterInterest
                          ? 'Interest registered'
                          : 'Order confirmed',
                      style: VyanaType.label.copyWith(color: t.green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Size $_size · ${_countryController.text.trim()}\n'
                      '${_pricing.displayLabel}\n'
                      'Estimated delivery: ${RingOrderPricing.shippingEtaDays} days',
                      style: VyanaType.bodySm.copyWith(color: t.textSec),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      _orderCompleteSignature!,
                      style: VyanaType.mono10.copyWith(color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ] else if (canCheckout) ...[
              if (_awaitingWallet)
                Panel(
                  pad: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.gold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Approve in ${_walletLabel()}',
                              style: VyanaType.label.copyWith(color: t.text),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pricing.asset == RingPaymentAsset.sol
                            ? 'Confirm the ${RingOrderPricing.interestSol} SOL transfer in your wallet app. '
                                'This times out after 20 seconds.'
                            : 'Confirm the USDC payment in your wallet app. '
                                'This times out after 20 seconds.',
                        style: VyanaType.caption
                            .copyWith(color: t.textSec, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _cancelPayment,
                          child: Text(
                            'Cancel',
                            style: VyanaType.label.copyWith(color: t.vit('hr')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_paymentError != null && !_awaitingWallet) ...[
                const SizedBox(height: 10),
                Panel(
                  pad: 14,
                  accent: t.vit('hr'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment not completed',
                          style: VyanaType.label.copyWith(color: t.text)),
                      const SizedBox(height: 6),
                      Text(
                        _paymentError!,
                        style: VyanaType.caption
                            .copyWith(color: t.textSec, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Cta(
                        label: 'Try again',
                        icon: 'refresh',
                        solid: false,
                        onTap: _paying ? null : _pay,
                      ),
                    ],
                  ),
                ),
              ],
              if (!_awaitingWallet) ...[
                if (!wallet.isConnected || wallet.solanaAddress == null)
                  Cta(
                    label: wallet.connecting ? 'Connecting…' : 'Connect wallet',
                    icon: 'wallet',
                    onTap: wallet.connecting ? null : _connectWallet,
                  )
                else ...[
                  Text(
                    'Pay from ${wallet.shortAddress()}',
                    style: VyanaType.caption.copyWith(color: t.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Cta(
                    label: _paying
                        ? 'Preparing…'
                        : _pricing.checkoutButtonLabel,
                    icon: _pricing.isRegisterInterest ? 'bell' : 'wallet',
                    onTap: _paying ? null : _pay,
                  ),
                ],
              ],
            ] else if (_isSms == false) ...[
              Cta(
                label: 'Coming soon',
                icon: 'ring',
                onTap: null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RingOrdersScreen extends ConsumerWidget {
  const RingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final orders = ref.watch(ringOrdersProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              VAppBar(
                title: 'Your orders',
                sub: 'On this device',
                leading: IconBtn(
                  icon: 'chevL',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                Panel(
                  pad: 20,
                  child: Text(
                    'No ring orders yet.',
                    style: VyanaType.bodySm.copyWith(color: t.textMuted),
                  ),
                )
              else
                for (final order in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      pad: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${order.productName} · size ${order.size}',
                                  style: VyanaType.label.copyWith(color: t.text),
                                ),
                              ),
                              Text(
                                order.status.toUpperCase(),
                                style: VyanaType.mono10.copyWith(
                                  color: order.status == 'paid' ||
                                          order.status == 'interest'
                                      ? t.green
                                      : t.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.orderType == 'interest'
                                ? '${order.color} · ${order.amountUsdc} SOL'
                                : '${order.color} · \$${order.amountUsdc.toStringAsFixed(0)} USDC',
                            style: VyanaType.caption.copyWith(color: t.textSec),
                          ),
                          if (order.shippingCountry != null &&
                              order.shippingCountry!.isNotEmpty)
                            Text(
                              'Ship to: ${order.shippingCountry}',
                              style:
                                  VyanaType.caption.copyWith(color: t.textMuted),
                            ),
                          if (order.orderMessage != null &&
                              order.orderMessage!.isNotEmpty)
                            Text(
                              order.orderMessage!,
                              style:
                                  VyanaType.caption.copyWith(color: t.textMuted),
                            ),
                          if (order.referralCode != null)
                            Text(
                              'Code: ${order.referralCode}',
                              style: VyanaType.caption.copyWith(color: t.textMuted),
                            ),
                          Text(
                            'Ships within ${order.shippingEtaDays} days',
                            style: VyanaType.caption.copyWith(color: t.textMuted),
                          ),
                          if (order.txSignature != null) ...[
                            const SizedBox(height: 6),
                            SelectableText(
                              order.txSignature!,
                              style: VyanaType.mono10.copyWith(color: t.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}