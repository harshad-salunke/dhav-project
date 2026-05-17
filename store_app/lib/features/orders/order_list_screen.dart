import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Orders', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: 1)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'All'), Tab(text: 'Active'), Tab(text: 'Completed')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(orders: _allOrders),
          _OrderList(orders: _allOrders.where((o) => o['status'] == 'active').toList()),
          _OrderList(orders: _allOrders.where((o) => o['status'] != 'active').toList()),
        ],
      ),
    );
  }

  static final List<Map<String, dynamic>> _allOrders = [
    {'id': 'OD-9928', 'items': 4, 'amount': '₹1,240', 'time': '14:35 PM', 'status': 'active', 'badge': 'ACTIVE', 'badgeColor': AppColors.primary},
    {'id': 'OD-9927', 'items': 2, 'amount': '₹450', 'time': '14:20 PM', 'status': 'delivered', 'badge': 'PAID', 'badgeColor': AppColors.green},
    {'id': 'OD-9926', 'items': 5, 'amount': '₹980', 'time': '13:45 PM', 'status': 'delivered', 'badge': 'PAID', 'badgeColor': AppColors.green},
    {'id': 'OD-9925', 'items': 1, 'amount': '₹0', 'time': '13:10 PM', 'status': 'failed', 'badge': 'FAILED', 'badgeColor': AppColors.red},
    {'id': 'OD-9924', 'items': 3, 'amount': '₹650', 'time': '12:30 PM', 'status': 'delivered', 'badge': 'PAID', 'badgeColor': AppColors.green},
  ];
}

class _OrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (orders.isEmpty) {
      return Center(child: Text('No orders', style: GoogleFonts.inter(color: c.textHint, fontSize: 15)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.orderDetail),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: order['status'] == 'active' ? Border.all(color: AppColors.primary, width: 1.5) : Border.all(color: c.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Order #${order['id']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (order['badgeColor'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(order['badge'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: order['badgeColor'] as Color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shopping_basket_outlined, color: c.textHint, size: 14),
                const SizedBox(width: 4),
                Text('${order['items']} items', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                const SizedBox(width: 16),
                Icon(Icons.access_time_rounded, color: c.textHint, size: 14),
                const SizedBox(width: 4),
                Text(order['time'] as String, style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                const Spacer(),
                Text(order['amount'] as String, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
              ],
            ),
            if (order['status'] == 'active') ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.activeOrder),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('MANAGE ORDER', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
