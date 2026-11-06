import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;
  static final Map<String, Object> _memoryCache = <String, Object>{};

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.error('Failed to initialize SharedPreferences', e);
    }
  }

  static Future<SharedPreferences?> _ensurePrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return _prefs;
  }

  static Future<bool> setString(String key, String value) async {
    _memoryCache[key] = value;
    final prefs = await _ensurePrefs();
    if (prefs == null) return true;
    try {
      return await prefs.setString(key, value);
    } catch (_) {
      return true;
    }
  }

  static String? getString(String key) {
    if (_memoryCache.containsKey(key) && _memoryCache[key] is String) {
      return _memoryCache[key] as String;
    }
    try {
      final val = _prefs?.getString(key);
      if (val != null) _memoryCache[key] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    final copy = List<String>.from(value);
    _memoryCache[key] = copy;
    final prefs = await _ensurePrefs();
    if (prefs == null) return true;
    try {
      return await prefs.setStringList(key, copy);
    } catch (_) {
      return true;
    }
  }

  static List<String> getStringList(String key) {
    if (_memoryCache.containsKey(key) && _memoryCache[key] is List<String>) {
      return List<String>.from(_memoryCache[key] as List<String>);
    }
    try {
      final val = _prefs?.getStringList(key);
      if (val != null) {
        final copy = List<String>.from(val);
        _memoryCache[key] = copy;
        return List<String>.from(copy);
      }
    } catch (_) {}
    return <String>[];
  }

  static Future<bool> setBool(String key, bool value) async {
    _memoryCache[key] = value;
    final prefs = await _ensurePrefs();
    if (prefs == null) return true;
    try {
      return await prefs.setBool(key, value);
    } catch (_) {
      return true;
    }
  }

  static bool? getBool(String key) {
    if (_memoryCache.containsKey(key) && _memoryCache[key] is bool) {
      return _memoryCache[key] as bool;
    }
    try {
      final val = _prefs?.getBool(key);
      if (val != null) _memoryCache[key] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setInt(String key, int value) async {
    _memoryCache[key] = value;
    final prefs = await _ensurePrefs();
    if (prefs == null) return true;
    try {
      return await prefs.setInt(key, value);
    } catch (_) {
      return true;
    }
  }

  static int? getInt(String key) {
    if (_memoryCache.containsKey(key) && _memoryCache[key] is int) {
      return _memoryCache[key] as int;
    }
    try {
      final val = _prefs?.getInt(key);
      if (val != null) _memoryCache[key] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> remove(String key) async {
    _memoryCache.remove(key);
    final prefs = await _ensurePrefs();
    if (prefs == null) return true;
    try {
      return await prefs.remove(key);
    } catch (_) {
      return true;
    }
  }
}
