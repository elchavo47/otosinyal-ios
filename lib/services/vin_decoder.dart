import 'package:otosinyal_obd2/data/vehicle_brands.dart';
import 'package:otosinyal_obd2/services/uds_diagnostic.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// OBD2 Mode 09 (Vehicle Info) PID 02 ile okunan ham VIN yanıtını
/// çözümler ve WMI (ilk 3 karakter) üzerinden marka tahmini yapar.
class VinDecoder {
  static const Map<String, int> _yearMapPre2010 = <String, int>{
    'A':1980,'B':1981,'C':1982,'D':1983,'E':1984,'F':1985,'G':1986,'H':1987,
    'J':1988,'K':1989,'L':1990,'M':1991,'N':1992,'P':1993,'R':1994,'S':1995,
    'T':1996,'V':1997,'W':1998,'X':1999,'Y':2000,'1':2001,'2':2002,'3':2003,
    '4':2004,'5':2005,'6':2006,'7':2007,'8':2008,'9':2009,
  };
  static const Map<String, int> _yearMapPost2010 = <String, int>{
    'A':2010,'B':2011,'C':2012,'D':2013,'E':2014,'F':2015,'G':2016,'H':2017,
    'J':2018,'K':2019,'L':2020,'M':2021,'N':2022,'P':2023,'R':2024,'S':2025,
    'T':2026,'V':2027,'W':2028,'X':2029,'Y':2030,'1':2031,'2':2032,'3':2033,
    '4':2034,'5':2035,'6':2036,'7':2037,'8':2038,'9':2039,
  };

  static bool isValidVin(String vin) {
    final normalized = vin.trim().toUpperCase();
    return normalized.length == 17 &&
        RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(normalized);
  }

  static int? modelYear(String vin) {
    final normalized = vin.trim().toUpperCase();
    if (!isValidVin(normalized)) return null;
    final yearCode = normalized[9];
    // obd_vin_decoder referansındaki ISO-3779 çevrim ayrımı: 7. karakter
    // rakamsa 1980-2009, harfse 2010-2039 çevrimi.
    final pre2010 = RegExp(r'[0-9]').hasMatch(normalized[6]);
    final year = (pre2010 ? _yearMapPre2010 : _yearMapPost2010)[yearCode];
    if (year == null || year > DateTime.now().year + 1) return null;
    return year;
  }

  /// ELM327'nin `0902` yanıtından VIN çıkarır.
  /// Hem ISO-TP frame'lerini hem de ELM'in Mode 09 için kullandığı
  /// `49 02 <record> ...` çok-kayıt biçimini destekler.
  static String extractVin(String raw) {
    final upper = raw.toUpperCase();
    if (upper.trim().isEmpty || upper.contains('NO DATA')) return '';

    final messages = UdsDiagnostic.udsMessages(upper);
    final recordChunks = <int, List<int>>{};
    final directPayloads = <List<int>>[];

    for (final bytes in messages) {
      for (var i = 0; i + 1 < bytes.length; i++) {
        if (bytes[i] != 0x49 || bytes[i + 1] != 0x02) continue;
        if (i + 2 < bytes.length && bytes[i + 2] > 0 && bytes[i + 2] <= 0x20) {
          recordChunks[bytes[i + 2]] = List<int>.from(bytes.sublist(i + 3));
        } else {
          directPayloads.add(List<int>.from(bytes.sublist(i + 2)));
        }
        break;
      }
    }

    if (recordChunks.isNotEmpty) {
      final joined = <int>[];
      final keys = recordChunks.keys.toList()..sort();
      for (final key in keys) joined.addAll(recordChunks[key]!);
      final vin = _vinFromPayload(joined);
      if (vin.isNotEmpty) return vin;
    }

    for (final payload in directPayloads) {
      final vin = _vinFromPayload(payload);
      if (vin.isNotEmpty) return vin;
    }

    // Bazı ELM firmware'leri CAF1 altında bütün kayıtları tek byte akışında
    // birleştirir. Her 49 02 kaydını ayrı toplayıp tekrar sırala.
    final flat = _responseBytes(upper);
    final flatRecords = <int, List<int>>{};
    for (var i = 0; i + 2 < flat.length; i++) {
      if (flat[i] != 0x49 || flat[i + 1] != 0x02) continue;
      final record = flat[i + 2];
      if (record <= 0 || record > 0x20) continue;
      final payload = <int>[];
      var j = i + 3;
      while (j < flat.length) {
        if (j + 2 < flat.length && flat[j] == 0x49 && flat[j + 1] == 0x02) break;
        payload.add(flat[j]);
        j++;
      }
      flatRecords[record] = payload;
      i = j - 1;
    }
    if (flatRecords.isNotEmpty) {
      final joined = <int>[];
      final keys = flatRecords.keys.toList()..sort();
      for (final key in keys) joined.addAll(flatRecords[key]!);
      final vin = _vinFromPayload(joined);
      if (vin.isNotEmpty) return vin;
    }

    // Son çare: 49 02 marker'ından sonraki byte'larda geçerli VIN ara.
    for (var i = 0; i + 1 < flat.length; i++) {
      if (flat[i] == 0x49 && flat[i + 1] == 0x02) {
        final start = i + 2 < flat.length && flat[i + 2] <= 0x20 ? i + 3 : i + 2;
        final vin = _vinFromPayload(flat.sublist(start));
        if (vin.isNotEmpty) return vin;
      }
    }
    return '';
  }

  /// UDS `22 F190` pozitif cevabından VIN çıkarır.
  static String extractVinFromUds(String raw) {
    final upper = raw.toUpperCase();
    if (upper.trim().isEmpty || upper.contains('NO DATA')) return '';
    for (final bytes in UdsDiagnostic.udsMessages(upper)) {
      for (var i = 0; i + 2 < bytes.length; i++) {
        if (bytes[i] == 0x62 && bytes[i + 1] == 0xF1 && bytes[i + 2] == 0x90) {
          final vin = _vinFromPayload(bytes.sublist(i + 3));
          if (vin.isNotEmpty) return vin;
        }
      }
    }
    final bytes = _responseBytes(upper);
    for (var i = 0; i + 2 < bytes.length; i++) {
      if (bytes[i] == 0x62 && bytes[i + 1] == 0xF1 && bytes[i + 2] == 0x90) {
        final vin = _vinFromPayload(bytes.sublist(i + 3));
        if (vin.isNotEmpty) return vin;
      }
    }
    return '';
  }

  static List<int> _responseBytes(String raw) => UdsDiagnostic.hexBytes(raw);

  static String _vinFromPayload(Iterable<int> bytes) {
    final chars = <int>[];
    for (final byte in bytes) {
      final c = String.fromCharCode(byte).toUpperCase();
      if (RegExp(r'^[A-HJ-NPR-Z0-9]$').hasMatch(c)) {
        chars.add(c.codeUnitAt(0));
        if (chars.length == 17) {
          final candidate = String.fromCharCodes(chars);
          if (isValidVin(candidate)) return candidate;
          chars.removeAt(0);
        }
      } else if (byte == 0x00 || byte == 0xFF || byte <= 0x20) {
        // ISO-TP padding/ayraç: geçerli VIN byte'larını bozma.
      } else {
        chars.clear();
      }
    }
    return '';
  }

  /// WMI (VIN'in ilk 3 karakteri) üzerinden `vehicleBrands` listesindeki
  /// bir markayla eşleştirmeye çalışır. Bulamazsa null döner.
  static String? guessBrand(String vin) {
    if (vin.length < 3) return null;
    final wmi = vin.substring(0, 3).toUpperCase();

    const wmiMap = <String, String>{
      // Volkswagen Grubu
      'WVW': 'Volkswagen', 'WV1': 'Volkswagen', 'WV2': 'Volkswagen',
      '3VW': 'Volkswagen', '1VW': 'Volkswagen',
      'WAU': 'Audi', 'TRU': 'Audi',
      'WBA': 'BMW', 'WBS': 'BMW', 'WBX': 'BMW', '4US': 'BMW',
      'WDB': 'Mercedes-Benz', 'WDD': 'Mercedes-Benz', 'WDC': 'Mercedes-Benz',
      'WDF': 'Mercedes-Benz',
      'VSS': 'Seat', 'VSE': 'Seat',
      'TMB': 'Škoda',
      // Fransız
      'VF1': 'Renault', 'VF6': 'Renault',
      'VF3': 'Peugeot', 'VF7': 'Peugeot',
      'VF7A': 'Citroën', 'VF7B': 'Citroën',
      'UU1': 'Dacia', 'VF1D': 'Dacia',
      // İtalyan
      'ZFA': 'Fiat',
      'ZAR': 'Alfa Romeo',
      'ZFF': 'Fiat',
      // Amerikan
      '1FA': 'Ford', '1FT': 'Ford', '1FM': 'Ford', '3FA': 'Ford',
      'WF0': 'Ford',
      '1G1': 'Chevrolet', '1GC': 'Chevrolet', '1GB': 'Chevrolet',
      '1C3': 'Chrysler', '2C3': 'Chrysler',
      '1D3': 'Dodge', '1D7': 'Dodge', '3D3': 'Dodge',
      '1J4': 'Jeep', '1J8': 'Jeep',
      // Japon
      'JHM': 'Honda', '1HG': 'Honda', '19X': 'Honda',
      'JT2': 'Toyota', 'JT4': 'Toyota', 'JTD': 'Toyota', 'JTN': 'Toyota',
      'JN1': 'Nissan', 'JN3': 'Nissan', 'JN6': 'Nissan',
      'JM1': 'Mazda', 'JM3': 'Mazda',
      'JS2': 'Suzuki', 'JS3': 'Suzuki',
      'JA3': 'Mitsubishi', 'JA4': 'Mitsubishi',
      'JF1': 'Subaru', 'JF2': 'Subaru',
      'JTH': 'Lexus', 'JTJ': 'Lexus',
      // Kore
      'KMH': 'Hyundai', 'KMF': 'Hyundai',
      'KNA': 'Kia', 'KND': 'Kia', 'KNM': 'Kia',
      // İsveç
      'YV1': 'Volvo', 'YV4': 'Volvo',
      'YS3': 'Saab',
      // İngiliz
      'SAJ': 'Jaguar', 'SAL': 'Land Rover',
      'SCC': 'Rover', 'SDB': 'MINI', 'WMW': 'MINI',
      // Diğer
      'WP0': 'Porsche', 'WP1': 'Porsche',
    };

    // En uzun eşleşen anahtarı bul (bazı üreticiler 4 karakterlik WMI kullanır)
    for (int len = 4; len >= 3; len--) {
      if (vin.length < len) continue;
      final key = vin.substring(0, len).toUpperCase();
      if (wmiMap.containsKey(key)) {
        final brand = wmiMap[key]!;
        // Sadece listemizde (dropdown'da) olan markaları öner
        if (vehicleBrands.containsKey(brand)) return brand;
      }
    }
    return null;
  }
}
