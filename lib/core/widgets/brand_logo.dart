import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AlShahadLogo extends StatelessWidget {
  const AlShahadLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 190 : 310,
    height: compact ? 82 : 220,
    child: CustomPaint(
      painter: _AlShahadLogoPainter(compact: compact),
    ),
  );
}

class _AlShahadLogoPainter extends CustomPainter {
  const _AlShahadLogoPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, compact ? 25 : 68);
    final scale = compact ? 0.48 : 1.0;
    final strokeWidth = 11 * scale;

    final redPaint = Paint()
      ..color = const Color(0xffdf1015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final darkPaint = Paint()
      ..color = const Color(0xff202124)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final redArc = Rect.fromCenter(
      center: center.translate(18 * scale, 0),
      width: 150 * scale,
      height: 115 * scale,
    );
    final darkArc = Rect.fromCenter(
      center: center.translate(18 * scale, 7 * scale),
      width: 170 * scale,
      height: 126 * scale,
    );
    canvas.drawArc(redArc, math.pi * 1.05, math.pi * 1.15, false, redPaint);
    canvas.drawArc(darkArc, math.pi * 1.55, math.pi * 0.8, false, darkPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'SH',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 74 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: -4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2 - 4 * scale, center.dy - textPainter.height / 2),
    );

    if (!compact) {
      final labelPainter = TextPainter(
        text: const TextSpan(
          text: 'AL-SHAHAD',
          style: TextStyle(
            color: Color(0xff202124),
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset((size.width - labelPainter.width) / 2, 145),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AlShahadLogoPainter oldDelegate) =>
      oldDelegate.compact != compact;
}
