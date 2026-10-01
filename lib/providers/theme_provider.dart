import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OtoThemePreference { system, day, night }

class ThemeProvider extends ChangeNotifier {
  static const _storageKey='otosinyal_theme_preference';
  OtoThemePreference _preference=OtoThemePreference.system;

  OtoThemePreference get preference=>_preference;
  ThemeMode get themeMode=>switch(_preference){
    OtoThemePreference.system=>ThemeMode.system,
    OtoThemePreference.day=>ThemeMode.light,
    OtoThemePreference.night=>ThemeMode.dark,
  };
  String get label=>switch(_preference){
    OtoThemePreference.system=>'Sistem',
    OtoThemePreference.day=>'Gündüz gri',
    OtoThemePreference.night=>'Gece koyu',
  };

  ThemeProvider(){_load();}

  Future<void> _load() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final saved=prefs.getString(_storageKey);
      _preference=OtoThemePreference.values.firstWhere(
        (item)=>item.name==saved,
        orElse:()=>OtoThemePreference.system,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPreference(OtoThemePreference value) async {
    if(_preference==value)return;
    _preference=value;
    notifyListeners();
    try {
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString(_storageKey,value.name);
    } catch (_) {}
  }
}
