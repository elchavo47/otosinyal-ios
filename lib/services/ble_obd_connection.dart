import 'package:otosinyal_obd2/providers/ble_provider.dart';
import 'package:otosinyal_obd2/services/obd_connection.dart';

class BleObdConnection implements ObdConnection {
  final BleProvider provider;

  BleObdConnection(this.provider);

  @override
  String get transportId => 'bluetooth-ble';

  @override
  Stream<String> get incoming => provider.rxStream;

  @override
  bool get isConnected => provider.isConnected;

  @override
  bool get isReconnecting => provider.isReconnectingBackground;

  @override
  Future<void> send(String command) async {
    await provider.sendCommand(command);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await provider.disconnect();
  }
}
