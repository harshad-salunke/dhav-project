import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/order.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';
import 'rate_order_sheet.dart';

/// Full-page view for a completed/failed/cancelled order.
/// Accepts a [CustomerOrder] via route arguments or an [orderId] string
/// (will load from OrderProvider if only id is given).
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  CustomerOrder? _order;
  bool _loading = false;
  bool _hasRated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_order != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CustomerOrder) {
      _order = args;
      _hasRated = args.hasReview;
    } else if (args is Map<String, dynamic>) {
      // Might receive {'order_id': '...'} or a full order map
      final orderId = args['order_id'] as String?;
      if (orderId != null) {
        _loadOrder(orderId);
      }
    } else if (args is String) {
      _loadOrder(args);
    }
  }

  Future<void> _loadOrder(String orderId) async {
    setState(() => _loading = true);
    try {
      final op = context.read<OrderProvider>();
      final order = await op.loadOrder(orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _hasRated = order?.hasReview ?? false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Reorder ──────────────────────────────────────────────────────────────

  void _reorder() {
    final order = _order;
    if (order == null) return;
    final cart = context.read<CartProvider>();
    final catalog = context.read<CatalogProvider>();
    for (final item in order.items) {
      try {
        final catalogItem = catalog.items.firstWhere(
          (c) => c.id == item.itemId,
          orElse: () => catalog.items.isNotEmpty
              ? catalog.items.first
              : throw Exception('Catalog not loaded'),
        );
        cart.addItem(catalogItem);
      } catch (_) {
        // item may not exist in catalog any more — skip silently
      }
    }
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/cart');
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'cancelled':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'delivered':
        return '✓ Delivered';
      case 'failed':
        return '✕ Failed';
      case 'cancelled':
        return '✕ Cancelled';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Order Details',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: _loading
          ? const OrderDetailShimmer()
          : _order == null
              ? _buildEmpty()
              : _buildContent(_order!),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('Order not found',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContent(CustomerOrder order) {
    final statusColor = _statusColor(order.status);
    final isDelivered = order.status == 'delivered';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ──────────────────────────────────────────────
          _StatusBanner(
            status: order.status,
            label: _statusLabel(order.status),
            color: statusColor,
            orderId: order.orderId,
            date: order.createdAt,
            formatDate: _formatDate,
          ),

          const SizedBox(height: 16),

          // ── Store info ─────────────────────────────────────────────────
          if (order.storeName != null)
            _SectionCard(
              children: [
                _InfoRow(
                  icon: Icons.storefront_rounded,
                  label: 'Store',
                  value: order.storeName!,
                ),
                if (order.storePhone != null)
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Store phone',
                    value: order.storePhone!,
                    onTap: () =>
                        HapticFeedback.selectionClick(),
                  ),
              ],
            ),

          const SizedBox(height: 12),

          // ── Delivery address ───────────────────────────────────────────
          _SectionCard(
            children: [
              _InfoRow(
                icon: Icons.location_on_rounded,
                label: 'Delivered to',
                value: order.deliveryAddress.isNotEmpty
                    ? order.deliveryAddress
                    : 'Address not available',
              ),
              if (order.deliveryBoyName != null)
                _InfoRow(
                  icon: Icons.delivery_dining_rounded,
                  label: 'Delivery by',
                  value: order.deliveryBoyName!,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Items ──────────────────────────────────────────────────────
          _SectionTitle('Items Ordered'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                ...order.items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.quantity}×',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary),
                                  ),
                                  if (item.unit.isNotEmpty)
                                    Text(
                                      item.unit,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            if (item.price != null)
                              Text(
                                '₹${(item.price! * item.quantity).toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                          ],
                        ),
                      ),
                      if (i < order.items.length - 1)
                        Divider(
                            height: 1,
                            color: AppColors.border,
                            indent: 16,
                            endIndent: 16),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Price breakdown ────────────────────────────────────────────
          _SectionTitle('Price Breakdown'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              if (order.productTotal != null)
                _PriceRow(
                    label: 'Items total',
                    value: '₹${order.productTotal!.toStringAsFixed(0)}'),
              if (order.deliveryFee != null)
                _PriceRow(
                    label: 'Delivery fee',
                    value: '₹${order.deliveryFee!.toStringAsFixed(0)}'),
              const Divider(height: 16, color: AppColors.divider),
              _PriceRow(
                label: 'Grand Total',
                value: '₹${order.grandTotal.toStringAsFixed(0)}',
                bold: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Payment note ───────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Paid in cash to delivery boy',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Actions ────────────────────────────────────────────────────
          if (isDelivered && !_hasRated)
            _ActionButton(
              label: '⭐  Rate this delivery',
              color: AppColors.warning,
              onTap: () async {
                await RateOrderSheet.show(
                  context,
                  orderId: order.orderId,
                  storeName: order.storeName,
                );
                if (mounted) setState(() => _hasRated = true);
              },
            ),

          if (isDelivered && !_hasRated) const SizedBox(height: 10),

          _ActionButton(
            label: '🔁  Order Again',
            color: AppColors.primary,
            onTap: _reorder,
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final String orderId;
  final DateTime? date;
  final String Function(DateTime) formatDate;

  const _StatusBanner({
    required this.status,
    required this.label,
    required this.color,
    required this.orderId,
    required this.date,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Order #${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              formatDate(date!),
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.4),
      );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: onTap != null
                            ? AppColors.primary
                            : AppColors.textPrimary),
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

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textPrimary : AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
    );
  }
}
