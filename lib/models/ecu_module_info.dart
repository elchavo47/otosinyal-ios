class EcuModuleInfo {
  final String canId;
  final String label;
  final String? ecuName;
  final String? calibrationId;
  final String? cvn;
  final List<String> rawResponses;

  const EcuModuleInfo({
    required this.canId,
    required this.label,
    this.ecuName,
    this.calibrationId,
    this.cvn,
    this.rawResponses = const [],
  });

  bool get hasIdentity =>
      (ecuName?.trim().isNotEmpty ?? false) ||
      (calibrationId?.trim().isNotEmpty ?? false) ||
      (cvn?.trim().isNotEmpty ?? false);

  EcuModuleInfo copyWith({
    String? label,
    String? ecuName,
    String? calibrationId,
    String? cvn,
    List<String>? rawResponses,
  }) {
    return EcuModuleInfo(
      canId: canId,
      label: label ?? this.label,
      ecuName: ecuName ?? this.ecuName,
      calibrationId: calibrationId ?? this.calibrationId,
      cvn: cvn ?? this.cvn,
      rawResponses: rawResponses ?? this.rawResponses,
    );
  }

  Map<String, dynamic> toJson() => {
        'can_id': canId,
        'label': label,
        'ecu_name': ecuName,
        'calibration_id': calibrationId,
        'cvn': cvn,
      };
}
