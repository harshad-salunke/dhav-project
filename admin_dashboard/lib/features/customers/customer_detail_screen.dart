import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_sidebar.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/services/api_client.dart';
import '../../core/constants/app_routes.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _orders = [];
  int _totalOrders = 0;
  int _deliveredOrders = 0;
  double _totalSpent = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = widget.customerId;
      final results = await Future.wait([
        _api.get('/admin/customers/$uid'),
        _api.get('/admin/customers/$uid/orders'),
      ]);

      final customerData = results[0] as Map<String, dynamic>;
      final ordersData = results[1] as Map<String, dynamic>;
      final rawOrders = (ordersData['orders'] as List? ?? [])
          .map((o) => Map<String, dynamic>.from(o as Map))
          .toList();

      setState(() {
        _customer = customerData;
        _orders = rawOrders;
        _totalOrders = (ordersData['total'] as num?)?.toInt() ?? rawOrders.length;
        _deliveredOrders = (ordersData['delivered'] as num?)?.toInt() ?? 0;
        _totalSpent = (ordersData['total_spent'] as num?)?.toDouble() ?? 0;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.orange))
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _loadAll)
                    : _CustomerDetailBody(
                        customer: _customer!,
                        orders: _orders,
                        totalOrders: _totalOrders,
                        deliveredOrders: _deliveredOrders,
                        totalSpent: _totalSpent,
                        tabs: _tabs,
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Main body ──────────────────────────────────────────────────────────────────

class _CustomerDetailBody extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> orders;
  final int totalOrders;
  final int deliveredOrders;
  final double totalSpent;
  final TabController tabs;

  const _CustomerDetailBody({
    required this.customer,
    required this.orders,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.totalSpent,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final name = customer['name'] ?? customer['display_name'] ?? 'Unknown';
    final email = customer['email'] ?? '—';
    final phone = customer['phone'] ?? '—';
    final createdAt = customer['created_at'] as int?;
    final joinedDate = createdAt != null
        ? DateFormat('MMM d, yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + title row
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.customers),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back_rounded,
                              color: AppColors.textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text('Customers',
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 8),
                  Text(name,
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary, fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.textSecondary, size: 18),
                    tooltip: 'Refresh',
                    onPressed: () {
                      // Trigger reload via parent — use a rebuild
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Customer avatar + info + KPIs
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                    child: Text(
                      name.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.inter(
                          color: AppColors.orange,
                          fontSize: 26,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name / email / phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined,
                                color: AppColors.textMuted, size: 13),
                            const SizedBox(width: 5),
                            Text(email,
                                style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(width: 16),
                            const Icon(Icons.phone_outlined,
                                color: AppColors.textMuted, size: 13),
                            const SizedBox(width: 5),
                            Text(phone,
                                style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                color: AppColors.textMuted, size: 12),
                            const SizedBox(width: 5),
                            Text('Joined $joinedDate',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // KPI cards
                  _KpiCard(
                      label: 'Total Orders',
                      value: totalOrders.toString(),
                      color: AppColors.blue),
                  const SizedBox(width: 12),
                  _KpiCard(
                      label: 'Delivered',
                      value: deliveredOrders.toString(),
                      color: AppColors.green),
                  const SizedBox(width: 12),
                  _KpiCard(
                      label: 'Total Spent',
                      value: '₹${totalSpent.toStringAsFixed(0)}',
                      color: AppColors.orange),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs
              TabBar(
                controller: tabs,
                isScrollable: false,
                labelStyle: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
                labelColor: AppColors.orange,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.orange,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Orders'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab body ─────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              _OverviewTab(customer: customer),
              _OrdersTab(orders: orders),
            ],
          ),
        ),
      ],
    );
  }
}

// ── KPI card ───────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Overview tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _OverviewTab({required this.customer});

  @override
  Widget build(BuildContext context) {
    final addresses = customer['saved_addresses'] as List<dynamic>? ?? [];
    final defaultAddr = customer['default_address'] as Map<String, dynamic>?;
    final language = customer['language'] ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column
          Expanded(
            child: Column(
              children: [
                _SectionCard(
                  title: 'Contact Information',
                  child: Column(
                    children: [
                      _InfoRow(label: 'Full Name',
                          value: customer['name'] ?? customer['display_name'] ?? '—'),
                      _InfoRow(label: 'Email', value: customer['email'] ?? '—'),
                      _InfoRow(label: 'Phone', value: customer['phone'] ?? '—'),
                      _InfoRow(label: 'Language', value: language),
                      _InfoRow(
                        label: 'Member Since',
                        value: customer['created_at'] != null
                            ? DateFormat('MMMM d, yyyy').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                    customer['created_at'] as int))
                            : '—',
                      ),
                    ],
                  ),
                ),
                if (defaultAddr != null) ...[
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Default Address',
                    child: _AddressCard(address: defaultAddr),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Right column — saved addresses
          Expanded(
            child: _SectionCard(
              title: 'Saved Addresses (${addresses.length})',
              child: addresses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No saved addresses',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 13)),
                    )
                  : Column(
                      children: addresses
                          .asMap()
                          .entries
                          .map((e) => Column(
                                children: [
                                  if (e.key > 0)
                                    const Divider(
                                        color: AppColors.border, height: 24),
                                  _AddressCard(
                                      address: Map<String, dynamic>.from(
                                          e.value as Map)),
                                ],
                              ))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    final label = address['label']?.toString() ?? '';
    final flat = address['flat_building']?.toString() ?? '';
    final floor = address['floor']?.toString() ?? '';
    final area = address['area']?.toString() ?? '';
    final landmark = address['landmark']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final pincode = address['pincode']?.toString() ?? '';
    final fullAddress = address['full_address']?.toString() ?? '';
    final lat = address['lat'];
    final lng = address['lng'];

    final lines = <String>[
      if (flat.isNotEmpty) flat + (floor.isNotEmpty ? ', Floor $floor' : ''),
      if (area.isNotEmpty) area,
      if (landmark.isNotEmpty) 'Near $landmark',
      if (city.isNotEmpty || pincode.isNotEmpty)
        [city, pincode].where((s) => s.isNotEmpty).join(' - '),
      if (fullAddress.isNotEmpty && flat.isEmpty) fullAddress,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
        ],
        ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(l,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 13)),
            )),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.textMuted, size: 12),
              const SizedBox(width: 4),
              Text('$lat, $lng',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Orders tab ─────────────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _OrdersTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No orders yet',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 14)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Table header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: const [
                  Expanded(
                      flex: 3,
                      child: Text('ORDER ID',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('DATE',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 3,
                      child: Text('ITEMS',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('STATUS',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      child: Text('AMOUNT',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            ...orders.map((o) => _OrderRow(order: o)),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final orderId = order['order_id']?.toString() ?? '—';
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final status = order['status']?.toString() ?? 'unknown';
    final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = order['created_at'] as int?;
    final date = createdAt != null
        ? DateFormat('dd MMM yy, hh:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '—';

    final rawItems = order['items'] as List<dynamic>? ?? [];
    final itemSummary = rawItems.isEmpty
        ? '—'
        : rawItems.length == 1
            ? rawItems.first['name']?.toString() ?? '1 item'
            : '${rawItems.length} items';

    final deliveryAddr = order['delivery_address'] as Map<String, dynamic>?;
    final addrLine = deliveryAddr?['full_address']?.toString() ??
        deliveryAddr?['area']?.toString() ??
        '';

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
      childrenPadding:
          const EdgeInsets.fromLTRB(20, 0, 20, 16),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: AppColors.surface.withValues(alpha: 0.4),
      iconColor: AppColors.textMuted,
      collapsedIconColor: AppColors.textMuted,
      shape: const Border(top: BorderSide(color: AppColors.border)),
      collapsedShape: const Border(top: BorderSide(color: AppColors.border)),
      title: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('#$shortId...',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(date,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(itemSummary,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: StatusBadge.forOrderStatus(status),
          ),
          Expanded(
            child: Text('₹${amount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      children: [
        // Expanded detail: items list + address
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rawItems.isNotEmpty) ...[
              Text('Items',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...rawItems.map((item) {
                final i = item as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 4, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(i['name']?.toString() ?? '—',
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary, fontSize: 13))),
                      Text('x${i['quantity'] ?? 1}',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('₹${(i['price'] as num?)?.toStringAsFixed(0) ?? '—'}',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
            if (addrLine.isNotEmpty) ...[
              Text('Delivery Address',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(addrLine,
                          style: GoogleFonts.inter(
                              color: AppColors.textPrimary, fontSize: 13))),
                ],
              ),
            ],
            if (order['accepted_by_store_id'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text('Store: ${order['accepted_by_store_id']}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.red, size: 40),
          const SizedBox(height: 12),
          Text(error,
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
          ),
        ],
      ),
    );
  }
}
