import 'package:flutter/material.dart';

/// Les trois cornières du motif de détection QR — la signature visuelle de
/// QRFlow. Réutilisée sur l'accueil, l'écran de résultat et la bulle flottante.
class FinderMark extends StatelessWidget {
  const FinderMark({
    super.key,
    this.size = 64,
    this.color = const Color(0xFF5B5FEF),
    this.strokeRatio = 0.07,
  });

  final double size;
  final Color color;
  final double strokeRatio;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FinderPainter(color, size * strokeRatio),
    );
  }
}

class _FinderPainter extends CustomPainter {
  _FinderPainter(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double arm = s * 0.34; // longueur de chaque branche
    final double inset = stroke / 2;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Coin haut-gauche
    canvas.drawLine(
        Offset(inset, inset), Offset(inset + arm, inset), paint);
    canvas.drawLine(
        Offset(inset, inset), Offset(inset, inset + arm), paint);
    // Coin haut-droit
    canvas.drawLine(
        Offset(s - inset, inset), Offset(s - inset - arm, inset), paint);
    canvas.drawLine(
        Offset(s - inset, inset), Offset(s - inset, inset + arm), paint);
    // Coin bas-gauche
    canvas.drawLine(
        Offset(inset, s - inset), Offset(inset + arm, s - inset), paint);
    canvas.drawLine(
        Offset(inset, s - inset), Offset(inset, s - inset - arm), paint);
  }

  @override
  bool shouldRepaint(_FinderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.stroke != stroke;
}
