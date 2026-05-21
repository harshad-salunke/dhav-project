import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _Card {
  final String icon;
  final String title;
  final String subtitle;
  final String decorEmoji;
  final List<Color> gradient;
  const _Card(this.icon, this.title, this.subtitle, this.decorEmoji,
      this.gradient);
}

const _kCards = [
  _Card(
    '⚡',
    '10–20 min',
    'Express delivery to your door',
    '🛒',
    [Color(0xFFFF7A2F), Color(0xFFEA6A00)],
  ),
  _Card(
    '🏪',
    'Local kirana',
    'Trusted stores right near you',
    '🌾',
    [Color(0xFFE8600A), Color(0xFFD45000)],
  ),
  _Card(
    '🛵',
    'Live tracking',
    'Watch your order arrive in real time',
    '📍',
    [Color(0xFFD94F00), Color(0xFFC24400)],
  ),
];

class HeroBanner extends StatefulWidget {
  const HeroBanner({super.key});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController(viewportFraction: 1.0);
  int _page = 0;
  Timer? _timer;

  // Pulse glow on the icon circle
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Float on the decor emoji
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  // Entry animation (once on first build)
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);
    _entrySlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_page + 1) % _kCards.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Container(
          height: 116,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Stack(
            children: [
              // Cards
              PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _kCards.length,
                itemBuilder: (_, i) => AnimatedBuilder(
                  animation:
                      Listenable.merge([_pulseCtrl, _floatCtrl]),
                  builder: (_, __) =>
                      _CardTile(card: _kCards[i], pulse: _pulseAnim.value, float: _floatAnim.value),
                ),
              ),

              // Page dots
              Positioned(
                bottom: 9,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_kCards.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final _Card card;
  final double pulse;
  final double float;
  const _CardTile(
      {required this.card, required this.pulse, required this.float});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: card.gradient,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: card.gradient.first.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // Extra bottom padding so dots don't overlap text
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 26),
      child: Row(
        children: [
          // Icon with pulsing glow ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 58 + pulse * 10,
                height: 58 + pulse * 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: 0.06 + pulse * 0.06),
                ),
              ),
              // Inner circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: Center(
                  child: Text(card.icon,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Floating decor emoji
          Transform.translate(
            offset: Offset(0, float),
            child: Text(
              card.decorEmoji,
              style: TextStyle(
                fontSize: 34,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(2, 5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmering "speed lines" painter used by the scooter trail ────────────────

class SpeedLinesPainter extends CustomPainter {
  final double opacity;
  SpeedLinesPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final lines = [
      (0.0, 0.45, 0.35, 0.45),
      (0.0, 0.52, 0.22, 0.52),
      (0.0, 0.59, 0.28, 0.59),
    ];
    for (final l in lines) {
      canvas.drawLine(
        Offset(l.$1 * size.width, l.$2 * size.height),
        Offset(l.$3 * size.width, l.$4 * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SpeedLinesPainter old) => old.opacity != opacity;
}
