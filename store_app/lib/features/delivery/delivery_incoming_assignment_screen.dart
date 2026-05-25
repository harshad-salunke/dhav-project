import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show fcmService;

class DeliveryIncomingAssignmentScreen extends StatefulWidget {
  final String? orderId;
  const DeliveryIncomingAssignmentScreen({super.key, this.orderId});

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

  Order? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    fcmService.startRingtone();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrder());
  }

  Future<void> _loadOrder() async {
    final id = widget.orderId;
    if (id != null) {
      try {
        final order = await context.read<OrderProvider>().loadOrder(id);
        if (mounted) setState(() => _order = order);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) _exitOrPop();
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
    fcmService.stopRingtone();
    super.dispose();
  }

  void _accept() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.deliveryAssignment,
      arguments: widget.orderId,
    );
  }

  void _decline() {
    _timer?.cancel();
    _exitOrPop();
  }

  /// Phone-call-style dismiss. If the screen was force-launched over
  /// another app (only route in the stack), close the activity and return
  /// the user to whatever they were doing. Otherwise, jump back to the
  /// delivery home screen.
  void _exitOrPop() {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      SystemNavigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRoutes.deliveryHome);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / _totalSeconds;
    final isUrgent = _secondsLeft <= 10;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
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
              child: _loading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildCard(context, progress, isUrgent),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, double progress, bool isUrgent) {
    final timerColor = isUrgent
        ? AppColors.red
        : (_secondsLeft <= 20 ? AppColors.primary : AppColors.green);

    final order = _order;
    final itemCount = order?.itemCount ?? 0;
    final earnings = order?.deliveryFee ?? 0.0;
    final deliverTo = order?.customerAddress.area ?? '—';
    final fullAddress = order?.customerAddress.oneLine ?? '—';
    final payMethod = order?.paymentMethod.toUpperCase() ?? 'COD';
    final shortId = order != null
        ? order.orderId.substring(0, 8).toUpperCase()
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? AppColors.red : AppColors.primary)
                .withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header banner ───────────────────────────────────────────
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
                  isUrgent
                      ? Icons.priority_high_rounded
                      : Icons.delivery_dining_rounded,
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
                // ── Earnings + Countdown ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOU EARN',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGrey,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(
                            '₹${earnings.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.green),
                          ),
                          Text(
                            payMethod == 'COD'
                                ? '+ COD collection on delivery'
                                : 'Online — already paid',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.textGrey),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(timerColor),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$_secondsLeft',
                                  style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: timerColor)),
                              Text('sec',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.textGrey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Destination card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _RouteStop(
                    icon: Icons.location_on_rounded,
                    color: AppColors.green,
                    label: 'DELIVER TO',
                    name: deliverTo,
                    sub: fullAddress,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Info chips ───────────────────────────────────────────
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.shopping_bag_rounded,
                        label: '$itemCount',
                        sublabel: 'items'),
                    const SizedBox(width: 10),
                    _InfoChip(
                        icon: Icons.payments_rounded,
                        label: payMethod,
                        sublabel: 'payment'),
                    const SizedBox(width: 10),
                    _InfoChip(
                        icon: Icons.tag_rounded,
                        label: '#$shortId',
                        sublabel: 'order'),
                  ],
                ),

                const SizedBox(height: 20),

                // ── ACCEPT button ────────────────────────────────────────
                GestureDetector(
                  onTap: _accept,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text('ACCEPT ASSIGNMENT',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── View Details + Decline row ───────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDetailsSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('VIEW DETAILS',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _decline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.red, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('DECLINE',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.red,
                                    letterSpacing: 1)),
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
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textGrey),
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
      builder: (_) => _DetailsSheet(
        order: _order,
        onAccept: () {
          Navigator.pop(context);
          _accept();
        },
        onDecline: () {
          Navigator.pop(context);
          _decline();
        },
      ),
    );
  }
}

// ─── Route Stop widget ─────────────────────────────────────────────────────────

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
              color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              Text(sub,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textGrey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Info Chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _InfoChip(
      {required this.icon, required this.label, required this.sublabel});

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
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
                overflow: TextOverflow.ellipsis),
            Text(sublabel,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

// ─── Details Bottom Sheet ──────────────────────────────────────────────────────

class _DetailsSheet extends StatelessWidget {
  final Order? order;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _DetailsSheet({
    required this.order,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    final shortId = o != null ? o.orderId.substring(0, 8).toUpperCase() : '—';
    final itemCount = o?.itemCount ?? 0;
    final earnings = o?.deliveryFee ?? 0.0;
    final payMethod = o?.paymentMethod.toUpperCase() ?? 'COD';

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
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
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
                        Text('Assignment #$shortId',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark)),
                        Text('$itemCount items',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text('₹${earnings.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green)),
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
                  // Deliver to
                  if (o != null) ...[
                    _SheetSection(
                      title: 'DELIVER TO',
                      child: _AddressCard(
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.green,
                        title: o.customerAddress.area,
                        subtitle: o.customerAddress.oneLine,
                        badge: o.estimatedDeliveryMinutes > 0
                            ? '~${o.estimatedDeliveryMinutes} min'
                            : 'Est.',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items
                    _SheetSection(
                      title: 'ORDER ITEMS',
                      child: Column(
                        children: o.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: AppColors.surfaceGrey,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.textMedium,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.itemName,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark)),
                                      Text('Qty: ${item.quantity.toInt()}',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                                Text('₹${item.totalPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Earnings breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _EarnRow(
                            label: 'Delivery fee', value: '₹${earnings.toStringAsFixed(2)}'),
                        _EarnRow(
                            label: 'Payment mode', value: payMethod),
                        const Divider(color: AppColors.border, height: 18),
                        _EarnRow(
                            label: 'You earn',
                            value: '₹${earnings.toStringAsFixed(2)}',
                            bold: true,
                            color: AppColors.green),
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
                            decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(12)),
                            child: Center(
                              child: Text('ACCEPT',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onDecline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.red, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('DECLINE',
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

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textGrey,
                letterSpacing: 1.5)),
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
      decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textGrey)),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  Text(phone!,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(badge,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: iconColor)),
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

  const _EarnRow(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: bold ? c : AppColors.textMedium)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600,
                  color: c)),
        ],
      ),
    );
  }
}
