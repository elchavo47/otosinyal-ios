import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// Wi‑Fi ELM327 transport.
///
/// Most Wi‑Fi OBD adapters expose a small TCP server after the phone joins the
/// adapter's hotspot. The diagnostic protocol above this class is identical
/// to Bluetooth/USB: ASCII ELM commands terminated with CR.
class WifiObdProvider extends ChangeNotifier {
  static const int defaultPort = 35000;

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSubscription;
  final StreamController<String> _rxController = StreamController<String>.broadcast();

  String _host = '192.168.0.10';
  int _port = defaultPort;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _error;
  DateTime? _lastRxAt;

  Stream<String> get rxStream => _rxController.stream;
  String get host => _host;
  int get port => _port;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isReconnecting => false;
  String? get error => _error;
  DateTime? get lastRxAt => _lastRxAt;

  Map<String, dynamic> exportData() => <String, dynamic>{
        'host': _host,
        'port': _port,
      };

  void importData(Map<String, dynamic> data) {
    final host = data['host'];
    final port = data['port'];
    if (host is String && host.trim().isNotEmpty) _host = host.trim();
    if (port is int && port > 0 && port <= 65535) _port = port;
    notifyListeners();
  }

  Future<bool> connect({String? host, int? port}) async {
    final nextHost = (host ?? _host).trim();
    final nextPort = port ?? _port;
    if (nextHost.isEmpty || nextPort < 1 || nextPort > 65535) {
      _error = tx('Geçerli bir Wi‑Fi OBD IP ve port girin');
      notifyListeners();
      return false;
    }

    await disconnect();
    _host = nextHost;
    _port = nextPort;
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      final socket = await Socket.connect(
        _host,
        _port,
        timeout: const Duration(seconds: 10),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _isConnected = true;
      _isConnecting = false;
      _socketSubscription = socket.listen(
        (bytes) {
          _lastRxAt = DateTime.now();
          _rxController.add(utf8.decode(bytes, allowMalformed: true));
          notifyListeners();
        },
        onError: (Object error, StackTrace stack) {
          _error = tx('Wi‑Fi veri akışı kesildi: {0}', [error]);
          unawaited(disconnect());
        },
        onDone: () {
          if (_isConnected) {
            _error = tx('Wi‑Fi OBD bağlantısı kapandı');
            unawaited(disconnect());
          }
        },
        cancelOnError: true,
      );
      notifyListeners();
      return true;
    } on SocketException catch (error) {
      _error = tx('Wi‑Fi OBD bulunamadı: {0}', [error.message]);
    } on TimeoutException {
      _error = tx('Wi‑Fi OBD bağlantısı zaman aşımına uğradı');
    } catch (error) {
      _error = tx('Wi‑Fi OBD bağlantısı kurulamadı: {0}', [error]);
    }

    _isConnecting = false;
    _isConnected = false;
    notifyListeners();
    return false;
  }

  Future<void> sendCommand(String command) async {
    final socket = _socket;
    if (!_isConnected || socket == null) {
      throw StateError(tx('Wi‑Fi OBD bağlantısı hazır değil'));
    }
    final clean = command.replaceAll('\r', '').replaceAll('\n', '').trim();
    if (clean.isEmpty) return;
    socket.add(utf8.encode('$clean\r'));
    await socket.flush();
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await socket?.close();
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socket?.destroy();
    _socket = null;
    _rxController.close();
    super.dispose();
  }
}
