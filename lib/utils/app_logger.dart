import 'package:flutter/foundation.dart';

/// A simple logger that only prints in debug mode.
class AppLogger {
  /// Logs a message if the app is in debug mode.
  static void debug(Object? message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('DEBUG: $message');
    }
  }

  /// Logs an info message if the app is in debug mode.
  static void info(Object? message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('INFO:  $message');
    }
  }

  /// Logs an error message if the app is in debug mode.
  static void error(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('ERROR: $message');
      if (error != null) {
        // ignore: avoid_print
        print('CAUSE: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print(stackTrace);
      }
    }
  }
}
