import 'dart:async';
import 'dart:math';
import '../models/obd_data.dart';

class DemoDataGenerator {
  Timer? _timer;
  final _random = Random();
  int _tick = 0;

  void start(Function(ObdData) onData) {
    stop();
    _tick = 0;
    onData(_generateData());
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) => onData(_generateData()));
  }

  void stop() { _timer?.cancel(); _timer = null; }

  ObdData _generateData() {
    _tick++;
    final wave = sin(_tick / 4.0);
    final rpm = (2050 + wave * 850 + _random.nextInt(180)).round().clamp(800, 4200).toInt();
    final speed = (72 + wave * 24 + _random.nextInt(5)).round().clamp(0, 150).toInt();
    final map = (150 + mathMax(0, wave) * 75 + _random.nextInt(8)).round().clamp(98, 235).toInt();
    return ObdData(
      speed: speed,
      rpm: rpm,
      engineTemp: 90 + _random.nextInt(4),
      voltage: 13.8 + (_random.nextDouble() * .4),
      boostKpa: map,
    );
  }

  double mathMax(double a, double b) => a > b ? a : b;
}
