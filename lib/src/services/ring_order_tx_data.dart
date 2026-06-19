import 'dart:convert';

/// On-chain memo payload attached to ring checkout transactions.
class RingOrderTxData {
  const RingOrderTxData({
    required this.orderType,
    required this.size,
    required this.country,
    this.message,
  });

  final String orderType;
  final int size;
  final String country;
  final String? message;

  /// Compact JSON written into the Solana memo instruction (max 566 bytes).
  String toMemo() {
    final payload = <String, dynamic>{
      'app': 'vyana',
      'product': 'prana_ring',
      'type': orderType,
      'size': size,
      'country': country,
    };
    final note = message?.trim();
    if (note != null && note.isNotEmpty) {
      payload['message'] = note;
    }
    return jsonEncode(payload);
  }
}