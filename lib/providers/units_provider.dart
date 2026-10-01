import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hız/sıcaklık birimlerini (metrik/emperyal) yönetir ve cihazda saklar.
/// Uygulama içi tüm veri (ObdData, TripLog vb.) HER ZAMAN metrik (km/h, °C)
/// olarak tutulur — bu sınıf sadece EKRANDA gösterirken çeviri yapar.
class UnitsProvider extends ChangeNotifier {
  static const _key = 'otosinyal_units_is_metric';

  bool _isMetric = true;
  bool get isMetric => _isMetric;

  Map<String, dynamic> exportData() => <String, dynamic>{'isMetric': _isMetric};

  Future<void> importData(Map<String, dynamic> data) async {
    final value = data['isMetric'];
    if (value is! bool) return;
    _isMetric = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, _isMetric);
    } catch (_) {}
  }

  UnitsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMetric = prefs.getBool(_key) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle() async {
    _isMetric = !_isMetric;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, _isMetric);
    } catch (_) {}
  }

  // --- Çeviri yardımcıları ---

  String get speedUnit => _isMetric ? 'km/h' : 'mph';
  String get tempUnit => _isMetric ? '°C' : '°F';
  String get pressureUnit => 'kPa'; // basınç her zaman kPa gösterilir

  int displaySpeed(int kmh) => _isMetric ? kmh : (kmh * 0.621371).round();
  int displayTemp(int celsius) =>
      _isMetric ? celsius : (celsius * 9 / 5 + 32).round();
}
