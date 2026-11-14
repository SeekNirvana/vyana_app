part of '../../main.dart';

/// Ring orders — the record of ones already placed, and a door to the shop.
///
/// Item 61: the app used to take the payment itself. That flow put the
/// buyer's shipping country and a free-text message — where people
/// reasonably typed their address — into the Solana memo, which is public
/// and permanent, while collecting no name, address or phone, so an order
/// could be paid for and undeliverable. The website checkout at
/// [kRingOrderUrl] already takes card and USDC on Solana or Base and asks
/// for size, name, email, phone and address privately.
///
/// So buying happens there, on every phone including Solana ones, and the
/// app keeps only what it already had: orders placed before this release,
/// readable and not editable. Nothing here writes a new one.

/// Where buying a ring happens.
const String kRingOrderUrl = 'https://seeknirvana.com/order';

/// Opens the shop in the browser rather than a checkout in the app.
Future<void> openRingOrder(BuildContext context) async {
  final uri = Uri.parse(kRingOrderUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    showVyanaSnackBar(
      context,
      message: 'Could not open $kRingOrderUrl',
      icon: 'alert',
    );
  }
}

/// The orders this phone already holds.
Future<void> openRingOrders(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const RingOrdersScreen()));

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
