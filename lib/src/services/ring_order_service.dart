import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import 'ring_order_pricing.dart';

class RingOrderService {
  RingOrderService(this._db);

  final VyanaDatabase _db;

  Stream<List<RingOrderRow>> watchOrders() => _db.watchRingOrders();

  Future<bool> hasOrders() => _db.hasRingOrders();

  Future<void> savePaidOrder({
    required int size,
    required RingOrderPricing pricing,
    required String walletAddress,
    required String txSignature,
    required String shippingCountry,
    String? orderMessage,
  }) {
    return _db.insertRingOrder(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      status: pricing.isRegisterInterest ? 'interest' : 'paid',
      productName: RingOrderPricing.productName,
      color: RingOrderPricing.color,
      size: size,
      amountUsdc: pricing.storedOrderAmount,
      referralCode: pricing.referralCode,
      treasuryAddress: RingOrderPricing.treasuryAddress,
      walletAddress: walletAddress,
      txSignature: txSignature,
      shippingEtaDays: RingOrderPricing.shippingEtaDays,
      orderType: pricing.orderType,
      shippingCountry: shippingCountry,
      orderMessage: orderMessage,
    );
  }

  Future<void> saveFailedOrder({
    required int size,
    required RingOrderPricing pricing,
    required String walletAddress,
    required String errorMessage,
    String? shippingCountry,
    String? orderMessage,
  }) {
    return _db.insertRingOrder(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      status: 'failed',
      productName: RingOrderPricing.productName,
      color: RingOrderPricing.color,
      size: size,
      amountUsdc: pricing.storedOrderAmount,
      referralCode: pricing.referralCode,
      treasuryAddress: RingOrderPricing.treasuryAddress,
      walletAddress: walletAddress,
      errorMessage: errorMessage,
      shippingEtaDays: RingOrderPricing.shippingEtaDays,
      orderType: pricing.orderType,
      shippingCountry: shippingCountry,
      orderMessage: orderMessage,
    );
  }
}

final ringOrderServiceProvider = Provider<RingOrderService>((ref) {
  return RingOrderService(ref.watch(databaseProvider));
});

final ringOrdersProvider = StreamProvider<List<RingOrderRow>>((ref) {
  return ref.watch(ringOrderServiceProvider).watchOrders();
});

final hasRingOrdersProvider = FutureProvider<bool>((ref) async {
  return ref.watch(ringOrderServiceProvider).hasOrders();
});