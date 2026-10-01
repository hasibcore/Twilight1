import 'package:flutter/material.dart';
import '../../core/services/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'mt_theme_mode';
  static const String _keyDataSaver = 'mt_data_saver';
  static const String _keyAutoplay = 'mt_autoplay';
  static const String _keyWifiOnly = 'mt_wifi_only';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _dataSaver = false;
  bool _autoplay = true;
  bool _wifiOnly = false;

  ThemeProvider() {
    _loadPreferences();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get dataSaver => _dataSaver;
  bool get autoplay => _autoplay;
  bool get wifiOnly => _wifiOnly;

  void _loadPreferences() {
    final mode = LocalStorageService.getString(_keyThemeMode);
    if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }

    _dataSaver = LocalStorageService.getBool(_keyDataSaver) ?? false;
    _autoplay = LocalStorageService.getBool(_keyAutoplay) ?? true;
    _wifiOnly = LocalStorageService.getBool(_keyWifiOnly) ?? false;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    String val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.system) val = 'system';
    LocalStorageService.setString(_keyThemeMode, val);
    notifyListeners();
  }

  void toggleDataSaver(bool val) {
    _dataSaver = val;
    LocalStorageService.setBool(_keyDataSaver, val);
    notifyListeners();
  }

  void toggleAutoplay(bool val) {
    _autoplay = val;
    LocalStorageService.setBool(_keyAutoplay, val);
    notifyListeners();
  }

  void toggleWifiOnly(bool val) {
    _wifiOnly = val;
    LocalStorageService.setBool(_keyWifiOnly, val);
    notifyListeners();
  }
}
