import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

enum LivePidMetric { rpm, speed, coolant, boost, egr, egrError, fuelRail, fuelRate, oilTemp, maf, torque, catalyst, voltage }

class LivePidChartScreen extends StatefulWidget {
  const LivePidChartScreen({super.key, required this.metric, required this.title, required this.unit});
  final LivePidMetric metric;
  final String title;
  final String unit;

  @override
  State<LivePidChartScreen> createState() => _LivePidChartScreenState();
}

class _LivePidChartScreenState extends State<LivePidChartScreen> {
  final List<_Point> _points = [];
  Timer? _timer;
  int _windowSeconds = 30;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _sample());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sample());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sample() {
    if (!mounted) return;
    final obd = context.read<ObdProvider>();
    final value = _readValue(obd);
    if (value == null || !value.isFinite) return;
    final now = DateTime.now();
    setState(() {
      _points.add(_Point(now, value));
      final keepAfter = now.subtract(const Duration(minutes: 11));
      _points.removeWhere((e) => e.time.isBefore(keepAfter));
    });
  }

  double? _readValue(ObdProvider obd) {
    switch (widget.metric) {
      case LivePidMetric.rpm: return obd.data.rpm.toDouble();
      case LivePidMetric.speed: return obd.data.speed.toDouble();
      case LivePidMetric.coolant: return obd.data.engineTemp.toDouble();
      case LivePidMetric.boost: return obd.actualBoostGaugeBarPid70 ?? obd.boostGaugeBar;
      case LivePidMetric.egr: return obd.egrCommandedPercent;
      case LivePidMetric.egrError: return obd.egrErrorPercent;
      case LivePidMetric.fuelRail: return obd.fuelRailPressureKpa == null ? null : obd.fuelRailPressureKpa! / 1000.0;
      case LivePidMetric.fuelRate: return obd.fuelRateLph;
      case LivePidMetric.oilTemp: return obd.oilTempC?.toDouble();
      case LivePidMetric.maf: return obd.mafGps;
      case LivePidMetric.torque: return obd.actualTorquePercent?.toDouble();
      case LivePidMetric.catalyst: return obd.catalystTempC;
      case LivePidMetric.voltage: return obd.controlModuleVoltage ?? obd.data.voltage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = _points.where((e) => e.time.isAfter(now.subtract(Duration(seconds: _windowSeconds)))).toList();
    final latest = visible.isEmpty ? null : visible.last.value;
    final min = visible.isEmpty ? null : visible.map((e) => e.value).reduce(math.min);
    final max = visible.isEmpty ? null : visible.map((e) => e.value).reduce(math.max);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.info.withValues(alpha: .28)),
            ),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.show_chart_rounded, color: AppColors.info)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(latest == null ? '--' : '${latest.toStringAsFixed(_digits(latest))} ${widget.unit}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.8)),
              ])),
              _LivePill(),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [30, 120, 600].map((seconds) {
            final selected = _windowSeconds == seconds;
            final label = seconds == 30 ? tx('30 sn') : seconds == 120 ? tx('2 dk') : tx('10 dk');
            return Expanded(child: Padding(padding: EdgeInsets.only(right: seconds == 600 ? 0 : 8), child: InkWell(
              onTap: () => setState(() => _windowSeconds = seconds),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: selected ? AppColors.info.withValues(alpha: .15) : Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppColors.info : Theme.of(context).colorScheme.outlineVariant)), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? AppColors.info : Colors.white54, fontWeight: FontWeight.w900, fontSize: 11))),
            )));
          }).toList()),
          const SizedBox(height: 14),
          Expanded(child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF101114), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: visible.length < 2 ? Center(child: Text(tx('Canlı veri bekleniyor...'), style: TextStyle(color: Colors.white38))) : CustomPaint(painter: _LineChartPainter(visible)),
          )),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatBox(label: tx('EN DÜŞÜK'), value: min == null ? '--' : '${min.toStringAsFixed(_digits(min))} ${widget.unit}')),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(label: tx('EN YÜKSEK'), value: max == null ? '--' : '${max.toStringAsFixed(_digits(max))} ${widget.unit}')),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(label: tx('ÖRNEK'), value: '${visible.length}')),
          ]),
        ]),
      ),
    );
  }

  int _digits(double value) => widget.metric == LivePidMetric.boost || widget.metric == LivePidMetric.voltage || widget.metric == LivePidMetric.fuelRate || widget.metric == LivePidMetric.maf ? 1 : 0;
}

class _Point { const _Point(this.time, this.value); final DateTime time; final double value; }

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.points);
  final List<_Point> points;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((e) => e.value).toList();
    var minV = values.reduce(math.min), maxV = values.reduce(math.max);
    if ((maxV - minV).abs() < .001) { maxV += 1; minV -= 1; }
    final grid = Paint()..color = Colors.white.withValues(alpha: .06)..strokeWidth = 1;
    for (var i = 1; i < 5; i++) canvas.drawLine(Offset(0, size.height * i / 5), Offset(size.width, size.height * i / 5), grid);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - ((points[i].value - minV) / (maxV - minV)) * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    final glow = Paint()..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = AppColors.info.withValues(alpha: .15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glow);
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = AppColors.info;
    canvas.drawPath(path, line);
  }
  @override bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.points.length != points.length || (points.isNotEmpty && oldDelegate.points.isNotEmpty && oldDelegate.points.last.value != points.last.value);
}

class _LivePill extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: .10), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.success.withValues(alpha: .45))), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 7, color: AppColors.success), SizedBox(width: 5), Text('CANLI', style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.w900))]));
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value}); final String label, value;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(13), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7.5, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))]));
}
