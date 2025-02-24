import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // Crashlytics 초기화
  static Future<void> init() async {
    // 앱이 릴리즈 모드일 때만 Crashlytics 활성화
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Flutter 에러를 Crashlytics로 전송
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!kDebugMode) {
        // 릴리즈 모드에서는 Crashlytics로 에러 전송
        _crashlytics.recordFlutterError(details);
      } else {
        // 디버그 모드에서는 콘솔에 출력
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // 비동기 에러 처리
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kDebugMode) {
        _crashlytics.recordError(error, stack, fatal: true);
      }
      return true;
    };
  }

  // 사용자 식별자 설정
  static Future<void> setUserIdentifier(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }

  // 사용자 정보 추가
  static Future<void> setCustomKey(String key, dynamic value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  // 로그 메시지 기록
  static Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  // 에러 기록
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      information: information,
      fatal: fatal,
    );
  }
}
