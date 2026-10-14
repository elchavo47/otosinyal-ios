import 'package:shared_preferences/shared_preferences.dart';
import 'package:otosinyal_obd2/models/obd_device.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// En son başarıyla bağlanılan cihazı hatırlar, böylece bir sonraki
/// açılışta kullanıcı listeden seçmeden otomatik bağlanabilir.
class AutoConnectService {
  static const _keyAddress = 'otosinyal_last_device_address';
  static const _keyName = 'otosinyal_last_device_name';
  static const _keyIsBle = 'otosinyal_last_device_is_ble';

  static Future<void> saveLastDevice(ObdDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAddress, device.address);
      await prefs.setString(_keyName, device.name);
      await prefs.setBool(_keyIsBle, device.isBle);
    } catch (_) {}
  }

  static Future<ObdDevice?> getLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_keyAddress);
      if (address == null) return null;
      return ObdDevice(
        name: prefs.getString(_keyName) ?? tx('Bilinmeyen Cihaz'),
        address: address,
        isBle: prefs.getBool(_keyIsBle) ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAddress);
      await prefs.remove(_keyName);
      await prefs.remove(_keyIsBle);
    } catch (_) {}
  }
}
