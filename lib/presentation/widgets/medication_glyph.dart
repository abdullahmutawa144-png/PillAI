import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MedicationGlyphType { capsule, tablet, bottle }

/// An asset-free medicine illustration that scales cleanly at any size.
class MedicationGlyph extends StatelessWidget {
  const MedicationGlyph({
    super.key,
    this.type = MedicationGlyphType.capsule,
    this.size = 96,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = Colors.white,
    this.backgroundColor = AppColors.primarySoft,
    this.semanticLabel = 'Medicine',
  });

  final MedicationGlyphType type;
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _MedicationPainter(
              type: type,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              backgroundColor: backgroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationPainter extends CustomPainter {
  const _MedicationPainter({
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final MedicationGlyphType type;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale, scale);

    canvas.drawCircle(
      const Offset(50, 50),
      45,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: <Color>[Colors.white, backgroundColor],
        ).createShader(const Rect.fromLTWH(5, 5, 90, 90)),
    );

    switch (type) {
      case MedicationGlyphType.capsule:
        _paintCapsule(canvas);
      case MedicationGlyphType.tablet:
        _paintTablet(canvas);
      case MedicationGlyphType.bottle:
        _paintBottle(canvas);
    }
    canvas.restore();
  }

  void _paintCapsule(Canvas canvas) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-math.pi / 5);

    final RRect capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 37, height: 70),
      const Radius.circular(19),
    );
    final Path shadowPath = Path()..addRRect(capsule.shift(const Offset(0, 3)));
    canvas.drawShadow(shadowPath, AppColors.navy.withAlpha(48), 7, false);
    canvas.drawRRect(capsule, Paint()..color = secondaryColor);

    canvas.save();
    canvas.clipRRect(capsule);
    canvas.drawRect(
      const Rect.fromLTWH(-20, -36, 40, 36),
      Paint()..color = primaryColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -27, 8, 22),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withAlpha(95),
    );
    canvas.restore();

    canvas.drawLine(
      const Offset(-18.5, 0),
      const Offset(18.5, 0),
      Paint()
        ..color = AppColors.navy.withAlpha(26)
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = AppColors.navy.withAlpha(22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _paintTablet(Canvas canvas) {
    final Path shadow = Path()
      ..addOval(Rect.fromCircle(center: const Offset(50, 53), radius: 25));
    canvas.drawShadow(shadow, AppColors.navy.withAlpha(44), 6, false);
    canvas.drawCircle(const Offset(50, 49), 25, Paint()..color = primaryColor);
    canvas.drawArc(
      const Rect.fromLTWH(32, 31, 36, 36),
      math.pi * 1.05,
      math.pi * 0.7,
      false,
      Paint()
        ..color = Colors.white.withAlpha(85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(33, 66),
      const Offset(67, 32),
      Paint()
        ..color = Colors.white.withAlpha(220)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBottle(Canvas canvas) {
    final RRect body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 34, 44, 49),
      const Radius.circular(9),
    );
    final Path shadow = Path()..addRRect(body.shift(const Offset(0, 3)));
    canvas.drawShadow(shadow, AppColors.navy.withAlpha(46), 6, false);
    canvas.drawRRect(body, Paint()..color = primaryColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 23, 36, 16),
        const Radius.circular(5),
      ),
      Paint()..color = AppColors.navy,
    );
    canvas.drawRect(
      const Rect.fromLTWH(36, 39, 28, 4),
      Paint()..color = Colors.white.withAlpha(90),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 49, 32, 24),
        const Radius.circular(5),
      ),
      Paint()..color = secondaryColor,
    );
    canvas.drawRect(
      const Rect.fromLTWH(47, 54, 6, 14),
      Paint()..color = AppColors.mint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(43, 58, 14, 6),
      Paint()..color = AppColors.mint,
    );
  }

  @override
  bool shouldRepaint(_MedicationPainter oldDelegate) {
    return type != oldDelegate.type ||
        primaryColor != oldDelegate.primaryColor ||
        secondaryColor != oldDelegate.secondaryColor ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
