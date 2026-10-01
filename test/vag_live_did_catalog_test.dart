import 'package:flutter_test/flutter_test.dart';
import 'package:otosinyal_obd2/services/vag_live_did_catalog.dart';

void main() {
  test('VAG live DID decoders use declared scale', () {
    final dpfPressure = VagLiveDidCatalog.candidates.firstWhere((e) => e.did == 0x1057);
    expect(dpfPressure.decodeNumber(const [0x00, 0xB4]), closeTo(1.8, 0.001));

    final soot = VagLiveDidCatalog.candidates.firstWhere((e) => e.did == 0x4E16);
    expect(soot.decodeNumber(const [0x03, 0x5C]), closeTo(8.60, 0.001));
  });
}
