import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otosinyal_obd2/models/trip_log.dart';

/// Geçmiş sürüş oturumlarını (trip log) cihazda kalıcı olarak saklar.
class TripLogProvider extends ChangeNotifier {
  static const _key = 'otosinyal_trip_logs';
  static const _maxStored = 200; // çok şişmesin diye üst limit

  List<TripLog> _trips = [];
  List<TripLog> get trips => List.unmodifiable(_trips.reversed);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Map<String, dynamic> exportData() => <String, dynamic>{
        'trips': _trips.map((trip) => trip.toMap()).toList(growable: false),
      };

  Future<void> importData(Map<String, dynamic> data) async {
    try {
      final rawTrips = data['trips'];
      final imported = rawTrips is List
          ? rawTrips
              .whereType<Map>()
              .map((item) => TripLog.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : <TripLog>[];
      if (imported.length > _maxStored) {
        _trips = imported.sublist(imported.length - _maxStored);
      } else {
        _trips = imported;
      }
      notifyListeners();
      await _persist();
    } catch (_) {}
  }

  TripLogProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _trips = TripLog.decodeList(raw);
      }
    } catch (_) {
      _trips = [];
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> addTrip(TripLog trip) async {
    _trips.add(trip);
    if (_trips.length > _maxStored) {
      _trips = _trips.sublist(_trips.length - _maxStored);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _trips = [];
    notifyListeners();
    await _persist();
  }

  List<TripLog> tripsForVehicle(String? vehicleId) {
    return trips.where((t) => t.vehicleId == vehicleId).toList();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, TripLog.encodeList(_trips));
    } catch (_) {}
  }
}
