import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:otosinyal_obd2/models/bluetooth_enums.dart';
import 'package:otosinyal_obd2/models/obd_device.dart';
import 'package:otosinyal_obd2/services/bluetooth_permission_service.dart';
import 'package:otosinyal_obd2/providers/scannable_provider.dart';
import 'package:otosinyal_obd2/services/auto_connect_service.dart';

/// Bilinen ELM327 BLE klonlarının kullandığı GATT servis/karakteristik
/// UUID'leri. Piyasada tek bir standart yok — her üretici kendi UUID'ini
/// kullanıyor, bu yüzden birden fazla olası eşleşme deneniyor. Hiçbiri
/// tutmazsa, write+notify özellikli ilk karakteristik çifti otomatik
/// olarak kullanılır (bkz. _discoverElm327Characteristics).
class _KnownElm327Profile {
  final String serviceUuid;
  final String writeCharUuid;
  final String notifyCharUuid;
  const _KnownElm327Profile(this.serviceUuid, this.writeCharUuid, this.notifyCharUuid);
}

const _knownProfiles = [
  // Nordic UART Service — birçok "gerçek" ELM327 BLE klonu bunu kullanır
  _KnownElm327Profile(
    '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  ),
  // HM-10 / HM-19 tabanlı ucuz BLE-seri köprüler (Vgate/Vlinker klonlarında yaygın)
  _KnownElm327Profile('0000ffe0-0000-1000-8000-00805f9b34fb',
      '0000ffe1-0000-1000-8000-00805f9b34fb', '0000ffe1-0000-1000-8000-00805f9b34fb'),
];

/// [BleProvider] — BLE (Bluetooth Low Energy) OBD2 cihazları için bağlantı
/// yönetimi. Mimarisi [BluetoothProvider] (Classic SPP) ile aynı desende
/// kurulmuştur ki ObdProvider hangisine bağlı olduğunu bilmesin.
class BleProvider extends ChangeNotifier implements ScannableBluetoothProvider {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  ObdDevice? _connectedDevice;
  ObdDevice? get connectedDevice => _connectedDevice;

  final List<ObdDevice> _discoveredDevices = [];
  List<ObdDevice> get discoveredDevices => _discoveredDevices;

  final Map<String, BluetoothDevice> _deviceMap = {};

  BluetoothDevice? _activeDevice;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  bool _writeWithoutResponse = false;
  bool? _probeWriteWithoutResponse;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  final _rxController = StreamController<String>.broadcast();
  Stream<String> get rxStream => _rxController.stream;

  int _connectionId = 0;

  String _connectionMessage = "";
  String get connectionMessage => _connectionMessage;

  String _backgroundMessage = "";
  String get backgroundMessage => _backgroundMessage;

  bool _isReconnectingBackground = false;
  bool get isReconnectingBackground => _isReconnectingBackground;

  Timer? _scanTimer;

  bool _isHardwareOn = false;
  bool get isHardwareOn => _isHardwareOn;

  // CoreBluetooth'a ilk erişim iOS'ta Bluetooth izin penceresini açar.
  // Bu yüzden adaptör dinleyicisi uygulama açılışında değil, kullanıcı
  // ilk kez cihaz taradığında başlatılır (App Review 5.1.1).
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  void _ensureAdapterListener() {
    _adapterSubscription ??= FlutterBluePlus.adapterState.listen((state) {
      _isHardwareOn = state == BluetoothAdapterState.on;
      if (state == BluetoothAdapterState.off) {
        disconnect();
        _stopScan();
        _discoveredDevices.clear();
        _deviceMap.clear();
      }
      notifyListeners();
    });
  }

  void _addDeviceToList(ScanResult result) {
    final device = result.device;
    final id = device.remoteId.str;
    if (result.advertisementData.advName.isEmpty && device.platformName.isEmpty) return;

    final existingIndex = _discoveredDevices.indexWhere((d) => d.address == id);
    if (existingIndex >= 0) {
      final old = _discoveredDevices[existingIndex];
      _discoveredDevices[existingIndex] = ObdDevice(
        name: old.name,
        address: old.address,
        isBle: true,
        rssi: result.rssi,
      );
      return;
    }

    _deviceMap[id] = device;
    _discoveredDevices.add(
      ObdDevice(
        name: device.platformName.isNotEmpty
            ? device.platformName
            : (result.advertisementData.advName.isNotEmpty
                ? result.advertisementData.advName
                : "Bilinmeyen BLE Cihazı"),
        address: id,
        isBle: true,
        rssi: result.rssi,
      ),
    );
  }

  Future<BluetoothScanResult> startScan() async {
    if (_isScanning) return BluetoothScanResult.started;

    final permissionStatus = await requestBluetoothPermissions();
    if (permissionStatus == BluetoothPermissionStatus.permanentlyDenied) {
      return BluetoothScanResult.permanentlyDenied;
    }
    if (permissionStatus != BluetoothPermissionStatus.granted) {
      return BluetoothScanResult.notStarted;
    }

    _ensureAdapterListener();
    final adapterState = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5),
            onTimeout: () => BluetoothAdapterState.unknown);
    _isHardwareOn = adapterState == BluetoothAdapterState.on;

    if (!_isHardwareOn) {
      return BluetoothScanResult.notStarted;
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _deviceMap.clear();

    if (_isConnected && _connectedDevice != null && _activeDevice != null) {
      _deviceMap[_activeDevice!.remoteId.str] = _activeDevice!;
      _discoveredDevices.add(_connectedDevice!);
    }

    notifyListeners();

    try {
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          _addDeviceToList(r);
        }
        notifyListeners();
      }, onError: (e) {
        developer.log("BLE tarama hatası: $e", name: 'reBle');
        _stopScan();
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), () {
        if (_isScanning) _stopScan();
      });
    } catch (e) {
      developer.log("BLE tarama başlatma hatası: $e", name: 'reBle');
      _isScanning = false;
      notifyListeners();
      return BluetoothScanResult.notStarted;
    }

    return BluetoothScanResult.started;
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  /// BLE tarafında yalnızca "write var / notify var" diye ilk karakteristiği
  /// seçmek güvenli değil. Bazı adaptörlerde birden fazla servis var ve yanlış
  /// write/notify çifti seçilirse telefon GATT'a bağlanır ama ELM hiç cevap vermez.
  /// Bu nedenle aday çiftleri aynı servis içinde toplar ve her birini `ATI` ile
  /// gerçekten test ederiz. ELM cevabı gelen kanal kullanılmadan bağlantı hazır
  /// sayılmaz.
  Future<bool> _discoverElm327Characteristics(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final candidates = <({BluetoothCharacteristic write, BluetoothCharacteristic notify, String label})>[];
    final seen = <String>{};

    void addCandidate(
      BluetoothCharacteristic write,
      BluetoothCharacteristic notify,
      String label,
    ) {
      final key = '${write.uuid.str}|${notify.uuid.str}';
      if (seen.add(key)) {
        candidates.add((write: write, notify: notify, label: label));
      }
    }

    // Önce bilinen UART profilleri.
    for (final profile in _knownProfiles) {
      for (final service in services) {
        if (service.uuid.str.toLowerCase() != profile.serviceUuid) continue;
        BluetoothCharacteristic? writeChar;
        BluetoothCharacteristic? notifyChar;
        for (final c in service.characteristics) {
          final uuid = c.uuid.str.toLowerCase();
          if (uuid == profile.writeCharUuid) writeChar = c;
          if (uuid == profile.notifyCharUuid) notifyChar = c;
        }
        if (writeChar != null && notifyChar != null) {
          addCandidate(writeChar, notifyChar, 'bilinen ELM UART');
        }
      }
    }

    // Tek karakteristik hem write hem notify ise BLE-seri köprülerde en güçlü adaydır.
    for (final service in services) {
      for (final c in service.characteristics) {
        final canWrite = c.properties.write || c.properties.writeWithoutResponse;
        final canNotify = c.properties.notify || c.properties.indicate;
        if (canWrite && canNotify) {
          addCandidate(c, c, 'aynı karakteristik UART');
        }
      }
    }

    // Son çare: AYNI servis içindeki write x notify çiftlerini dene.
    // Eski kod farklı servislerden iki karakteristiği eşleştirebiliyordu.
    for (final service in services) {
      final writes = service.characteristics
          .where((c) => c.properties.write || c.properties.writeWithoutResponse)
          .toList();
      final notifies = service.characteristics
          .where((c) => c.properties.notify || c.properties.indicate)
          .toList();
      for (final w in writes) {
        for (final n in notifies) {
          addCandidate(w, n, 'otomatik UART');
        }
      }
    }

    if (candidates.isEmpty) return false;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      _connectionMessage =
          'ELM veri kanalı test ediliyor ${i + 1}/${candidates.length}...';
      notifyListeners();

      if (await _probeElmCandidate(candidate.write, candidate.notify)) {
        _writeChar = candidate.write;
        _notifyChar = candidate.notify;
        _writeWithoutResponse = _probeWriteWithoutResponse ??
            (!candidate.write.properties.write && candidate.write.properties.writeWithoutResponse);
        developer.log(
          'BLE ELM kanalı doğrulandı: ${candidate.label} '
          'write=${candidate.write.uuid.str} notify=${candidate.notify.uuid.str} mode=${_writeWithoutResponse ? 'WNR' : 'WRITE'}',
          name: 'reBle',
        );
        return true;
      }
    }

    _writeChar = null;
    _notifyChar = null;
    return false;
  }

  Future<bool> _probeElmCandidate(
    BluetoothCharacteristic writeChar,
    BluetoothCharacteristic notifyChar,
  ) async {
    StreamSubscription<List<int>>? testSubscription;
    _probeWriteWithoutResponse = null;
    final buffer = StringBuffer();
    final responseCompleter = Completer<bool>();

    try {
      await notifyChar.setNotifyValue(true);
      testSubscription = notifyChar.onValueReceived.listen((data) {
        if (data.isEmpty) return;
        final text = String.fromCharCodes(data);
        buffer.write(text);
        final upper = buffer.toString().toUpperCase();
        if (!responseCompleter.isCompleted &&
            (upper.contains('ELM') ||
                upper.contains('OBD') ||
                upper.contains('OK') ||
                upper.contains('>'))) {
          responseCompleter.complete(true);
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final bytes = Uint8List.fromList('ATI\r'.codeUnits);

      // Bazı BLE-seri köprüler write-with-response ister. İkisi de varsa önce
      // güvenilir olan write-with-response kullanılır.
      if (writeChar.properties.write) {
        await writeChar.write(bytes, withoutResponse: false);
      } else {
        await writeChar.write(bytes, withoutResponse: true);
      }

      final ok = await responseCompleter.future.timeout(
        const Duration(milliseconds: 1800),
        onTimeout: () => false,
      );
      if (ok) {
        _probeWriteWithoutResponse = !writeChar.properties.write && writeChar.properties.writeWithoutResponse;
        return true;
      }

      // İlk deneme başarısızsa ve WNR da destekleniyorsa onu da test et.
      if (writeChar.properties.write && writeChar.properties.writeWithoutResponse) {
        buffer.clear();
        await writeChar.write(bytes, withoutResponse: true);
        final fallbackOk = await responseCompleter.future.timeout(
          const Duration(milliseconds: 1200),
          onTimeout: () => false,
        );
        if (fallbackOk) _probeWriteWithoutResponse = true;
        return fallbackOk;
      }
    } catch (e) {
      developer.log('BLE ELM kanal testi başarısız: $e', name: 'reBle');
    } finally {
      await testSubscription?.cancel();
    }
    return false;
  }

  Future<bool> connectToDevice(ObdDevice device) async {
    if (_isConnected && _connectedDevice?.address == device.address) {
      return true;
    }
    if (_isConnecting) return false;

    _connectionId++;
    final int currentId = _connectionId;

    _isReconnectingBackground = false;
    _isConnecting = true;
    _connectionMessage = "${device.name} cihazına bağlanılıyor...";
    notifyListeners();

    await disconnect();
    if (currentId != _connectionId) return false;

    final physicalDevice = _deviceMap[device.address];
    if (physicalDevice == null) {
      _isConnecting = false;
      notifyListeners();
      return false;
    }

    for (int i = 1; i <= 3; i++) {
      try {
        if (i > 1) {
          _connectionMessage = "Bağlantı denemesi #${i - 1}";
        } else {
          _connectionMessage = "GATT servisleri keşfediliyor...";
        }
        notifyListeners();

        await physicalDevice.connect(timeout: const Duration(seconds: 8));
        if (currentId != _connectionId) {
          await physicalDevice.disconnect();
          return false;
        }

        final found = await _discoverElm327Characteristics(physicalDevice);
        if (!found) {
          throw Exception("BLE bağlantısı kuruldu fakat ELM327 veri kanalı doğrulanamadı");
        }

        if (currentId != _connectionId) {
          await physicalDevice.disconnect();
          return false;
        }

        await _notifyChar!.setNotifyValue(true);
        await _notifySubscription?.cancel();
        _notifySubscription = _notifyChar!.onValueReceived.listen((data) {
          if (data.isNotEmpty) {
            _rxController.add(String.fromCharCodes(data));
          }
        });
        // Notify aboneliğinin Android GATT tarafında oturması için kısa süre ver.
        await Future<void>.delayed(const Duration(milliseconds: 180));

        await _connectionStateSubscription?.cancel();
        _connectionStateSubscription = physicalDevice.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected && _isConnected) {
            disconnect(isIntentional: false);
          }
        });

        _activeDevice = physicalDevice;
        _connectedDevice = device;
        _isConnected = true;

        _discoveredDevices.removeWhere((d) => d.address == device.address);
        _discoveredDevices.insert(0, device);

        if (currentId == _connectionId) _isConnecting = false;
        unawaited(AutoConnectService.saveLastDevice(device));
        notifyListeners();
        return true;
      } catch (e) {
        developer.log("BLE bağlantı hatası: $e", name: 'reBle', error: e);
        try {
          await physicalDevice.disconnect();
        } catch (_) {}

        if (currentId != _connectionId) return false;
        if (i < 3) {
          await Future.delayed(const Duration(milliseconds: 2000));
        } else {
          _isConnected = false;
          _connectedDevice = null;
          _isConnecting = false;
          notifyListeners();
          return false;
        }
      }
    }

    _isConnecting = false;
    notifyListeners();
    return false;
  }

  Future<void> sendCommand(String command) async {
    if (!_isConnected || _writeChar == null) return;
    try {
      final clean = command.replaceAll('\r', '').replaceAll('\n', '').trim();
      final bytes = Uint8List.fromList('$clean\r'.codeUnits);
      // Kanal testi hangi yazma tipinde cevap aldıysa gerçek ELM komutlarında da
      // aynı modu kullan. Bazı BLE-ELM klonları iki property'yi birden ilan edip
      // yalnızca writeWithoutResponse ile veri köprüsüne geçiriyor.
      var useWithoutResponse = _writeWithoutResponse;
      if (useWithoutResponse && !_writeChar!.properties.writeWithoutResponse) {
        useWithoutResponse = false;
      } else if (!useWithoutResponse && !_writeChar!.properties.write &&
          _writeChar!.properties.writeWithoutResponse) {
        useWithoutResponse = true;
      }
      await _writeChar!.write(bytes, withoutResponse: useWithoutResponse);
    } catch (e) {
      developer.log("BLE komut gönderme hatası: $e", name: 'reBle');
    }
  }

  Future<void> disconnect({bool isIntentional = true}) async {
    try {
      await _notifySubscription?.cancel();
      await _connectionStateSubscription?.cancel();
      await _activeDevice?.disconnect();
      _activeDevice = null;
      _writeChar = null;
      _notifyChar = null;
      _writeWithoutResponse = false;
      _probeWriteWithoutResponse = null;
    } catch (e) {
      developer.log("BLE bağlantı kapatma hatası: $e", name: 'reBle');
    }

    if (isIntentional) {
      _isConnected = false;
      _connectedDevice = null;
      _isConnecting = false;
      notifyListeners();
    } else {
      _startBackgroundReconnect();
    }
  }

  Future<void> _startBackgroundReconnect() async {
    if (_connectedDevice == null) return;

    _connectionId++;
    final int currentId = _connectionId;

    _isReconnectingBackground = true;
    _backgroundMessage = "yeniden bağlanılıyor...";
    notifyListeners();

    final physicalDevice = _deviceMap[_connectedDevice!.address];
    if (physicalDevice == null) {
      _isReconnectingBackground = false;
      disconnect(isIntentional: true);
      return;
    }

    for (int i = 1; i <= 3; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 4000));
        if (currentId != _connectionId) {
          _isReconnectingBackground = false;
          notifyListeners();
          return;
        }
        _backgroundMessage = "yeniden bağlanılıyor... #$i";
        notifyListeners();

        await physicalDevice.connect(timeout: const Duration(seconds: 8));
        final found = await _discoverElm327Characteristics(physicalDevice);
        if (!found) throw Exception("Karakteristik bulunamadı");

        if (currentId != _connectionId) {
          await physicalDevice.disconnect();
          _isReconnectingBackground = false;
          notifyListeners();
          return;
        }

        await _notifyChar!.setNotifyValue(true);
        await _notifySubscription?.cancel();
        _notifySubscription = _notifyChar!.onValueReceived.listen((data) {
          _rxController.add(String.fromCharCodes(data));
        });

        _activeDevice = physicalDevice;
        _isConnected = true;
        _isReconnectingBackground = false;
        notifyListeners();
        return;
      } catch (e) {
        developer.log("BLE yeniden bağlanma hatası #$i: $e", name: 'reBle');
        if (currentId != _connectionId) {
          _isReconnectingBackground = false;
          notifyListeners();
          return;
        }
        if (i == 3) {
          _isReconnectingBackground = false;
          await disconnect();
        }
      }
    }
  }

  void cancelConnection() {
    _connectionId++;
    _isConnecting = false;
    _isReconnectingBackground = false;
    disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _stopScan();
    disconnect();
    super.dispose();
  }
}
