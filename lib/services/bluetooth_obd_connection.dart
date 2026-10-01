import 'package:otosinyal_obd2/providers/bluetooth_provider.dart';
import 'package:otosinyal_obd2/services/obd_connection.dart';

class BluetoothObdConnection implements ObdConnection {
  final BluetoothProvider provider;

  BluetoothObdConnection(this.provider);

  @override
  String get transportId => 'bluetooth-classic';

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

  /// DONT IMPLEMENTS!!!!!
  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await provider.disconnect();
  }
}
