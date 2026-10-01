import 'dart:convert';

enum FuelType {
  gasoline,
  diesel,
  hybrid,
  lpg;

  String get label {
    switch (this) {
      case FuelType.gasoline:
        return 'Benzin';
      case FuelType.diesel:
        return 'Dizel';
      case FuelType.hybrid:
        return 'Hibrit';
      case FuelType.lpg:
        return 'LPG';
    }
  }

  static FuelType fromName(String? name) {
    return FuelType.values.firstWhere(
      (f) => f.name == name,
      orElse: () => FuelType.gasoline,
    );
  }
}

class Vehicle {
  final String id;
  final String brand;
  final String model;
  final String plate;
  final int? year;
  final FuelType fuelType;
  final String generation;
  final String engine;
  final String engineCode;
  final String transmission;
  final String vin;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.plate,
    this.year,
    this.fuelType = FuelType.gasoline,
    this.generation = '',
    this.engine = '',
    this.engineCode = '',
    this.transmission = '',
    this.vin = '',
  });

  String get displayName => '$brand $model'.trim();

  String get profileSummary {
    final parts = <String>[
      if (generation.trim().isNotEmpty) generation.trim(),
      if (engine.trim().isNotEmpty) engine.trim(),
      if (engineCode.trim().isNotEmpty) engineCode.trim(),
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'brand': brand,
        'model': model,
        'plate': plate,
        'year': year,
        'fuelType': fuelType.name,
        'generation': generation,
        'engine': engine,
        'engineCode': engineCode,
        'transmission': transmission,
        'vin': vin,
      };

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: (map['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      plate: map['plate'] as String? ?? '',
      year: map['year'] is num ? (map['year'] as num).toInt() : int.tryParse('${map['year'] ?? ''}'),
      fuelType: FuelType.fromName(map['fuelType'] as String?),
      generation: map['generation'] as String? ?? '',
      engine: map['engine'] as String? ?? '',
      engineCode: map['engineCode'] as String? ?? '',
      transmission: map['transmission'] as String? ?? '',
      vin: map['vin'] as String? ?? '',
    );
  }

  static String encodeList(List<Vehicle> vehicles) {
    return jsonEncode(vehicles.map((v) => v.toMap()).toList());
  }

  static List<Vehicle> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Vehicle.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
