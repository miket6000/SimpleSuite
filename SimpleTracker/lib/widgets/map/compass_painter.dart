import 'dart:math';

import 'package:flutter/material.dart';

class CompassPainter extends CustomPainter {
  final double bearingDegrees;

  CompassPainter({required this.bearingDegrees});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Draw compass circle
    final circlePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw cardinal direction ticks and labels
    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5;

    const cardinals = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * pi / 180; // -90 so N is at top
      final outerPoint = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - 6) * cos(angle),
        center.dy + (radius - 6) * sin(angle),
      );
      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Draw cardinal letter
      final textPainter = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: cardinals[i] == 'N' ? Colors.red : Colors.grey.shade700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelRadius = radius - 14;
      final labelOffset = Offset(
        center.dx + labelRadius * cos(angle) - textPainter.width / 2,
        center.dy + labelRadius * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    }

    // Draw bearing arrow
    final bearingRad = (bearingDegrees - 90) * pi / 180; // -90 so 0° points up
    final arrowLength = radius - 18;

    final arrowTip = Offset(
      center.dx + arrowLength * cos(bearingRad),
      center.dy + arrowLength * sin(bearingRad),
    );

    // Arrow shaft
    final arrowPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, arrowTip, arrowPaint);

    // Arrowhead
    final headLength = 8.0;
    final headAngle = 0.4; // radians (~23°)
    final leftHead = Offset(
      arrowTip.dx - headLength * cos(bearingRad - headAngle),
      arrowTip.dy - headLength * sin(bearingRad - headAngle),
    );
    final rightHead = Offset(
      arrowTip.dx - headLength * cos(bearingRad + headAngle),
      arrowTip.dy - headLength * sin(bearingRad + headAngle),
    );
    final headPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(leftHead.dx, leftHead.dy)
      ..lineTo(rightHead.dx, rightHead.dy)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill,
    );

    // Center dot
    canvas.drawCircle(
      center,
      3,
      Paint()..color = Colors.blue,
    );
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.bearingDegrees != bearingDegrees;
  }
}
