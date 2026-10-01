import 'package:otosinyal_obd2/models/bluetooth_enums.dart';
import 'package:otosinyal_obd2/models/obd_device.dart';

/// [BluetoothProvider] (Classic) ve [BleProvider] (BLE) ortak arayüzü.
/// UI katmanı (BluetoothTab ve alt widget'ları) bu sayede hangi
/// bağlantı türüyle konuştuğunu bilmeden aynı kodu kullanabilir.
abstract class ScannableBluetoothProvider {
  bool get isScanning;
  bool get isConnected;
  bool get isConnecting;
  ObdDevice? get connectedDevice;
  List<ObdDevice> get discoveredDevices;
  String get connectionMessage;

  Future<BluetoothScanResult> startScan();
  Future<bool> connectToDevice(ObdDevice device);
  void cancelConnection();
}
