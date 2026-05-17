import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/order.dart';
import '../../core/theme/app_colors.dart';

class OrderAcceptedScreen extends StatelessWidget {
  const OrderAcceptedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final order = args?['order'] as CustomerOrder?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Green success header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              decoration: const BoxDecoration(
                color: AppColors.success,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text('Order Accepted!',
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    order?.storeName != null
                        ? '${order!.storeName} is packing your order'
                        : 'A nearby store is packing your order',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.white.withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Store info card
                  if (order?.storeName != null)
                    _InfoCard(
                      icon: Icons.storefront_rounded,
                      iconColor: AppColors.primary,
                      title: order!.storeName!,
                      subtitle: 'Your order is being prepared',
                    ),

                  const SizedBox(height: 12),

                  // Estimated time
                  _InfoCard(
                    icon: Icons.access_time_rounded,
                    iconColor: AppColors.warning,
                    title: 'Estimated delivery: 30–45 min',
                    subtitle: 'Delivery boy will be assigned shortly',
                  ),

                  const SizedBox(height: 20),

                  // Items list
                  if (order != null && order.items.isNotEmpty) ...[
                    Text('Your Items',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    ...order.items.map((item) => _ItemRow(item: item)),
                  ],

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 12),

                  // Price breakdown
                  if (order?.productTotal != null) ...[
                    _PriceRow('Items',
                        '₹${order!.productTotal!.toStringAsFixed(0)}'),
                    const _PriceRow('Delivery fee',
                        'TBD (based on distance)'),
                    const Divider(color: AppColors.divider),
                    _PriceRow(
                        'Total (approx)',
                        '₹${order.productTotal!.toStringAsFixed(0)}',
                        bold: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pay the exact total (products + delivery) to the delivery boy in cash.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (order != null) {
                    Navigator.pushReplacementNamed(context, '/order-tracking',
                        arguments: {'order_id': order.orderId});
                  } else {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Track My Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('${item.quantity}×',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(item.name,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textPrimary))),
          if (item.price != null)
            Text('₹${(item.price * item.quantity).toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _PriceRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: bold
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w500,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
