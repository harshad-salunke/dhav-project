import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/order.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadAssignments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  static final _now = DateTime.now();

  static bool _isToday(int? ms) {
    if (ms == null) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return dt.year == _now.year &&
        dt.month == _now.month &&
        dt.day == _now.day;
  }

  static bool _isThisWeek(int? ms) {
    if (ms == null) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final weekStart = _now.subtract(Duration(days: _now.weekday - 1));
    return dt.isAfter(weekStart.subtract(const Duration(days: 1)));
  }

  List<Order> _filter(List<Order> all, int tab) {
    switch (tab) {
      case 0:
        return all.where((o) => _isToday(o.deliveredAt ?? o.createdAt)).toList();
      case 1:
        return all.where((o) => _isThisWeek(o.deliveredAt ?? o.createdAt)).toList();
      default:
        return all;
    }
  }

  // ── Summary stats ─────────────────────────────────────────────────────────

  Map<String, dynamic> _summary(List<Order> orders) {
    final delivered = orders.where((o) => o.status == 'delivered').toList();
    final failed = orders.where((o) => o.status == 'failed').toList();
    final totalEarned =
        delivered.fold<double>(0, (sum, o) => sum + o.deliveryFee);

    return {
      'deliveries': delivered.length,
      'failed': failed.length,
      'earned': totalEarned,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dp = context.watch<DeliveryProvider>();

    final allCompleted = dp.orders
        .where((o) => o.status == 'delivered' || o.status == 'failed')
        .toList();

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Delivery History',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.primary,
              unselectedLabelColor: c.textHint,
              labelStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'This Week'),
                Tab(text: 'All Time'),
              ],
            ),
          ),
        ),
      ),
      body: dp.loading
          ? _buildLoading(c)
          : dp.error != null && allCompleted.isEmpty
              ? _buildError(c, dp.error!)
              : RefreshIndicator(
                  onRefresh: () =>
                      context.read<DeliveryProvider>().loadAssignments(),
                  child: Column(
                    children: [
                      // Summary card
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _SummaryCard(
                          stats: _summary(
                              _filter(allCompleted, _tabController.index)),
                          tabLabel: ['TODAY', 'THIS WEEK', 'ALL TIME'][_tabController.index],
                        ),
                      ),

                      // Delivery list per tab
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _DeliveryList(
                                deliveries:
                                    _filter(allCompleted, 0)),
                            _DeliveryList(
                                deliveries:
                                    _filter(allCompleted, 1)),
                            _DeliveryList(deliveries: allCompleted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoading(DhavColors c) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 120,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, __) => Container(
              height: 76,
              decoration: BoxDecoration(
                  color: c.card, borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(DhavColors c, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: c.textHint),
          const SizedBox(height: 12),
          Text(error,
              style: GoogleFonts.inter(
                  fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                context.read<DeliveryProvider>().loadAssignments(),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String tabLabel;

  const _SummaryCard({required this.stats, required this.tabLabel});

  @override
  Widget build(BuildContext context) {
    final delivered = stats['deliveries'] as int;
    final failed = stats['failed'] as int;
    final earned = stats['earned'] as double;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(tabLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryMetric(
                  label: 'Deliveries', value: '$delivered'),
              _SummaryMetric(
                  label: 'Earned',
                  value:
                      '₹${earned.toStringAsFixed(0)}'),
              _SummaryMetric(
                  label: 'Failed', value: '$failed'),
            ],
          ),
          if (delivered == 0 && failed == 0) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text('No deliveries in this period',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
      ],
    );
  }
}

// ─── Delivery list ────────────────────────────────────────────────────────────

class _DeliveryList extends StatelessWidget {
  final List<Order> deliveries;

  const _DeliveryList({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining_rounded,
                size: 52, color: c.textHint),
            const SizedBox(height: 12),
            Text('No deliveries yet',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary)),
            const SizedBox(height: 4),
            Text('Your completed deliveries will appear here',
                style: GoogleFonts.inter(
                    fontSize: 12, color: c.textHint)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: deliveries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _HistoryCard(order: deliveries[i]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Order order;

  const _HistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDelivered = order.status == 'delivered';
    final timeMs = order.deliveredAt ?? order.createdAt;
    final timeStr = timeMs != null
        ? DateFormat('hh:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(timeMs))
        : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDelivered ? c.greenBg : c.redBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDelivered
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: isDelivered ? AppColors.green : AppColors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                const SizedBox(height: 3),
                Text(order.customerAddress.oneLine,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: c.textHint),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 11, color: c.textHint),
                    const SizedBox(width: 3),
                    Text(timeStr,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: c.textHint)),
                    const SizedBox(width: 8),
                    Icon(Icons.shopping_bag_outlined,
                        size: 11, color: c.textHint),
                    const SizedBox(width: 3),
                    Text('${order.items.length} items',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: c.textHint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isDelivered
                    ? '₹${order.deliveryFee.toStringAsFixed(0)}'
                    : '₹0',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDelivered
                        ? AppColors.green
                        : c.textHint),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivered ? c.greenBg : c.redBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDelivered ? 'Delivered' : 'Failed',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDelivered
                          ? AppColors.green
                          : AppColors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
