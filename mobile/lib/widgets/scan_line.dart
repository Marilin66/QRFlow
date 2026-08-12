import 'package:flutter/material.dart';

/// Ligne de balayage animée — la signature « instrumentale » de QRFlow,
/// posée sous le motif finder pour évoquer le passage du laser.
class ScanLine extends StatefulWidget {
  const ScanLine({super.key, this.size = 120, this.color = const Color(0xFF5B5FEF)});

  final double size;
  final Color color;

  @override
  State<ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = reduced ? 0.5 : _controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ScanLinePainter(widget.size * (0.1 + 0.8 * t), widget.color),
          ),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter(this.y, this.color);

  final double y;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect band = Rect.fromLTWH(0, 0, size.width, 1);
    final Paint line = Paint()
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(band);
    final Paint glow = Paint()
      ..strokeWidth = 8
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(band);

    canvas.drawLine(Offset(0, y), Offset(size.width, y), glow);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) =>
      oldDelegate.y != y || oldDelegate.color != color;
}
