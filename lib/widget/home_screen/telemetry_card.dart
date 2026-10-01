import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';

/// Instrument-grade dial: consistent 240-degree sweep, ticks, scale and needle.
class TelemetryCard extends StatelessWidget {
  const TelemetryCard({super.key, required this.title, required this.value,
    this.valueSuffix = '', this.fractionDigits = 0, required this.unit,
    required this.iconPath, required this.progress});
  final String title, valueSuffix, unit, iconPath;
  final double value, progress;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final rpm = title.toLowerCase() == 'rpm';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF15171B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF33363E)),
      ),
      child: Column(children: [
        Row(children: [
          SvgPicture.asset(iconPath, width: 17, height: 17,
            colorFilter: const ColorFilter.mode(AppColors.accentBright, BlendMode.srcIn)),
          const SizedBox(width: 7),
          Expanded(child: Text(title.toUpperCase(), maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFBDC0C8), fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 1.1))),
        ]),
        const SizedBox(height: 6),
        Expanded(child: LayoutBuilder(builder: (context, bounds) =>
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => CustomPaint(
              painter: _InstrumentPainter(progress: animated, rpm: rpm),
              child: SizedBox.expand(child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${value.toStringAsFixed(fractionDigits)}$valueSuffix',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 29,
                      fontWeight: FontWeight.w800, height: 1, letterSpacing: -1.3,
                      fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(height: 3),
                  Text(unit.toUpperCase(), style: const TextStyle(
                    color: Color(0xFF989CA5), fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  const SizedBox(height: 3),
                ],
              )),
            ),
          ),
        )),
      ]),
    );
  }
}

class _InstrumentPainter extends CustomPainter {
  const _InstrumentPainter({required this.progress, required this.rpm});
  final double progress;
  final bool rpm;
  static const _start = math.pi * 5 / 6;
  static const _sweep = math.pi * 4 / 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .43);
    final radius = math.min(size.width * .43, size.height * .43);
    if (radius <= 0) return;
    final track = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(track, _start, _sweep, false, Paint()
      ..color = const Color(0xFF343941)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(track, _start, _sweep * progress, false, Paint()
        ..color = AppColors.accentBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round);
    }
    if (rpm) {
      canvas.drawArc(track, _start + _sweep * .78, _sweep * .22,
        false, Paint()..color = const Color(0xFFFF6B71)
          ..style = PaintingStyle.stroke..strokeWidth = 4.5);
    }
    for (var i = 0; i <= 40; i++) {
      final major = i % 5 == 0;
      final angle = _start + _sweep * i / 40;
      final outer = radius - 9;
      final inner = outer - (major ? 9 : 4);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + direction * inner, center + direction * outer,
        Paint()..color = major ? const Color(0xFFE0E2E7) : const Color(0xFF717680)
          ..strokeWidth = major ? 1.6 : .85..strokeCap = StrokeCap.round);
      if (major && i % 10 == 0) {
        final label = rpm ? '${i ~/ 5}' : '${i * 6}';
        final text = TextPainter(text: TextSpan(text: label,
          style: const TextStyle(color: Color(0xFF8F949D), fontSize: 8,
            fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)
          ..layout();
        final pos = center + direction * (radius - 31);
        text.paint(canvas, pos - Offset(text.width / 2, text.height / 2));
      }
    }
    final angle = _start + _sweep * progress;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final needle = Path()
      ..moveTo(center.dx - direction.dy * 2.5, center.dy + direction.dx * 2.5)
      ..lineTo(center.dx + direction.dx * (radius - 35),
        center.dy + direction.dy * (radius - 35))
      ..lineTo(center.dx + direction.dy * 2.5, center.dy - direction.dx * 2.5)
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFF4F5F7));
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF101216));
    canvas.drawCircle(center, 2.5, Paint()..color = AppColors.accentBright);
  }
  @override
  bool shouldRepaint(covariant _InstrumentPainter old) =>
    old.progress != progress || old.rpm != rpm;
}
