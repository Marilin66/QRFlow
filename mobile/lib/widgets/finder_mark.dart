import 'package:flutter/material.dart';

/// Le motif de repérage d'un QR code — signe visuel de QRFlow.
class FinderMark extends StatelessWidget {
  const FinderMark({super.key, this.size = 32, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.square(size),
      painter: _FinderMarkPainter(paintColor),
    );
  }
}

class _FinderMarkPainter extends CustomPainter {
  _FinderMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final outer = size.width * 0.30;
    final offset = size.width * 0.05;

    void corner(double dx, double dy) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, dy, outer, outer),
          Radius.circular(outer * 0.18),
        ),
        paint,
      );
      final inner = outer * 0.38;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            dx + outer / 2 - inner / 2,
            dy + outer / 2 - inner / 2,
            inner,
            inner,
          ),
          Radius.circular(inner * 0.2),
        ),
        paint,
      );
    }

    // Trois coins de repérage, comme sur un QR code.
    corner(offset, offset);
    corner(size.width - offset - outer, offset);
    corner(offset, size.height - offset - outer);
  }

  @override
  bool shouldRepaint(covariant _FinderMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
