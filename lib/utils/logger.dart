import 'package:flutter/foundation.dart';

/// Centralized logging utility for the application.
///
/// This logger uses Flutter's `debugPrint` which automatically:
/// - Only logs in debug builds (disabled in release)
/// - Respects Flutter's logging system
/// - Handles long messages properly
///
/// Usage:
/// ```dart
/// Logger.debug('Debug message');
/// Logger.info('Info message');
/// Logger.warning('Warning message');
/// Logger.error('Error message', error, stackTrace);
/// ```
class Logger {
  /// Log a debug message (for verbose debugging)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('🐛 [DEBUG] $message');
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   Stack: $stackTrace');
    }
  }

  /// Log an info message (for general information)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  /// Log a warning message (for non-critical issues)
  static void warning(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('⚠️ [WARNING] $message');
      if (error != null) debugPrint('   Error: $error');
    }
  }

  /// Log an error message (for errors and exceptions)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   Stack: $stackTrace');
    }
  }
}
