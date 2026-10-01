import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class OemEcuDefinition {
  final String address;
  final String name;
  final String commonName;
  const OemEcuDefinition({required this.address, required this.name, required this.commonName});
}

class OemDidDefinition {
  final String did;
  final String name;
  final String description;
  final String? ecuAddress;
  final String decoderKind;
  final String? unit;
  final bool verified;
  const OemDidDefinition({required this.did, required this.name, required this.description, this.ecuAddress, required this.decoderKind, this.unit, required this.verified});
}

class OemDtcInfo {
  final String code;
  final String description;
  final String severity;
  final bool verified;
  final List<String> possibleCauses;
  const OemDtcInfo({required this.code, required this.description, required this.severity, required this.verified, required this.possibleCauses});
}

class OemCatalogSummary {
  final String key;
  final String displayName;
  final int ecuCount;
  final int didCount;
  final int verifiedDidCount;
  final int routineCount;
  final List<OemEcuDefinition> ecus;
  const OemCatalogSummary({required this.key, required this.displayName, required this.ecuCount, required this.didCount, required this.verifiedDidCount, required this.routineCount, required this.ecus});
}

class OemDiagnosticCatalog {
  static const Map<String, String> _brandFiles = {
    'volkswagen': 'vw', 'audi': 'vw', 'skoda': 'vw', 'škoda': 'vw', 'seat': 'vw', 'cupra': 'vw', 'porsche': 'vw',
    'bmw': 'bmw', 'mini': 'bmw',
    'mercedes': 'mercedes', 'mercedes-benz': 'mercedes',
    'ford': 'ford',
    'toyota': 'toyota', 'lexus': 'toyota',
    'hyundai': 'hmg', 'kia': 'hmg', 'genesis': 'hmg',
  };

  static final Map<String, Map<String, dynamic>> _catalogCache = {};
  static final Map<String, Map<String, OemDtcInfo>> _dtcCache = {};

  static String? fileKeyForBrand(String? brand) {
    final b = (brand ?? '').trim().toLowerCase();
    if (b.isEmpty) return null;
    for (final e in _brandFiles.entries) {
      if (b.contains(e.key)) return e.value;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _loadCatalog(String key) async {
    if (_catalogCache.containsKey(key)) return _catalogCache[key];
    try {
      final raw = await rootBundle.loadString('assets/data/delphi/$key.json');
      final value = jsonDecode(raw) as Map<String, dynamic>;
      _catalogCache[key] = value;
      return value;
    } catch (_) { return null; }
  }

  static Future<OemCatalogSummary?> summaryForBrand(String? brand) async {
    final key = fileKeyForBrand(brand);
    if (key == null) return null;
    final c = await _loadCatalog(key);
    if (c == null) return null;
    final ecuRaw = (c['ecus'] as List?) ?? const [];
    final didRaw = (c['dids'] as List?) ?? const [];
    final routineRaw = (c['routines'] as List?) ?? const [];
    final ecus = ecuRaw.take(200).whereType<Map>().map((e) => OemEcuDefinition(
      address: '${e['address'] ?? '-'}', name: '${e['name'] ?? 'ecu'}', commonName: '${e['common_name'] ?? e['name'] ?? 'ECU'}',
    )).toList(growable: false);
    final verified = didRaw.whereType<Map>().where((e) => e['verified'] == true).length;
    return OemCatalogSummary(key:key, displayName:'${c['display_name'] ?? key.toUpperCase()}', ecuCount:ecuRaw.length, didCount:didRaw.length, verifiedDidCount:verified, routineCount:routineRaw.length, ecus:ecus);
  }

  static Future<List<OemDidDefinition>> didsForBrand(String? brand, {int limit = 80}) async {
    final key = fileKeyForBrand(brand); if (key == null) return const [];
    final c = await _loadCatalog(key); if (c == null) return const [];
    final raw = (c['dids'] as List?) ?? const [];
    return raw.whereType<Map>().take(limit).map((e) {
      final decoder = e['decoder'] is Map ? e['decoder'] as Map : const {};
      return OemDidDefinition(did:'${e['did'] ?? ''}', name:'${e['name'] ?? ''}', description:'${e['description'] ?? ''}', ecuAddress:e['ecu_address']?.toString(), decoderKind:'${decoder['kind'] ?? 'hex'}', unit:decoder['unit']?.toString(), verified:e['verified'] == true);
    }).toList(growable:false);
  }

  static Future<Map<String, OemDtcInfo>> _loadDtc(String key) async {
    if (_dtcCache.containsKey(key)) return _dtcCache[key]!;
    try {
      final raw = await rootBundle.loadString('assets/data/delphi/dtc-$key.json');
      final root = jsonDecode(raw) as Map<String,dynamic>;
      final result = <String,OemDtcInfo>{};
      for (final item in ((root['dtcs'] as List?) ?? const []).whereType<Map>()) {
        final code='${item['code'] ?? ''}'.toUpperCase(); if(code.isEmpty) continue;
        result[code]=OemDtcInfo(code:code,description:'${item['description'] ?? ''}',severity:'${item['severity'] ?? 'unknown'}',verified:item['verified']==true,possibleCauses:((item['possible_causes'] as List?)??const[]).map((e)=>e.toString()).toList(growable:false));
      }
      _dtcCache[key]=result; return result;
    } catch (_) { return const {}; }
  }

  static Future<OemDtcInfo?> lookupDtc(String code, String? brand) async {
    final key=fileKeyForBrand(brand); if(key==null) return null;
    return (await _loadDtc(key))[code.trim().toUpperCase()];
  }
}
