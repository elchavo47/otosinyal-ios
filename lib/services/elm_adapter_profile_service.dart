import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Observed ELM327 capabilities for one transport. Values stay nullable until
/// OTOSINYAL has actually tested them; a missing VIN is never treated as a
/// failed vehicle connection.
class ElmAdapterProfile {
  const ElmAdapterProfile({
    required this.transportId,
    this.longMessagesSupported,
    this.vinMode09Supported,
    this.protocolNumber,
    this.supportedMode01Pids = const <int>[],
    this.averageLatencyMs = 0,
    this.successfulCommands = 0,
    this.failedCommands = 0,
    this.bufferFullCount = 0,
  });

  final String transportId;
  final bool? longMessagesSupported;
  final bool? vinMode09Supported;
  final String? protocolNumber;
  final List<int> supportedMode01Pids;
  final int averageLatencyMs;
  final int successfulCommands;
  final int failedCommands;
  final int bufferFullCount;

  ElmAdapterProfile copyWith({
    bool? longMessagesSupported,
    bool? vinMode09Supported,
    String? protocolNumber,
    List<int>? supportedMode01Pids,
    int? averageLatencyMs,
    int? successfulCommands,
    int? failedCommands,
    int? bufferFullCount,
  }) => ElmAdapterProfile(
    transportId: transportId,
    longMessagesSupported: longMessagesSupported ?? this.longMessagesSupported,
    vinMode09Supported: vinMode09Supported ?? this.vinMode09Supported,
    protocolNumber: protocolNumber ?? this.protocolNumber,
    supportedMode01Pids: supportedMode01Pids ?? this.supportedMode01Pids,
    averageLatencyMs: averageLatencyMs ?? this.averageLatencyMs,
    successfulCommands: successfulCommands ?? this.successfulCommands,
    failedCommands: failedCommands ?? this.failedCommands,
    bufferFullCount: bufferFullCount ?? this.bufferFullCount,
  );

  Map<String, dynamic> toJson() => {
    'transportId': transportId,
    'longMessagesSupported': longMessagesSupported,
    'vinMode09Supported': vinMode09Supported,
    'protocolNumber': protocolNumber,
    'supportedMode01Pids': supportedMode01Pids,
    'averageLatencyMs': averageLatencyMs,
    'successfulCommands': successfulCommands,
    'failedCommands': failedCommands,
    'bufferFullCount': bufferFullCount,
  };

  factory ElmAdapterProfile.fromJson(Map<String, dynamic> data) => ElmAdapterProfile(
    transportId: data['transportId'] as String? ?? '',
    longMessagesSupported: data['longMessagesSupported'] as bool?,
    vinMode09Supported: data['vinMode09Supported'] as bool?,
    protocolNumber: data['protocolNumber'] as String?,
    supportedMode01Pids: (data['supportedMode01Pids'] as List<dynamic>? ?? const [])
        .whereType<num>().map((e) => e.toInt()).toList(growable: false),
    averageLatencyMs: (data['averageLatencyMs'] as num?)?.toInt() ?? 0,
    successfulCommands: (data['successfulCommands'] as num?)?.toInt() ?? 0,
    failedCommands: (data['failedCommands'] as num?)?.toInt() ?? 0,
    bufferFullCount: (data['bufferFullCount'] as num?)?.toInt() ?? 0,
  );
}

class ElmAdapterProfileService {
  static const _prefix = 'otosinyal_elm_profile_v2_';

  static Future<ElmAdapterProfile> load(String transportId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$transportId');
    if (raw == null) return ElmAdapterProfile(transportId: transportId);
    try {
      return ElmAdapterProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ElmAdapterProfile(transportId: transportId);
    }
  }

  static Future<void> save(ElmAdapterProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${profile.transportId}', jsonEncode(profile.toJson()));
  }
}
