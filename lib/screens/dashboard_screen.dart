import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/providers/units_provider.dart';
import 'package:otosinyal_obd2/screens/advanced_diagnostics_screen.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final units = context.watch<UnitsProvider>();
    final data = obd.data;
    final live = obd.isRealMode || obd.isDemoMode;

    final boostText = data.boostKpa == null
        ? '--'
        : obd.barometricKpa == null
            ? '${data.boostKpa}'
            : '${((data.boostKpa! - obd.barometricKpa!) / 100).toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            children: [
              const _DashboardHeader(),
              const SizedBox(height: 10),
              const _SectionTabs(),
              const SizedBox(height: 10),
              Expanded(
                child: live
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _GaugeMetric(
                                    label: tx('Hız'),
                                    value: '${units.displaySpeed(data.speed)}',
                                    unit: units.speedUnit,
                                    progress: units.displaySpeed(data.speed) / (units.isMetric ? 240 : 150),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _GaugeMetric(
                                    label: tx('Motor Devri'),
                                    value: '${data.rpm}',
                                    unit: 'rpm',
                                    progress: data.rpm / 8000,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _GaugeMetric(
                                    label: tx('Motor Sıcaklığı'),
                                    value: '${units.displayTemp(data.engineTemp)}',
                                    unit: units.tempUnit,
                                    progress: data.engineTemp / 130,
                                    warning: data.engineTemp > 105,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _GaugeMetric(
                                    label: tx('Emme Manifoldu'),
                                    value: boostText,
                                    unit: obd.barometricKpa == null ? 'kPa' : 'bar',
                                    progress: data.boostKpa == null ? 0 : data.boostKpa! / 250,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _ValueMetric(
                                    label: tx('Akü Voltajı'),
                                    value: data.voltage.toStringAsFixed(1),
                                    unit: 'V',
                                    icon: Icons.battery_charging_full_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ValueMetric(
                                    label: tx('Protokol'),
                                    value: obd.protocolName?.isNotEmpty == true ? obd.protocolName! : '--',
                                    unit: '',
                                    icon: Icons.cable_rounded,
                                    smallValue: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _ValueMetric(
                                    label: tx('Motor Durumu'),
                                    value: obd.milOn == null ? '--' : (obd.milOn! ? tx('KONTROL GEREKLİ') : tx('SORUN YOK')),
                                    unit: '',
                                    icon: Icons.warning_amber_rounded,
                                    accent: obd.milOn == true ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ValueMetric(
                                    label: tx('DTC Sayısı'),
                                    value: '${obd.dtcEntries.length}',
                                    unit: tx('kod'),
                                    icon: Icons.fact_check_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const _NotLive(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: Colors.white70),
          const Spacer(),
          const Text(
            'Dashboard',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Icon(Icons.notifications_none_rounded, size: 21, color: Colors.white.withValues(alpha: .75)),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF211B1C))),
      ),
      child: Row(
        children: [
          Expanded(child: _Tab(label: tx('CANLI VERİLER'), active: true)),
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdvancedDiagnosticsScreen()),
              ),
              child: _Tab(label: tx('GELİŞMİŞ TEŞHİS'), active: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: active ? AppColors.accentBright : Colors.transparent, width: 2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.accentBright : Colors.white38,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _GaugeMetric extends StatelessWidget {
  const _GaugeMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    this.warning = false,
  });

  final String label;
  final String value;
  final String unit;
  final double progress;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.warning : AppColors.accentBright;
    return Container(
      height: 124,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: warning ? AppColors.warning.withValues(alpha: .45) : const Color(0xFF2D2425)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          Center(
            child: SizedBox(
              width: 96,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(96, 64),
                    painter: _DashboardArcPainter(progress.clamp(0.0, 1.0), color),
                  ),
                  Positioned(
                    top: 25,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(value, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -1)),
                        const SizedBox(width: 3),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardArcPainter extends CustomPainter {
  const _DashboardArcPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 8, size.width - 20, size.height - 18);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF392527);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color;
    const start = 3.45;
    const sweep = 2.73;
    canvas.drawArc(rect, start, sweep, false, bg);
    canvas.drawArc(rect, start, sweep * progress, false, fg);
    final tick = Paint()..strokeWidth = 1.1..color = Colors.white24;
    for (var i = 0; i <= 12; i++) {
      final a = start + sweep * (i / 12);
      final c = rect.center;
      final r1 = rect.width / 2 - 1;
      final r2 = r1 + 3;
      canvas.drawLine(Offset(c.dx + r1 * math.cos(a), c.dy - r1 * math.sin(a)), Offset(c.dx + r2 * math.cos(a), c.dy - r2 * math.sin(a)), tick);
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardArcPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}


class _ValueMetric extends StatelessWidget {
  const _ValueMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.accent = AppColors.accentBright,
    this.smallValue = false,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  final bool smallValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF111010),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF302426)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent == AppColors.accentBright ? Colors.white : accent, fontSize: smallValue ? 13 : 24, fontWeight: FontWeight.w800),
                ),
              ),
              if (unit.isNotEmpty) Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotLive extends StatelessWidget {
  const _NotLive();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111010),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF302426)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed_rounded, color: AppColors.accentBright, size: 46),
            SizedBox(height: 12),
            Text(tx('Canlı veri yok'), style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text(tx('Ana sayfadan ECU bağlantısını başlat veya demo modunu aç.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
