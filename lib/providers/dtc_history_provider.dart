import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dtc_scan_record.dart';

class DtcHistoryProvider extends ChangeNotifier {
  static const _key = 'otosinyal_dtc_history_v1';
  static const _max = 100;
  List<DtcScanRecord> _items = [];
  List<DtcScanRecord> get items => List.unmodifiable(_items.reversed);

  Map<String, dynamic> exportData() => <String, dynamic>{
        'items': _items.map((item) => item.toMap()).toList(growable: false),
      };

  Future<void> importData(Map<String, dynamic> data) async {
    try {
      final rawItems = data['items'];
      final imported = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => DtcScanRecord.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : <DtcScanRecord>[];
      _items = imported.length > _max
          ? imported.sublist(imported.length - _max)
          : imported;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, DtcScanRecord.encodeList(_items));
    } catch (_) {}
  }

  DtcHistoryProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _items = DtcScanRecord.decodeList(prefs.getString(_key) ?? '[]');
    notifyListeners();
  }

  Future<void> add(DtcScanRecord item) async {
    _items.add(item);
    if (_items.length > _max) _items = _items.sublist(_items.length - _max);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DtcScanRecord.encodeList(_items));
  }

  List<DtcScanRecord> forVehicle(String? id) => items.where((e) => e.vehicleId == id).toList();
}
