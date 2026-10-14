import 'package:flutter_test/flutter_test.dart';
import 'package:otosinyal_obd2/services/uds_diagnostic.dart';
import 'package:otosinyal_obd2/services/vin_decoder.dart';

void main() {
  group('ELM response compatibility', () {
    test('parses compact 11-bit CAN header response', () {
      final bytes = UdsDiagnostic.hexBytes('7E8064100000000>');
      expect(bytes, containsAllInOrder(<int>[0x06, 0x41, 0x00]));
    });

    test('parses compact 29-bit CAN header response', () {
      final bytes = UdsDiagnostic.hexBytes('18DAF110064100BE3EB811>');
      expect(bytes, containsAllInOrder(<int>[0x06, 0x41, 0x00]));
    });

    test('reassembles ISO-TP UDS VIN payload', () {
      const raw = '7E8 10 14 62 F1 90 57 56 57\r'
          '7E8 21 5A 5A 5A 41 55 5A 46\r'
          '7E8 22 57 30 30 30 30 30 31 00>'; // WVWZZZAUZFW000001
      expect(VinDecoder.extractVinFromUds(raw), 'WVWZZZAUZFW000001');
    });
  });
}
