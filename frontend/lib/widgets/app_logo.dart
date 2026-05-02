import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 48, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoMark(size: size, color: color),
        if (showText) ...[
          SizedBox(height: size * 0.18),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: size * 0.28,
                letterSpacing: 0.5,
                color: color,
                fontWeight: FontWeight.w300,
              ),
              children: [
                TextSpan(
                  text: 'nieuws',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: 'feed'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  final Color color;

  const _LogoMark({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(color: color),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;

  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w / 2, circlePaint);

    // White N lettermark
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pad = w * 0.26;
    final top = h * 0.24;
    final bot = h * 0.76;

    // Left vertical
    canvas.drawLine(Offset(pad, top), Offset(pad, bot), paint);
    // Diagonal
    canvas.drawLine(Offset(pad, top), Offset(w - pad, bot), paint);
    // Right vertical
    canvas.drawLine(Offset(w - pad, top), Offset(w - pad, bot), paint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
