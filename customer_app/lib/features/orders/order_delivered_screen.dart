import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/theme/app_colors.dart';
import 'rate_order_sheet.dart';

class OrderDeliveredScreen extends StatefulWidget {
  const OrderDeliveredScreen({super.key});

  @override
  State<OrderDeliveredScreen> createState() => _OrderDeliveredScreenState();
}

class _OrderDeliveredScreenState extends State<OrderDeliveredScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiCtrl;
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;

  CustomerOrder? _order;
  bool _summaryExpanded = false;
  bool _hasRated = false;

  // Confetti particles — seeded so layout is deterministic
  static final _particles = List.generate(48, (i) {
    final rng = math.Random(i * 31 + 7);
    return _Particle(
      x: rng.nextDouble(),
      startY: -0.05 - rng.nextDouble() * 0.25,
      speed: 0.7 + rng.nextDouble() * 0.7,
      rotSpeed: 1.0 + rng.nextDouble() * 3.0,
      size: 7.0 + rng.nextDouble() * 9.0,
      wide: rng.nextBool(),
      color: _confettiColors[i % _confettiColors.length],
    );
  });

  static const _confettiColors = [
    Color(0xFFF97316),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
  ];

  @override
  void initState() {
    super.initState();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkScale = CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.elasticOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiCtrl.forward();
      _checkCtrl.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _order ??= ModalRoute.of(context)?.settings.arguments as CustomerOrder?;
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _openRating() async {
    if (_order == null) return;
    final rated = await RateOrderSheet.show(
      context,
      orderId: _order!.orderId,
      storeName: _order?.storeName,
    );
    if (rated) setState(() => _hasRated = true);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Confetti layer ──
            AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(
                    _confettiCtrl.value, _particles),
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                ),
              ),
            ),

            // ── Main content ──
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  // ── Checkmark circle (scale-in) ──
                  ScaleTransition(
                    scale: _checkScale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: AppColors.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 60,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Heading ──
                  Text(
                    'Order Delivered!',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (order != null)
                    Text(
                      'Order Total: ₹${order.grandTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textSecondary),
                    ),
                  if (order?.storeName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'from ${order!.storeName}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 28),

                  // ── Order summary card ──
                  if (order != null) _buildSummaryCard(order),
                  const SizedBox(height: 20),

                  // ── Rate button ──
                  if (!_hasRated)
                    _RatePromptCard(onTap: _openRating)
                  else
                    _RatedBadge(),
                  const SizedBox(height: 20),

                  // ── Order Again ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamedAndRemoveUntil(
                              context, AppRoutes.home, (_) => false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Order Again',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Back to Home ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamedAndRemoveUntil(
                              context, AppRoutes.home, (_) => false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Back to Home',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(CustomerOrder order) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header (tap to toggle)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Order Summary',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _summaryExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Expandable items list
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _summaryExpanded
                ? Column(
                    children: [
                      const Divider(height: 1, color: AppColors.divider),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  '×${item.quantity}',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                                if (item.price != null) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    '₹${(item.price! * item.quantity).toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                ],
                              ],
                            ),
                          )),
                      const Divider(height: 1, color: AppColors.divider),
                      // Totals
                      _SummaryRow(
                          label: 'Items Total',
                          value:
                              '₹${(order.productTotal ?? 0).toStringAsFixed(0)}'),
                      _SummaryRow(
                          label: 'Delivery Fee',
                          value:
                              '₹${(order.deliveryFee ?? 0).toStringAsFixed(0)}'),
                      const Divider(height: 1, color: AppColors.divider),
                      _SummaryRow(
                        label: 'Total Paid',
                        value: '₹${order.grandTotal.toStringAsFixed(0)}',
                        bold: true,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small sub-widgets
// ─────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color:
                      bold ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _RatePromptCard extends StatelessWidget {
  final VoidCallback onTap;
  const _RatePromptCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate this delivery',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'How was your experience?',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _RatedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Text(
            'Thanks for your rating!',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Confetti particles
// ─────────────────────────────────────────────

class _Particle {
  final double x;
  final double startY;
  final double speed;
  final double rotSpeed;
  final double size;
  final bool wide;
  final Color color;

  const _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.rotSpeed,
    required this.size,
    required this.wide,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ConfettiPainter(this.progress, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final y = (p.startY + progress * p.speed) * size.height;
      if (y > size.height + 20 || y < -20) continue;

      final opacity = progress < 0.75
          ? 1.0
          : 1.0 - ((progress - 0.75) / 0.25);
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      final x = p.x * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.rotSpeed * math.pi * 4);

      final w = p.size;
      final h = p.wide ? p.size * 0.45 : p.size * 0.9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
