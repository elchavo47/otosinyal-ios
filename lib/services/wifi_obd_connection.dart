import '../providers/wifi_obd_provider.dart';
import 'obd_connection.dart';

class WifiObdConnection implements ObdConnection {
  WifiObdConnection(this.provider);
  final WifiObdProvider provider;

  String get host => provider.host;
  int get port => provider.port;

  @override
  Stream<String> get incoming => provider.rxStream;

  @override
  String get transportId => 'wifi-tcp';

  @override
  bool get isConnected => provider.isConnected;

  @override
  bool get isReconnecting => provider.isReconnecting;

  @override
  Future<void> send(String command) => provider.sendCommand(command);

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() => provider.disconnect();
}
