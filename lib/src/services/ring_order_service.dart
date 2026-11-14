import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';

/// Reads the ring orders this phone already holds.
///
/// Item 61: it used to write them too — two methods, both called from the
/// in-app checkout, for a paid order and a failed one. Buying moved to the
/// website, so nothing in the app creates an order any more and there is no
/// write path left to call by accident.
class RingOrderService {
  RingOrderService(this._db);

  final VyanaDatabase _db;

  Stream<List<RingOrderRow>> watchOrders() => _db.watchRingOrders();

  Future<bool> hasOrders() => _db.hasRingOrders();
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