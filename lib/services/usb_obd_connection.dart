import '../providers/usb_obd_provider.dart';
import 'obd_connection.dart';

class UsbObdConnection implements ObdConnection {
  UsbObdConnection(this.provider);
  final UsbObdProvider provider;

  @override
  Stream<String> get incoming => provider.rxStream;

  @override
  String get transportId => 'usb-otg';

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
