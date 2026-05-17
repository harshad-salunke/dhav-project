import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_routes.dart';

class DeliveryIncomingAssignmentScreen extends StatefulWidget {
  const DeliveryIncomingAssignmentScreen({super.key});

  @override
  State<DeliveryIncomingAssignmentScreen> createState() =>
      _DeliveryIncomingAssignmentScreenState();
}

class _DeliveryIncomingAssignmentScreenState
    extends State<DeliveryIncomingAssignmentScreen>
    with TickerProviderStateMixin {
  static const int _totalSeconds = 30;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.deliveryMissedOrder);
        }
      } else {
        if (mounted) setState(() => _secondsLeft--);
        if (_secondsLeft <= 10) HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / _totalSeconds;
    final isUrgent = _secondsLeft <= 10;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Stack(
        children: [
          // Dark overlay
          Positioned.fill(
            child: Container(color: const Color(0xFF0D1117).withValues(alpha: 0.85)),
          ),
          // Pulsing background ring
          Center(
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isUrgent ? AppColors.red : AppColors.primary)
                        .withValues(alpha: 0.15),
                    width: 40,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildAssignmentCard(context, progress, isUrgent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(BuildContext context, double progress, bool isUrgent) {
    final timerColor = isUrgent ? AppColors.red : (_secondsLeft <= 20 ? AppColors.primary : AppColors.green);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? AppColors.red : AppColors.primary).withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isUrgent ? AppColors.red : AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUrgent ? Icons.priority_high_rounded : Icons.delivery_dining_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isUrgent ? 'URGENT — RESPOND NOW!' : 'NEW DELIVERY ASSIGNMENT',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timer + earnings row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOU EARN',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹55.00',
                            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.green),
                          ),
                          Text(
                            '+ ₹0 COD bonus on delivery',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    // Circular countdown
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 6,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_secondsLeft',
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: timerColor),
                              ),
                              Text(
                                'sec',
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Route card — Store → Customer
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _RouteStop(
                        icon: Icons.store_rounded,
                        color: AppColors.primary,
                        label: 'PICKUP FROM',
                        name: 'Raj Kirana Store',
                        sub: 'Kothrud, Pune — 0.6 km away',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Column(
                          children: List.generate(
                            3,
                            (_) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(width: 2, height: 6, color: AppColors.border),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _RouteStop(
                        icon: Icons.location_on_rounded,
                        color: AppColors.green,
                        label: 'DELIVER TO',
                        name: 'Priya Sharma',
                        sub: 'Flat 302, Laxmi Niwas — 1.4 km',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info chips
                Row(
                  children: [
                    _InfoChip(icon: Icons.straighten_rounded, label: '2.0 km', sublabel: 'total route'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.access_time_rounded, label: '12 min', sublabel: 'est. time'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.shopping_bag_rounded, label: '3 items', sublabel: 'to carry'),
                  ],
                ),

                const SizedBox(height: 20),

                // Accept button
                GestureDetector(
                  onTap: () {
                    _timer?.cancel();
                    HapticFeedback.mediumImpact();
                    Navigator.pushReplacementNamed(context, AppRoutes.deliveryAssignment);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: AppColors.green.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'ACCEPT ASSIGNMENT',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Secondary row — Details + Decline
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDetailsSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'VIEW DETAILS',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _timer?.cancel();
                          Navigator.pushReplacementNamed(context, AppRoutes.deliveryMissedOrder);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.red, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'DECLINE',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Accepting improves your priority score',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryAssignmentDetailsSheet(
        onAccept: () {
          _timer?.cancel();
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, AppRoutes.deliveryAssignment);
        },
        onDecline: () {
          _timer?.cancel();
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, AppRoutes.deliveryMissedOrder);
        },
      ),
    );
  }
}

// ─── Route Stop widget ───────────────────────────────────────────────────────

class _RouteStop extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String name;
  final String sub;

  const _RouteStop({
    required this.icon,
    required this.color,
    required this.label,
    required this.name,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Info Chip ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _InfoChip({required this.icon, required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(sublabel, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

// ─── Details Bottom Sheet ────────────────────────────────────────────────────

class _DeliveryAssignmentDetailsSheet extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _DeliveryAssignmentDetailsSheet({required this.onAccept, required this.onDecline});

  static const List<Map<String, dynamic>> _items = [
    {'name': 'Tata Salt 1kg', 'qty': 2, 'price': '₹50'},
    {'name': 'Amul Butter 100g', 'qty': 1, 'price': '₹60'},
    {'name': 'Fortune Oil 1L', 'qty': 1, 'price': '₹175'},
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assignment #OD-9928', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        Text('3 items · 2.0 km total route', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text('₹55.00', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.green)),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 20),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  // Pickup point
                  _SheetSection(
                    title: 'PICKUP FROM',
                    child: _AddressCard(
                      icon: Icons.store_rounded,
                      iconColor: AppColors.primary,
                      title: 'Raj Kirana Store',
                      subtitle: 'Shop 4, Laxmi Complex, Kothrud, Pune 411038',
                      badge: '0.6 km',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Drop point
                  _SheetSection(
                    title: 'DELIVER TO',
                    child: _AddressCard(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.green,
                      title: 'Priya Sharma',
                      subtitle: 'Flat 302, Laxmi Niwas, Kothrud, Pune 411038',
                      badge: '1.4 km',
                      phone: '+91 98765 43210',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Items
                  _SheetSection(
                    title: 'ORDER ITEMS',
                    child: Column(
                      children: _items
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMedium, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['name'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                          Text('Qty: ${item['qty']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey)),
                                        ],
                                      ),
                                    ),
                                    Text(item['price'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Earnings summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _EarnRow(label: 'Base delivery pay', value: '₹40.00'),
                        _EarnRow(label: 'Distance bonus (2 km)', value: '₹15.00'),
                        const Divider(color: AppColors.border, height: 18),
                        _EarnRow(label: 'Total earnings', value: '₹55.00', bold: true, color: AppColors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Payment type
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text('Payment mode:', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
                        const Spacer(),
                        Text('Online (Paid)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: onAccept,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                            child: Center(
                              child: Text('ACCEPT', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onDecline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.red, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('DECLINE', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.red, letterSpacing: 1)),
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

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final String? phone;

  const _AddressCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  Text(phone!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: iconColor)),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _EarnRow({required this.label, required this.value, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: bold ? c : AppColors.textMedium)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}
