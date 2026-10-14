import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/maintenance_reminder.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class MaintenanceProvider extends ChangeNotifier {
  static const _key = 'otosinyal_maintenance_v1';
  List<MaintenanceReminder> _items = const [];
  List<MaintenanceReminder> get items => List.unmodifiable(_items);
  List<MaintenanceReminder> get dueItems => _items.where((e) => e.isDue).toList(growable: false);
  MaintenanceProvider() { _load(); }
  static const _defaults = <MaintenanceReminder>[MaintenanceReminder(id: 'oil', title: tx('Motor yağı ve filtre'), intervalDays: 365), MaintenanceReminder(id: 'brake', title: tx('Fren ve lastik kontrolü'), intervalDays: 180), MaintenanceReminder(id: 'air', title: tx('Hava filtresi'), intervalDays: 365), MaintenanceReminder(id: 'coolant', title: tx('Soğutma sıvısı'), intervalDays: 730), MaintenanceReminder(id: 'timing', title: tx('Triger / zincir kontrolü'), intervalDays: 1825)];
  Map<String, dynamic> exportData() => {'items': _items.map((e) => e.toMap()).toList(growable: false)};
  Future<void> importData(Map<String, dynamic> data) async { final raw = data['items']; if (raw is! List) return; _items = raw.whereType<Map>().map((e) => MaintenanceReminder.fromMap(Map<String, dynamic>.from(e))).where((e) => e.id.isNotEmpty).toList(); notifyListeners(); await _persist(); }
  Future<void> complete(String id) async { _items = _items.map((e) => e.id == id ? e.complete() : e).toList(growable: false); notifyListeners(); await _persist(); }
  Future<void> _load() async { final prefs = await SharedPreferences.getInstance(); final raw = prefs.getString(_key); if (raw == null) { _items = _defaults; } else { try { _items = (jsonDecode(raw) as List).whereType<Map>().map((e) => MaintenanceReminder.fromMap(Map<String, dynamic>.from(e))).toList(); } catch (_) { _items = _defaults; } } notifyListeners(); }
  Future<void> _persist() async => (await SharedPreferences.getInstance()).setString(_key, jsonEncode(_items.map((e) => e.toMap()).toList()));
}
