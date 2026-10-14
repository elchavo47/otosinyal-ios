import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:otosinyal_obd2/l10n/tx.dart';

class DoipDiagnosticException implements Exception {
  final String message;
  const DoipDiagnosticException(this.message);
  @override
  String toString() => message;
}

/// Minimal ISO 13400 read-only client for DoIP gateways.
///
/// It deliberately exposes only routing activation and diagnostic messages;
/// no ECU coding, security access, flashing or actuator service is available.
class DoipDiagnosticClient {
  static const int defaultPort = 13400;
  static const int testerLogicalAddress = 0x0E00;

  Socket? _socket;
  StreamIterator<Uint8List>? _iterator;
  final List<int> _readBuffer = <int>[];
  int? _entityLogicalAddress;

  bool get isConnected => _socket != null;
  int? get entityLogicalAddress => _entityLogicalAddress;

  Future<void> connect(
    String host, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    await disconnect();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _iterator = StreamIterator<Uint8List>(socket);
      _readBuffer.clear();

      final activation = <int>[
        (testerLogicalAddress >> 8) & 0xFF,
        testerLogicalAddress & 0xFF,
        0x00, // default routing activation type
        0x00,
        0x00,
        0x00,
        0x00,
      ];
      final frame = await _requestFrame(
        0x0005,
        activation,
        timeout: timeout,
        expectedPayloadTypes: const <int>[0x0006],
      );
      if (frame.length < 3 || frame[2] != 0x10 && frame[2] != 0x00) {
        throw DoipDiagnosticException(tx('DoIP routing activation reddedildi'));
      }
      if (frame.length >= 2) {
        _entityLogicalAddress = (frame[0] << 8) | frame[1];
      }
    } catch (error) {
      await disconnect();
      if (error is DoipDiagnosticException) rethrow;
      throw DoipDiagnosticException(tx('DoIP bağlantısı kurulamadı: {0}', [error]));
    }
  }

  Future<List<int>> requestUds(
    int targetLogicalAddress,
    List<int> udsData, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (!isConnected) throw DoipDiagnosticException(tx('DoIP bağlantısı hazır değil'));
    if (targetLogicalAddress < 0 || targetLogicalAddress > 0xFFFF) {
      throw DoipDiagnosticException(tx('Geçersiz DoIP logical address'));
    }
    final payload = <int>[
      (testerLogicalAddress >> 8) & 0xFF,
      testerLogicalAddress & 0xFF,
      (targetLogicalAddress >> 8) & 0xFF,
      targetLogicalAddress & 0xFF,
      ...udsData,
    ];
    final response = await _requestFrame(
      0x8001,
      payload,
      timeout: timeout,
      expectedPayloadTypes: const <int>[0x8001],
    );
    if (response.length < 5) {
      throw DoipDiagnosticException(tx('DoIP teşhis cevabı eksik'));
    }
    return response.sublist(4);
  }

  Future<List<int>> _requestFrame(
    int payloadType,
    List<int> payload, {
    required Duration timeout,
    required List<int> expectedPayloadTypes,
  }) async {
    final socket = _socket;
    final iterator = _iterator;
    if (socket == null || iterator == null) {
      throw DoipDiagnosticException(tx('DoIP socket hazır değil'));
    }

    final bytes = <int>[
      0x02,
      0xFD,
      (payloadType >> 8) & 0xFF,
      payloadType & 0xFF,
      (payload.length >> 24) & 0xFF,
      (payload.length >> 16) & 0xFF,
      (payload.length >> 8) & 0xFF,
      payload.length & 0xFF,
      ...payload,
    ];
    socket.add(bytes);
    await socket.flush();

    final header = await _readExact(iterator, 8, timeout);
    if (header[0] != 0x02 || header[1] != 0xFD) {
      throw DoipDiagnosticException(tx('DoIP protokol başlığı geçersiz'));
    }
    final responseType = (header[2] << 8) | header[3];
    if (!expectedPayloadTypes.contains(responseType)) {
      throw DoipDiagnosticException(tx('Beklenmeyen DoIP payload tipi: 0x{0}', [responseType.toRadixString(16)]));
    }
    final length = (header[4] << 24) | (header[5] << 16) | (header[6] << 8) | header[7];
    if (length < 0 || length > 1024 * 1024) {
      throw DoipDiagnosticException(tx('DoIP payload boyutu geçersiz'));
    }
    return _readExact(iterator, length, timeout);
  }

  Future<List<int>> _readExact(
    StreamIterator<Uint8List> iterator,
    int length,
    Duration timeout,
  ) async {
    while (_readBuffer.length < length) {
      final moved = await iterator.moveNext().timeout(timeout);
      if (!moved) throw DoipDiagnosticException(tx('DoIP bağlantısı kapandı'));
      _readBuffer.addAll(iterator.current);
    }
    final result = _readBuffer.sublist(0, length);
    _readBuffer.removeRange(0, length);
    return result;
  }

  Future<void> disconnect() async {
    final socket = _socket;
    final iterator = _iterator;
    _iterator = null;
    _entityLogicalAddress = null;
    _socket = null;
    _readBuffer.clear();
    await iterator?.cancel();
    await socket?.close();
  }
}
