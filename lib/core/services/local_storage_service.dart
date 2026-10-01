import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.error('Failed to initialize SharedPreferences', e);
    }
  }

  static Future<bool> setString(String key, String value) async {
    if (_prefs == null) return false;
    return await _prefs!.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    if (_prefs == null) return false;
    return await _prefs!.setStringList(key, value);
  }

  static List<String> getStringList(String key) {
    return _prefs?.getStringList(key) ?? [];
  }

  static Future<bool> setBool(String key, bool value) async {
    if (_prefs == null) return false;
    return await _prefs!.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  static Future<bool> remove(String key) async {
    if (_prefs == null) return false;
    return await _prefs!.remove(key);
  }
}
