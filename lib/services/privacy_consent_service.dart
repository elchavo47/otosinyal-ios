import 'package:shared_preferences/shared_preferences.dart';

/// Gizlilik politikası onay durumunu cihazda kalıcı olarak saklar.
/// Kullanıcı bir kere kabul ettiyse uygulama açılışında tekrar sorulmaz.
class PrivacyConsentService {
  static const _key = 'otosinyal_privacy_consent_accepted';

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, accepted);
  }
}
