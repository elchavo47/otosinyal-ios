import 'diagnostic_units.dart';

enum OemModuleProtocol { canUds, doip }

/// A read-only address profile discovered from the selected brand catalog.
/// Addresses are candidates only; the ECU must answer before it is reported.
class OemModuleProfile {
  final DiagnosticUnit unit;
  final String name;
  final String source;
  final OemModuleProtocol protocol;
  final String? requestId;
  final String? responseId;
  final int? doipLogicalAddress;

  const OemModuleProfile({
    required this.unit,
    required this.name,
    required this.source,
    required this.protocol,
    this.requestId,
    this.responseId,
    this.doipLogicalAddress,
  });

  String get protocolLabel => switch (protocol) {
        OemModuleProtocol.canUds => 'CAN UDS',
        OemModuleProtocol.doip => 'DoIP / UDS',
      };

  String get addressLabel {
    if (protocol == OemModuleProtocol.canUds) {
      return '${requestId ?? '-'} → ${responseId ?? '-'}';
    }
    return '0x${(doipLogicalAddress ?? 0).toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }
}
