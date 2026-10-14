import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:otosinyal_obd2/models/bluetooth_enums.dart';

Future<BluetoothPermissionStatus> requestBluetoothPermissions() async {


  if (Platform.isIOS) {
    // CoreBluetooth reports a rejected authorization as unauthorized.
    // Scanning is still responsible for triggering the initial iOS prompt.
    // İlk erişimde iOS izin penceresi açılır; kullanıcı cevap verene kadar
    // durum "unknown" kalır. Kesin bir duruma geçmesini bekle.
    final state = await FlutterBluePlus.adapterState
        .where((s) =>
            s != BluetoothAdapterState.unknown &&
            s != BluetoothAdapterState.turningOn &&
            s != BluetoothAdapterState.turningOff)
        .first
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
    if (state == BluetoothAdapterState.unauthorized) {
      return BluetoothPermissionStatus.permanentlyDenied;
    }
    return BluetoothPermissionStatus.granted;
  }
  if (!Platform.isAndroid) return BluetoothPermissionStatus.granted;

  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;

  final sdk = androidInfo.version.sdkInt;

  Map<Permission, PermissionStatus> statuses = {};

  if (sdk >= 31) {
    // Android 12+
    statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  } else if (sdk >= 29) {
    // Android 10–11
    statuses = await [Permission.location, Permission.bluetooth].request();
  } else {
    // Android 9 и ниже
    statuses = await [Permission.location].request();
  }

  final isPermanentlyDenied =
      statuses.values.any((s) => s.isPermanentlyDenied);
  if (isPermanentlyDenied) return BluetoothPermissionStatus.permanentlyDenied;

  final isGranted = statuses.values.every((s) => s.isGranted);
  return isGranted
      ? BluetoothPermissionStatus.granted
      : BluetoothPermissionStatus.denied;
}
