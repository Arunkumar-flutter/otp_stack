import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the rounded border of an OTP card.
///
/// When [animated] is `true` the border is a rotating [SweepGradient] driven
/// by [progress] (0..1). When `false` it is a plain static stroke.
class OtpBorderPainter extends CustomPainter {
  OtpBorderPainter({
    required this.progress,
    required this.color,
    required this.animated,
  });

  /// Rotation progress in the range 0..1. Only used when [animated] is `true`.
  final double progress;

  /// The border color.
  final Color color;

  /// Whether to draw the rotating gradient border.
  final bool animated;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(1.7), const Radius.circular(11)),
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = animated ? 3.2 : 1.2
      ..color = color;

    if (animated) {
      paint.shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.1),
          color,
          const Color(0xFFB66BFF),
          color.withValues(alpha: 0.1),
        ],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(rect);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant OtpBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.animated != animated;
}
