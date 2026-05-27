import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/services/first_launch_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/dhav_pune_scene.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Stage 1 — radial burst background
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgScale;

  // Stage 2 — logo box
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Stage 3 — DHAV letters
  late final AnimationController _lettersCtrl;

  // Stage 4 — tagline + badge
  late final AnimationController _taglineCtrl;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _badgeFade;
  late final Animation<Offset> _badgeSlide;

  // Ambient float loop for decorative items
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _bgScale = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _logoScale = Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));

    _lettersCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _taglineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _taglineFade = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn);
    _taglineSlide = Tween<Offset>(
            begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));
    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _taglineCtrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeIn)));
    _badgeSlide = Tween<Offset>(
            begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _taglineCtrl,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOut)));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 60));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    _lettersCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 260));
    _taglineCtrl.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.bootstrap();
    if (!mounted) return;
    if (auth.isLoggedIn) {
      // Pre-load notification history in background
      context.read<NotificationProvider>().loadFromBackend();
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    final isFirst = await FirstLaunchService.isFirstLaunch();
    if (!mounted) return;
    if (isFirst) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _logoCtrl.dispose();
    _lettersCtrl.dispose();
    _taglineCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF00251A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Pune scene — full screen background ──
            DhavPuneScene(
              borderRadius: 0,
              tealSky: true,
            ),

            // ── 2. Gradient overlay — dark teal top → transparent ──
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.42, 0.65, 1.0],
                  colors: [
                    const Color(0xFF00251A),
                    const Color(0xFF004D40).withValues(alpha: 0.94),
                    const Color(0xFF004D40).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // ── 3. Animated branding layer ──
            AnimatedBuilder(
              animation: Listenable.merge([
                _bgCtrl,
                _logoCtrl,
                _lettersCtrl,
                _taglineCtrl,
                _floatCtrl,
              ]),
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  _buildFloatingItems(size),
                  SafeArea(
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        _buildLogo(),
                        const SizedBox(height: 22),
                        _buildDhavLetters(),
                        const SizedBox(height: 10),
                        _buildTagline(),
                        const Spacer(flex: 5),
                        _buildBottomBadge(),
                        const SizedBox(height: 36),
                      ],
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

  Widget _buildFloatingItems(Size size) {
    final items = [
      ('🌾', 0.08, 0.12, 28.0),
      ('🛢️', 0.84, 0.18, 24.0),
      ('🥛', 0.10, 0.74, 26.0),
      ('🍚', 0.80, 0.70, 28.0),
      ('🧴', 0.88, 0.46, 22.0),
      ('🫙', 0.04, 0.48, 24.0),
      ('🧹', 0.78, 0.38, 20.0),
      ('👶', 0.14, 0.34, 20.0),
    ];
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: items.map((item) {
            final yOff =
                math.sin(_floatCtrl.value * math.pi) * 6 * (item.$1.hashCode % 3 == 0 ? -1 : 1);
            final opacity = (_bgScale.value * 0.55).clamp(0.0, 0.55);
            return Positioned(
              left: item.$2 * size.width,
              top: item.$3 * size.height + yOff,
              child: Opacity(
                opacity: opacity,
                child: Text(item.$1,
                    style: TextStyle(fontSize: item.$4)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Opacity(
      opacity: _logoFade.value,
      child: Transform.scale(
        scale: _logoScale.value,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF5EE), Colors.white],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.shopping_bag_rounded,
                color: AppColors.primary, size: 52),
          ),
        ),
      ),
    );
  }

  Widget _buildDhavLetters() {
    const letters = ['D', 'H', 'A', 'V'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: letters.asMap().entries.map((e) {
        final i = e.key;
        final letter = e.value;
        final startFrac = i * 0.16;
        final endFrac = (startFrac + 0.50).clamp(0.0, 1.0);
        final fadeEnd = (startFrac + 0.22).clamp(0.0, 1.0);

        final slideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _lettersCtrl,
            curve: Interval(startFrac, endFrac, curve: Curves.elasticOut),
          ),
        );
        final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _lettersCtrl,
            curve: Interval(startFrac, fadeEnd, curve: Curves.easeIn),
          ),
        );
        return Opacity(
          opacity: fadeAnim.value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - slideAnim.value)),
            child: Text(
              letter,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                height: 1.0,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTagline() {
    return SlideTransition(
      position: _taglineSlide,
      child: FadeTransition(
        opacity: _taglineFade,
        child: Text(
          'Apni Dukaan, Apke Darwaze Tak',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomBadge() {
    return SlideTransition(
      position: _badgeSlide,
      child: FadeTransition(
        opacity: _badgeFade,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.28), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                'HYPERLOCAL KIRANA DELIVERY • PUNE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
