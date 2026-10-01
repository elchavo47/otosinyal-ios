import 'dart:convert';

class DtcScanRecord {
  final String id;
  final String? vehicleId;
  final DateTime scannedAt;
  final List<String> stored;
  final List<String> pending;
  final List<String> permanent;
  final bool? milOn;

  const DtcScanRecord({
    required this.id,
    required this.vehicleId,
    required this.scannedAt,
    required this.stored,
    required this.pending,
    required this.permanent,
    required this.milOn,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicleId': vehicleId,
        'scannedAt': scannedAt.toIso8601String(),
        'stored': stored,
        'pending': pending,
        'permanent': permanent,
        'milOn': milOn,
      };

  factory DtcScanRecord.fromMap(Map<String, dynamic> map) => DtcScanRecord(
        id: map['id'] as String? ?? '',
        vehicleId: map['vehicleId'] as String?,
        scannedAt: DateTime.tryParse(map['scannedAt'] as String? ?? '') ?? DateTime.now(),
        stored: List<String>.from(map['stored'] as List? ?? const []),
        pending: List<String>.from(map['pending'] as List? ?? const []),
        permanent: List<String>.from(map['permanent'] as List? ?? const []),
        milOn: map['milOn'] as bool?,
      );

  static String encodeList(List<DtcScanRecord> items) => jsonEncode(items.map((e) => e.toMap()).toList());
  static List<DtcScanRecord> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => DtcScanRecord.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
