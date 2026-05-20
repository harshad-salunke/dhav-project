import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../core/models/analytics.dart';
import '../../core/models/store.dart';
import '../../core/models/order.dart';
import '../../core/models/settlement.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/constants/app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          const AdminSidebar(),
          const VerticalDivider(color: AppColors.border, width: 1),
          Expanded(
            child: Consumer<DashboardProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.orange));
                }
                if (provider.error != null) {
                  return _ErrorView(
                      message: provider.error!,
                      onRetry: () => provider.loadDashboard());
                }
                return _DashboardContent(provider: provider);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardProvider provider;
  const _DashboardContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => provider.loadDashboard(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Metric cards
          if (provider.analytics != null)
            _MetricsGrid(analytics: provider.analytics!),
          const SizedBox(height: 28),

          // Two-column lower section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent orders
              Expanded(
                flex: 3,
                child: _RecentOrdersCard(orders: provider.recentOrders),
              ),
              const SizedBox(width: 20),
              // Right column
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _PendingSettlementsCard(
                        settlements: provider.pendingSettlements),
                    const SizedBox(height: 20),
                    _RecentStoresCard(stores: provider.recentStores),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final AnalyticsSummary analytics;
  const _MetricsGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final metrics = [
      _Metric(
        icon: Icons.storefront_rounded,
        iconColor: AppColors.orange,
        label: 'Total Stores',
        value: analytics.totalStores.toString(),
        sub: '${analytics.activeStores} online now',
        subColor: AppColors.green,
      ),
      _Metric(
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.blue,
        label: 'Total Orders',
        value: analytics.totalOrders.toString(),
        sub: '${analytics.deliveredOrders} delivered',
        subColor: AppColors.green,
      ),
      _Metric(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.green,
        label: 'Success Rate',
        value: '${analytics.successRatePct}%',
        sub: '${analytics.failedOrders} failed',
        subColor: analytics.failedOrders > 0 ? AppColors.red : AppColors.textMuted,
      ),
      _Metric(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.yellow,
        label: 'Platform Fee',
        value: currencyFmt.format(analytics.platformFeeCollected),
        sub: 'Total collected',
        subColor: AppColors.textMuted,
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: metrics.map((m) => _MetricCard(metric: m)).toList(),
    );
  }
}

class _Metric {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  const _Metric(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      required this.sub,
      required this.subColor});
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metric.label,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: metric.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(metric.icon, color: metric.iconColor, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(metric.value,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(metric.sub,
                  style: GoogleFonts.inter(
                      color: metric.subColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  final List<AdminOrder> orders;
  const _RecentOrdersCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Orders',
      actionLabel: 'View all',
      onAction: () => Navigator.pushNamed(context, AppRoutes.orders),
      child: orders.isEmpty
          ? _EmptyState(message: 'No orders yet')
          : Column(
              children: orders
                  .take(8)
                  .map((o) => _OrderRow(order: o))
                  .toList(),
            ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final AdminOrder order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('hh:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderId.substring(0, 8).toUpperCase(),
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(order.deliveryAddress,
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: StatusBadge.forOrderStatus(order.status),
          ),
          Expanded(
            child: Text('₹${order.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Text(timeFmt.format(order.createdDateTime),
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PendingSettlementsCard extends StatelessWidget {
  final List<AdminSettlement> settlements;
  const _PendingSettlementsCard({required this.settlements});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Pending Settlements',
      actionLabel: 'View all',
      onAction: () => Navigator.pushNamed(context, AppRoutes.settlements),
      child: settlements.isEmpty
          ? _EmptyState(message: 'All settlements paid!')
          : Column(
              children: settlements.take(5).map((s) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.storeName,
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(s.weekStart,
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${s.totalFeeOwed.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                  color: s.isOverdue
                                      ? AppColors.red
                                      : AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          if (s.isOverdue)
                            Text('OVERDUE',
                                style: GoogleFonts.inter(
                                    color: AppColors.red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _RecentStoresCard extends StatelessWidget {
  final List<AdminStore> stores;
  const _RecentStoresCard({required this.stores});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Stores',
      actionLabel: 'Manage',
      onAction: () => Navigator.pushNamed(context, AppRoutes.stores),
      child: stores.isEmpty
          ? _EmptyState(message: 'No stores yet')
          : Column(
              children: stores.take(5).map((s) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: AppColors.orange, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(s.area,
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      StatusBadge.forStoreStatus(s.statusLabel),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    textStyle: GoogleFonts.inter(fontSize: 12)),
                child: Text(actionLabel),
              ),
            ],
          ),
          const Divider(color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(message,
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 13)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 40),
          const SizedBox(height: 12),
          Text('Failed to load dashboard',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
