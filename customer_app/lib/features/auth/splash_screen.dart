import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/first_launch_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/lottie_utils.dart';

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

  // Stage 4 — scooter track
  late final AnimationController _scooterCtrl;
  late final Animation<double> _scooterX;

  // Stage 5 — tagline + badge
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

    _scooterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _scooterX = Tween<double>(begin: -0.25, end: 1.25).animate(
        CurvedAnimation(parent: _scooterCtrl, curve: Curves.easeInOut));

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
    _scooterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 220));
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
    _scooterCtrl.dispose();
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
        backgroundColor: AppColors.primaryDark,
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _bgCtrl,
            _logoCtrl,
            _lettersCtrl,
            _scooterCtrl,
            _taglineCtrl,
            _floatCtrl,
          ]),
          builder: (context, _) => Stack(
            children: [
              // Radial burst background
              Positioned.fill(
                child: CustomPaint(
                  painter: _RadialBurstPainter(progress: _bgScale.value),
                ),
              ),

              // Floating kirana items (ambient)
              _buildFloatingItems(size),

              // Main content
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    _buildLogo(),
                    const SizedBox(height: 28),
                    _buildDhavLetters(),
                    const SizedBox(height: 6),
                    _buildScooterTrack(size),
                    const SizedBox(height: 20),
                    _buildTagline(),
                    const Spacer(flex: 3),
                    _buildBottomBadge(),
                    const SizedBox(height: 44),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildScooterTrack(Size size) {
    return SizedBox(
      height: 56,
      width: size.width,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Dashed road line
          Positioned(
            left: 40,
            right: 40,
            top: 48,
            child: Row(
              children: List.generate(
                8,
                (i) => Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
              ),
            ),
          ),
          // Lottie delivery animation moving left → right
          Align(
            alignment: Alignment(_scooterX.value * 2 - 1, 0),
            child: SizedBox(
              width: 90,
              height: 56,
              child: Lottie.asset(
                'assets/images/delivery_riding.lottie',
                decoder: decodeDotLottie,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
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
            color: Colors.white.withOpacity(0.88),
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
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: Colors.white.withOpacity(0.28), width: 1),
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
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background radial burst ───────────────────────────────────────────────────

class _RadialBurstPainter extends CustomPainter {
  final double progress;
  const _RadialBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.40);
    final maxRadius = size.longestSide * 1.2;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: const [
          Color(0xFF80CBC4),
          Color(0xFF26A69A),
          Color(0xFF00897B),
          Color(0xFF00695C),
        ],
        stops: const [0.0, 0.25, 0.6, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius * progress, paint);
  }

  @override
  bool shouldRepaint(_RadialBurstPainter old) =>
      old.progress != progress;
}
