import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<DeliveryProvider>().loadAssignments());
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delivery = context.watch<DeliveryProvider>();
    final user = context.watch<AuthProvider>().user;
    final active = delivery.activeAssignment;
    final recent = delivery.orders
        .where((o) => o.status == 'delivered')
        .take(5)
        .toList();
    final todayDelivered = delivery.orders
        .where((o) =>
            o.status == 'delivered' &&
            (o.deliveredAt ?? 0) > _startOfDayMs())
        .toList();

    // Show shimmer skeleton on first load before any data arrives
    if (delivery.loading && delivery.orders.isEmpty) {
      return Scaffold(
        backgroundColor: c.scaffold,
        body: SafeArea(child: const DeliveryHomeShimmer()),
      );
    }

    return Scaffold(
      backgroundColor: c.scaffold,
      body: RefreshIndicator(
        onRefresh: () => delivery.loadAssignments(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(c, user?.displayName ?? 'Delivery Partner')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildAvailabilityCard(c),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildTodayStats(c, todayDelivered),
              ),
            ),
            if (active != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildActiveDelivery(c, active),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text('RECENT DELIVERIES',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.textHint,
                            letterSpacing: 1.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.deliveryHistory),
                      child: Text('VIEW ALL',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),
            if (recent.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text('No deliveries yet.',
                      style: GoogleFonts.inter(color: c.textHint, fontSize: 13)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _RecentDeliveryTile(order: recent[i]),
                  ),
                  childCount: recent.length,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded, color: AppColors.red),
                  label: Text('Sign Out',
                      style: GoogleFonts.inter(color: AppColors.red)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  int _startOfDayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  Widget _buildHeader(DhavColors c, String name) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                Text('Delivery Partner',
                    style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(DhavColors c) {
    return GestureDetector(
      onTap: () => setState(() => _isAvailable = !_isAvailable),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _isAvailable
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                )
              : null,
          color: _isAvailable ? null : c.card,
          borderRadius: BorderRadius.circular(20),
          border: _isAvailable ? null : Border.all(color: c.divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_isAvailable ? Colors.white : c.iconBg).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isAvailable
                    ? Icons.delivery_dining_rounded
                    : Icons.do_not_disturb_rounded,
                color: _isAvailable ? Colors.white : c.textHint,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isAvailable ? 'ONLINE' : 'OFFLINE',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _isAvailable ? Colors.white : c.textHint,
                          letterSpacing: 1)),
                  Text(_isAvailable ? 'Accepting deliveries' : 'Tap to go online',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _isAvailable ? Colors.white70 : c.textHint)),
                ],
              ),
            ),
            Switch(
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(DhavColors c, List<Order> todayDelivered) {
    final earnings = todayDelivered.fold<double>(
        0, (a, o) => a + o.deliveryFee);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TODAY'S PERFORMANCE",
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textHint,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
                icon: Icons.local_shipping_rounded,
                label: 'Deliveries',
                value: '${todayDelivered.length}',
                color: AppColors.primary,
                c: c),
            const SizedBox(width: 10),
            _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Earned',
                value: '₹${earnings.toStringAsFixed(0)}',
                color: AppColors.green,
                c: c),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveDelivery(DhavColors c, Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACTIVE DELIVERY',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textHint,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryAssignment,
              arguments: order.orderId),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    const Spacer(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(order.status.toUpperCase().replaceAll('_', ' '),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.green, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.customerAddress.oneLine,
                          style: GoogleFonts.inter(fontSize: 12, color: c.textHint),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('NAVIGATE',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final DhavColors c;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}

class _RecentDeliveryTile extends StatelessWidget {
  final Order order;
  const _RecentDeliveryTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final time = order.deliveredAt == null
        ? ''
        : DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(order.deliveredAt!));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: c.greenBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                Text(order.customerAddress.area,
                    style: GoogleFonts.inter(fontSize: 11, color: c.textHint),
                    overflow: TextOverflow.ellipsis),
                Text(time,
                    style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
              ],
            ),
          ),
          Text('₹${order.deliveryFee.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.green)),
        ],
      ),
    );
  }
}
