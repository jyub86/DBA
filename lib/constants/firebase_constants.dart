import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:dba/services/logger_service.dart';

class FirebaseConstants {
  static String get apiKey {
    final value = Platform.isIOS
        ? const String.fromEnvironment('FIREBASE_IOS_API_KEY')
        : const String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    if (value.isEmpty) {
      LoggerService.warning('Firebase API Key가 설정되지 않았습니다.');
    }
    return value;
  }

  static String get appId {
    final value = Platform.isIOS
        ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
        : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    if (value.isEmpty) {
      LoggerService.warning('Firebase App ID가 설정되지 않았습니다.');
    }
    return value;
  }

  static String get messagingSenderId {
    const value = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if (value.isEmpty) {
      LoggerService.warning('Firebase Messaging Sender ID가 설정되지 않았습니다.');
    }
    return value;
  }

  static String get projectId {
    const value = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (value.isEmpty) {
      LoggerService.warning('Firebase Project ID가 설정되지 않았습니다.');
    }
    return value;
  }

  static String get storageBucket {
    const value = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    if (value.isEmpty) {
      LoggerService.warning('Firebase Storage Bucket이 설정되지 않았습니다.');
    }
    return value;
  }

  static FirebaseOptions get firebaseOptions {
    final options = FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );

    // 디버그 정보 출력
    LoggerService.info('Firebase 옵션 정보:'
        '\n  플랫폼: ${Platform.isIOS ? 'iOS' : 'Android'}'
        '\n  API Key: ${maskSensitiveInfo(apiKey)}'
        '\n  App ID: ${maskSensitiveInfo(appId)}'
        '\n  Messaging Sender ID: ${maskSensitiveInfo(messagingSenderId)}'
        '\n  Project ID: $projectId'
        '\n  Storage Bucket: $storageBucket');

    return options;
  }

  // 민감한 정보 마스킹 (로그에 전체 키를 노출하지 않기 위함)
  static String maskSensitiveInfo(String value) {
    if (value.isEmpty) return '[비어 있음]';
    if (value.length <= 8) return '****${value.substring(value.length - 4)}';
    return '****${value.substring(value.length - 4)}';
  }

  // 환경 변수가 올바르게 설정되었는지 확인
  static bool validateEnvironmentVariables() {
    bool isValid = true;

    // 플랫폼 확인
    LoggerService.info('현재 플랫폼: ${Platform.isIOS ? 'iOS' : 'Android'}');

    if (apiKey.isEmpty) {
      LoggerService.error('Firebase API Key가 설정되지 않았습니다.', null, null);
      isValid = false;
    }

    if (appId.isEmpty) {
      LoggerService.error('Firebase App ID가 설정되지 않았습니다.', null, null);
      isValid = false;
    }

    if (messagingSenderId.isEmpty) {
      LoggerService.error(
          'Firebase Messaging Sender ID가 설정되지 않았습니다.', null, null);
      isValid = false;
    }

    if (projectId.isEmpty) {
      LoggerService.error('Firebase Project ID가 설정되지 않았습니다.', null, null);
      isValid = false;
    }

    if (storageBucket.isEmpty) {
      LoggerService.error('Firebase Storage Bucket이 설정되지 않았습니다.', null, null);
      isValid = false;
    }

    return isValid;
  }
}
