class ObdData {
  final int rpm;
  final int speed;
  final int engineTemp;
  final double voltage;
  final int? boostKpa; // Manifold mutlak basıncı (MAP, PID 0B)

  const ObdData({
    this.rpm = 0,
    this.speed = 0,
    this.engineTemp = 0,
    this.voltage = 0.0,
    this.boostKpa,
  });

  ObdData copyWith({
    int? rpm,
    int? speed,
    int? engineTemp,
    double? voltage,
    int? boostKpa,
  }) {
    return ObdData(
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      engineTemp: engineTemp ?? this.engineTemp,
      voltage: voltage ?? this.voltage,
      boostKpa: boostKpa ?? this.boostKpa,
    );
  }

  @override
  String toString() {
    return 'ObdData(rpm: $rpm, speed: $speed km/h, temp: $engineTemp°C, voltage: $voltage V, map: $boostKpa kPa)';
  }
}
