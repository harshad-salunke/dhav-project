import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

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
          'Order #OD-9928',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'PAID',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderSummaryCard(c: c),
            const SizedBox(height: 16),
            _CustomerInfoCard(c: c),
            const SizedBox(height: 16),
            _OrderItemsCard(c: c),
            const SizedBox(height: 16),
            _PaymentCard(c: c),
            const SizedBox(height: 16),
            _StatusTimeline(c: c),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final DhavColors c;
  const _OrderSummaryCard({required this.c});

  @override
  Widget build(BuildContext context) {
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
              Text('Order #OD-9928', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹1,240', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text('4 items', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: c.divider, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryChip(icon: Icons.access_time_rounded, label: '14:35 PM', c: c),
              const SizedBox(width: 12),
              _SummaryChip(icon: Icons.calendar_today_rounded, label: 'Today', c: c),
              const SizedBox(width: 12),
              _SummaryChip(icon: Icons.local_shipping_outlined, label: '0.8 km', c: c),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final DhavColors c;
  const _SummaryChip({required this.icon, required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.textHint),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
      ],
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  final DhavColors c;
  const _CustomerInfoCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUSTOMER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.iconBg,
                child: Icon(Icons.person_rounded, color: c.textHint, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Priya Sharma', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Flat 302, Laxmi Niwas, Kothrud', style: GoogleFonts.inter(fontSize: 13, color: c.textHint)),
                    const SizedBox(height: 2),
                    Text('+91 98765 43210', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  final DhavColors c;
  const _OrderItemsCard({required this.c});

  static const List<Map<String, dynamic>> _items = [
    {'name': 'Tata Salt 1kg', 'qty': 2, 'price': '₹50', 'total': '₹100'},
    {'name': 'Amul Butter 100g', 'qty': 1, 'price': '₹60', 'total': '₹60'},
    {'name': 'Fortune Refined Oil 1L', 'qty': 1, 'price': '₹175', 'total': '₹175'},
    {'name': 'Parle-G Biscuits 800g', 'qty': 2, 'price': '₹85', 'total': '₹170'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORDER ITEMS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          ..._items.map((item) => _ItemRow(item: item, c: c)),
          Divider(color: c.divider, height: 24),
          Row(
            children: [
              Text('Subtotal', style: GoogleFonts.inter(fontSize: 14, color: c.textHint)),
              const Spacer(),
              Text('₹505', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Delivery Fee', style: GoogleFonts.inter(fontSize: 14, color: c.textHint)),
              const Spacer(),
              Text('₹735', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: c.divider, height: 8),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('TOTAL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const Spacer(),
              Text('₹1,240', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
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
                Text(item['name'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Text('Qty: ${item['qty']} × ${item['price']}', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          Text(item['total'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final DhavColors c;
  const _PaymentCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.greenBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.money_rounded, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash on Delivery', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    Text('Payment collected at door', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: c.greenBg, borderRadius: BorderRadius.circular(8)),
                child: Text('PAID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final DhavColors c;
  const _StatusTimeline({required this.c});

  static const List<Map<String, dynamic>> _steps = [
    {'label': 'Order Placed', 'time': '14:20 PM', 'done': true},
    {'label': 'Order Accepted', 'time': '14:22 PM', 'done': true},
    {'label': 'Packed & Dispatched', 'time': '14:28 PM', 'done': true},
    {'label': 'Out for Delivery', 'time': '14:30 PM', 'done': true},
    {'label': 'Delivered', 'time': '14:35 PM', 'done': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORDER TIMELINE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          ..._steps.asMap().entries.map((e) => _TimelineRow(
                step: e.value,
                isLast: e.key == _steps.length - 1,
                c: c,
              )),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Map<String, dynamic> step;
  final bool isLast;
  final DhavColors c;
  const _TimelineRow({required this.step, required this.isLast, required this.c});

  @override
  Widget build(BuildContext context) {
    final done = step['done'] as bool;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.green : c.iconBg,
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.circle_outlined,
                size: 14,
                color: done ? Colors.white : c.textHint,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: done ? AppColors.green.withValues(alpha: 0.4) : c.divider,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 28),
          child: Row(
            children: [
              Text(step['label'] as String,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: done ? c.textPrimary : c.textHint)),
              const SizedBox(width: 8),
              Text(step['time'] as String,
                  style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
            ],
          ),
        ),
      ],
    );
  }
}
