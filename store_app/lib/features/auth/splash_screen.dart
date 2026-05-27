import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dhav_colors.dart';
import '../../main.dart' show fcmService;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    await auth.bootstrap();
    // Min splash duration for branding feel.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // COLD-START FROM NOTIFICATION OR NATIVE FORCE-LAUNCH: if the app was
    // launched by either a tapped notification OR a force-launch from
    // DhavMessagingService (Uber-style popup-over-other-apps), jump straight
    // to the incoming-order popup instead of the dashboard.
    var coldOrderId = await fcmService.getInitialNotificationOrderId();
    String? coldType;
    if (coldOrderId == null) {
      final pending = await fcmService.consumePendingNativeOrder();
      coldOrderId = pending?['order_id'];
      coldType = pending?['type'];
    }
    if (coldOrderId != null && mounted) {
      if (auth.status == AuthStatus.signedIn) {
        final user = auth.user!;
        // Choose route by the FCM message `type` when we have it (from the
        // native force-launch); otherwise fall back to user role.
        final isDelivery = coldType == 'delivery_assigned' ||
            (coldType == null && user.isDeliveryBoy);
        if (isDelivery && user.isDeliveryBoy) {
          fcmService.syncDeliveryTokenToBackend();
          fcmService.listenForDeliveryTokenRefresh();
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.deliveryIncomingAssignment,
            arguments: coldOrderId,
          );
          return;
        } else if (user.isStoreOwner) {
          fcmService.syncTokenToBackend();
          fcmService.listenForTokenRefresh();
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.incomingOrder,
            arguments: coldOrderId,
          );
          return;
        }
      }
    }

    // Re-check mounted after the two extra awaits above (lines 49 & 52).
    if (!mounted) return;

    if (auth.status == AuthStatus.signedIn) {
      final user = auth.user!;
      if (user.isStoreOwner) {
        fcmService.syncTokenToBackend();
        fcmService.listenForTokenRefresh();
        // Pre-load notification history in background
        context.read<StoreNotificationProvider>().loadFromBackend();
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.permissionGate,
          arguments: AppRoutes.dashboard,
        );
      } else if (user.isDeliveryBoy) {
        fcmService.syncDeliveryTokenToBackend();
        fcmService.listenForDeliveryTokenRefresh();
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.permissionGate,
          arguments: AppRoutes.deliveryHome,
        );
      } else {
        // Default role (customer / first-time user) — let them self-onboard a store.
        Navigator.pushReplacementNamed(context, AppRoutes.registerStore);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
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
      body: Stack(
        children: [
          Positioned.fill(
              child: CustomPaint(
                  painter: _DiagonalLinesPainter(c.diagonalLines))),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 32,
                              spreadRadius: 8),
                        ],
                      ),
                      child: const Icon(Icons.shopping_bag_rounded,
                          color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('DHAV',
                      style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: c.textPrimary,
                          letterSpacing: 6)),
                  const SizedBox(height: 8),
                  Text('STORE PARTNER APP',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.textHint,
                          letterSpacing: 3)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                'For Store Owners & Delivery Partners',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: c.textHint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalLinesPainter extends CustomPainter {
  final Color lineColor;
  const _DiagonalLinesPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalLinesPainter old) =>
      old.lineColor != lineColor;
}
