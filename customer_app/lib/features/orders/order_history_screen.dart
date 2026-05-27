import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';
import 'rate_order_sheet.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();

    final active = orders.orders
        .where((o) =>
            !['delivered', 'failed', 'cancelled'].contains(o.status))
        .toList();
    final past = orders.orders
        .where(
            (o) => ['delivered', 'failed', 'cancelled'].contains(o.status))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Orders',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past Orders'),
          ],
        ),
      ),
      body: orders.loading
          ? const OrderHistoryShimmer()
          : TabBarView(
              controller: _tabs,
              children: [
                _OrderList(
                    orders: active,
                    emptyMessage: 'No active orders',
                    emptyIcon: Icons.hourglass_empty_rounded),
                _OrderList(
                    orders: past,
                    emptyMessage: 'No past orders yet',
                    emptyIcon: Icons.receipt_long_outlined,
                    showReorder: true),
              ],
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<CustomerOrder> orders;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool showReorder;

  const _OrderList({
    required this.orders,
    required this.emptyMessage,
    required this.emptyIcon,
    this.showReorder = false,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(emptyIcon,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<OrderProvider>().loadHistory(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) =>
            _OrderCard(order: orders[i], showReorder: showReorder),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CustomerOrder order;
  final bool showReorder;

  const _OrderCard({required this.order, this.showReorder = false});

  Color get _statusColor {
    switch (order.status) {
      case 'delivered':
        return AppColors.success;
      case 'failed':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (order.status) {
      case 'pending':
        return 'Finding store';
      case 'accepted':
      case 'store_accepted':
        return 'Accepted';
      case 'packed':
        return 'Packing';
      case 'out_for_delivery':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = !['delivered', 'failed', 'cancelled'].contains(order.status);
    return GestureDetector(
      onTap: () {
        if (isActive) {
          Navigator.pushNamed(context, AppRoutes.orderTracking,
              arguments: {'order_id': order.orderId});
        } else {
          Navigator.pushNamed(context, AppRoutes.orderDetail,
              arguments: order);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.storeName ?? 'DHAV Order',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.items.map((i) => '${i.name} ×${i.quantity}').join(', '),
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (order.createdAt != null)
                  Text(
                    _formatDate(order.createdAt!),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                const Spacer(),
                if (isActive)
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, '/order-tracking',
                        arguments: {'order_id': order.orderId}),
                    child: Text('Track',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  )
                else if (showReorder) ...[
                  if (order.status == 'delivered' && !order.hasReview)
                    GestureDetector(
                      onTap: () => RateOrderSheet.show(
                        context,
                        orderId: order.orderId,
                        storeName: order.storeName,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_outline_rounded,
                              size: 15, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text('Rate',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (order.status == 'delivered' && !order.hasReview)
                    const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _reorder(context),
                    child: Text('Reorder',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _reorder(BuildContext context) {
    final cart = context.read<CartProvider>();
    final catalog = context.read<CatalogProvider>();
    for (final item in order.items) {
      final catalogItem =
          catalog.items.firstWhere((c) => c.id == item.itemId,
              orElse: () => catalog.items.isNotEmpty
                  ? catalog.items.first
                  : throw Exception('No items'));
      cart.addItem(catalogItem);
    }
    Navigator.pushNamed(context, '/cart');
  }

  String _formatDate(DateTime d) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
