import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../core/constants/app_routes.dart';

class DeliveryCompletionScreen extends StatefulWidget {
  const DeliveryCompletionScreen({super.key});

  @override
  State<DeliveryCompletionScreen> createState() => _DeliveryCompletionScreenState();
}

class _DeliveryCompletionScreenState extends State<DeliveryCompletionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Success animation circle
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 3),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 64),
                ),
              ),

              const SizedBox(height: 28),

              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      'Delivered!',
                      style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: c.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order #OD-9928 has been delivered\nsuccessfully to Priya Sharma.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 15, color: c.textHint, height: 1.6),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Earning card
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.green, Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text('YOU EARNED', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text('₹55.00', style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _EarnChip(label: 'Distance', value: '2.0 km'),
                          _EarnChip(label: 'Time', value: '14 min'),
                          _EarnChip(label: 'Rating', value: '5.0 ★'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Today's summary
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TODAY'S SUMMARY", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 1.5)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SummaryItem(label: 'Deliveries', value: '9', icon: Icons.local_shipping_rounded, color: AppColors.primary),
                          _SummaryItem(label: 'Earned', value: '₹535', icon: Icons.account_balance_wallet_rounded, color: AppColors.green),
                          _SummaryItem(label: 'Distance', value: '14 km', icon: Icons.route_rounded, color: Colors.blue),
                          _SummaryItem(label: 'Rating', value: '4.8', icon: Icons.star_rounded, color: Colors.amber),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Actions
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.deliveryHome, (_) => false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                        child: Center(
                          child: Text('BACK TO HOME', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryHistory),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: c.divider, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('VIEW DELIVERY HISTORY', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarnChip extends StatelessWidget {
  final String label;
  final String value;
  const _EarnChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: c.textHint)),
      ],
    );
  }
}
