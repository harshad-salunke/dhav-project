import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';

class BroadcastingScreen extends StatefulWidget {
  const BroadcastingScreen({super.key});

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulse1;
  late AnimationController _pulse2;
  late AnimationController _pulse3;

  Timer? _pollTimer;
  String? _orderId;
  int _wave = 1;
  bool _timedOut = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pulse1 = _makePulse(0);
    _pulse2 = _makePulse(500);
    _pulse3 = _makePulse(1000);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _orderId = args?['order_id'] as String?;
    if (_orderId != null && _pollTimer == null) {
      _startPolling();
    }
  }

  AnimationController _makePulse(int delayMs) {
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) ctrl.repeat();
    });
    return ctrl;
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_checking || !mounted) return;
      _checking = true;
      final order =
          await context.read<OrderProvider>().fetchOrder(_orderId!);
      _checking = false;
      if (!mounted) return;
      if (order == null) return;

      // Wave updates
      if (order.status == 'broadcasting_wave_2') setState(() => _wave = 2);
      if (order.status == 'broadcasting_wave_3') setState(() => _wave = 3);

      if (order.status == 'accepted' || order.status == 'store_accepted') {
        _pollTimer?.cancel();
        Navigator.pushReplacementNamed(context, '/order-accepted',
            arguments: {'order': order});
      } else if (order.status == 'failed' || order.status == 'no_stores') {
        _pollTimer?.cancel();
        setState(() => _timedOut = true);
      }
    });

    // Timeout after 3 minutes
    Timer(const Duration(minutes: 3), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
        _pollTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pulse1.dispose();
    _pulse2.dispose();
    _pulse3.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5EC),
      body: SafeArea(
        child: _timedOut ? _buildTimedOut() : _buildBroadcasting(),
      ),
    );
  }

  Widget _buildBroadcasting() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Finding your nearest\nkirana store…',
            style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Wave $_wave of 3 • Radius: ${_wave}km',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textSecondary),
        ),
        const Spacer(),
        // Pulsing rings animation
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _PulseRing(controller: _pulse1, maxRadius: 130),
              _PulseRing(controller: _pulse2, maxRadius: 110),
              _PulseRing(controller: _pulse3, maxRadius: 90),
              // Center icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 36),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Wave indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final active = i < _wave;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.2),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          'Checking ${_wave == 1 ? 'stores within 1km' : _wave == 2 ? 'expanding to 2km' : 'expanding to 3km'}',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildTimedOut() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: AppColors.errorLight, shape: BoxShape.circle),
            child: const Icon(Icons.store_outlined,
                size: 50, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          Text(
            'No stores available\nright now',
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Sorry, no kirana stores are available in your area at this time. Please try again in a little while.',
            style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('Back to Home'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _timedOut = false;
                _wave = 1;
              });
              _startPolling();
            },
            child: Text('Try Again',
                style: GoogleFonts.inter(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double maxRadius;

  const _PulseRing(
      {required this.controller, required this.maxRadius});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final radius = maxRadius * t;
        final opacity = (1 - t) * 0.4;
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(opacity),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
