import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/dhav_bottom_nav.dart';
import '../../core/widgets/shimmer_widgets.dart';
import '../earnings/earnings_screen.dart';
import '../inventory/inventory_screen.dart';
import '../orders/order_list_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final store = context.read<StoreProvider>();
    final orders = context.read<OrderProvider>();
    await store.loadMyStore();
    await orders.loadStoreOrders();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _DashboardHome(onRefresh: _refresh),
          const OrderListScreen(),
          const InventoryScreen(),
          const EarningsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: DhavBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _DashboardHome({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final storeProv = context.watch<StoreProvider>();
    final orderProv = context.watch<OrderProvider>();
    final store = storeProv.store;
    final isInitialLoading = storeProv.loading && store == null;
    final title = store?.shopName.toUpperCase() ?? 'KIRANA PARTNER';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: c.card,
                    child: Icon(Icons.person_rounded, color: c.textSecondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isInitialLoading
                        ? DhavShimmer(child: ShimmerBox(width: 160, height: 14, radius: 4))
                        : Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                                letterSpacing: 2),
                          ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                    child: Stack(
                      children: [
                        Icon(Icons.notifications_rounded, color: c.textPrimary, size: 26),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.red, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isInitialLoading
                  ? const DashboardShimmer()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _PendingVerificationBanner(),
                          _StoreStatusCard(),
                          SizedBox(height: 16),
                          _StatsRow(),
                          SizedBox(height: 20),
                          _ActiveOrderSection(),
                          SizedBox(height: 20),
                          _RecentOrdersSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingVerificationBanner extends StatelessWidget {
  const _PendingVerificationBanner();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>().store;
    if (store == null || store.isVerified) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending verification',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'DHAV is reviewing your store. You can set up inventory '
                  'now — you’ll be able to go live once verified.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = context.watch<StoreProvider>().store;
    final isOpen = store?.isOpen ?? false;
    final loading = context.watch<StoreProvider>().loading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isOpen ? c.greenBg : c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isOpen
                ? AppColors.green.withValues(alpha: 0.3)
                : c.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT STORE STATUS',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.textHint,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(
                    loading && store == null
                        ? 'LOADING...'
                        : (isOpen ? 'OPEN' : 'CLOSED'),
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isOpen ? AppColors.green : c.textHint,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Switch(
            value: isOpen,
            onChanged: store == null
                ? null
                : (v) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await context.read<StoreProvider>().toggleOpen(v);
                    } catch (e) {
                      messenger.showSnackBar(
                          SnackBar(content: Text('Failed: $e')));
                    }
                  },
            activeThumbColor: AppColors.green,
            inactiveThumbColor: AppColors.textGrey,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final orders = context.watch<OrderProvider>().orders;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final todayOrders = orders.where((o) => (o.createdAt ?? 0) >= startOfDay).toList();
    final delivered = todayOrders.where((o) => o.status == 'delivered').length;
    final earnings = todayOrders
        .where((o) => o.status == 'delivered')
        .fold<double>(0, (a, b) => a + b.deliveryFee);

    return Row(
      children: [
        _StatCard(label: 'ORDERS', value: '${todayOrders.length}', valueColor: c.textPrimary),
        const SizedBox(width: 12),
        _StatCard(label: 'DELIVERED', value: '$delivered', valueColor: AppColors.green),
        const SizedBox(width: 12),
        _StatCard(
          label: 'EARNINGS',
          value: '₹${earnings.toStringAsFixed(0)}',
          valueColor: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: c.textHint, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }
}

class _ActiveOrderSection extends StatelessWidget {
  const _ActiveOrderSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = context.watch<OrderProvider>().activeOrder;
    if (active == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.divider),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, color: c.textHint, size: 36),
            const SizedBox(height: 8),
            Text('No active orders',
                style: GoogleFonts.inter(fontSize: 14, color: c.textHint)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('ACTIVE MONITORING',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textHint,
                    letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 10),
        _ActiveOrderCard(order: active),
      ],
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Order order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary)),
              const Spacer(),
              Text(order.status.toUpperCase().replaceAll('_', ' '),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${order.itemCount} items • ₹${order.totalCustomerAmount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.activeOrder,
                      arguments: order.orderId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Center(
                      child: Text('VIEW ITEMS',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  const _RecentOrdersSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final recent = context.watch<OrderProvider>().recent.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent Orders',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.orderList),
              child: Text('VIEW ALL',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No completed orders yet.',
                style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          )
        else
          ...recent.map((o) => _OrderRow(order: o)),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isFail = order.status == 'failed' || order.status == 'cancelled';
    final time = order.createdAt == null
        ? ''
        : DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(order.createdAt!));
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.orderDetail,
          arguments: order.orderId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.divider, width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isFail ? c.redBg : c.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  isFail
                      ? Icons.cancel_outlined
                      : Icons.shopping_bag_outlined,
                  color: isFail ? AppColors.red : c.textHint,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${order.status} • $time',
                      style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${order.totalCustomerAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
