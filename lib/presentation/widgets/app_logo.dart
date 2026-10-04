import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({
    super.key,
    this.size = 38,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ignore: sized_box_for_whitespace
        Container(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.asset(
              'assets/images/twilight_icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => CustomPaint(
                size: Size(size, size),
                painter: const _TwilightLogoPainter(),
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFF80D8FF),
                Color(0xFFA7FFEB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'Twilight',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TwilightLogoPainter extends CustomPainter {
  const _TwilightLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final w = size.width;

    // 1. Deep Blue to Purple Starry Sky Background matching logo image
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0B1238), Color(0xFF1B0B3A), Color(0xFF3B083C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    final RRect rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.26));
    canvas.drawRRect(rrect, bgPaint);

    // 2. Horizontal Sound Wave Lines
    final wavePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;

    final wavePath = Path();
    wavePath.moveTo(w * 0.08, center.dy);
    wavePath.quadraticBezierTo(
        w * 0.25, center.dy - w * 0.06, w * 0.4, center.dy);
    wavePath.quadraticBezierTo(
        w * 0.6, center.dy + w * 0.06, w * 0.75, center.dy);
    wavePath.quadraticBezierTo(
        w * 0.88, center.dy - w * 0.04, w * 0.92, center.dy);
    canvas.drawPath(wavePath, wavePaint);

    // 3. Glowing Crescent Moon
    final moonCenter = Offset(center.dx - w * 0.05, center.dy);
    final moonRadius = w * 0.32;

    final moonPath = Path();
    moonPath.addArc(
        Rect.fromCircle(center: moonCenter, radius: moonRadius), -2.2, 3.4);
    moonPath.arcTo(
      Rect.fromCircle(
          center: Offset(moonCenter.dx + w * 0.14, moonCenter.dy - w * 0.05),
          radius: moonRadius * 0.85),
      1.2,
      -3.4,
      false,
    );
    moonPath.close();

    final moonPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFE0), Color(0xFF80FFEA), Color(0xFF00E5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(moonPath, moonPaint);

    // 4. Glowing Cyan Musical Double Note (♫)
    final notePath = Path();
    final nX = center.dx - w * 0.08;
    final nY = center.dy - w * 0.14;

    // Left Note Head
    notePath.addOval(
        Rect.fromCircle(center: Offset(nX, nY + w * 0.28), radius: w * 0.08));
    // Right Note Head
    notePath.addOval(Rect.fromCircle(
        center: Offset(nX + w * 0.22, nY + w * 0.22), radius: w * 0.08));

    // Stems & Beam
    notePath.moveTo(nX + w * 0.06, nY + w * 0.28);
    notePath.lineTo(nX + w * 0.06, nY);
    notePath.lineTo(nX + w * 0.28, nY - w * 0.06);
    notePath.lineTo(nX + w * 0.28, nY + w * 0.22);

    final notePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE0FF4F), Color(0xFF00E5FF), Color(0xFF18FFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(notePath, notePaint);

    final noteStroke = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;

    final beamPath = Path();
    beamPath.moveTo(nX + w * 0.06, nY + w * 0.28);
    beamPath.lineTo(nX + w * 0.06, nY);
    beamPath.lineTo(nX + w * 0.28, nY - w * 0.06);
    beamPath.lineTo(nX + w * 0.28, nY + w * 0.22);
    canvas.drawPath(beamPath, noteStroke);

    // 5. Sparkle Stars
    _drawStar(
        canvas, Offset(w * 0.2, w * 0.2), w * 0.025, const Color(0xFFE8FFB7));
    _drawStar(
        canvas, Offset(w * 0.8, w * 0.22), w * 0.03, const Color(0xFF80FFEA));
    _drawStar(
        canvas, Offset(w * 0.88, w * 0.55), w * 0.02, const Color(0xFFFFFFFF));
    _drawStar(
        canvas, Offset(w * 0.15, w * 0.72), w * 0.02, const Color(0xFF80FFEA));
  }

  void _drawStar(Canvas canvas, Offset pos, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(pos.dx, pos.dy - r);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx + r, pos.dy);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + r);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx - r, pos.dy);
    path.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - r);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
