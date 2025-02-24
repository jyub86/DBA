import 'package:flutter/foundation.dart';
import 'crashlytics_service.dart';

class LoggerService {
  static void info(String message) {
    if (!kDebugMode) {
      CrashlyticsService.log('INFO: $message');
    } else {
      debugPrint('INFO: $message');
    }
  }

  static void error(
    String message,
    dynamic error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) {
    if (!kDebugMode) {
      CrashlyticsService.recordError(
        error,
        stackTrace,
        reason: message,
        fatal: fatal,
      );
    } else {
      debugPrint('ERROR: $message');
      debugPrint('STACK: $stackTrace');
    }
  }

  static void warning(String message) {
    if (!kDebugMode) {
      CrashlyticsService.log('WARNING: $message');
    } else {
      debugPrint('WARNING: $message');
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }
}
