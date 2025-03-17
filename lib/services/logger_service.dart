import 'package:flutter/foundation.dart';
import 'crashlytics_service.dart';

enum LogLevel {
  debug, // 가장 상세한 로그 (개발 중에만 사용)
  info, // 일반적인 정보 로그
  warning, // 경고 로그
  error, // 오류 로그
  none // 로그 비활성화
}

class LoggerService {
  // 기본 로그 레벨 설정 - 릴리즈 모드에서는 warning 이상만 로깅
  static LogLevel _currentLogLevel =
      kReleaseMode ? LogLevel.warning : LogLevel.debug;

  // 로그 레벨 설정 메서드
  static void setLogLevel(LogLevel level) {
    _currentLogLevel = level;
  }

  static void info(String message) {
    // info 로그는 현재 로그 레벨이 info 이하일 때만 출력
    if (_currentLogLevel.index <= LogLevel.info.index) {
      if (!kDebugMode) {
        // 릴리즈 모드에서는 중요한 info 로그만 Crashlytics에 기록
        if (message.contains('초기화 성공') ||
            message.contains('초기화 실패') ||
            message.contains('토큰 저장 성공')) {
          CrashlyticsService.log('INFO: $message');
        }
      } else {
        debugPrint('INFO: $message');
      }
    }
  }

  static void error(
    String message,
    dynamic error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) {
    // error 로그는 항상 출력 (로그 레벨이 none이 아닌 경우)
    if (_currentLogLevel != LogLevel.none) {
      if (!kDebugMode) {
        CrashlyticsService.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: fatal,
        );
      } else {
        debugPrint('ERROR: $message');
        if (error != null) {
          debugPrint('ERROR DETAILS: $error');
        }
        if (stackTrace != null) {
          debugPrint('STACK: $stackTrace');
        }
      }
    }
  }

  static void warning(String message) {
    // warning 로그는 현재 로그 레벨이 warning 이하일 때만 출력
    if (_currentLogLevel.index <= LogLevel.warning.index) {
      if (!kDebugMode) {
        CrashlyticsService.log('WARNING: $message');
      } else {
        debugPrint('WARNING: $message');
      }
    }
  }

  static void debug(String message) {
    // debug 로그는 현재 로그 레벨이 debug일 때만 출력하고, 릴리즈 모드에서는 출력하지 않음
    if (_currentLogLevel == LogLevel.debug && kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }
}
