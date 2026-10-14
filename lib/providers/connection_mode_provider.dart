import 'package:flutter/foundation.dart';

enum ConnectionMode { classic, ble, wifi, usb }

/// Kullanıcının seçtiği taşıma katmanını tutar. Teşhis motoru Bluetooth,
/// Wi‑Fi TCP ve Android USB OTG üzerinde aynı komut akışını kullanır.
class ConnectionModeProvider extends ChangeNotifier {
  ConnectionMode _mode = ConnectionMode.ble;
  ConnectionMode get mode => _mode;

  Map<String, dynamic> exportData() => <String, dynamic>{'mode': _mode.name};

  void importData(Map<String, dynamic> data) {
    final name = data['mode'];
    if (name is! String) return;
    ConnectionMode? next;
    for (final item in ConnectionMode.values) {
      if (item.name == name) {
        next = item;
        break;
      }
    }
    if (next == null) return;
    next = _supported(next);
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
  }

  /// iOS'ta Classic/SPP ve USB OTG yok; bunlar BLE'ye düşürülür.
  static ConnectionMode _supported(ConnectionMode mode) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        (mode == ConnectionMode.classic || mode == ConnectionMode.usb)) {
      return ConnectionMode.ble;
    }
    return mode;
  }

  void setMode(ConnectionMode mode) {
    mode = _supported(mode);
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  String get label => switch (_mode) {
        ConnectionMode.classic => 'Bluetooth Classic',
        ConnectionMode.ble => 'Bluetooth BLE',
        ConnectionMode.wifi => 'Wi‑Fi TCP',
        ConnectionMode.usb => 'USB OTG',
      };
}
