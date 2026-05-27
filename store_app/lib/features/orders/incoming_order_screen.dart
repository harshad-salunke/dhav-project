import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show fcmService;

// ── Screen 1: Quick-Accept Popup ─────────────────────────────────────────────

class IncomingOrderScreen extends StatefulWidget {
  final String? orderId;
  const IncomingOrderScreen({super.key, this.orderId});

  @override
  State<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends State<IncomingOrderScreen> {
  static const _totalSeconds = 45;

  late final ValueNotifier<int> _timerNotifier;
  Timer? _timer;
  Order? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timerNotifier = ValueNotifier(_totalSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerNotifier.value <= 0) {
        t.cancel();
        _autoReject();
      } else {
        _timerNotifier.value--;
      }
    });
    // Ring continuously like an incoming phone call. The notification's
    // built-in sound only plays for ~1s before the activity launch
    // dismisses it, so we restart it here on loop until the user responds.
    fcmService.startRingtone();
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
    _timerNotifier.dispose();
    fcmService.stopRingtone();
    super.dispose();
  }

  void _autoReject() {
    if (!mounted) return;
    _exitToDashboard();
  }

  /// Behave like declining a phone call. If this popup was opened from
  /// within the app (dashboard already on the stack), pop back to it.
  /// If it was force-launched over another app (no route underneath),
  /// close the activity so the user returns to whatever they were doing
  /// — WhatsApp, home screen, lock screen, etc.
  void _exitToDashboard() {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      // Force-launch case — only this popup is in the stack. Closing the
      // activity returns control to the previous task/launcher.
      SystemNavigator.pop();
      return;
    }
    navigator.popUntil(
      (route) => route.settings.name == AppRoutes.dashboard || route.isFirst,
    );
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
    if (mounted) _exitToDashboard();
  }

  void _openDetails() {
    if (_order == null) return;
    Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingOrderDetailsScreen(
          order: _order!,
          timerNotifier: _timerNotifier,
        ),
      ),
    ).then((result) {
      if (result == 'accept') _accept();
      if (result == 'reject') _reject();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xCC1A1F2E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : _error != null
                  ? _ErrorCard(message: _error!, onDismiss: () => Navigator.pop(context))
                  : _order == null
                      ? _ErrorCard(
                          message: 'Order not available',
                          onDismiss: () => Navigator.pop(context))
                      : _QuickAcceptCard(
                          order: _order!,
                          timerNotifier: _timerNotifier,
                          totalSeconds: _totalSeconds,
                          busy: _busy,
                          onAccept: _accept,
                          onReject: _reject,
                          onViewDetails: _openDetails,
                        ),
        ),
      ),
    );
  }
}

// ── Quick Accept Card (Screen 1 content) ──────────────────────────────────────

class _QuickAcceptCard extends StatelessWidget {
  final Order order;
  final ValueNotifier<int> timerNotifier;
  final int totalSeconds;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onViewDetails;

  const _QuickAcceptCard({
    required this.order,
    required this.timerNotifier,
    required this.totalSeconds,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Chips row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'ITEMS',
                  value: '${order.itemCount} items',
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.near_me_rounded,
                  label: 'DISTANCE',
                  value: '${order.broadcastRadiusKm.toStringAsFixed(1)} km',
                ),
              ],
            ),
          ),

          // ── Map image ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/order_map.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2535),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.map_rounded,
                            color: Colors.white38, size: 48),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${order.estimatedDeliveryMinutes} MIN EST.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Earning + Timer row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POTENTIAL EARNING',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${order.totalCustomerAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: timerNotifier,
                  builder: (_, secs, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'AUTO-REJECT IN',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${secs}s',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Progress bar ──────────────────────────────────────────────────
          ValueListenableBuilder<int>(
            valueListenable: timerNotifier,
            builder: (_, secs, __) {
              final progress = secs / totalSeconds;
              final color = progress > 0.5
                  ? AppColors.green
                  : progress > 0.25
                      ? AppColors.primary
                      : AppColors.red;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Buttons ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // QUICK ACCEPT
                GestureDetector(
                  onTap: busy ? null : onAccept,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        else
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'QUICK ACCEPT',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // VIEW DETAILS + REJECT
                Row(
                  children: [
                    Expanded(
                      child: _OutlineBtn(
                        label: 'VIEW DETAILS',
                        color: AppColors.primary,
                        onTap: onViewDetails,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OutlineBtn(
                        label: 'REJECT',
                        color: AppColors.red,
                        onTap: onReject,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Text(
            'Accepting this order increases your priority score.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Screen 2: Incoming Order Details ─────────────────────────────────────────

class IncomingOrderDetailsScreen extends StatefulWidget {
  final Order order;
  final ValueNotifier<int> timerNotifier;

  const IncomingOrderDetailsScreen({
    super.key,
    required this.order,
    required this.timerNotifier,
  });

  @override
  State<IncomingOrderDetailsScreen> createState() =>
      _IncomingOrderDetailsScreenState();
}

class _IncomingOrderDetailsScreenState
    extends State<IncomingOrderDetailsScreen> {
  // Details sheet never makes async calls; always non-busy.
  final bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final storeName = context.read<StoreProvider>().store?.shopName.toUpperCase()
        ?? 'KIRANA PARTNER';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top app bar ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white12,
                    child: const Icon(Icons.store_rounded,
                        color: Colors.white70, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      storeName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Icon(Icons.notifications_outlined,
                      color: Colors.white70, size: 24),
                ],
              ),
            ),

            // ── Timer pill ───────────────────────────────────────────────
            ValueListenableBuilder<int>(
              valueListenable: widget.timerNotifier,
              builder: (_, secs, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$secs sec',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── White content card ───────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // NEW ORDER REQUEST + FAST DELIVERY badge
                            Row(
                              children: [
                                Text(
                                  'NEW ORDER REQUEST',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black45,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'FAST DELIVERY',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Order # and amount
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Order #${order.orderId.substring(0, 8).toUpperCase()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.black12, width: 1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹ ${order.totalCustomerAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Map thumbnail + address
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/images/order_map.png',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A2535),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.map_rounded,
                                          color: Colors.white38, size: 32),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.near_me_rounded,
                                              color: AppColors.primary,
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${order.broadcastRadiusKm.toStringAsFixed(1)} km away',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Drop-off: ${order.customerAddress.oneLine}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            Divider(color: Colors.black.withValues(alpha: 0.08), height: 1),
                            const SizedBox(height: 16),

                            // ORDER ITEMS header
                            Text(
                              'ORDER ITEMS (${order.itemCount})',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black45,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Items list
                            ...order.items.map((item) => _ItemRow(item: item)),

                            const SizedBox(height: 8),
                            Divider(color: Colors.black.withValues(alpha: 0.08), height: 1),
                            const SizedBox(height: 12),

                            // Payment method
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.payments_outlined,
                                        color: Colors.black54,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    order.paymentMethod == 'cod'
                                        ? 'Cash on Delivery'
                                        : order.paymentMethod.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '₹ ${order.totalCustomerAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // ── Sticky bottom buttons ──────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            top: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _OutlineBtn(
                              label: 'REJECT',
                              color: AppColors.red,
                              onTap: _busy
                                  ? () {}
                                  : () => Navigator.pop(context, 'reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: _busy
                                  ? null
                                  : () => Navigator.pop(context, 'accept'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_busy)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    else
                                      const Icon(Icons.flash_on_rounded,
                                          color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ACCEPT',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
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
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Qty: ${item.quantity.toInt()} ${item.unit}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          Text(
            '₹ ${item.totalPrice.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorCard({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 36),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.black87)),
          const SizedBox(height: 12),
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      ),
    );
  }
}
