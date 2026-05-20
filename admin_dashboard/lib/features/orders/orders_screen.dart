import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/orders_provider.dart';
import '../../core/models/order.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/widgets/status_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _search = '';
  String? _statusFilter;

  static const _statuses = [
    null,
    'pending',
    'broadcast',
    'accepted',
    'packed',
    'out_for_delivery',
    'delivered',
    'failed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
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
            child: Consumer<OrdersProvider>(
              builder: (context, provider, _) {
                final filtered = provider.orders
                    .where(
                      (o) =>
                          o.orderId.toLowerCase().contains(
                            _search.toLowerCase(),
                          ) ||
                          o.deliveryAddress.toLowerCase().contains(
                            _search.toLowerCase(),
                          ),
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrdersHeader(
                      total: provider.orders.length,
                      statusFilter: _statusFilter,
                      statuses: _statuses,
                      onSearch: (v) => setState(() => _search = v),
                      onStatusChange: (s) {
                        setState(() => _statusFilter = s);
                        provider.loadOrders(status: s);
                      },
                    ),
                    Expanded(
                      child: provider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.orange,
                              ),
                            )
                          : _OrdersTable(orders: filtered, provider: provider),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  final int total;
  final String? statusFilter;
  final List<String?> statuses;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatusChange;

  const _OrdersHeader({
    required this.total,
    required this.statusFilter,
    required this.statuses,
    required this.onSearch,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$total orders loaded',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Status dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: statusFilter,
                dropdownColor: AppColors.surface,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
                items: statuses.map((s) {
                  return DropdownMenuItem<String?>(
                    value: s,
                    child: Text(
                      s ?? 'All statuses',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onStatusChange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: onSearch,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                hintText: 'Search by order ID or address...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<AdminOrder> orders;
  final OrdersProvider provider;
  const _OrdersTable({required this.orders, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No orders found',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _TableHeader(),
            const Divider(color: AppColors.border, height: 1),
            ...orders.map((o) => _OrderRow(order: o, provider: provider)),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('ORDER ID', style: style)),
          Expanded(flex: 3, child: Text('ADDRESS', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(child: Text('AMOUNT', style: style)),
          Expanded(child: Text('FEE', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          SizedBox(width: 60, child: Text('ACTION', style: style)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final AdminOrder order;
  final OrdersProvider provider;
  const _OrderRow({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM, hh:mm a');
    final isTerminal = [
      'delivered',
      'failed',
      'cancelled',
    ].contains(order.status);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                order.orderId.substring(0, 8).toUpperCase(),
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                order.deliveryAddress,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 2, child: StatusBadge.forOrderStatus(order.status)),
            Expanded(
              child: Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '₹${order.platformFeeAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                dateFmt.format(order.createdDateTime),
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: isTerminal
                  ? const SizedBox.shrink()
                  : Tooltip(
                      message: 'Force fail',
                      child: IconButton(
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.red,
                          size: 18,
                        ),
                        onPressed: () => _confirmForceFail(context),
                        splashRadius: 18,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmForceFail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Force fail order?',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Order ${order.orderId.substring(0, 8).toUpperCase()} will be marked as failed and a strike issued to the store.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.forceFailOrder(order.orderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Force Fail'),
          ),
        ],
      ),
    );
  }
}
