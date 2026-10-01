import 'ios_share_origin.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/connection_mode_provider.dart';
import '../providers/dtc_history_provider.dart';
import '../providers/garage_provider.dart';
import '../providers/trip_log_provider.dart';
import '../providers/units_provider.dart';
import '../providers/usb_obd_provider.dart';
import '../providers/wifi_obd_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/coding_history_provider.dart';

/// OTOSİNYAL'a özel, şifreli kullanıcı yedeği.
///
/// Dosya JSON olarak dışarı çıkmaz. Uygulama kendi kapsayıcı başlığını
/// doğrular, AES-256-GCM ile açar ve MAC doğrulaması geçmeden hiçbir provider'a
/// veri yazmaz. ECU raw logları yine ayrı teşhis export'unda tutulur.
class DataBackupService {
  static const int schemaVersion = 1;
  static const String fileExtension = 'otosinyal';
  static const String fileFormat = 'OTOSINYAL encrypted user backup';

  // OTOSİNYAL kapsayıcı formatı: magic(8) + version(1) + algorithm(1) +
  // nonceLength(1) + macLength(1) + ciphertextLength(4) + payload.
  static const List<int> _magic = <int>[0x4F, 0x54, 0x53, 0x59, 0x4E, 0x47, 0x4C, 0x31];
  static const int _containerVersion = 1;
  static const int _aesGcm256 = 1;
  static const int _headerLength = 16;
  static const int _maxPayloadBytes = 10 * 1024 * 1024;

  // Uygulamaya ait format anahtarıdır. Dosya başka uygulamalarda okunamaz;
  // farklı cihazda geri yükleme yapılabilmesi için cihazla kilitlenmez.
  // Mutlak güvenlik iddiası değildir: tersine mühendisliğe karşı üretim
  // sürümünde native secret/keystore rotasyonu ayrıca uygulanmalıdır.
  static const List<int> _appKeyBytes = <int>[
    0x4F, 0x54, 0x4F, 0x53, 0x49, 0x4E, 0x59, 0x41,
    0x4C, 0x2D, 0x56, 0x49, 0x50, 0x2D, 0x32, 0x30,
    0x32, 0x36, 0x2D, 0x45, 0x4E, 0x43, 0x52, 0x59,
    0x50, 0x54, 0x2D, 0x41, 0x45, 0x53, 0x47, 0x43,
  ];
  static final AesGcm _cipher = AesGcm.with256bits();
  static final SecretKey _appKey = SecretKey(_appKeyBytes);

  static Map<String, dynamic> buildBackup({
    required GarageProvider garage,
    required TripLogProvider trips,
    required DtcHistoryProvider dtcHistory,
    required UnitsProvider units,
    required ConnectionModeProvider connectionMode,
    required WifiObdProvider wifi,
    required UsbObdProvider usb,
    required MaintenanceProvider maintenance,
    required CodingHistoryProvider codingHistory,
  }) {
    return <String, dynamic>{
      'format': fileFormat,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'garage': garage.exportData(),
      'tripLogs': trips.exportData(),
      'dtcHistory': dtcHistory.exportData(),
      'units': units.exportData(),
      'connection': connectionMode.exportData(),
      'wifi': wifi.exportData(),
      'usb': usb.exportData(),
      'maintenance': maintenance.exportData(),
      'codingHistory': codingHistory.exportData(),
    };
  }

  static Future<File> writeBackup({
    required GarageProvider garage,
    required TripLogProvider trips,
    required DtcHistoryProvider dtcHistory,
    required UnitsProvider units,
    required ConnectionModeProvider connectionMode,
    required WifiObdProvider wifi,
    required UsbObdProvider usb,
    required MaintenanceProvider maintenance,
    required CodingHistoryProvider codingHistory,
  }) async {
    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    final file = File('${directory.path}/OTOSINYAL_YEDEK_$stamp.$fileExtension');
    final payload = buildBackup(
      garage: garage,
      trips: trips,
      dtcHistory: dtcHistory,
      units: units,
      connectionMode: connectionMode,
      wifi: wifi,
      usb: usb,
      maintenance: maintenance,
      codingHistory: codingHistory,
    );
    final plainText = utf8.encode(jsonEncode(payload));
    if (plainText.length > _maxPayloadBytes) {
      throw const FormatException('Yedek boyutu desteklenen sınırı aşıyor');
    }

    final secretBox = await _cipher.encrypt(plainText, secretKey: _appKey);
    await file.writeAsBytes(_encodeContainer(secretBox), flush: true);
    return file;
  }

  static Future<void> shareBackup({
    required GarageProvider garage,
    required TripLogProvider trips,
    required DtcHistoryProvider dtcHistory,
    required UnitsProvider units,
    required ConnectionModeProvider connectionMode,
    required WifiObdProvider wifi,
    required UsbObdProvider usb,
    required MaintenanceProvider maintenance,
    required CodingHistoryProvider codingHistory,
  }) async {
    final file = await writeBackup(
      garage: garage,
      trips: trips,
      dtcHistory: dtcHistory,
      units: units,
      connectionMode: connectionMode,
      wifi: wifi,
      usb: usb,
      maintenance: maintenance,
      codingHistory: codingHistory,
    );
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'OTOSİNYAL şifreli kullanıcı yedeği (.otosinyal)',
      sharePositionOrigin: otoShareOrigin(),
    );
  }

  static Future<Map<String, dynamic>?> pickBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [fileExtension],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final selected = result.files.single;
    if (!selected.name.toLowerCase().endsWith('.$fileExtension')) {
      throw const FormatException('Yalnızca OTOSİNYAL yedeği (.otosinyal) seçilebilir');
    }
    final bytes = selected.bytes;
    final rawBytes = bytes ??
        (selected.path == null ? null : await File(selected.path!).readAsBytes());
    if (rawBytes == null || rawBytes.isEmpty) {
      throw const FormatException('Yedek dosyası okunamadı');
    }
    return await _decodeContainer(rawBytes);
  }

  static Future<void> restoreBackup({
    required Map<String, dynamic> backup,
    required GarageProvider garage,
    required TripLogProvider trips,
    required DtcHistoryProvider dtcHistory,
    required UnitsProvider units,
    required ConnectionModeProvider connectionMode,
    required WifiObdProvider wifi,
    required UsbObdProvider usb,
    required MaintenanceProvider maintenance,
    required CodingHistoryProvider codingHistory,
  }) async {
    if (backup['format'] != fileFormat || backup['schemaVersion'] is! int) {
      throw const FormatException('Geçersiz OTOSİNYAL yedek içeriği');
    }
    final garageData = backup['garage'];
    final tripData = backup['tripLogs'];
    final dtcData = backup['dtcHistory'];
    final unitsData = backup['units'];
    final connectionData = backup['connection'];
    final wifiData = backup['wifi'];
    final usbData = backup['usb'];
    final maintenanceData = backup['maintenance'];
    final codingHistoryData = backup['codingHistory'];
    if (garageData is Map) await garage.importData(Map<String, dynamic>.from(garageData));
    if (tripData is Map) await trips.importData(Map<String, dynamic>.from(tripData));
    if (dtcData is Map) await dtcHistory.importData(Map<String, dynamic>.from(dtcData));
    if (unitsData is Map) await units.importData(Map<String, dynamic>.from(unitsData));
    if (connectionData is Map) connectionMode.importData(Map<String, dynamic>.from(connectionData));
    if (wifiData is Map) wifi.importData(Map<String, dynamic>.from(wifiData));
    if (usbData is Map) usb.importData(Map<String, dynamic>.from(usbData));
    if (maintenanceData is Map) await maintenance.importData(Map<String, dynamic>.from(maintenanceData));
    if (codingHistoryData is Map) await codingHistory.importData(Map<String, dynamic>.from(codingHistoryData));
  }

  static Uint8List _encodeContainer(SecretBox secretBox) {
    final nonce = secretBox.nonce;
    final cipherText = secretBox.cipherText;
    final mac = secretBox.mac.bytes;
    if (nonce.length > 255 || mac.length > 255 || cipherText.length > 0x7FFFFFFF) {
      throw const FormatException('Yedek kapsayıcısı oluşturulamadı');
    }

    final header = ByteData(_headerLength);
    final headerBytes = header.buffer.asUint8List();
    headerBytes.setRange(0, _magic.length, _magic);
    headerBytes[8] = _containerVersion;
    headerBytes[9] = _aesGcm256;
    headerBytes[10] = nonce.length;
    headerBytes[11] = mac.length;
    header.setUint32(12, cipherText.length, Endian.big);

    final output = BytesBuilder(copy: false)
      ..add(headerBytes)
      ..add(nonce)
      ..add(cipherText)
      ..add(mac);
    return output.takeBytes();
  }

  static Future<Map<String, dynamic>> _decodeContainer(List<int> input) async {
    if (input.length < _headerLength) {
      throw const FormatException('Geçersiz .otosinyal dosyası');
    }
    if (input.length > _headerLength + _maxPayloadBytes + 32 + 32) {
      throw const FormatException('Yedek dosyası desteklenen boyut sınırını aşıyor');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (input[i] != _magic[i]) {
        throw const FormatException('Bu dosya OTOSİNYAL yedeği değil');
      }
    }

    final bytes = Uint8List.fromList(input);
    final header = ByteData.sublistView(bytes, 0, _headerLength);
    if (bytes[8] != _containerVersion || bytes[9] != _aesGcm256) {
      throw const FormatException('Bu .otosinyal sürümü desteklenmiyor');
    }
    final nonceLength = bytes[10];
    final macLength = bytes[11];
    final cipherLength = header.getUint32(12, Endian.big);
    if (nonceLength < 8 || nonceLength > 32 || macLength < 12 || macLength > 32 ||
        cipherLength == 0 || cipherLength > _maxPayloadBytes) {
      throw const FormatException('Yedek kapsayıcısı bozuk');
    }
    final expectedLength = _headerLength + nonceLength + cipherLength + macLength;
    if (expectedLength != bytes.length) {
      throw const FormatException('Yedek dosyası eksik veya değiştirilmiş');
    }

    final nonceStart = _headerLength;
    final cipherStart = nonceStart + nonceLength;
    final macStart = cipherStart + cipherLength;
    final secretBox = SecretBox(
      bytes.sublist(cipherStart, macStart),
      nonce: bytes.sublist(nonceStart, cipherStart),
      mac: Mac(bytes.sublist(macStart)),
    );

    try {
      final clearBytes = await _cipher.decrypt(secretBox, secretKey: _appKey);
      final decoded = jsonDecode(utf8.decode(clearBytes, allowMalformed: false));
      if (decoded is! Map) {
        throw const FormatException('Şifreli yedek içeriği geçersiz');
      }
      final backup = Map<String, dynamic>.from(decoded);
      if (backup['format'] != fileFormat) {
        throw const FormatException('Bu dosya OTOSİNYAL yedeği değil');
      }
      final version = backup['schemaVersion'];
      if (version is! int || version > schemaVersion || version < 1) {
        throw const FormatException('Yedek verisi sürümü desteklenmiyor');
      }
      return backup;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Şifre çözülemedi: dosya bozuk, değiştirilmiş veya başka uygulamaya ait');
    }
  }
}
