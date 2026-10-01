import 'package:flutter_test/flutter_test.dart';
import 'package:otosinyal_obd2/services/vin_decoder.dart';

void main() {
  group('VIN decoder hardening', () {
    test('OBDium style raw ISO-TP Mode 09 VIN is decoded', () {
      const raw = '7E8 10 14 49 02 01 4D 41 54\r'
          '7E8 21 34 30 33 30 39 36 42\r'
          '7E8 22 4E 4C 30 30 30 30 30>';
      expect(VinDecoder.extractVin(raw), 'MAT403096BNL00000');
    });

    test('ELM record-numbered Mode 09 VIN is decoded', () {
      const raw = '49 02 01 57 56 57 5A 5A 5A\r'
          '49 02 02 41 55 5A 46 57 30\r'
          '49 02 03 30 30 30 30 30 31>';
      expect(VinDecoder.extractVin(raw), 'WVWZZZAUZFW000001');
    });

    test('UDS F190 VIN remains supported', () {
      const raw = '7E8 10 14 62 F1 90 57 56 57\r'
          '7E8 21 5A 5A 5A 41 55 5A 46\r'
          '7E8 22 57 30 30 30 30 30 31 00>';
      expect(VinDecoder.extractVinFromUds(raw), 'WVWZZZAUZFW000001');
    });

    test('VIN validation rejects I O Q and accepts VAG VIN', () {
      expect(VinDecoder.isValidVin('WVWZZZAUZFW000001'), isTrue);
      expect(VinDecoder.isValidVin('WVWZZZAUIFW000001'), isFalse);
      expect(VinDecoder.isValidVin('WVWZZZAUOFW000001'), isFalse);
      expect(VinDecoder.isValidVin('WVWZZZAUQFW000001'), isFalse);
    });

    test('model year cycle resolves 2015', () {
      expect(VinDecoder.modelYear('WVWZZZAUZFW000001'), 2015);
    });
  });
}
