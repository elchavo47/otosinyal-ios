import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coding_backup_record.dart';

class CodingHistoryProvider extends ChangeNotifier {
  static const _storageKey = 'otosinyal_coding_history_v1';
  static const _maxRecords = 150;
  final List<CodingBackupRecord> _records = [];

  CodingHistoryProvider() { _load(); }

  List<CodingBackupRecord> get records => List.unmodifiable(_records);
  List<CodingBackupRecord> forVin(String? vin) => vin == null
      ? const []
      : _records.where((record) => record.vin == vin).toList(growable: false);

  Future<void> capture(CodingBackupRecord record) async {
    if (record.vin.length != 17 || record.originalHex.isEmpty) {
      throw const FormatException('Kodlama yedeği için VIN ve mevcut ECU değeri zorunludur');
    }
    _records.removeWhere((item) => item.id == record.id);
    _records.insert(0, record);
    if (_records.length > _maxRecords) _records.removeRange(_maxRecords, _records.length);
    await _persist();
    notifyListeners();
  }

  Future<void> updateStatus(
    String id,
    CodingBackupStatus status, {
    String? requestedHex,
    String? verifiedHex,
  }) async {
    final index = _records.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _records[index] = _records[index].copyWith(
      status: status,
      requestedHex: requestedHex,
      verifiedHex: verifiedHex,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  Map<String, dynamic> exportData() => {
    'version': 1,
    'records': _records.map((record) => record.toMap()).toList(),
  };

  Future<void> importData(Map<String, dynamic> data) async {
    final raw = data['records'];
    if (raw is! List) return;
    final parsed = raw.whereType<Map>().map((item) => CodingBackupRecord.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.vin.length == 17 && item.originalHex.isNotEmpty)
        .take(_maxRecords)
        .toList();
    _records
      ..clear()
      ..addAll(parsed);
    await _persist();
    notifyListeners();
  }

  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) await importData(Map<String, dynamic>.from(decoded));
    } catch (_) {}
  }

  Future<void> _persist() async {
    await (await SharedPreferences.getInstance()).setString(_storageKey, jsonEncode(exportData()));
  }
}
