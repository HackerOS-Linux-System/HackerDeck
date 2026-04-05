// ─────────────────────────────────────────────
//  HackerDeck — Keymapper CustomPainter
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:hackerdeck/models.dart';

class KeymapperPainter extends CustomPainter {
  final List<KeyCircle> circles;
  final int draggingIndex;

  KeymapperPainter({required this.circles, required this.draggingIndex});

  @override
  void paint(Canvas canvas, Size size) {
    // Background grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < circles.length; i++) {
      final circle = circles[i];
      final isDragging = i == draggingIndex;
      final center = Offset(circle.x, circle.y);
      final color = isDragging ? Colors.orange : const Color(0xFF00E5FF);

      // Glow
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center, circle.radius + 4, glowPaint);

      // Fill
      canvas.drawCircle(
        center,
        circle.radius,
        Paint()..color = color.withOpacity(0.82),
      );

      // Border
      canvas.drawCircle(
        center,
        circle.radius,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Key label
      final tp = TextPainter(
        text: TextSpan(
          text: circle.key.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout();
      tp.paint(canvas, Offset(circle.x - tp.width / 2, circle.y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant KeymapperPainter old) =>
      circles != old.circles || draggingIndex != old.draggingIndex;
}
