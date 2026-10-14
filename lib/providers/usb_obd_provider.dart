import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// Android USB‑OTG serial transport for common ELM327 cables.
///
/// usb_serial supports FTDI/CDC style USB serial devices. The actual
/// diagnostic command layer remains shared with every other transport.
class UsbObdProvider extends ChangeNotifier {
  static const List<int> supportedBaudRates = <int>[9600, 38400, 115200];

  final StreamController<String> _rxController = StreamController<String>.broadcast();
  final List<UsbDevice> _devices = <UsbDevice>[];

  UsbPort? _port;
  UsbDevice? _selectedDevice;
  StreamSubscription<Uint8List>? _inputSubscription;
  StreamSubscription<UsbEvent>? _usbEventSubscription;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _error;
  int? _preferredBaudRate;
  int? _activeBaudRate;

  List<UsbDevice> get devices => List.unmodifiable(_devices);
  UsbDevice? get selectedDevice => _selectedDevice;
  Stream<String> get rxStream => _rxController.stream;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isReconnecting => false;
  String? get error => _error;
  int? get preferredBaudRate => _preferredBaudRate;
  int? get activeBaudRate => _activeBaudRate;
  bool get isAutoBaud => _preferredBaudRate == null;

  Map<String, dynamic> exportData() => <String, dynamic>{
        'preferredBaudRate': _preferredBaudRate,
      };

  void importData(Map<String, dynamic> data) {
    final value = data['preferredBaudRate'];
    setBaudPreference(value is int ? value : null);
  }

  String get baudLabel => _activeBaudRate == null
      ? (_preferredBaudRate == null ? tx('Otomatik') : '$_preferredBaudRate baud')
      : '$_activeBaudRate baud';

  UsbObdProvider() {
    _usbEventSubscription = UsbSerial.usbEventStream?.listen((_) => refresh());
  }

  Future<void> refresh() async {
    try {
      _devices
        ..clear()
        ..addAll(await UsbSerial.listDevices());
      notifyListeners();
    } catch (error) {
      _error = tx('USB cihazları okunamadı: {0}', [error]);
      notifyListeners();
    }
  }

  String deviceLabel(UsbDevice device) {
    final manufacturer = (device.manufacturerName ?? '').trim();
    final product = (device.productName ?? '').trim();
    final name = [manufacturer, product].where((e) => e.isNotEmpty).join(' ');
    return name.isEmpty ? 'USB OBD • ${device.deviceId ?? '-'}' : name;
  }

  void setBaudPreference(int? baudRate) {
    if (baudRate != null && !supportedBaudRates.contains(baudRate)) return;
    if (_preferredBaudRate == baudRate) return;
    _preferredBaudRate = baudRate;
    notifyListeners();
  }

  Future<UsbPort?> _openAtBaud(
    UsbDevice device,
    int baudRate, {
    required bool probe,
  }) async {
    UsbPort? port;
    StreamSubscription<Uint8List>? probeSubscription;
    try {
      port = await device.create();
      if (port == null) return null;
      if (!await port.open()) {
        await port.close();
        return null;
      }

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      if (!probe) return port;

      final buffer = StringBuffer();
      final probeFinished = Completer<void>();
      final input = port.inputStream;
      if (input == null) {
        await port.close();
        return null;
      }
      probeSubscription = input.listen((bytes) {
        buffer.write(utf8.decode(bytes, allowMalformed: true));
        final value = buffer.toString().toUpperCase();
        if (!probeFinished.isCompleted &&
            (value.contains('>') ||
                value.contains('ELM') ||
                value.contains('OBD') ||
                value.contains('OK') ||
                value.contains('NO DATA') ||
                value.contains('ERROR'))) {
          probeFinished.complete();
        }
      });

      await port.write(Uint8List.fromList(utf8.encode('ATI\r')));
      try {
        await probeFinished.future.timeout(const Duration(milliseconds: 1200));
      } on TimeoutException {
        // Bu baud hızında cevap gelmediyse sıradaki hızı dene.
      }
      await probeSubscription.cancel();
      probeSubscription = null;

      final response = buffer.toString().toUpperCase();
      final looksLikeElm = response.contains('>') ||
          response.contains('ELM') ||
          response.contains('OBD') ||
          response.contains('OK') ||
          response.contains('NO DATA') ||
          response.contains('ERROR');
      if (!looksLikeElm) {
        await port.close();
        return null;
      }
      return port;
    } catch (_) {
      await probeSubscription?.cancel();
      try {
        await port?.close();
      } catch (_) {}
      return null;
    }
  }

  Future<bool> connect(UsbDevice device, {int? baudRate}) async {
    await disconnect();
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      final requestedBaud = baudRate ?? _preferredBaudRate;
      final candidates = requestedBaud == null
          ? supportedBaudRates
          : <int>[requestedBaud];
      UsbPort? port;
      int? selectedBaud;
      for (final candidate in candidates) {
        port = await _openAtBaud(
          device,
          candidate,
          probe: requestedBaud == null,
        );
        if (port != null) {
          selectedBaud = candidate;
          break;
        }
      }
      if (port == null) {
        throw StateError(
          tx('ELM327 cevabı alınamadı; denenen hızlar: {0}', [candidates.join(', ')]),
        );
      }

      _port = port;
      _selectedDevice = device;
      _activeBaudRate = selectedBaud;
      _isConnected = true;
      _isConnecting = false;
      _inputSubscription = port.inputStream?.listen(
        (bytes) => _rxController.add(utf8.decode(bytes, allowMalformed: true)),
        onError: (Object error, StackTrace stack) {
          _error = tx('USB veri akışı kesildi: {0}', [error]);
          unawaited(disconnect());
        },
        onDone: () => unawaited(disconnect()),
        cancelOnError: true,
      );
      notifyListeners();
      return true;
    } catch (error) {
      _error = tx('USB OBD bağlantısı kurulamadı: {0}', [error]);
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendCommand(String command) async {
    final port = _port;
    if (!_isConnected || port == null) {
      throw StateError(tx('USB OBD bağlantısı hazır değil'));
    }
    final clean = command.replaceAll('\r', '').replaceAll('\n', '').trim();
    if (clean.isEmpty) return;
    await port.write(Uint8List.fromList(utf8.encode('$clean\r')));
  }

  Future<void> disconnect() async {
    final port = _port;
    _port = null;
    _isConnected = false;
    _activeBaudRate = null;
    _selectedDevice = null;
    _isConnecting = false;
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    await port?.close();
    notifyListeners();
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _usbEventSubscription?.cancel();
    _port?.close();
    _port = null;
    _rxController.close();
    super.dispose();
  }
}
