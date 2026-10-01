import 'dart:convert';

/// Bir bağlantı oturumu boyunca kaydedilen sürüş özeti.
class TripLog {
  final String id;
  final String? vehicleId;
  final DateTime startTime;
  final int durationSeconds;
  final int maxSpeed;
  final int maxRpm;
  final int? maxBoostKpa;

  const TripLog({
    required this.id,
    required this.vehicleId,
    required this.startTime,
    required this.durationSeconds,
    required this.maxSpeed,
    required this.maxRpm,
    this.maxBoostKpa,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicleId': vehicleId,
    'startTime': startTime.toIso8601String(),
    'durationSeconds': durationSeconds,
    'maxSpeed': maxSpeed,
    'maxRpm': maxRpm,
    'maxBoostKpa': maxBoostKpa,
  };

  factory TripLog.fromMap(Map<String, dynamic> map) {
    return TripLog(
      id: map['id'] as String,
      vehicleId: map['vehicleId'] as String?,
      startTime: DateTime.tryParse(map['startTime'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      maxSpeed: map['maxSpeed'] as int? ?? 0,
      maxRpm: map['maxRpm'] as int? ?? 0,
      maxBoostKpa: map['maxBoostKpa'] as int?,
    );
  }

  static String encodeList(List<TripLog> trips) {
    return jsonEncode(trips.map((t) => t.toMap()).toList());
  }

  static List<TripLog> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => TripLog.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
