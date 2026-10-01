enum CodingBackupStatus { captured, applied, verificationFailed, rolledBack, rollbackFailed }

extension CodingBackupStatusLabel on CodingBackupStatus {
  String get label => switch (this) {
    CodingBackupStatus.captured => 'Yazma öncesi yedeklendi',
    CodingBackupStatus.applied => 'Kodlama uygulandı',
    CodingBackupStatus.verificationFailed => 'Doğrulama başarısız',
    CodingBackupStatus.rolledBack => 'Önceki koda dönüldü',
    CodingBackupStatus.rollbackFailed => 'Geri dönüş başarısız',
  };
}

class CodingBackupRecord {
  final String id;
  final String vin;
  final String brand;
  final String moduleName;
  final String requestId;
  final String responseId;
  final String did;
  final String originalHex;
  final String? requestedHex;
  final String? verifiedHex;
  final String? ecuPartNumber;
  final String? ecuSoftwareVersion;
  final CodingBackupStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CodingBackupRecord({
    required this.id,
    required this.vin,
    required this.brand,
    required this.moduleName,
    required this.requestId,
    required this.responseId,
    required this.did,
    required this.originalHex,
    required this.status,
    required this.createdAt,
    this.requestedHex,
    this.verifiedHex,
    this.ecuPartNumber,
    this.ecuSoftwareVersion,
    this.updatedAt,
  });

  bool get canRollback => status == CodingBackupStatus.applied || status == CodingBackupStatus.verificationFailed;

  CodingBackupRecord copyWith({
    CodingBackupStatus? status,
    String? requestedHex,
    String? verifiedHex,
    DateTime? updatedAt,
  }) => CodingBackupRecord(
    id: id,
    vin: vin,
    brand: brand,
    moduleName: moduleName,
    requestId: requestId,
    responseId: responseId,
    did: did,
    originalHex: originalHex,
    requestedHex: requestedHex ?? this.requestedHex,
    verifiedHex: verifiedHex ?? this.verifiedHex,
    ecuPartNumber: ecuPartNumber,
    ecuSoftwareVersion: ecuSoftwareVersion,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'vin': vin,
    'brand': brand,
    'moduleName': moduleName,
    'requestId': requestId,
    'responseId': responseId,
    'did': did,
    'originalHex': originalHex,
    'requestedHex': requestedHex,
    'verifiedHex': verifiedHex,
    'ecuPartNumber': ecuPartNumber,
    'ecuSoftwareVersion': ecuSoftwareVersion,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory CodingBackupRecord.fromMap(Map<String, dynamic> map) {
    final statusName = '${map['status'] ?? ''}';
    var status = CodingBackupStatus.captured;
    for (final value in CodingBackupStatus.values) {
      if (value.name == statusName) {
        status = value;
        break;
      }
    }
    return CodingBackupRecord(
      id: '${map['id'] ?? ''}',
      vin: '${map['vin'] ?? ''}',
      brand: '${map['brand'] ?? ''}',
      moduleName: '${map['moduleName'] ?? ''}',
      requestId: '${map['requestId'] ?? ''}',
      responseId: '${map['responseId'] ?? ''}',
      did: '${map['did'] ?? ''}',
      originalHex: '${map['originalHex'] ?? ''}',
      requestedHex: map['requestedHex']?.toString(),
      verifiedHex: map['verifiedHex']?.toString(),
      ecuPartNumber: map['ecuPartNumber']?.toString(),
      ecuSoftwareVersion: map['ecuSoftwareVersion']?.toString(),
      status: status,
      createdAt: DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse('${map['updatedAt'] ?? ''}'),
    );
  }
}
