class VagLongCodingModule {
  final String module;
  final String name;
  final String requestId;
  final String responseId;
  final bool writeAllowed;
  final bool safetyCritical;

  const VagLongCodingModule({
    required this.module,
    required this.name,
    required this.requestId,
    required this.responseId,
    this.writeAllowed = false,
    this.safetyCritical = false,
  });
}

class VagLongCodingReadResult {
  final bool success;
  final String message;
  final String? valueHex;
  final String? partNumber;
  final String? softwareVersion;

  const VagLongCodingReadResult({
    required this.success,
    required this.message,
    this.valueHex,
    this.partNumber,
    this.softwareVersion,
  });
}

class VagModuleBackupSnapshot {
  final String module;
  final String moduleName;
  final String requestId;
  final String responseId;
  final DateTime createdAt;
  final Map<String,String> values;
  final int attempted;
  final int succeeded;

  const VagModuleBackupSnapshot({
    required this.module,
    required this.moduleName,
    required this.requestId,
    required this.responseId,
    required this.createdAt,
    required this.values,
    required this.attempted,
    required this.succeeded,
  });
}
