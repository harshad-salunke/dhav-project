import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';

class IncomingOrderScreen extends StatefulWidget {
  final String? orderId;
  const IncomingOrderScreen({super.key, this.orderId});

  @override
  State<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends State<IncomingOrderScreen> {
  int _secondsLeft = 45;
  Timer? _timer;
  Order? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _secondsLeft--);
      }
    });
    _load();
  }

  Future<void> _load() async {
    if (widget.orderId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final order =
          await context.read<OrderProvider>().loadOrder(widget.orderId!);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_order == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<OrderProvider>().accept(_order!.orderId);
      _timer?.cancel();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.activeOrder,
          arguments: _order!.orderId);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Accept failed: $e')));
      }
    }
  }

  Future<void> _reject() async {
    if (_order == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<OrderProvider>().reject(_order!.orderId);
    } catch (_) {}
    _timer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: Stack(
        children: [
          Positioned.fill(
              child: Container(color: const Color(0xFF1A1F2E).withValues(alpha: 0.7))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _error != null
                      ? _errorCard(_error!)
                      : _order == null
                          ? _errorCard('Order not available')
                          : _buildOrderCard(_order!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 36),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textDark)),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss')),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final progress = _secondsLeft / 45.0;
    final earning = order.platformFeeAmount + order.deliveryFee;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'ITEMS',
                    value: '${order.itemCount} items'),
                const SizedBox(width: 12),
                _InfoChip(
                    icon: Icons.near_me_rounded,
                    label: 'AREA',
                    value: order.customerAddress.area),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('POTENTIAL EARNING',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMedium,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text('₹${earning.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('AUTO-REJECT IN',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('${_secondsLeft}s',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.5
                      ? AppColors.green
                      : progress > 0.25
                          ? AppColors.primary
                          : AppColors.red,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _busy ? null : _accept,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy)
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                        else
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text('QUICK ACCEPT',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineButton(
                        label: 'VIEW DETAILS',
                        color: AppColors.primary,
                        onTap: () => _showDetailsSheet(order),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OutlineButton(
                        label: 'REJECT',
                        color: AppColors.red,
                        onTap: _reject,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Accepting this order increases your priority score.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showDetailsSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsSheet(order: order, onAccept: _accept, onReject: _reject),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(12)),
        child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1))),
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  final Order order;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _DetailsSheet(
      {required this.order, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${order.orderId.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark)),
                        Text('${order.itemCount} items • ${order.customerAddress.area}',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textMedium)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        '₹${(order.platformFeeAmount + order.deliveryFee).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark)),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  Text('ORDER ITEMS',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGrey,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  ...order.items.map((item) => _ItemRow(item: item)),
                  const SizedBox(height: 16),
                  _SummaryRow(
                      label: 'Item Total',
                      value: '₹${order.totalProductAmount.toStringAsFixed(2)}'),
                  _SummaryRow(
                      label: 'Platform Fee',
                      value: '₹${order.platformFeeAmount.toStringAsFixed(2)}'),
                  const Divider(color: AppColors.border, height: 24),
                  _SummaryRow(
                      label: 'You Earn',
                      value:
                          '₹${(order.platformFeeAmount + order.deliveryFee).toStringAsFixed(2)}',
                      isBold: true,
                      color: AppColors.green),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            onAccept();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(12)),
                            child: Center(
                                child: Text('ACCEPT ORDER',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onReject();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.red, width: 1.5),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('REJECT',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.red,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.textMedium, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text('Qty: ${item.quantity} ${item.unit}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          Text('₹${item.totalPrice.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _SummaryRow(
      {required this.label, required this.value, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                  color: color ?? AppColors.textMedium)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                  color: color ?? AppColors.textDark)),
        ],
      ),
    );
  }
}
