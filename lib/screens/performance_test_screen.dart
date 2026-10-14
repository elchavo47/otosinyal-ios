import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class PerformanceTestScreen extends StatefulWidget {
  const PerformanceTestScreen({super.key});

  @override
  State<PerformanceTestScreen> createState() => _PerformanceTestScreenState();
}

class _RunPreset {
  final int start;
  final int target;
  const _RunPreset(this.start, this.target);
  String get label => '$start-$target';
}

class _PerformanceRecord {
  final String id;
  final int start;
  final int target;
  final double seconds;
  final double maxObd;
  final double? maxGps;
  final double? finishObd;
  final double? finishGps;
  final DateTime createdAt;

  const _PerformanceRecord({
    required this.id,
    required this.start,
    required this.target,
    required this.seconds,
    required this.maxObd,
    required this.maxGps,
    required this.finishObd,
    required this.finishGps,
    required this.createdAt,
  });

  String get label => '$start-$target';

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'target': target,
        'seconds': seconds,
        'maxObd': maxObd,
        'maxGps': maxGps,
        'finishObd': finishObd,
        'finishGps': finishGps,
        'createdAt': createdAt.toIso8601String(),
      };

  factory _PerformanceRecord.fromJson(Map<String, dynamic> json) => _PerformanceRecord(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        start: (json['start'] as num?)?.toInt() ?? 0,
        target: (json['target'] as num?)?.toInt() ?? 100,
        seconds: (json['seconds'] as num?)?.toDouble() ?? 0,
        maxObd: (json['maxObd'] as num?)?.toDouble() ?? 0,
        maxGps: (json['maxGps'] as num?)?.toDouble(),
        finishObd: (json['finishObd'] as num?)?.toDouble(),
        finishGps: (json['finishGps'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class _PerformanceTestScreenState extends State<PerformanceTestScreen> {
  static const _historyKey = 'performance_test_history_v2';
  static const presets = [
    _RunPreset(0, 100),
    _RunPreset(60, 100),
    _RunPreset(80, 120),
    _RunPreset(100, 200),
  ];

  _RunPreset preset = presets.first;
  StreamSubscription<Position>? posSub;
  Timer? timer;
  double? gps;
  double maxObd = 0;
  double maxGps = 0;
  double? _lastSpeed;
  String _timingSource = 'AUTO';
  bool armed = false;
  bool running = false;
  bool accepted = false;
  bool _saving = false;
  final Stopwatch sw = Stopwatch();
  double? result;
  String status = tx('Hazır');
  List<_PerformanceRecord> history = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    posSub?.cancel();
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => _PerformanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => history = list);
    } catch (_) {}
  }

  Future<void> _persistHistory(List<_PerformanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(records.take(30).map((e) => e.toJson()).toList()));
  }

  Future<bool> _gps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => status = tx('GPS kapalı • OBD hızı kullanılacak'));
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      if (mounted) setState(() => status = tx('GPS izni yok • OBD hızı kullanılacak'));
      return false;
    }
    await posSub?.cancel();
    posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((x) {
      if (!mounted) return;
      setState(() => gps = math.max(0.0, x.speed * 3.6));
    });
    return true;
  }

  Future<void> arm() async {
    if (!accepted || armed) return;
    await _gps();
    if (!mounted) return;
    result = null;
    maxObd = 0;
    maxGps = 0;
    _lastSpeed = null;
    _timingSource = 'AUTO';
    sw
      ..reset()
      ..stop();
    // V7.32: Test, seçili presetin başlangıç hızını beklemez.
    // Kullanıcı hangi hızda TESTİ BAŞLAT'a basarsa kronometre o anda başlar.
    // Presette yalnızca hedef hız bitiş koşuludur (örn. 0-100 seçiliyken
    // 80 km/h'de başlatılırsa sayaç 100 km/h'ye ulaşıldığı anda durur).
    setState(() {
      armed = true;
      running = true;
      status = tx('ÖLÇÜM başladı • hedef {0} km/h', [preset.target]);
    });
    sw
      ..reset()
      ..start();
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
  }

  bool _obdLooksAlive(ObdProvider provider, double obd) {
    if (!(provider.isRealMode || provider.isDemoMode || provider.isDeviceConnected)) return false;
    // A real 0 km/h reading is valid while stationary. Once either sensor shows movement,
    // an OBD value stuck at zero is treated as stale and GPS may take over.
    if (obd > 0.2) return true;
    final g = gps;
    if (g == null || g < 6) return true;
    return false;
  }

  double _measurementSpeed(ObdProvider provider, double obd, double? currentGps) {
    // Keep a stable timing source. Switching OBD <-> GPS around the start threshold
    // was the main reason some runs never armed/started. Prefer OBD when it is alive;
    // otherwise use GPS. Once the run starts, keep that source unless it clearly dies.
    final obdAlive = _obdLooksAlive(provider, obd);
    final gpsAlive = currentGps != null && currentGps >= 0;

    if (_timingSource == 'OBD') {
      if (obdAlive) return obd;
      if (gpsAlive) {
        _timingSource = 'GPS';
        return currentGps!;
      }
    }
    if (_timingSource == 'GPS') {
      if (gpsAlive) return currentGps!;
      if (obdAlive) {
        _timingSource = 'OBD';
        return obd;
      }
    }

    if (obdAlive) {
      _timingSource = 'OBD';
      return obd;
    }
    if (gpsAlive) {
      _timingSource = 'GPS';
      return currentGps!;
    }
    return obd;
  }

  void _tick() {
    if (!mounted || !armed || _saving) return;
    final o = context.read<ObdProvider>();
    final obd = o.data.speed.toDouble();
    final g = gps;
    maxObd = math.max(maxObd, obd);
    if (g != null) maxGps = math.max(maxGps, g);
    final speed = _measurementSpeed(o, obd, g);
    _lastSpeed = speed;

    if (running && speed >= preset.target) {
      sw.stop();
      timer?.cancel();
      final elapsed = sw.elapsedMicroseconds / 1000000.0;
      setState(() {
        result = elapsed;
        running = false;
        armed = false;
        status = tx('Tamamlandı • otomatik kaydediliyor');
      });
      unawaited(_saveCompletedRun(elapsed, obd, g));
    } else {
      setState(() {});
    }
  }

  Future<void> _saveCompletedRun(double elapsed, double finishObd, double? finishGps) async {
    if (_saving) return;
    _saving = true;
    final record = _PerformanceRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      start: preset.start,
      target: preset.target,
      seconds: elapsed,
      maxObd: maxObd,
      maxGps: gps == null ? null : maxGps,
      finishObd: finishObd,
      finishGps: finishGps,
      createdAt: DateTime.now(),
    );
    final next = [record, ...history].take(30).toList();
    await _persistHistory(next);
    if (!mounted) return;
    setState(() {
      history = next;
      _saving = false;
      status = tx('Tamamlandı • otomatik kaydedildi');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx('{0} km/h • {1} sn otomatik kaydedildi', [record.label, record.seconds.toStringAsFixed(2)])),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void cancel() {
    timer?.cancel();
    sw.stop();
    setState(() {
      armed = false;
      running = false;
        status = tx('İptal edildi');
    });
  }

  Future<void> _deleteRecord(_PerformanceRecord record) async {
    final next = history.where((e) => e.id != record.id).toList();
    setState(() => history = next);
    await _persistHistory(next);
  }

  String _date(DateTime value) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final o = context.watch<ObdProvider>();
    final obd = o.data.speed.toDouble();
    final diff = gps == null ? null : (obd - gps!).abs();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: Text(tx('PERFORMANS TESTİ'), style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.warning.withValues(alpha: .3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety_rounded, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tx('Hızlanma testlerini trafikte yapma. Bu ekran yalnız kapalı pist/özel alan ve güvenli koşullar için tasarlandı.'),
                    style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: accepted,
            onChanged: (v) => setState(() => accepted = v ?? false),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.accent,
            title: Text(
              tx('Kapalı ve güvenli alanda test yapacağımı onaylıyorum'),
              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: presets
                .map((p) => ChoiceChip(
                      selected: preset == p,
                      label: Text('${p.label} km/h'),
                      onSelected: armed
                          ? null
                          : (_) => setState(() {
                                preset = p;
                                result = null;
                                status = tx('Hazır');
                              }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _SpeedCard(tx('OBD HIZI'), obd, 'km/h', AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: _SpeedCard(tx('GPS HIZI'), gps, 'km/h', AppColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    result == null
                        ? (running ? tx('{0} sn', [(sw.elapsedMicroseconds / 1000000).toStringAsFixed(2)]) : tx('--.-- sn'))
                        : tx('{0} sn', [result!.toStringAsFixed(2)]),
                    key: ValueKey('${result ?? running}-${sw.elapsedMilliseconds ~/ 100}'),
                    style: const TextStyle(color: Colors.white, fontSize: 39, fontWeight: FontWeight.w900, letterSpacing: -1.5),
                  ),
                ),
                Text('${preset.label} km/h • $status', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _Mini(tx('GPS↔OBD FARKI'), diff == null ? '—' : '${diff.toStringAsFixed(1)} km/h')),
                    const SizedBox(width: 8),
                    Expanded(child: _Mini('MAX GPS', gps == null ? '—' : '${maxGps.toStringAsFixed(0)} km/h')),
                    const SizedBox(width: 8),
                    Expanded(child: _Mini('MAX OBD', '${maxObd.toStringAsFixed(0)} km/h')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!armed)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: accepted ? arm : null,
                icon: const Icon(Icons.flag_rounded),
                label: Text(tx('TESTİ BAŞLAT • HEDEF {0}', [preset.target]), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            )
          else
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: cancel,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                icon: const Icon(Icons.stop_rounded),
                label: Text(tx('İPTAL ET'), style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            tx('Testi hangi hızda başlatırsan kronometre o anda çalışır. Seçilen testte yalnız hedef hız bitiş koşuludur; örneğin 0-100 testi 80 km/h’de başlatılırsa 100 km/h’ye ulaşıldığı anda otomatik durur ve kaydedilir. Geçerli OBD verisi varsa OBD, gerekirse GPS kullanılır.'),
            style: TextStyle(color: Colors.white38, fontSize: 9, height: 1.45),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text(tx('TEST GEÇMİŞİ'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
              Text('${history.length}/30', style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
              child: Text(tx('Henüz kayıtlı test yok. İlk hedef hıza ulaştığında sonuç burada otomatik oluşacak.'), style: TextStyle(color: Colors.white54, fontSize: 10, height: 1.4)),
            )
          else
            ...history.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.timer_rounded, color: AppColors.accentBright),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx('{0} km/h • {1} sn', [r.label, r.seconds.toStringAsFixed(2)]), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                            '${_date(r.createdAt)} • OBD max ${r.maxObd.toStringAsFixed(0)}${r.maxGps == null ? '' : ' • GPS max ${r.maxGps!.toStringAsFixed(0)}'}',
                            style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tx('Kaydı sil'),
                      onPressed: () => _deleteRecord(r),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 19),
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

class _SpeedCard extends StatelessWidget {
  const _SpeedCard(this.label, this.value, this.unit, this.color);
  final String label, unit;
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(value == null ? '—' : '${value!.toStringAsFixed(1)} $unit', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 6.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800)),
      ]);
}
