import '../models/diagnostic_units.dart';

class VagUdsAddress {
  final DiagnosticUnit unit;
  final String name;
  final String requestId;
  final String responseId;

  const VagUdsAddress(this.unit, this.name, this.requestId, this.responseId);
}

/// Common 11-bit UDS endpoints used by VAG MQB-family vehicles.
/// Every address remains a candidate until the ECU gives a positive response.
class VagUdsAddressCatalog {
  static const addresses = <VagUdsAddress>[
    VagUdsAddress(DiagnosticUnit.engine, 'Motor kontrol ünitesi', '7E0', '7E8'),
    VagUdsAddress(DiagnosticUnit.transmission, 'Şanzıman kontrol ünitesi', '7E1', '7E9'),
    VagUdsAddress(DiagnosticUnit.abs, 'ABS / ESP', '713', '77D'),
    VagUdsAddress(DiagnosticUnit.airbag, 'Airbag / SRS', '715', '77F'),
    VagUdsAddress(DiagnosticUnit.body, 'Merkezi elektrik / BCM', '70E', '778'),
    VagUdsAddress(DiagnosticUnit.body, 'Konfor sistemi', '70D', '777'),
    VagUdsAddress(DiagnosticUnit.gateway, 'CAN Gateway', '710', '77A'),
  ];

  static List<VagUdsAddress> forUnit(DiagnosticUnit unit) =>
      addresses.where((item) => item.unit == unit).toList(growable: false);
}
