import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının dil tercihi.
enum AppLanguageMode { system, turkish, english }

/// Uygulama dilini yönetir.
///
/// Otomatik modda telefonun dili Türkçe ise Türkçe, diğer tüm dillerde
/// İngilizce kullanılır. Ayarlar'dan elle Türkçe veya İngilizce seçilebilir.
class AppLanguage extends ChangeNotifier with WidgetsBindingObserver {
  AppLanguage() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _prefsKey = 'otosinyal_language_mode';

  static bool _isEnglish = !_systemIsTurkish();

  /// Metin çevirisi için global, bağlamsız erişim.
  static bool get isEnglish => _isEnglish;

  AppLanguageMode _mode = AppLanguageMode.system;
  AppLanguageMode get mode => _mode;

  Locale get locale => _isEnglish ? const Locale('en') : const Locale('tr');

  static bool _systemIsTurkish() {
    final locales = PlatformDispatcher.instance.locales;
    if (locales.isEmpty) return false;
    return locales.first.languageCode.toLowerCase() == 'tr';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _mode = AppLanguageMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => AppLanguageMode.system,
      );
    } catch (_) {
      _mode = AppLanguageMode.system;
    }
    _apply(notify: false);
  }

  Future<void> setMode(AppLanguageMode mode) async {
    _mode = mode;
    _apply();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {}
  }

  void _apply({bool notify = true}) {
    final english = switch (_mode) {
      AppLanguageMode.system => !_systemIsTurkish(),
      AppLanguageMode.turkish => false,
      AppLanguageMode.english => true,
    };
    if (english != _isEnglish) {
      _isEnglish = english;
      if (notify) notifyListeners();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_mode == AppLanguageMode.system) _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
