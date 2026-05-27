import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/widgets/shimmer_widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  final String? orderId;
  const OrderDetailScreen({super.key, this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = widget.orderId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'No order specified';
      });
      return;
    }
    try {
      final order = await context.read<OrderProvider>().loadOrder(id);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _order == null
              ? 'Order Detail'
              : 'Order #${_order!.orderId.substring(0, 8).toUpperCase()}',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
      ),
      body: _loading
          ? const OrderDetailShimmer()
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: GoogleFonts.inter(color: AppColors.red)))
              : _order == null
                  ? const SizedBox.shrink()
                  : _buildBody(c, _order!),
    );
  }

  Widget _buildBody(DhavColors c, Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderSummaryCard(c: c, order: order),
          const SizedBox(height: 16),
          _CustomerInfoCard(c: c, order: order),
          const SizedBox(height: 16),
          _OrderItemsCard(c: c, order: order),
          const SizedBox(height: 16),
          _PaymentCard(c: c, order: order),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final DhavColors c;
  final Order order;
  const _OrderSummaryCard({required this.c, required this.order});

  @override
  Widget build(BuildContext context) {
    final time = order.createdAt == null
        ? '—'
        : DateFormat('d MMM, HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(order.createdAt!));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(order.status.toUpperCase().replaceAll('_', ' '),
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const Spacer(),
              Text('₹${order.totalCustomerAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: c.textHint),
              const SizedBox(width: 4),
              Text(time,
                  style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              const SizedBox(width: 16),
              Icon(Icons.shopping_basket_outlined, size: 14, color: c.textHint),
              const SizedBox(width: 4),
              Text('${order.itemCount} items',
                  style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  final DhavColors c;
  final Order order;
  const _CustomerInfoCard({required this.c, required this.order});

  @override
  Widget build(BuildContext context) {
    final a = order.customerAddress;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUSTOMER',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Text(a.oneLine,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('${a.city} ${a.pincode ?? ''}',
              style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
          if (order.deliveryBoyName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.delivery_dining_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Delivered by ${order.deliveryBoyName!}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  final DhavColors c;
  final Order order;
  const _OrderItemsCard({required this.c, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORDER ITEMS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          ...order.items.map((item) => _ItemRow(item: item, c: c)),
          Divider(color: c.divider, height: 24),
          _line('Subtotal', '₹${order.totalProductAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _line('Delivery Fee', '₹${order.deliveryFee.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Divider(color: c.divider, height: 8),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('TOTAL',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const Spacer(),
              Text('₹${order.totalCustomerAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 14, color: c.textHint)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
        ],
      );
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  final DhavColors c;
  const _ItemRow({required this.item, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.inventory_2_outlined, color: c.textHint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                Text(
                    'Qty: ${item.quantity} ${item.unit} × ₹${item.pricePerUnit.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          Text('₹${item.totalPrice.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final DhavColors c;
  final Order order;
  const _PaymentCard({required this.c, required this.order});

  @override
  Widget build(BuildContext context) {
    final label = order.paymentMethod.toUpperCase();
    final paid = order.status == 'delivered';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textHint,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: c.greenBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.money_rounded,
                    color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: paid
                        ? c.greenBg
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(paid ? 'PAID' : 'PENDING',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: paid ? AppColors.green : AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
