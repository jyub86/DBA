import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'logger_service.dart';

class CrashlyticsService {
  static FirebaseCrashlytics? _crashlyticsInstance;

  static FirebaseCrashlytics get _crashlytics {
    if (_crashlyticsInstance == null) {
      try {
        if (Firebase.apps.isEmpty) {
          LoggerService.error(
              'Crashlytics 인스턴스 접근 실패: Firebase가 초기화되지 않았습니다.', null, null);
          throw Exception('Firebase가 초기화되지 않았습니다.');
        }
        _crashlyticsInstance = FirebaseCrashlytics.instance;
        LoggerService.info('Crashlytics 인스턴스 접근 성공');
      } catch (e) {
        LoggerService.error('Crashlytics 인스턴스 접근 실패', e, null);
        rethrow;
      }
    }
    return _crashlyticsInstance!;
  }

  // Crashlytics 초기화
  static Future<void> init() async {
    try {
      // Firebase 앱이 초기화되었는지 확인
      if (Firebase.apps.isEmpty) {
        LoggerService.error(
            'Crashlytics 초기화 실패: Firebase가 초기화되지 않았습니다.', null, null);
        return;
      }

      // 기본 Firebase 앱 사용
      final firebaseApp = Firebase.apps.isNotEmpty ? Firebase.apps.first : null;

      LoggerService.info(
          'Crashlytics 초기화 시도 중... 앱 이름: ${firebaseApp?.name ?? "[DEFAULT]"}');

      // Crashlytics 인스턴스 초기화
      try {
        _crashlyticsInstance = FirebaseCrashlytics.instance;
        LoggerService.info('Crashlytics 인스턴스 초기화 성공');
      } catch (e) {
        LoggerService.error('Crashlytics 인스턴스 초기화 실패', e, null);
        return;
      }

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

      LoggerService.info('Crashlytics 초기화 성공');
    } catch (e, stackTrace) {
      LoggerService.error('Crashlytics 초기화 실패', e, stackTrace);
    }
  }

  // 사용자 식별자 설정
  static Future<void> setUserIdentifier(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
    } catch (e) {
      LoggerService.error('Crashlytics 사용자 식별자 설정 실패', e, null);
    }
  }

  // 사용자 정보 추가
  static Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (e) {
      LoggerService.error('Crashlytics 커스텀 키 설정 실패', e, null);
    }
  }

  // 로그 메시지 기록
  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (e) {
      LoggerService.error('Crashlytics 로그 기록 실패', e, null);
    }
  }

  // 에러 기록
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        fatal: fatal,
      );
    } catch (e) {
      LoggerService.error('Crashlytics 에러 기록 실패', e, null);
    }
  }
}
