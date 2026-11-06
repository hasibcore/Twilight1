import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message) {
    debugPrint('[Twilight INFO]: $message');
  }

  static void warning(String message) {
    debugPrint('[Twilight WARN]: $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[Twilight ERROR]: $message | Error: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
