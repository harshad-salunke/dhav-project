import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/dhav_bottom_nav.dart';
import '../../core/constants/app_routes.dart';
import '../orders/order_list_screen.dart';
import '../inventory/inventory_screen.dart';
import '../earnings/earnings_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  bool _isStoreOpen = true;

  final List<Widget> _pages = const [
    _DashboardHome(),
    OrderListScreen(),
    InventoryScreen(),
    EarningsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: _navIndex == 0 ? _buildDashboard(c) : _pages[_navIndex],
      bottomNavigationBar: DhavBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  Widget _buildDashboard(DhavColors c) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(c),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StoreStatusCard(isOpen: _isStoreOpen, onToggle: (v) => setState(() => _isStoreOpen = v)),
                  const SizedBox(height: 16),
                  _StatsRow(),
                  const SizedBox(height: 20),
                  _ActiveOrderSection(),
                  const SizedBox(height: 20),
                  _RecentOrdersSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(DhavColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: c.card,
            child: Icon(Icons.person_rounded, color: c.textSecondary, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'KIRANA PARTNER',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
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
                    decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
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

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _StoreStatusCard extends StatelessWidget {
  final bool isOpen;
  final ValueChanged<bool> onToggle;

  const _StoreStatusCard({required this.isOpen, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isOpen ? c.greenBg : c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? AppColors.green.withValues(alpha: 0.3) : c.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT STORE STATUS',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: c.textHint, letterSpacing: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  isOpen ? 'OPEN' : 'CLOSED',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isOpen ? AppColors.green : c.textHint, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Switch(
            value: isOpen,
            onChanged: onToggle,
            activeThumbColor: AppColors.green,
            inactiveThumbColor: AppColors.textGrey,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        _StatCard(label: 'ORDERS', value: '124', valueColor: c.textPrimary),
        const SizedBox(width: 12),
        _StatCard(label: 'DELIVERED', value: '118', valueColor: AppColors.green),
        const SizedBox(width: 12),
        _StatCard(label: 'EARNINGS', value: '₹8.4k', valueColor: AppColors.primary),
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
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('ACTIVE MONITORING', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Order #OD-9928', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
                  const Spacer(),
                  Text('08:42', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Text('4 Items • Pickup in 8 mins', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.activeOrder),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Text('VIEW ITEMS', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(border: Border.all(color: c.divider, width: 1.5), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.phone_rounded, color: c.textHint, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  final List<Map<String, dynamic>> _orders = const [
    {'id': 'OD-9927', 'time': '14:20 PM', 'amount': '₹1,240', 'status': 'PAID', 'statusColor': AppColors.green, 'icon': Icons.shopping_bag_outlined, 'cancelled': false},
    {'id': 'OD-9926', 'time': '13:45 PM', 'amount': '₹450', 'status': 'PAID', 'statusColor': AppColors.green, 'icon': Icons.shopping_bag_outlined, 'cancelled': false},
    {'id': 'OD-9925', 'time': '13:10 PM', 'amount': '₹0', 'status': 'FAILED', 'statusColor': AppColors.red, 'icon': Icons.cancel_outlined, 'cancelled': true},
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent Orders', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.orderList),
              child: Text('VIEW ALL', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._orders.map((order) => _OrderRow(order: order)),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.orderDetail),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider, width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: order['cancelled'] == true ? c.redBg : c.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(order['icon'] as IconData, color: order['cancelled'] == true ? AppColors.red : c.textHint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order['id']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Completed • ${order['time']}', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(order['amount'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (order['statusColor'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order['status'] as String,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: order['statusColor'] as Color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
