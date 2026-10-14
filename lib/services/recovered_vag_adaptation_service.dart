import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:otosinyal_obd2/l10n/tx.dart';

class RecoveredVagOption {
  final String title;
  final String valueSpec;
  final String rawOverride;

  const RecoveredVagOption({
    required this.title,
    required this.valueSpec,
    this.rawOverride = '',
  });
}

class RecoveredVagAdaptation {
  final String platform;
  final String sourceResource;
  final int uid;
  final String name;
  final String description;
  final String innerDescription;
  final String did;
  final String requestId;
  final String responseId;
  final String password;
  final String passwordHints;
  final int valueType;
  final int startByteIndex;
  final int dataLength;
  final double multiplier;
  final double offset;
  final bool signed;
  final bool reverseByteSequence;
  final bool repeat;
  final int group;
  final bool hasCurrentState;
  final String preWrite;
  final String postWrite;
  final List<RecoveredVagOption> options;

  const RecoveredVagAdaptation({
    required this.platform,
    required this.sourceResource,
    required this.uid,
    required this.name,
    required this.description,
    required this.innerDescription,
    required this.did,
    required this.requestId,
    required this.responseId,
    required this.password,
    required this.passwordHints,
    required this.valueType,
    required this.startByteIndex,
    required this.dataLength,
    required this.multiplier,
    required this.offset,
    required this.signed,
    required this.reverseByteSequence,
    required this.repeat,
    required this.group,
    required this.hasCurrentState,
    required this.preWrite,
    required this.postWrite,
    required this.options,
  });

  bool get hasPasswordRequirement => password.trim().isNotEmpty || passwordHints.trim().isNotEmpty;
  bool get hasCustomProcedure => preWrite.trim().isNotEmpty || postWrite.trim().isNotEmpty;
  bool get hasSelectableOptions => options.isNotEmpty;

  String get displayName => RecoveredVagAdaptationService.prettyResource(name);
  String get displayDescription => RecoveredVagAdaptationService.prettyResource(
        description.isNotEmpty ? description : innerDescription,
      );
}


class RecoveredVagAdaptationReadResult {
  final bool success;
  final String message;
  final String? currentHex;
  final String? selectedOptionTitle;
  final List<int>? payload;

  const RecoveredVagAdaptationReadResult({
    required this.success,
    required this.message,
    this.currentHex,
    this.selectedOptionTitle,
    this.payload,
  });
}

class RecoveredVagAdaptationCatalogSummary {
  final int totalRecords;
  final Map<String, int> platformCounts;
  const RecoveredVagAdaptationCatalogSummary(this.totalRecords, this.platformCounts);
}

class RecoveredVagAdaptationService {
  static const _base = 'assets/data/vag_recovered';
  static final Map<String, List<RecoveredVagAdaptation>> _cache = {};

  static final Map<String, String> _files = {
    'MQB': 'recovered_mqb_adaptations_v1.json',
    'PQ26': 'recovered_pq26_adaptations_v1.json',
    'PQ35': 'recovered_pq35_adaptations_v1.json',
    'MLB-A4B9': 'recovered_mlb_a4b9_adaptations_v1.json',
    'MEB': tx('recovered_meb_adaptations_v1.json'),
    'MQB-CAMERA-FUSION': 'recovered_mqb_camera_fusion_adaptations_v1.json',
    'PQ26-NEW-RAPID-2020': 'recovered_pq26_new_rapid_2020_adaptations_v1.json',
    'MQB-SWAP-CUSTOM-CODING': 'recovered_mqb_swap_custom_coding_adaptations_v1.json',
  };

  static List<String> get supportedPlatforms => _files.keys.toList(growable: false);

  static Future<RecoveredVagAdaptationCatalogSummary> loadSummary() async {
    final raw = await rootBundle.loadString('$_base/adaptation_catalog_manifest_v1.json');
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final catalogs = (map['catalogs'] as List? ?? const []);
    final counts = <String, int>{};
    for (final entry in catalogs.whereType<Map>()) {
      final row = Map<String, dynamic>.from(entry);
      counts['${row['platform']}'] = (row['records'] as num?)?.toInt() ?? 0;
    }
    return RecoveredVagAdaptationCatalogSummary(
      (map['totalRecords'] as num?)?.toInt() ?? counts.values.fold(0, (a, b) => a + b),
      counts,
    );
  }

  static Future<List<RecoveredVagAdaptation>> loadPlatform(String platform) async {
    final key = platform.trim().toUpperCase();
    final cached = _cache[key];
    if (cached != null) return cached;
    final file = _files[key];
    if (file == null) return const [];
    final raw = await rootBundle.loadString('$_base/$file');
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final source = '${map['source'] ?? file}';
    final records = <RecoveredVagAdaptation>[];
    for (final entry in (map['records'] as List? ?? const []).whereType<Map>()) {
      final row = Map<String, dynamic>.from(entry);
      final options = <RecoveredVagOption>[];
      for (final optRaw in (row['OPTS'] as List? ?? const []).whereType<Map>()) {
        final opt = Map<String, dynamic>.from(optRaw);
        options.add(RecoveredVagOption(
          title: prettyResource('${opt['TTL'] ?? ''}'),
          valueSpec: '${opt['VL'] ?? ''}'.trim(),
          rawOverride: '${opt['ROVL'] ?? ''}'.trim(),
        ));
      }
      final did = '${row['AD'] ?? ''}'.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
      final request = '${row['RQH'] ?? ''}'.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
      final response = '${row['RSH'] ?? ''}'.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
      if (request.isEmpty || response.isEmpty) continue;
      records.add(RecoveredVagAdaptation(
        platform: key,
        sourceResource: source,
        uid: (row['UID'] as num?)?.toInt() ?? 0,
        name: '${row['NM'] ?? ''}'.trim(),
        description: '${row['DSC'] ?? ''}'.trim(),
        innerDescription: '${row['InnerDescription'] ?? ''}'.trim(),
        did: did,
        requestId: request,
        responseId: response,
        password: '${row['PWD'] ?? ''}'.trim(),
        passwordHints: '${row['PWH'] ?? ''}'.trim(),
        valueType: (row['VT'] as num?)?.toInt() ?? 0,
        startByteIndex: (row['SBI'] as num?)?.toInt() ?? 0,
        dataLength: (row['DL'] as num?)?.toInt() ?? 0,
        multiplier: (row['MUL'] as num?)?.toDouble() ?? 1.0,
        offset: (row['OFS'] as num?)?.toDouble() ?? 0.0,
        signed: row['SIG'] == true,
        reverseByteSequence: row['RBS'] == true,
        repeat: row['RP'] == true,
        group: (row['Group'] as num?)?.toInt() ?? 0,
        hasCurrentState: row['HasCurrentState'] != false,
        preWrite: '${row['PreWrite'] ?? ''}'.trim(),
        postWrite: '${row['PostWrite'] ?? ''}'.trim(),
        options: List.unmodifiable(options),
      ));
    }
    _cache[key] = List.unmodifiable(records);
    return _cache[key]!;
  }

  static String prettyResource(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';
    const common = <String,String>{'RES_ENABLE':tx('Açık'),'RES_DISABLE':tx('Kapalı'),'RES_YES':tx('Evet'),'RES_NO':tx('Hayır')};
    final direct = common[text.toUpperCase()];
    if (direct != null) return direct;
    text = text.replaceFirst(RegExp(r'^RES:'), '');
    text = text.replaceFirst(RegExp(r'^codingDB_opt_'), '');
    text = text.replaceFirst(RegExp(r'^codingDB_'), '');
    text = text.replaceFirst(RegExp(r'_Name$'), '');
    text = text.replaceFirst(RegExp(r'_Description$'), '');
    text = text.replaceAll('_', ' ');
    text = text.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return text.trim();
  }

  static bool isBitSpec(String spec) => spec.trim().toUpperCase().startsWith('BIT:');

  static List<int>? applyOptionToPayload(
    List<int> current,
    RecoveredVagAdaptation adaptation,
    RecoveredVagOption option,
  ) {
    final payload = List<int>.from(current);
    final spec = option.valueSpec.trim().toUpperCase();
    if (spec.isEmpty) return null;
    if (isBitSpec(spec)) {
      final matcher = RegExp(r'BIT:(\d+):(\d+)=(0|1)', caseSensitive: false);
      final matches = matcher.allMatches(spec).toList(growable: false);
      if (matches.isEmpty) return null;
      for (final match in matches) {
        final byteIndex = int.tryParse(match.group(1)!);
        final bitIndex = int.tryParse(match.group(2)!);
        final value = int.tryParse(match.group(3)!);
        if (byteIndex == null || bitIndex == null || value == null || bitIndex > 7 || byteIndex < 0 || byteIndex >= payload.length) {
          return null;
        }
        if (value == 1) {
          payload[byteIndex] = (payload[byteIndex] | (1 << bitIndex)) & 0xFF;
        } else {
          payload[byteIndex] = (payload[byteIndex] & ~(1 << bitIndex)) & 0xFF;
        }
      }
      return payload;
    }
    final hex = spec.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (hex.isEmpty || hex.length.isOdd) return null;
    final value = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      value.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    final start = adaptation.startByteIndex;
    if (start < 0 || start + value.length > payload.length) return null;
    for (var i = 0; i < value.length; i++) {
      payload[start + i] = value[i];
    }
    return payload;
  }

  static bool optionMatches(
    List<int> current,
    RecoveredVagAdaptation adaptation,
    RecoveredVagOption option,
  ) {
    final spec = option.valueSpec.trim().toUpperCase();
    if (spec.isEmpty) return false;
    if (isBitSpec(spec)) {
      final matcher = RegExp(r'BIT:(\d+):(\d+)=(0|1)', caseSensitive: false);
      final matches = matcher.allMatches(spec).toList(growable: false);
      if (matches.isEmpty) return false;
      for (final match in matches) {
        final byteIndex = int.tryParse(match.group(1)!);
        final bitIndex = int.tryParse(match.group(2)!);
        final value = int.tryParse(match.group(3)!);
        if (byteIndex == null || bitIndex == null || value == null || bitIndex > 7 || byteIndex < 0 || byteIndex >= current.length) {
          return false;
        }
        final actual = (current[byteIndex] >> bitIndex) & 1;
        if (actual != value) return false;
      }
      return true;
    }
    final hex = spec.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (hex.isEmpty || hex.length.isOdd) return false;
    final start = adaptation.startByteIndex;
    final count = hex.length ~/ 2;
    if (start < 0 || start + count > current.length) return false;
    for (var i = 0; i < count; i++) {
      final expected = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (current[start + i] != expected) return false;
    }
    return true;
  }

  static String humanReadableValue(List<int> payload, RecoveredVagAdaptation adaptation) {
    for (final option in adaptation.options) {
      if (optionMatches(payload, adaptation, option)) {
        final title = option.title.trim();
        return title.isEmpty ? tx('Seçili değer') : title;
      }
    }
    final start = adaptation.startByteIndex;
    var length = adaptation.dataLength;
    if (length <= 0) length = 1;
    if (start < 0 || start >= payload.length || start + length > payload.length || length > 8) {
      return tx('ECU değeri okundu');
    }
    var bytes = payload.sublist(start, start + length);
    if (adaptation.reverseByteSequence) bytes = bytes.reversed.toList(growable: false);
    var raw = 0;
    for (final b in bytes) { raw = (raw << 8) | (b & 0xFF); }
    if (adaptation.signed) {
      final bits = length * 8;
      final signBit = 1 << (bits - 1);
      if ((raw & signBit) != 0) raw -= 1 << bits;
    }
    final value = raw * adaptation.multiplier + adaptation.offset;
    final rounded = value.roundToDouble() == value ? value.toInt().toString() : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return rounded;
  }

  static String hex(List<int> bytes) => bytes.map((e) => (e & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()).join();
}
