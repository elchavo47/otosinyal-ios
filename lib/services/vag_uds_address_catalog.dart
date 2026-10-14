import '../models/diagnostic_units.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

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
  static final addresses = <VagUdsAddress>[
    VagUdsAddress(DiagnosticUnit.engine, tx('Motor kontrol ünitesi'), '7E0', '7E8'),
    VagUdsAddress(DiagnosticUnit.transmission, tx('Şanzıman kontrol ünitesi'), '7E1', '7E9'),
    VagUdsAddress(DiagnosticUnit.abs, 'ABS / ESP', '713', '77D'),
    VagUdsAddress(DiagnosticUnit.airbag, 'Airbag / SRS', '715', '77F'),
    VagUdsAddress(DiagnosticUnit.body, tx('Merkezi elektrik / BCM'), '70E', '778'),
    VagUdsAddress(DiagnosticUnit.body, tx('Konfor sistemi'), '70D', '777'),
    VagUdsAddress(DiagnosticUnit.gateway, 'CAN Gateway', '710', '77A'),
  ];

  static List<VagUdsAddress> forUnit(DiagnosticUnit unit) =>
      addresses.where((item) => item.unit == unit).toList(growable: false);
}
