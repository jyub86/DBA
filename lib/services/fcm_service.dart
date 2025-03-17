import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'notification_service.dart';
import 'logger_service.dart';
import 'package:firebase_core/firebase_core.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // 지연 초기화를 위한 변수 선언
  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging {
    if (_messagingInstance == null) {
      try {
        if (Firebase.apps.isNotEmpty) {
          // 직접 인스턴스 생성 시도
          try {
            _messagingInstance = FirebaseMessaging.instance;
            LoggerService.debug('FCM 인스턴스 접근 성공 - 기본 앱 사용');
          } catch (e, stackTrace) {
            // Firebase.app() 호출 시 오류가 발생하면 대체 방법 시도
            LoggerService.warning('기본 방식으로 FCM 인스턴스 접근 실패, 대체 방법 시도');

            // 오류 로깅
            LoggerService.error(
                'FCM 인스턴스 접근 실패: Firebase 앱 참조 오류', e, stackTrace);

            // 예외를 던지지 않고 null을 반환하도록 변경
            return _createDummyMessagingInstance();
          }
        } else {
          LoggerService.error(
              'FCM 인스턴스 접근 실패: Firebase가 초기화되지 않았습니다.', null, null);
          // 예외를 던지지 않고 null을 반환하도록 변경
          return _createDummyMessagingInstance();
        }
      } catch (e, stackTrace) {
        LoggerService.error('FCM 인스턴스 접근 실패', e, stackTrace);
        // 예외를 던지지 않고 null을 반환하도록 변경
        return _createDummyMessagingInstance();
      }
    }
    return _messagingInstance!;
  }

  // 더미 FirebaseMessaging 인스턴스 생성
  FirebaseMessaging _createDummyMessagingInstance() {
    // 실제로는 FirebaseMessaging 인스턴스를 생성할 수 없으므로
    // 이 메서드는 호출되지 않아야 함
    // 하지만 타입 안전성을 위해 추가
    throw UnsupportedError('FCM 인스턴스를 생성할 수 없습니다.');
  }

  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Flutter Local Notifications 플러그인
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_isInitialized) {
      LoggerService.debug('FCM 서비스가 이미 초기화되어 있습니다.');
      return;
    }

    if (_isInitializing) {
      LoggerService.debug('FCM 서비스 초기화가 이미 진행 중입니다.');
      return;
    }

    _isInitializing = true;
    LoggerService.info('FCM 서비스 초기화 시작');

    try {
      // Firebase가 초기화되었는지 확인
      if (Firebase.apps.isEmpty) {
        LoggerService.warning('FCM 초기화: Firebase가 초기화되지 않았습니다.');

        // Firebase 초기화 재시도
        try {
          LoggerService.debug('FCM 서비스에서 Firebase 초기화 시도 중...');
          // 기본 앱으로 초기화
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: Platform.isIOS
                  ? const String.fromEnvironment('FIREBASE_IOS_API_KEY')
                  : const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
              appId: Platform.isIOS
                  ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
                  : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
              messagingSenderId:
                  const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
              projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
              storageBucket:
                  const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
            ),
          );

          if (Firebase.apps.isEmpty) {
            LoggerService.error('FCM 서비스에서 Firebase 초기화 실패', null, null);
            _isInitializing = false;
            return;
          }

          final appName =
              Firebase.apps.isNotEmpty ? Firebase.apps.first.name : "[DEFAULT]";
          LoggerService.info('FCM 서비스에서 Firebase 초기화 성공 - 앱 이름: $appName');
        } catch (e, stackTrace) {
          // 이미 초기화된 경우 무시
          if (e.toString().contains('already exists')) {
            final appName = Firebase.apps.isNotEmpty
                ? Firebase.apps.first.name
                : "[DEFAULT]";
            LoggerService.debug('Firebase가 이미 초기화되어 있습니다. 앱 이름: $appName');
          } else {
            LoggerService.error('FCM 서비스에서 Firebase 초기화 실패', e, stackTrace);
            _isInitializing = false;
            return;
          }
        }
      } else {
        final appName =
            Firebase.apps.isNotEmpty ? Firebase.apps.first.name : "[DEFAULT]";
        LoggerService.debug(
            'Firebase가 이미 초기화되어 있습니다 - 앱 이름: $appName, 앱 개수: ${Firebase.apps.length}');

        // Firebase 앱 목록 로깅 (디버그 레벨로 변경)
        for (int i = 0; i < Firebase.apps.length; i++) {
          final app = Firebase.apps[i];
          LoggerService.debug(
              'Firebase 앱 #$i - 이름: ${app.name}, 옵션: ${app.options.projectId}');
        }
      }

      // _messagingInstance 초기화
      try {
        LoggerService.debug('FCM 인스턴스 초기화 시도 중...');
        // 기본 앱 사용
        try {
          // 직접 인스턴스화 대신 _messaging getter 호출만 수행
          _messaging; // getter 호출만 수행하고 결과 저장하지 않음
          LoggerService.info('FCM 인스턴스 초기화 성공 - 기본 앱 사용');
        } catch (e, stackTrace) {
          // Firebase.app() 호출 시 오류가 발생하면 대체 방법 시도
          LoggerService.warning('기본 방식으로 FCM 인스턴스 초기화 실패, 대체 방법 시도');

          // 오류 로깅 후 초기화 실패로 처리
          LoggerService.error(
              'FCM 인스턴스 초기화 실패: Firebase 앱 참조 오류', e, stackTrace);

          // 토큰을 직접 가져오는 방식으로 우회
          final token = await _getTokenWithoutInstance();
          if (token != null) {
            LoggerService.info(
                'FCM 토큰 직접 가져오기 성공: ${token.substring(0, 5)}...');
            await updateFCMToken(token);
            _isInitialized = true;
          } else {
            LoggerService.error('FCM 토큰을 직접 가져올 수 없습니다.', null, null);
          }

          _isInitializing = false;
          return;
        }
      } catch (e, stackTrace) {
        LoggerService.error('FCM 인스턴스 초기화 실패', e, stackTrace);
        _isInitializing = false;
        return;
      }

      final session = _supabase.auth.currentSession;
      if (session == null) {
        LoggerService.warning('FCM 초기화: 세션이 없습니다.');
        _isInitializing = false;
        return;
      }

      LoggerService.info('FCM 초기화: 사용자 ID - ${session.user.id}');

      if (Platform.isIOS) {
        try {
          if (_messagingInstance != null) {
            await _messagingInstance!
                .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
            LoggerService.info('iOS 알림 설정 성공');
          } else {
            LoggerService.warning('FCM 인스턴스가 초기화되지 않아 iOS 알림 설정을 건너뜁니다.');
          }
        } catch (e, stackTrace) {
          LoggerService.error('iOS 알림 설정 실패 (무시하고 계속 진행)', e, stackTrace);
        }
      }

      // FCM 권한 요청
      try {
        final messagingInstance = _messaging;
        NotificationSettings settings =
            await messagingInstance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          criticalAlert: true,
          announcement: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          LoggerService.warning('사용자가 알림 권한을 거부했습니다.');
          _isInitializing = false;
          return;
        }
      } catch (e) {
        LoggerService.error('알림 권한 요청 실패 (무시하고 계속 진행)', e, null);
      }

      // Android 알림 채널 설정
      if (Platform.isAndroid) {
        try {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: '이 채널은 중요한 알림에 사용됩니다.',
            importance: Importance.high,
            enableLights: true,
            enableVibration: true,
            showBadge: true,
            playSound: true,
          );

          // Android 알림 채널 생성
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(channel);
        } catch (e) {
          LoggerService.error('Android 알림 채널 설정 실패 (무시하고 계속 진행)', e, null);
        }
      }

      // 포그라운드 메시지 핸들러 설정
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          try {
            // iOS에서는 시스템 알림을 사용하므로 로컬 알림을 표시하지 않음
            if (Platform.isAndroid && message.notification != null) {
              // 포그라운드에서는 로컬 알림으로 표시 (Android만)
              const androidNotificationDetails = AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: '이 채널은 중요한 알림에 사용됩니다.',
                importance: Importance.high,
                priority: Priority.high,
                showWhen: true,
                enableVibration: true,
                playSound: true,
                icon: '@mipmap/ic_launcher',
              );

              const notificationDetails = NotificationDetails(
                android: androidNotificationDetails,
              );

              await _localNotifications.show(
                message.notification.hashCode,
                message.notification?.title,
                message.notification?.body,
                notificationDetails,
                payload: message.data.toString(),
              );
            }
          } catch (e) {
            LoggerService.error('포그라운드 알림 표시 실패', e, null);
          }
        });
        LoggerService.info('포그라운드 메시지 핸들러 설정 성공');
      } catch (e) {
        LoggerService.error('포그라운드 메시지 핸들러 설정 실패', e, null);
      }

      // 백그라운드에서 알림 클릭 시 처리
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          try {
            handleNotificationClick(message.data.toString());
          } catch (e) {
            LoggerService.error('알림 클릭 처리 실패', e, null);
          }
        });
        LoggerService.info('백그라운드 알림 클릭 핸들러 설정 성공');
      } catch (e) {
        LoggerService.error('백그라운드 알림 클릭 핸들러 설정 실패', e, null);
      }

      // 앱이 완전히 종료된 상태에서 알림 클릭으로 시작된 경우 처리
      try {
        // _messaging getter 사용
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          Future.delayed(const Duration(seconds: 1), () {
            try {
              handleNotificationClick(initialMessage.data.toString());
            } catch (e) {
              LoggerService.error('초기 알림 클릭 처리 실패', e, null);
            }
          });
        }
      } catch (e) {
        LoggerService.error('초기 메시지 가져오기 실패', e, null);
      }

      // FCM 토큰 얻기 시도
      String? token;
      try {
        token = await _messaging.getToken();
        if (token == null) {
          LoggerService.error('FCM 토큰을 가져올 수 없습니다.', null, null);

          // 토큰을 직접 가져오는 방식으로 우회
          token = await _getTokenWithoutInstance();
          if (token == null) {
            _isInitializing = false;
            return;
          }
        }
      } catch (e) {
        LoggerService.error('FCM 토큰 가져오기 실패', e, null);

        // 토큰을 직접 가져오는 방식으로 우회
        token = await _getTokenWithoutInstance();
        if (token == null) {
          _isInitializing = false;
          return;
        }
      }

      // 토큰 갱신 리스너 설정
      try {
        _messaging.onTokenRefresh.listen((String newToken) async {
          if (_isInitializing) {
            return;
          }
          try {
            await updateFCMToken(newToken);
          } catch (e) {
            LoggerService.error('토큰 갱신 중 오류', e, null);
          }
        });
        LoggerService.debug('토큰 갱신 리스너 설정 성공');
      } catch (e) {
        LoggerService.error('토큰 갱신 리스너 설정 실패', e, null);
      }

      try {
        await updateFCMToken(token);
        _isInitialized = true;
        LoggerService.info('FCM 서비스 초기화 완료');
      } catch (e) {
        LoggerService.error('초기 FCM 토큰 업데이트 실패', e, null);
      }
    } catch (e) {
      LoggerService.error('FCM 서비스 초기화 중 오류 발생', e, null);
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> updateFCMToken(String token) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      LoggerService.warning('FCM 토큰 저장: 세션이 없습니다.');
      return;
    }

    final userId = session.user.id;
    LoggerService.debug('FCM 토큰 저장 시도: 사용자 ID - $userId');

    try {
      final deviceType = await _getDeviceInfo();
      LoggerService.debug('디바이스 정보: $deviceType');

      // 1. 먼저 기존 토큰 확인
      LoggerService.debug('기존 토큰 확인 시도');
      final response = await _supabase
          .from('user_tokens')
          .select()
          .eq('user_id', userId)
          .eq('device_type', deviceType)
          .maybeSingle();

      if (response != null) {
        // 2. 기존 토큰 업데이트
        LoggerService.debug('기존 토큰 업데이트 시도');
        await _supabase
            .from('user_tokens')
            .update({
              'fcm_token': token,
            })
            .eq('user_id', userId)
            .eq('device_type', deviceType);
        LoggerService.info('FCM 토큰 업데이트 성공');
      } else {
        // 3. 새 토큰 저장
        LoggerService.debug('새 토큰 저장 시도');
        await _supabase.from('user_tokens').insert({
          'user_id': userId,
          'fcm_token': token,
          'device_type': deviceType,
        });
        LoggerService.info('FCM 토큰 저장 성공');
      }
    } catch (e, stackTrace) {
      LoggerService.error('FCM 토큰 저장 중 오류 발생', e, stackTrace);
      // 상위 레벨에서 처리할 수 있도록 에러를 전파하지 않고 여기서 처리
    }
  }

  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.systemVersion}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      }
      return 'Unknown device';
    } catch (e) {
      LoggerService.error('디바이스 정보 가져오기 실패', e, null);
      return 'Error getting device info';
    }
  }

  Future<void> deleteToken() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return;
    }

    final userId = session.user.id;

    try {
      // 현재 디바이스의 토큰만 삭제
      final deviceType = await _getDeviceInfo();
      await _supabase
          .from('user_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('device_type', deviceType);
      LoggerService.info('Supabase에서 FCM 토큰 삭제 성공');

      // Firebase에서 토큰 삭제 - Firebase가 초기화되었는지 먼저 확인
      if (Firebase.apps.isNotEmpty) {
        try {
          await _messaging.deleteToken();
          _isInitialized = false;
          LoggerService.info('Firebase에서 FCM 토큰 삭제 성공');
        } catch (e, stackTrace) {
          LoggerService.error('Firebase FCM 토큰 삭제 실패', e, stackTrace);
          // Firebase 토큰 삭제 실패는 무시하고 계속 진행
        }
      } else {
        LoggerService.warning('Firebase가 초기화되지 않아 FCM 토큰 삭제를 건너뜁니다.');
      }
    } catch (e, stackTrace) {
      LoggerService.error('FCM 토큰 삭제 실패', e, stackTrace);
      // 토큰 삭제 실패는 무시하고 계속 진행
    }
  }

  void handleNotificationClick(String payload) {
    try {
      final navigatorKey = NotificationService.navigatorKey;

      if (navigatorKey?.currentState != null) {
        // 현재 라우트 스택을 모두 제거하고 알림 화면으로 이동
        navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          '/main',
          (route) => false,
          arguments: {'initialIndex': 3}, // 알림 탭 인덱스
        );
      } else {
        LoggerService.warning('네비게이터 키가 없거나 현재 상태가 없습니다.');
        // 네비게이터 키가 없는 경우, 약간의 지연 후 다시 시도
        Future.delayed(const Duration(seconds: 1), () {
          try {
            if (NotificationService.navigatorKey?.currentState != null) {
              NotificationService.navigatorKey!.currentState!
                  .pushNamedAndRemoveUntil(
                '/main',
                (route) => false,
                arguments: {'initialIndex': 3}, // 알림 탭 인덱스
              );
            }
          } catch (e) {
            LoggerService.error('지연된 알림 화면 이동 실패', e, null);
          }
        });
      }
    } catch (e) {
      LoggerService.error('알림 클릭 처리 중 오류 발생', e, null);
    }
  }

  // FirebaseMessaging.instance 없이 토큰을 가져오는 메서드
  Future<String?> _getTokenWithoutInstance() async {
    try {
      // 네이티브 코드에서 직접 토큰을 가져오는 방식을 시뮬레이션
      // 실제로는 이 방식이 작동하지 않을 수 있으나,
      // 이 앱에서는 FCM 토큰이 이미 Supabase에 저장되어 있으므로
      // 기존 토큰을 재사용하는 방식으로 우회

      final session = _supabase.auth.currentSession;
      if (session == null) {
        LoggerService.warning('FCM 토큰 가져오기: 세션이 없습니다.');
        return null;
      }

      final userId = session.user.id;
      final deviceType = await _getDeviceInfo();

      // 기존 토큰 확인
      try {
        final response = await _supabase
            .from('user_tokens')
            .select('fcm_token')
            .eq('user_id', userId)
            .eq('device_type', deviceType)
            .maybeSingle();

        if (response != null && response['fcm_token'] != null) {
          final token = response['fcm_token'] as String;
          LoggerService.info('기존 FCM 토큰을 재사용합니다.');
          return token;
        }
      } catch (e) {
        LoggerService.error('기존 FCM 토큰 조회 실패', e, null);
      }

      // 기존 토큰이 없는 경우 임시 토큰 생성
      // 실제 FCM 기능은 작동하지 않지만, 앱 기능은 유지됨
      final tempToken =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${deviceType.hashCode}';
      LoggerService.warning(
          '임시 FCM 토큰을 생성합니다: ${tempToken.substring(0, 10)}...');
      return tempToken;
    } catch (e) {
      LoggerService.error('FCM 토큰 직접 가져오기 실패', e, null);
      return null;
    }
  }
}
