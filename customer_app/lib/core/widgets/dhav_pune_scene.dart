import 'dart:math';
import 'package:flutter/material.dart';

/// DHAV Pune parallax scene.
/// Layers back→front: sky · sun · clouds · distant hills ·
/// far buildings · Dagdusheth + FC Road + Shaniwar Wada ·
/// road + dashes · DHAV scooter character.
class DhavPuneScene extends StatefulWidget {
  final double borderRadius;
  final bool tealSky;

  const DhavPuneScene({
    super.key,
    this.borderRadius = 18.0,
    this.tealSky = false,
  });

  @override
  State<DhavPuneScene> createState() => _DhavPuneSceneState();
}

class _DhavPuneSceneState extends State<DhavPuneScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the full physical screen size so the painter always draws edge-to-edge.
    // CustomPaint clamps this to the actual widget bounds via constraints.constrain(),
    // so there is no overflow — but we never under-paint.
    final screenSize = MediaQuery.of(context).size;

    Widget painter = AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: screenSize,
        painter: _PuneScenePainter(_ctrl.value, widget.tealSky),
        isComplex: true,
        child: const SizedBox.expand(),
      ),
    );

    if (widget.borderRadius > 0) {
      painter = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: painter,
      );
    }

    return RepaintBoundary(child: painter);
  }
}

class _PuneScenePainter extends CustomPainter {
  final double t;
  final bool tealSky;
  _PuneScenePainter(this.t, this.tealSky);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.67;
    final s = (h / 200.0).clamp(0.2, 1.8);

    _drawSky(canvas, w, h, horizon, tealSky);
    _drawSun(canvas, w, horizon, s);
    _drawClouds(canvas, w, horizon, s);
    _drawDistantHills(canvas, w, horizon);
    _drawBuildingLayers(canvas, w, horizon, s);
    _drawRoad(canvas, w, h, horizon, s);
    _drawScooter(canvas, w, h, horizon, s);
  }

  // ── SKY ──────────────────────────────────────────────────────────────────────

  void _drawSky(Canvas canvas, double w, double h, double horizon, bool tealSky) {
    final colors = tealSky
        ? const [Color(0xFF00251A), Color(0xFF004D40), Color(0xFF00695C), Color(0xFF26A69A)]
        : const [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFF90CAF9)];
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
  }

  // ── SUN ──────────────────────────────────────────────────────────────────────

  void _drawSun(Canvas canvas, double w, double horizon, double s) {
    final sunX = w * 0.80;
    final sunY = horizon * 0.20;
    final r = 20.0 * s;

    canvas.drawCircle(
      Offset(sunX, sunY),
      r * 2.4,
      Paint()
        ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * s),
    );
    canvas.drawCircle(
        Offset(sunX, sunY), r, Paint()..color = const Color(0xFFFFF176));
  }

  // ── CLOUDS ───────────────────────────────────────────────────────────────────

  void _drawClouds(Canvas canvas, double w, double horizon, double s) {
    final offset = (t * w * 0.32) % w;
    const defs = [(0.15, 0.12), (0.46, 0.18), (0.75, 0.09)];
    for (final (fx, fy) in defs) {
      final cx = ((fx * w - offset + w) % (w * 1.4)) - w * 0.12;
      _cloud(canvas, cx, fy * horizon, 65 * s, 20 * s);
    }
  }

  void _cloud(Canvas canvas, double cx, double cy, double cw, double ch) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.86);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch), p);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + cw * 0.24, cy - ch * 0.42),
            width: cw * 0.54,
            height: ch * 0.82),
        p);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - cw * 0.22, cy - ch * 0.28),
            width: cw * 0.46,
            height: ch * 0.72),
        p);
  }

  // ── DISTANT HILLS ─────────────────────────────────────────────────────────────

  void _drawDistantHills(Canvas canvas, double w, double horizon) {
    final offset = (t * w * 0.10) % w;
    for (int tile = -1; tile <= 1; tile++) {
      _hillSilhouette(canvas, tile * w - offset, horizon, w,
          const Color(0xFF546E7A).withValues(alpha: 0.30));
    }
  }

  void _hillSilhouette(
      Canvas canvas, double x, double groundY, double w, Color color) {
    final path = Path()..moveTo(x, groundY);
    const xs = [
      0.0, 0.08, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95, 1.0
    ];
    const hs = [
      0.0, 0.12, 0.23, 0.08, 0.28, 0.17, 0.32, 0.13, 0.25, 0.09, 0.17, 0.0
    ];
    for (int i = 0; i < xs.length; i++) {
      path.lineTo(x + xs[i] * w, groundY - hs[i] * groundY * 0.36);
    }
    path.lineTo(x + w, groundY);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // ── BUILDING LAYERS ───────────────────────────────────────────────────────────

  void _drawBuildingLayers(
      Canvas canvas, double w, double horizon, double s) {
    // Continuous base strip — prevents sky colour showing through tile seams
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - 24 * s, w, 24 * s),
      Paint()..color = const Color(0xFF455A64).withValues(alpha: 0.30),
    );

    final farOff = (t * w * 0.55) % w;
    for (int tile = -1; tile <= 2; tile++) {
      _farBuildings(canvas, tile * w - farOff, horizon, w, s);
    }
    final midOff = (t * w * 1.25) % w;
    for (int tile = -1; tile <= 2; tile++) {
      _midTile(canvas, tile * w - midOff, horizon, w, s);
    }
  }

  void _farBuildings(
      Canvas canvas, double x0, double horizon, double w, double s) {
    const defs = [
      (0.04, 0.38, 48.0, 0xFF90A4AE),
      (0.16, 0.43, 42.0, 0xFFB0BEC5),
      (0.30, 0.35, 54.0, 0xFF78909C),
      (0.46, 0.41, 46.0, 0xFF9E9E9E),
      (0.60, 0.44, 40.0, 0xFFBDBDBD),
      (0.74, 0.37, 50.0, 0xFF90A4AE),
      (0.87, 0.40, 44.0, 0xFFB0BEC5),
    ];
    for (final (fx, fh, fw, col) in defs) {
      final bx = x0 + fx * w;
      final bh = horizon * fh;
      final bw = fw * s;
      canvas.drawRect(
          Rect.fromLTWH(bx, horizon - bh, bw, bh), Paint()..color = Color(col));
      _windows(canvas, bx, horizon - bh, bw, bh, 2, 3, s);
    }
  }

  void _windows(Canvas canvas, double x, double y, double w, double h,
      int cols, int rows, double s) {
    final ww = (w - (cols + 1) * 2 * s) / cols;
    final wh = 5.0 * s;
    final wp = Paint()..color = const Color(0xFFFFF9C4).withValues(alpha: 0.55);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(x + 2 * s + c * (ww + 2 * s),
              y + 6 * s + r * (wh + 4 * s), ww, wh),
          wp,
        );
      }
    }
  }

  void _midTile(
      Canvas canvas, double x0, double horizon, double w, double s) {
    // Seam fillers — bridge the gap between consecutive tiles at both edges
    _colorBlock(canvas, x0 - 16 * s, horizon, 24 * s, 42 * s,
        const Color(0xFF78909C));
    _colorBlock(canvas, x0 + w - 10 * s, horizon, 30 * s, 50 * s,
        const Color(0xFF90A4AE));

    _dagdusheth(canvas, x0 + w * 0.04, horizon, s);
    _fcRoadShops(canvas, x0 + w * 0.30, horizon, s);
    _shaniwarWada(canvas, x0 + w * 0.62, horizon, s);
    _colorBlock(canvas, x0 + w * 0.81, horizon, 38 * s, 58 * s,
        const Color(0xFFA5D6A7));
    _colorBlock(canvas, x0 + w * 0.90, horizon, 34 * s, 46 * s,
        const Color(0xFFFFCCBC));
    _tree(canvas, x0 + w * 0.27, horizon, s);
    _tree(canvas, x0 + w * 0.59, horizon, s);
    _tree(canvas, x0 + w * 0.77, horizon, s);
  }

  // ── DAGDUSHETH HALWAI GANPATI ─────────────────────────────────────────────────

  void _dagdusheth(Canvas canvas, double x, double groundY, double s) {
    final p = Paint();

    p.color = const Color(0xFFFFF8E1);
    canvas.drawRect(
        Rect.fromLTWH(x, groundY - 40 * s, 64 * s, 40 * s), p);

    p.color = const Color(0xFFFFE082);
    canvas.drawRect(
        Rect.fromLTWH(x + 2 * s, groundY - 38 * s, 8 * s, 38 * s), p);
    canvas.drawRect(
        Rect.fromLTWH(x + 54 * s, groundY - 38 * s, 8 * s, 38 * s), p);

    final archPath = Path()
      ..moveTo(x + 18 * s, groundY)
      ..lineTo(x + 18 * s, groundY - 22 * s)
      ..arcToPoint(Offset(x + 46 * s, groundY - 22 * s),
          radius: Radius.circular(14 * s), clockwise: false)
      ..lineTo(x + 46 * s, groundY)
      ..close();
    p.color = const Color(0xFFFF8F00);
    canvas.drawPath(archPath, p);

    final innerPath = Path()
      ..moveTo(x + 22 * s, groundY)
      ..lineTo(x + 22 * s, groundY - 18 * s)
      ..arcToPoint(Offset(x + 42 * s, groundY - 18 * s),
          radius: Radius.circular(10 * s), clockwise: false)
      ..lineTo(x + 42 * s, groundY)
      ..close();
    p.color = const Color(0xFF4E342E).withValues(alpha: 0.45);
    canvas.drawPath(innerPath, p);

    p.color = const Color(0xFFFFD54F);
    canvas.drawRect(
        Rect.fromLTWH(x + 14 * s, groundY - 60 * s, 36 * s, 22 * s), p);
    p.color = const Color(0xFFFFCA28);
    canvas.drawRect(
        Rect.fromLTWH(x + 18 * s, groundY - 76 * s, 28 * s, 18 * s), p);
    p.color = const Color(0xFFFFB300);
    canvas.drawRect(
        Rect.fromLTWH(x + 22 * s, groundY - 90 * s, 20 * s, 16 * s), p);
    p.color = const Color(0xFFFFA000);
    canvas.drawRect(
        Rect.fromLTWH(x + 25 * s, groundY - 102 * s, 14 * s, 14 * s), p);

    p.color = const Color(0xFFFF8F00);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x + 32 * s, groundY - 107 * s),
          width: 18 * s,
          height: 13 * s),
      p,
    );

    canvas.drawLine(
      Offset(x + 32 * s, groundY - 110 * s),
      Offset(x + 32 * s, groundY - 126 * s),
      Paint()
        ..color = const Color(0xFFE53935)
        ..strokeWidth = 1.4 * s,
    );
    final flagPath = Path()
      ..moveTo(x + 32 * s, groundY - 126 * s)
      ..lineTo(x + 44 * s, groundY - 122 * s)
      ..lineTo(x + 32 * s, groundY - 118 * s)
      ..close();
    p.color = const Color(0xFFE53935);
    canvas.drawPath(flagPath, p);

    p.color = const Color(0xFFFFB300).withValues(alpha: 0.45);
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
          Rect.fromLTWH(
              x + 14 * s, groundY - (46 + i * 5) * s, 36 * s, 1.4 * s),
          p);
    }

    _label(canvas, 'दगडूशेठ', x + 18 * s, groundY - 14 * s, 5.5 * s,
        const Color(0xFF4E342E));
  }

  // ── FC ROAD SHOPS ─────────────────────────────────────────────────────────────

  void _fcRoadShops(Canvas canvas, double x, double groundY, double s) {
    const shops = [
      (0xFFEF9A9A, 'Cafe', 30.0),
      (0xFF80CBC4, 'FC Road', 36.0),
      (0xFFFFCC80, 'Bakery', 28.0),
      (0xFFCE93D8, 'Irani', 33.0),
      (0xFF90CAF9, 'Chai', 26.0),
    ];

    double sx = x;
    for (final (col, name, bh) in shops) {
      final bw = 27.0 * s;
      final bHeight = bh * s;
      final color = Color(col);

      canvas.drawRect(
          Rect.fromLTWH(sx, groundY - bHeight, bw, bHeight),
          Paint()..color = color);

      final awning = Color.fromARGB(
        255,
        (color.r * 255.0 * 0.72).round().clamp(0, 255),
        (color.g * 255.0 * 0.72).round().clamp(0, 255),
        (color.b * 255.0 * 0.72).round().clamp(0, 255),
      );
      canvas.drawRect(
        Rect.fromLTWH(sx, groundY - bHeight + 6 * s, bw, 5 * s),
        Paint()..color = awning,
      );

      final wp = Paint()..color = Colors.white.withValues(alpha: 0.72);
      canvas.drawRect(
          Rect.fromLTWH(
              sx + 3 * s, groundY - bHeight + 13 * s, 8 * s, 7 * s),
          wp);
      canvas.drawRect(
          Rect.fromLTWH(
              sx + 15 * s, groundY - bHeight + 13 * s, 8 * s, 7 * s),
          wp);

      canvas.drawRect(
        Rect.fromLTWH(sx + 7 * s, groundY - 12 * s, 12 * s, 12 * s),
        Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.50),
      );

      _label(canvas, name, sx + 2 * s, groundY - bHeight + 2 * s, 5 * s,
          const Color(0xFF4E342E));
      sx += bw + 2 * s;
    }
  }

  // ── SHANIWAR WADA ─────────────────────────────────────────────────────────────

  void _shaniwarWada(Canvas canvas, double x, double groundY, double s) {
    final p = Paint();

    p.color = const Color(0xFFD7CCC8);
    canvas.drawRect(
        Rect.fromLTWH(x, groundY - 52 * s, 54 * s, 52 * s), p);

    p.color = const Color(0xFFBCAAA4);
    for (int i = 0; i < 6; i++) {
      canvas.drawRect(
          Rect.fromLTWH(x + i * 9 * s, groundY - 58 * s, 6 * s, 6 * s), p);
    }

    final gatePath = Path()
      ..moveTo(x + 16 * s, groundY)
      ..lineTo(x + 16 * s, groundY - 26 * s)
      ..arcToPoint(Offset(x + 38 * s, groundY - 26 * s),
          radius: Radius.circular(11 * s), clockwise: false)
      ..lineTo(x + 38 * s, groundY)
      ..close();
    p.color = const Color(0xFF8D6E63);
    canvas.drawPath(gatePath, p);

    p.color = const Color(0xFFBCAAA4);
    canvas.drawRect(
        Rect.fromLTWH(x - 5 * s, groundY - 64 * s, 14 * s, 64 * s), p);
    canvas.drawRect(
        Rect.fromLTWH(x + 45 * s, groundY - 64 * s, 14 * s, 64 * s), p);
    p.color = const Color(0xFF8D6E63);
    canvas.drawRect(
        Rect.fromLTWH(x - 7 * s, groundY - 68 * s, 18 * s, 5 * s), p);
    canvas.drawRect(
        Rect.fromLTWH(x + 43 * s, groundY - 68 * s, 18 * s, 5 * s), p);

    _label(canvas, 'Shaniwar Wada', x + 2 * s, groundY - 12 * s, 4.2 * s,
        const Color(0xFF5D4037));
  }

  void _colorBlock(Canvas canvas, double x, double groundY, double w,
      double h, Color color) {
    canvas.drawRect(
        Rect.fromLTWH(x, groundY - h, w, h), Paint()..color = color);
    _windows(canvas, x, groundY - h, w, h, 2, 3, 1.0);
  }

  // ── TREE ─────────────────────────────────────────────────────────────────────

  void _tree(Canvas canvas, double x, double groundY, double s) {
    canvas.drawRect(
      Rect.fromLTWH(x - 2.5 * s, groundY - 24 * s, 5 * s, 24 * s),
      Paint()..color = const Color(0xFF8D6E63),
    );
    canvas.drawCircle(Offset(x, groundY - 30 * s), 13 * s,
        Paint()..color = const Color(0xFF66BB6A));
    canvas.drawCircle(Offset(x - 7 * s, groundY - 23 * s), 9 * s,
        Paint()..color = const Color(0xFF43A047));
    canvas.drawCircle(Offset(x + 7 * s, groundY - 25 * s), 9 * s,
        Paint()..color = const Color(0xFF388E3C));
  }

  // ── ROAD ─────────────────────────────────────────────────────────────────────

  void _drawRoad(
      Canvas canvas, double w, double h, double horizon, double s) {
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()..color = const Color(0xFF37474F),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, 5),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF212121), Color(0xFF37474F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, horizon, w, 5)),
    );
    canvas.drawRect(Rect.fromLTWH(0, horizon + 4, w, 2 * s),
        Paint()..color = Colors.white.withValues(alpha: 0.48));
    canvas.drawRect(Rect.fromLTWH(0, h - 5 * s, w, 2 * s),
        Paint()..color = Colors.white.withValues(alpha: 0.38));

    final dashOffset = (t * w * 3.2) % 60.0;
    final dashY = horizon + (h - horizon) * 0.42;
    final dashPaint = Paint()
      ..color = const Color(0xFFFFEE58)
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    double dx = -dashOffset;
    while (dx < w + 60) {
      canvas.drawLine(Offset(dx, dashY), Offset(dx + 36, dashY), dashPaint);
      dx += 60;
    }
  }

  // ── SCOOTER ───────────────────────────────────────────────────────────────────

  void _drawScooter(
      Canvas canvas, double w, double h, double horizon, double s) {
    final groundY = horizon + (h - horizon) * 0.76;
    final bob = sin(t * pi * 2 * 5) * 1.6 * s;
    final wheelAngle = t * pi * 2 * 10;

    canvas.save();
    canvas.translate(w * 0.30, groundY + bob);
    _scooter(canvas, s, wheelAngle);
    canvas.restore();
  }

  void _scooter(Canvas canvas, double s, double wa) {
    final p = Paint();

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-2 * s, 2 * s), width: 75 * s, height: 6 * s),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // ── Wheels ──
    _wheel(canvas, -19 * s, 0, 11 * s, wa);
    _wheel(canvas, 15 * s, 0, 9 * s, wa);

    // ── Footboard (low base) ──
    p.color = const Color(0xFF004D40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-22 * s, -4 * s, 34 * s, 5 * s),
          Radius.circular(2 * s)),
      p,
    );

    // ── Main body ──
    p.color = const Color(0xFF00897B);
    final bodyPath = Path()
      ..moveTo(-22 * s, -4 * s)
      ..quadraticBezierTo(-24 * s, -18 * s, -12 * s, -22 * s)
      ..lineTo(6 * s, -22 * s)
      ..quadraticBezierTo(16 * s, -22 * s, 19 * s, -12 * s)
      ..lineTo(19 * s, -4 * s)
      ..close();
    canvas.drawPath(bodyPath, p);

    // Body top sheen
    p.color = const Color(0xFF4DB6AC).withValues(alpha: 0.40);
    final sheenPath = Path()
      ..moveTo(-10 * s, -22 * s)
      ..lineTo(6 * s, -22 * s)
      ..quadraticBezierTo(14 * s, -22 * s, 17 * s, -15 * s)
      ..lineTo(0 * s, -18 * s)
      ..close();
    canvas.drawPath(sheenPath, p);

    // ── Seat ──
    p.color = const Color(0xFF1B2A2B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-13 * s, -29 * s, 22 * s, 8 * s),
          Radius.circular(4 * s)),
      p,
    );
    // Seat stitching highlight
    p.color = const Color(0xFF2E4A4C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-11 * s, -29 * s, 18 * s, 2.5 * s),
          Radius.circular(1.5 * s)),
      p,
    );

    // ── Delivery box ──
    // Box body
    p.color = const Color(0xFF00574B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-36 * s, -26 * s, 20 * s, 18 * s),
          Radius.circular(3 * s)),
      p,
    );
    // Box lid
    p.color = const Color(0xFF00897B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-37 * s, -27 * s, 22 * s, 5 * s),
          Radius.circular(2.5 * s)),
      p,
    );
    // Lid handle
    p.color = const Color(0xFF00BFA5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-29 * s, -28 * s, 8 * s, 2 * s),
          Radius.circular(1 * s)),
      p,
    );
    // Box stripe detail
    p.color = const Color(0xFF00695C);
    canvas.drawRect(
        Rect.fromLTWH(-36 * s, -20 * s, 20 * s, 2 * s), p);
    // Emblem circle (no text)
    canvas.drawCircle(Offset(-26 * s, -14 * s), 5 * s,
        Paint()..color = const Color(0xFF00897B));
    canvas.drawCircle(Offset(-26 * s, -14 * s), 3.2 * s,
        Paint()..color = const Color(0xFF00BFA5));
    canvas.drawCircle(Offset(-26 * s, -14 * s), 1.5 * s,
        Paint()..color = Colors.white.withValues(alpha: 0.9));

    // ── Front fork / neck ──
    p.color = const Color(0xFF00695C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(11 * s, -18 * s, 5 * s, 14 * s),
          Radius.circular(2 * s)),
      p,
    );

    // ── Handlebar ──
    p.color = const Color(0xFF37474F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(12 * s, -26 * s, 4 * s, 10 * s),
          Radius.circular(2 * s)),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(10 * s, -26 * s, 8 * s, 3 * s),
          Radius.circular(1.5 * s)),
      p,
    );
    // Handlebar grips
    p.color = const Color(0xFF212121);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(10 * s, -27 * s, 3 * s, 4 * s),
          Radius.circular(1.5 * s)),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(15 * s, -27 * s, 3 * s, 4 * s),
          Radius.circular(1.5 * s)),
      p,
    );

    // ── Headlight housing ──
    p.color = const Color(0xFF00574B);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(20 * s, -10 * s), width: 16 * s, height: 14 * s),
      p,
    );
    // Headlight lens (yellow glow)
    p.color = const Color(0xFFFFF176);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(20 * s, -10 * s), width: 12 * s, height: 10 * s),
      p,
    );
    // Inner lens shimmer
    p.color = Colors.white.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(19 * s, -12 * s), width: 6 * s, height: 3 * s),
      p,
    );

    // ── Eyes (on headlight) ──
    // Left eye
    p.color = const Color(0xFF1A1A2E);
    canvas.drawCircle(Offset(17.5 * s, -11 * s), 2.8 * s, p);
    // Right eye
    canvas.drawCircle(Offset(22.5 * s, -11 * s), 2.8 * s, p);
    // Eye iris
    p.color = const Color(0xFF00897B);
    canvas.drawCircle(Offset(17.5 * s, -11 * s), 1.5 * s, p);
    canvas.drawCircle(Offset(22.5 * s, -11 * s), 1.5 * s, p);
    // Pupil
    p.color = const Color(0xFF0D0D1A);
    canvas.drawCircle(Offset(17.5 * s, -11 * s), 0.8 * s, p);
    canvas.drawCircle(Offset(22.5 * s, -11 * s), 0.8 * s, p);
    // Eye shine
    p.color = Colors.white;
    canvas.drawCircle(Offset(18.3 * s, -11.8 * s), 0.7 * s, p);
    canvas.drawCircle(Offset(23.3 * s, -11.8 * s), 0.7 * s, p);

    // ── Exhaust puffs (animated) ──
    final puffT = (sin(t * pi * 2 * 4) + 1) / 2;
    canvas.drawCircle(
        Offset(-41 * s, -8 * s),
        5 * s,
        Paint()..color = Colors.white.withValues(alpha: puffT * 0.28));
    canvas.drawCircle(
        Offset(-49 * s, -11 * s),
        3.5 * s,
        Paint()..color = Colors.white.withValues(alpha: puffT * 0.16));
    canvas.drawCircle(
        Offset(-56 * s, -9 * s),
        2 * s,
        Paint()..color = Colors.white.withValues(alpha: puffT * 0.08));

    // Speed lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22 + puffT * 0.12)
      ..strokeWidth = 1.2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(-42 * s, -3 * s), Offset(-30 * s, -3 * s), linePaint);
    canvas.drawLine(
        Offset(-45 * s, -9 * s), Offset(-35 * s, -9 * s), linePaint);
    canvas.drawLine(
        Offset(-40 * s, -15 * s), Offset(-32 * s, -15 * s), linePaint);
  }

  void _wheel(Canvas canvas, double cx, double cy, double r, double angle) {
    // Tire
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF1A1A1A));
    // Rim
    canvas.drawCircle(
        Offset(cx, cy), r * 0.72, Paint()..color = const Color(0xFF455A64));
    // Hub cap
    canvas.drawCircle(
        Offset(cx, cy), r * 0.28, Paint()..color = const Color(0xFF78909C));
    // Hub bolt
    canvas.drawCircle(
        Offset(cx, cy), r * 0.12, Paint()..color = const Color(0xFFB0BEC5));
    // Spokes
    final spokePaint = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 5; i++) {
      final a = angle + i * (2 * pi / 5);
      canvas.drawLine(
        Offset(cx + cos(a) * r * 0.28, cy + sin(a) * r * 0.28),
        Offset(cx + cos(a) * r * 0.70, cy + sin(a) * r * 0.70),
        spokePaint,
      );
    }
  }

  // ── UTIL ─────────────────────────────────────────────────────────────────────

  void _label(Canvas canvas, String text, double x, double y,
      double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_PuneScenePainter old) => old.t != t || old.tealSky != tealSky;
}
