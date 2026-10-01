import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otosinyal_obd2/models/vehicle.dart';
import 'package:otosinyal_obd2/services/vin_decoder.dart';

/// Garajdaki kayıtlı araçları yönetir ve cihazda kalıcı olarak saklar
/// (SharedPreferences — uygulama kapatılıp açılsa da kaybolmaz).
class GarageProvider extends ChangeNotifier {
  static const _storageKey = 'otosinyal_garage_vehicles';

  List<Vehicle> _vehicles = [];
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);

  String? _activeVehicleId;
  String? get activeVehicleId => _activeVehicleId;

  Vehicle? get activeVehicle {
    if (_activeVehicleId == null) return null;
    for (final v in _vehicles) {
      if (v.id == _activeVehicleId) return v;
    }
    return null;
  }

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Map<String, dynamic> exportData() => <String, dynamic>{
        'vehicles': _vehicles.map((vehicle) => vehicle.toMap()).toList(growable: false),
        'activeVehicleId': _activeVehicleId,
      };

  Future<void> importData(Map<String, dynamic> data) async {
    try {
      final rawVehicles = data['vehicles'];
      final vehicles = rawVehicles is List
          ? rawVehicles
              .whereType<Map>()
              .map((item) => Vehicle.fromMap(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <Vehicle>[];
      _vehicles = vehicles;
      final requestedActive = data['activeVehicleId'] as String?;
      _activeVehicleId = requestedActive != null && _vehicles.any((v) => v.id == requestedActive)
          ? requestedActive
          : (_vehicles.isNotEmpty ? _vehicles.first.id : null);
      notifyListeners();
      await _persist();
    } catch (_) {
      // Malformed backup never destroys the current garage.
    }
  }

  GarageProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        _vehicles = Vehicle.decodeList(raw);
      }
      _activeVehicleId = prefs.getString('${_storageKey}_active');
      if (_activeVehicleId != null &&
          !_vehicles.any((v) => v.id == _activeVehicleId)) {
        _activeVehicleId = null;
      }
    } catch (_) {
      _vehicles = [];
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, Vehicle.encodeList(_vehicles));
      if (_activeVehicleId != null) {
        await prefs.setString('${_storageKey}_active', _activeVehicleId!);
      } else {
        await prefs.remove('${_storageKey}_active');
      }
    } catch (_) {
      // Kalıcı kayıt başarısız olsa da uygulama içi state ile devam eder
    }
  }

  Future<void> addVehicle({
    required String brand,
    required String model,
    required String plate,
    int? year,
    FuelType fuelType = FuelType.gasoline,
    String generation = '',
    String engine = '',
    String engineCode = '',
    String transmission = '',
    String vin = '',
  }) async {
    final vehicle = Vehicle(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      brand: brand.trim(),
      model: model.trim(),
      plate: plate.trim(),
      year: year,
      fuelType: fuelType,
      generation: generation.trim(),
      engine: engine.trim(),
      engineCode: engineCode.trim(),
      transmission: transmission.trim(),
      vin: vin.trim().toUpperCase(),
    );

    _vehicles = [..._vehicles, vehicle];
    _activeVehicleId ??= vehicle.id; // ilk eklenen araç otomatik aktif olsun
    notifyListeners();
    await _persist();
  }

  /// VIN okunduktan sonra araç profilini otomatik oluşturur veya günceller.
  /// Aynı VIN tekrar bağlanınca garajda kopya araç oluşturulmaz.
  Future<void> upsertDetectedVehicle({
    required String vin,
    String? brand,
  }) async {
    final cleanVin = vin.trim().toUpperCase();
    if (cleanVin.length != 17) return;
    final existingIndex = _vehicles.indexWhere((v) => v.vin == cleanVin);
    final resolvedBrand = (brand == null || brand.trim().isEmpty) ? 'Tanımsız Marka' : brand.trim();
    if (existingIndex >= 0) {
      final old = _vehicles[existingIndex];
      _vehicles[existingIndex] = Vehicle(
        id: old.id,
        brand: resolvedBrand,
        model: old.model.isEmpty ? 'VIN ile algılandı' : old.model,
        plate: old.plate,
        year: old.year ?? VinDecoder.modelYear(cleanVin),
        fuelType: old.fuelType,
        generation: old.generation,
        engine: old.engine,
        engineCode: old.engineCode,
        transmission: old.transmission,
        vin: cleanVin,
      );
      _activeVehicleId = old.id;
    } else {
      final vehicle = Vehicle(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        brand: resolvedBrand,
        model: 'VIN ile algılandı',
        plate: '',
        year: VinDecoder.modelYear(cleanVin),
        vin: cleanVin,
      );
      _vehicles = [..._vehicles, vehicle];
      _activeVehicleId = vehicle.id;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeVehicle(String id) async {
    _vehicles = _vehicles.where((v) => v.id != id).toList();
    if (_activeVehicleId == id) {
      _activeVehicleId = _vehicles.isNotEmpty ? _vehicles.first.id : null;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setActiveVehicle(String id) async {
    _activeVehicleId = id;
    notifyListeners();
    await _persist();
  }
}
