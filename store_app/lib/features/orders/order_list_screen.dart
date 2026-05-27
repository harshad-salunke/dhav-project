import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<OrderProvider>().loadStoreOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final orderProv = context.watch<OrderProvider>();
    final orders = orderProv.orders;
    final isLoading = orderProv.loading && orders.isEmpty;
    final active = orders.where((o) => o.isActive).toList();
    final completed = orders.where((o) => o.isTerminal).toList();

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Orders',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: 1)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: isLoading ? 'All' : 'All (${orders.length})'),
            Tab(text: isLoading ? 'Active' : 'Active (${active.length})'),
            Tab(text: isLoading ? 'Completed' : 'Completed (${completed.length})'),
          ],
        ),
      ),
      body: isLoading
          ? const OrderListShimmer()
          : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(orders: orders),
                _OrderList(orders: active),
                _OrderList(orders: completed),
              ],
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (orders.isEmpty) {
      return Center(
          child: Text('No orders',
              style: GoogleFonts.inter(color: c.textHint, fontSize: 15)));
    }
    return RefreshIndicator(
      onRefresh: () => context.read<OrderProvider>().loadStoreOrders(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OrderCard(order: orders[i]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  Color _badgeColor() {
    if (order.status == 'failed' || order.status == 'cancelled') {
      return AppColors.red;
    }
    if (order.status == 'delivered') return AppColors.green;
    return AppColors.primary;
  }

  String _badgeLabel() => order.status.toUpperCase().replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final time = order.createdAt == null
        ? ''
        : DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(order.createdAt!));

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.orderDetail,
          arguments: order.orderId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: order.isActive
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: c.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _badgeColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_badgeLabel(),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _badgeColor())),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shopping_basket_outlined, color: c.textHint, size: 14),
                const SizedBox(width: 4),
                Text('${order.itemCount} items',
                    style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                const SizedBox(width: 16),
                Icon(Icons.access_time_rounded, color: c.textHint, size: 14),
                const SizedBox(width: 4),
                Text(time,
                    style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                const Spacer(),
                Text('₹${order.totalCustomerAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
              ],
            ),
            if (order.isActive) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.activeOrder,
                    arguments: order.orderId),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text('MANAGE ORDER',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
