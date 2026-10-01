import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RecoveredVagPlatform {
  final String id;
  final String title;
  final String description;

  const RecoveredVagPlatform({
    required this.id,
    required this.title,
    required this.description,
  });
}

class RecoveredVagCatalogSummary {
  final int dtcCount;
  final int platformCount;
  final int lightFunctionCount;
  final int lightTypeCount;
  final int opaqueResourceCount;
  final int normalizedAdaptationCount;
  final String recoverySourceSha256;
  final bool legacyRuntimeDeserializationEnabled;
  final bool recoveredOpaqueWritesEnabled;
  final List<String> readerAnchors;

  const RecoveredVagCatalogSummary({
    required this.dtcCount,
    required this.platformCount,
    required this.lightFunctionCount,
    required this.lightTypeCount,
    required this.opaqueResourceCount,
    required this.normalizedAdaptationCount,
    required this.recoverySourceSha256,
    required this.legacyRuntimeDeserializationEnabled,
    required this.recoveredOpaqueWritesEnabled,
    required this.readerAnchors,
  });
}

/// Read-only bridge for data recovered from the old VAG application build.
///
/// Important: opaque legacy adaptation databases are deliberately NOT
/// deserialized in the production Flutter runtime. Only deterministic,
/// normalized assets are loaded here. Write-capable recipes remain guarded by
/// the normal OTOSİNYAL identity + backup + verify + rollback path.
class RecoveredVagCatalogService {
  static const _base = 'assets/data/vag_recovered';

  static RecoveredVagCatalogSummary? _summaryCache;
  static List<RecoveredVagPlatform>? _platformCache;
  static Map<String, String>? _dtcCache;
  static Map<String, String>? _lightFunctionCache;
  static Map<String, String>? _lightTypeCache;

  static Future<Map<String, dynamic>> _json(String file) async {
    final raw = await rootBundle.loadString('$_base/$file');
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<RecoveredVagCatalogSummary> loadSummary() async {
    final cached = _summaryCache;
    if (cached != null) return cached;
    final map = await _json('recovery_manifest_v1.json');
    final decoded = Map<String, dynamic>.from(map['decoded'] as Map? ?? const {});
    final policy = Map<String, dynamic>.from(map['policy'] as Map? ?? const {});
    final assembly = Map<String, dynamic>.from(map['assembly'] as Map? ?? const {});
    final anchors = Map<String, dynamic>.from(assembly['anchors'] as Map? ?? const {});
    final result = RecoveredVagCatalogSummary(
      dtcCount: (decoded['vagDtcRecords'] as num?)?.toInt() ?? 0,
      platformCount: (decoded['platformRecords'] as num?)?.toInt() ?? 0,
      lightFunctionCount: (decoded['mqbLightFunctionRecords'] as num?)?.toInt() ?? 0,
      lightTypeCount: (decoded['mqbLightTypeRecords'] as num?)?.toInt() ?? 0,
      opaqueResourceCount: (map['opaqueResources'] as List?)?.length ?? 0,
      normalizedAdaptationCount: (decoded['recoveredAdaptationRecords'] as num?)?.toInt() ?? 746,
      recoverySourceSha256: '${map['recoverySourceSha256'] ?? ''}',
      legacyRuntimeDeserializationEnabled: policy['runtimeLegacyDeserialization'] == true,
      recoveredOpaqueWritesEnabled: policy['writesFromRecoveredOpaqueCatalogEnabled'] == true,
      readerAnchors: anchors.entries.where((e) => e.value == true).map((e) => e.key).toList(growable: false),
    );
    _summaryCache = result;
    return result;
  }

  static Future<List<RecoveredVagPlatform>> loadPlatforms() async {
    final cached = _platformCache;
    if (cached != null) return cached;
    final map = await _json('vag_platforms_v1.json');
    final rows = (map['records'] as List? ?? const []);
    final result = rows.whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      return RecoveredVagPlatform(
        id: '${row['VL'] ?? ''}'.trim(),
        title: '${row['TTL'] ?? row['VL'] ?? ''}'.trim(),
        description: '${row['DSC'] ?? ''}'.trim(),
      );
    }).where((e) => e.id.isNotEmpty).toList(growable: false);
    _platformCache = result;
    return result;
  }

  static Future<String?> lookupDtc(String code) async {
    _dtcCache ??= await _loadValueMap('vag_dtc_catalog_v1.json', key: 'code', value: 'description');
    return _dtcCache![code.trim().toUpperCase()];
  }

  static Future<Map<String, String>> loadMqbLightFunctions() async {
    _lightFunctionCache ??= await _loadValueMap('mqb_light_functions_v1.json', key: 'VL', value: 'TTL');
    return Map.unmodifiable(_lightFunctionCache!);
  }

  static Future<Map<String, String>> loadMqbLightTypes() async {
    _lightTypeCache ??= await _loadValueMap('mqb_light_types_v1.json', key: 'VL', value: 'TTL');
    return Map.unmodifiable(_lightTypeCache!);
  }

  static Future<Map<String, String>> _loadValueMap(
    String file, {
    required String key,
    required String value,
  }) async {
    final map = await _json(file);
    final rows = map['records'] as List? ?? const [];
    final result = <String, String>{};
    for (final raw in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final k = '${row[key] ?? ''}'.trim().toUpperCase();
      final v = '${row[value] ?? ''}'.trim();
      if (k.isNotEmpty && v.isNotEmpty) result[k] = v;
    }
    return result;
  }
}
