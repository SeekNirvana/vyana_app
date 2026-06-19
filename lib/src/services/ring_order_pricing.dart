/// PRANA ring checkout pricing and on-device referral codes.
enum RingPaymentAsset { usdc, sol }

class RingOrderPricing {
  const RingOrderPricing({
    required this.asset,
    required this.amount,
    required this.displayAmount,
    required this.displayUnit,
    this.referralCode,
  });

  static const treasuryAddress = '8bDudaBScd3qSiuE2VujZ5Pr29ruaLg25MhgPMRCjv5d';
  static const usdcMintMainnet = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  static const productName = 'PRANA Ring';
  static const color = 'Black';
  static const listPriceUsdc = 99.0;
  static const listPriceMicroUsdc = 99000000;
  static const interestSol = 0.001;
  static const interestLamports = 1000000;
  static const shippingEtaDays = 30;

  static const _testCode = 'TESTING';

  final RingPaymentAsset asset;
  final int amount;
  final double displayAmount;
  final String displayUnit;
  final String? referralCode;

  static RingOrderPricing standard() => const RingOrderPricing(
        asset: RingPaymentAsset.usdc,
        amount: listPriceMicroUsdc,
        displayAmount: listPriceUsdc,
        displayUnit: 'USDC',
      );

  static RingOrderPricing fromReferralCode(String? raw) {
    final code = raw?.trim().toUpperCase();
    if (code == null || code.isEmpty) return standard();
    if (code == _testCode) {
      return const RingOrderPricing(
        asset: RingPaymentAsset.sol,
        amount: interestLamports,
        displayAmount: interestSol,
        displayUnit: 'SOL',
        referralCode: _testCode,
      );
    }
    throw RingOrderPricingException('Unknown referral code.');
  }

  bool get isRegisterInterest => referralCode == _testCode;

  String get displayLabel => isRegisterInterest
      ? 'Register interest · $displayAmount $displayUnit'
      : '\$${displayAmount.toStringAsFixed(0)} $displayUnit';

  String get checkoutButtonLabel => isRegisterInterest
      ? 'Register interest · $displayAmount $displayUnit'
      : 'Buy · \$${displayAmount.toStringAsFixed(0)} $displayUnit';

  String get orderType => isRegisterInterest ? 'interest' : 'purchase';

  String get successMessage => isRegisterInterest
      ? 'Interest registered · we will follow up before shipping'
      : 'Order placed · ships within $shippingEtaDays days';

  /// Stored in local orders table (historical column name).
  double get storedOrderAmount => displayAmount;
}

class RingOrderPricingException implements Exception {
  RingOrderPricingException(this.message);
  final String message;

  @override
  String toString() => message;
}