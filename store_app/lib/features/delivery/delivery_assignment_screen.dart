import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

enum _DeliveryStep { headingToStore, atStore, pickedUp, delivering, delivered }

class DeliveryAssignmentScreen extends StatefulWidget {
  const DeliveryAssignmentScreen({super.key});

  @override
  State<DeliveryAssignmentScreen> createState() => _DeliveryAssignmentScreenState();
}

class _DeliveryAssignmentScreenState extends State<DeliveryAssignmentScreen> {
  _DeliveryStep _step = _DeliveryStep.headingToStore;

  void _advance() {
    HapticFeedback.mediumImpact();
    if (_step == _DeliveryStep.delivering) {
      Navigator.pushReplacementNamed(context, AppRoutes.deliveryCompletion);
      return;
    }
    setState(() => _step = _DeliveryStep.values[_step.index + 1]);
  }

  String get _ctaLabel {
    switch (_step) {
      case _DeliveryStep.headingToStore:
        return 'ARRIVED AT STORE';
      case _DeliveryStep.atStore:
        return 'ORDER PICKED UP';
      case _DeliveryStep.pickedUp:
        return 'START DELIVERY';
      case _DeliveryStep.delivering:
        return 'MARK AS DELIVERED';
      case _DeliveryStep.delivered:
        return 'DONE';
    }
  }

  Color get _ctaColor {
    if (_step == _DeliveryStep.delivering) return AppColors.green;
    return AppColors.primary;
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Active Delivery', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('OD-9929', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Step progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _buildStepBar(c),
          ),

          // Map preview
          _buildMapPreview(c),

          // Bottom sheet panel
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step instruction card
                    _buildStepInstruction(c),
                    const SizedBox(height: 16),

                    // Customer / Store info
                    if (_step.index >= _DeliveryStep.pickedUp.index)
                      _buildCustomerCard(c)
                    else
                      _buildStoreCard(c),

                    const SizedBox(height: 16),

                    // Items list
                    Text('ITEMS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    ..._items.map((item) => _ItemRow(item: item, c: c)),

                    const SizedBox(height: 16),

                    // Payment row
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_rounded, color: AppColors.green, size: 20),
                          const SizedBox(width: 10),
                          Text('Payment', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: c.greenBg, borderRadius: BorderRadius.circular(6)),
                            child: Text('Online · Paid', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Earnings row
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text('Your Earnings', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                          const Spacer(),
                          Text('₹55.00', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CTA button
                    GestureDetector(
                      onTap: _advance,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        decoration: BoxDecoration(
                          color: _ctaColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: _ctaColor.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_step == _DeliveryStep.delivering ? Icons.done_all_rounded : Icons.check_circle_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(_ctaLabel, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                    ),

                    // Open in Maps
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: c.divider, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text('Open in Google Maps', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBar(DhavColors c) {
    final steps = ['Store', 'Arrived', 'Picked Up', 'Delivering', 'Done'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final filled = _step.index > stepIdx;
            return Expanded(child: Container(height: 2, color: filled ? AppColors.primary : c.divider));
          }
          final stepIdx = i ~/ 2;
          final done = _step.index > stepIdx;
          final active = _step.index == stepIdx;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.primary : active ? AppColors.primary : c.divider,
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : active
                        ? Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), margin: const EdgeInsets.all(6))
                        : null,
              ),
              const SizedBox(height: 4),
              Text(steps[stepIdx], style: GoogleFonts.inter(fontSize: 9, fontWeight: active || done ? FontWeight.w700 : FontWeight.w400, color: active || done ? AppColors.primary : c.textHint)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMapPreview(DhavColors c) {
    return Container(
      height: 180,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2533), Color(0xFF2C3E50)],
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(painter: _MapGridPainter(), child: const SizedBox.expand()),
          ),
          // Store marker
          Positioned(
            left: 50,
            top: 50,
            child: _MapMarker(icon: Icons.store_rounded, color: AppColors.primary, label: 'Store'),
          ),
          // Customer marker
          Positioned(
            right: 50,
            bottom: 40,
            child: _MapMarker(icon: Icons.location_on_rounded, color: AppColors.green, label: 'Customer'),
          ),
          // ETA pill
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Text('5 MIN ETA', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepInstruction(DhavColors c) {
    final (icon, title, sub, color) = switch (_step) {
      _DeliveryStep.headingToStore => (Icons.store_rounded, 'Head to Raj Kirana Store', 'Shop 4, Laxmi Complex, Kothrud', AppColors.primary),
      _DeliveryStep.atStore => (Icons.inventory_2_rounded, "You're at the Store", 'Collect the items and verify the order', Colors.orange),
      _DeliveryStep.pickedUp => (Icons.delivery_dining_rounded, 'Order Picked Up!', 'Now head to the customer', AppColors.primary),
      _DeliveryStep.delivering => (Icons.location_on_rounded, 'Delivering to Customer', 'Flat 302, Laxmi Niwas, Kothrud', AppColors.green),
      _DeliveryStep.delivered => (Icons.check_circle_rounded, 'Order Delivered!', 'Great work!', AppColors.green),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(sub, style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(DhavColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Raj Kirana Store', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text('Shop 4, Laxmi Complex, Kothrud', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          _CallButton(c: c),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(DhavColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: c.divider, child: Icon(Icons.person_rounded, color: c.textHint, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Priya Sharma', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text('Flat 302, Laxmi Niwas, Kothrud', style: GoogleFonts.inter(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          _CallButton(c: c),
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _items = [
    {'name': 'Tata Salt 1kg', 'qty': 2},
    {'name': 'Amul Butter 100g', 'qty': 1},
    {'name': 'Fortune Refined Oil 1L', 'qty': 1},
  ];
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _CallButton extends StatelessWidget {
  final DhavColors c;
  const _CallButton({required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.inventory_2_outlined, color: c.textHint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item['name'] as String, style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(8)),
            child: Text('×${item['qty']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _MapMarker({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final streetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), streetPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), streetPaint);

    final routePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(66, 66)
      ..lineTo(66, size.height * 0.45)
      ..lineTo(size.width - 66, size.height * 0.45)
      ..lineTo(size.width - 66, size.height - 52);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
