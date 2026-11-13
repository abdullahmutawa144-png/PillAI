import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// PillAI's mark: a capsule with a spark, on the AI gradient.
///
/// Drawn in code so it stays crisp at every size and needs no assets.
class PillAiMark extends StatelessWidget {
  const PillAiMark({
    super.key,
    this.size = 80,
    this.showOnlineBadge = false,
    this.semanticLabel = 'PillAI assistant',
  });

  final double size;
  final bool showOnlineBadge;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(painter: _PillAiPainter()),
              ),
              if (showOnlineBadge)
                PositionedDirectional(
                  end: -size * 0.02,
                  bottom: -size * 0.02,
                  child: Container(
                    width: size * 0.26,
                    height: size * 0.26,
                    decoration: BoxDecoration(
                      color: AppColors.mintBright,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: math.max(1.5, size * 0.045),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alias intended for compact brand placements such as onboarding and headers.
class PillAiLogo extends StatelessWidget {
  const PillAiLogo({super.key, this.size = 56, this.showOnlineBadge = false});

  final double size;
  final bool showOnlineBadge;

  @override
  Widget build(BuildContext context) {
    return PillAiMark(size: size, showOnlineBadge: showOnlineBadge);
  }
}

class _PillAiPainter extends CustomPainter {
  const _PillAiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final RRect tile = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(30),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0E8C73), Color(0xFF5B4FD0)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    // Soft highlight for depth.
    canvas.drawCircle(
      const Offset(28, 22),
      38,
      Paint()..color = Colors.white.withAlpha(22),
    );

    // Capsule.
    canvas.save();
    canvas.translate(46, 54);
    canvas.rotate(-math.pi / 4);
    final RRect capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 26, height: 58),
      const Radius.circular(13),
    );
    canvas.drawRRect(capsule, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(capsule);
    canvas.drawRect(
      const Rect.fromLTWH(-14, 0, 28, 30),
      Paint()..color = const Color(0xFFBFF0DF),
    );
    canvas.restore();
    canvas.drawLine(
      const Offset(-13, 0),
      const Offset(13, 0),
      Paint()
        ..color = const Color(0x330A7A65)
        ..strokeWidth = 1.6,
    );
    canvas.restore();

    // Spark.
    _drawSpark(canvas, const Offset(74, 26), 11);
    _drawSpark(canvas, const Offset(80, 46), 5);

    canvas.restore();
  }

  void _drawSpark(Canvas canvas, Offset center, double r) {
    final Path path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PillAiPainter oldDelegate) => false;
}
