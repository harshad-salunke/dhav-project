import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/catalog_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show fcmService;

class BroadcastingScreen extends StatefulWidget {
  const BroadcastingScreen({super.key});

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  Timer? _waveTimer;
  Timer? _timeoutTimer;
  StreamSubscription<String>? _fcmSub;
  String? _orderId;
  int _wave = 1;
  bool _timedOut = false;
  bool _checking = false;
  DateTime? _startedAt;

  late final AnimationController _pulse1;
  late final AnimationController _pulse2;
  late final AnimationController _pulse3;

  @override
  void initState() {
    super.initState();
    _pulse1 = _makePulse(0);
    _pulse2 = _makePulse(600);
    _pulse3 = _makePulse(1200);
  }

  AnimationController _makePulse(int delayMs) {
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) ctrl.repeat();
    });
    return ctrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _orderId = args?['order_id'] as String?;
    if (_orderId != null && _pollTimer == null) {
      _startedAt = DateTime.now();
      _startPolling();
      _startWaveProgression();
      // React the instant the store-accepted push arrives (much faster than the
      // fallback poll). The poll below stays as a safety net for missed pushes.
      _fcmSub ??= fcmService.orderUpdates.listen((orderId) {
        if (orderId == _orderId) _checkOrder();
      });
    }
  }

  void _startWaveProgression() {
    // Fallback wave progression in case backend status updates are not received.
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      int target = 1;
      if (elapsed >= 80) {
        target = 3;
      } else if (elapsed >= 35) {
        target = 2;
      }
      if (target != _wave) {
        setState(() => _wave = target);
      }
    });
  }

  void _startPolling() {
    // Fallback poll (8s). The FCM stream handles the fast path; this only
    // catches a status change if a push was delayed or missed.
    _pollTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _checkOrder());

    _timeoutTimer = Timer(const Duration(minutes: 3), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
        _stopTimers();
      }
    });
  }

  /// Fetch the order and act on its status. Called by both the FCM push
  /// (instant) and the fallback poll. Guarded so the two never overlap.
  Future<void> _checkOrder() async {
    if (_checking || !mounted || _orderId == null) return;
    _checking = true;
    final order = await context.read<OrderProvider>().fetchOrder(_orderId!);
    _checking = false;
    if (!mounted || order == null) return;

    if (order.status == 'broadcasting_wave_2' && _wave < 2) {
      setState(() => _wave = 2);
    }
    if (order.status == 'broadcasting_wave_3' && _wave < 3) {
      setState(() => _wave = 3);
    }

    if (order.status == 'accepted' || order.status == 'store_accepted') {
      _stopTimers();
      Navigator.pushReplacementNamed(context, '/order-accepted',
          arguments: {'order': order});
    } else if (order.status == 'failed' || order.status == 'no_stores') {
      _stopTimers();
      setState(() => _timedOut = true);
    }
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _waveTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  @override
  void dispose() {
    _pulse1.dispose();
    _pulse2.dispose();
    _pulse3.dispose();
    _fcmSub?.cancel();
    _stopTimers();
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
    final catalog = context.watch<CatalogProvider>();
    final shopNames = catalog.allNearbyStores
        .map((s) => (s['name'] as String?)?.trim())
        .where((n) => n != null && n.isNotEmpty)
        .cast<String>()
        .toList();

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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            'Wave $_wave of 3 • Radius: ${_wave}km',
            key: ValueKey(_wave),
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        const Spacer(),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = min(constraints.maxWidth, 360.0);
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _PulseRing(controller: _pulse1, maxRadius: size / 2 - 10),
                  _PulseRing(controller: _pulse2, maxRadius: size / 2 - 40),
                  _PulseRing(controller: _pulse3, maxRadius: size / 2 - 70),
                  _ShopPopField(
                    width: size,
                    height: size,
                    shopNames: shopNames,
                  ),
                  // Center pin
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 40),
                  ),
                ],
              ),
            );
          },
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final active = i < _wave;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: active ? 22 : 10,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
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
                _startedAt = DateTime.now();
              });
              _startPolling();
              _startWaveProgression();
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

// ─── Shop pop field ──────────────────────────────────────────────────────────
// Spawns shop-icon badges at random positions around the center pin.
// Each badge fades in, holds, then fades out and respawns elsewhere with
// (possibly) a different shop name.

class _ShopPopField extends StatefulWidget {
  final double width;
  final double height;
  final List<String> shopNames;

  const _ShopPopField({
    required this.width,
    required this.height,
    required this.shopNames,
  });

  @override
  State<_ShopPopField> createState() => _ShopPopFieldState();
}

class _ShopPopFieldState extends State<_ShopPopField>
    with TickerProviderStateMixin {
  static const int _slotCount = 2;
  final _rand = Random();
  late final List<_PopSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.generate(_slotCount, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2400 + _rand.nextInt(900)),
      );
      final slot = _PopSlot(
        controller: ctrl,
        name: _pickName(),
        position: _randomPosition(),
      );
      ctrl.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          slot.position = _randomPosition();
          slot.name = _pickName();
          ctrl.reset();
          Future.delayed(
              Duration(milliseconds: 150 + _rand.nextInt(900)), () {
            if (mounted) ctrl.forward();
          });
          setState(() {});
        }
      });
      Future.delayed(Duration(milliseconds: 180 * i + _rand.nextInt(400)), () {
        if (mounted) ctrl.forward();
      });
      return slot;
    });
  }

  @override
  void didUpdateWidget(covariant _ShopPopField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh names when nearby shop list arrives later.
    if (oldWidget.shopNames.length != widget.shopNames.length) {
      for (final s in _slots) {
        if (s.controller.status != AnimationStatus.forward) {
          s.name = _pickName();
        }
      }
    }
  }

  String _pickName() {
    if (widget.shopNames.isEmpty) {
      const fallbacks = [
        'Kirana Store',
        'Mahesh Stores',
        'Sai Kirana',
        'Ganesh Stores',
        'Anand General',
      ];
      return fallbacks[_rand.nextInt(fallbacks.length)];
    }
    return widget.shopNames[_rand.nextInt(widget.shopNames.length)];
  }

  Offset _randomPosition() {
    // Badge approx 130 wide × 48 tall — keep it inside the box and
    // away from the center 95px-radius zone where the pin/rings sit.
    const badgeW = 130.0;
    const badgeH = 48.0;
    final cx = widget.width / 2;
    final cy = widget.height / 2;
    for (int i = 0; i < 30; i++) {
      final x = _rand.nextDouble() * (widget.width - badgeW);
      final y = _rand.nextDouble() * (widget.height - badgeH);
      final centerX = x + badgeW / 2;
      final centerY = y + badgeH / 2;
      final dist =
          sqrt(pow(centerX - cx, 2) + pow(centerY - cy, 2)).toDouble();
      if (dist > 95) return Offset(x, y);
    }
    return Offset(_rand.nextDouble() * (widget.width - badgeW),
        _rand.nextDouble() * (widget.height - badgeH));
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final slot in _slots)
            Positioned(
              left: slot.position.dx,
              top: slot.position.dy,
              child: AnimatedBuilder(
                animation: slot.controller,
                builder: (context, _) {
                  final t = slot.controller.value;
                  double opacity;
                  double scale;
                  if (t < 0.20) {
                    final p = t / 0.20;
                    opacity = p;
                    scale = 0.5 + 0.5 * Curves.easeOutBack.transform(p);
                  } else if (t < 0.78) {
                    opacity = 1.0;
                    scale = 1.0;
                  } else {
                    final p = (t - 0.78) / 0.22;
                    opacity = (1.0 - p).clamp(0.0, 1.0);
                    scale = 1.0 + 0.08 * p;
                  }
                  return IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: _ShopBadge(name: slot.name),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PopSlot {
  final AnimationController controller;
  String name;
  Offset position;
  _PopSlot({
    required this.controller,
    required this.name,
    required this.position,
  });
}

class _ShopBadge extends StatelessWidget {
  final String name;
  const _ShopBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
            color: AppColors.primary.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                color: AppColors.primary, size: 15),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulse ring (concentric expanding circles) ───────────────────────────────

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double maxRadius;

  const _PulseRing({required this.controller, required this.maxRadius});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final radius = maxRadius * t;
          final opacity = ((1 - t) * 0.45).clamp(0.0, 1.0);
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
      ),
    );
  }
}
