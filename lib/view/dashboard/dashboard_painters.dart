part of '../dashboard_screen.dart';

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / 100) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _HistoryBarsPainter extends CustomPainter {
  _HistoryBarsPainter({
    required this.values,
    required this.color,
    required this.tick,
  });

  final List<double> values;
  final Color color;
  final int tick;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final normalized = _normalizeSeries(values);
    final count = normalized.length;
    final gap = 2.0;
    final barWidth = max(2.0, (size.width - ((count - 1) * gap)) / count);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final barPaint = Paint()..style = PaintingStyle.fill;
    final cursorPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final cursorGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    for (var row = 1; row < 4; row++) {
      final y = (size.height / 4) * row;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final barHeight = max(3.0, (normalized[i] / 100) * size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(3),
      );
      final baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, size.height),
        const Radius.circular(3),
      );

      canvas.drawRRect(baseRect, basePaint);
      final isLatest = i == count - 1;
      final ageFactor = count <= 1 ? 1.0 : (i / (count - 1));
      barPaint.color = isLatest
          ? color
          : color.withValues(alpha: 0.18 + (ageFactor * 0.55));
      canvas.drawRRect(rect, barPaint);
    }

    final pulse = ((tick % 6) / 5).clamp(0, 1).toDouble();
    final cursorX = max(0.0, size.width - (barWidth * (0.9 - (pulse * 0.2))));
    canvas.drawLine(
      Offset(cursorX, 6),
      Offset(cursorX, size.height - 6),
      cursorGlowPaint,
    );
    canvas.drawLine(
      Offset(cursorX, 8),
      Offset(cursorX, size.height - 8),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryBarsPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.tick != tick;
  }
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / 100) * size.height);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [Color(0xFF4CC9F0), Color(0xFF80ED99), Color(0xFFFFC857)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * value.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
