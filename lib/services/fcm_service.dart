import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'notification_service.dart';
import 'logger_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Flutter Local Notifications 플러그인
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (_isInitializing) {
      return;
    }

    final session = _supabase.auth.currentSession;
    if (session == null) {
      return;
    }

    _isInitializing = true;

    try {
      if (Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // FCM 권한 요청
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
        announcement: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        LoggerService.warning('사용자가 알림 권한을 거부했습니다.');
        return;
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
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
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
      });

      // 백그라운드에서 알림 클릭 시 처리
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationClick(message.data.toString());
      });

      // 앱이 완전히 종료된 상태에서 알림 클릭으로 시작된 경우 처리
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(seconds: 1), () {
          handleNotificationClick(initialMessage.data.toString());
        });
      }

      // FCM 토큰 얻기 시도
      String? token;
      try {
        token = await _messaging.getToken();
        if (token == null) {
          LoggerService.error('FCM 토큰을 가져올 수 없습니다.', null, null);
          return;
        }
      } catch (e) {
        LoggerService.error('FCM 토큰 가져오기 실패', e, null);
        return;
      }

      // 토큰 갱신 리스너 설정
      _messaging.onTokenRefresh.listen((String newToken) async {
        if (_isInitializing) {
          return;
        }
        await updateFCMToken(newToken);
      });

      await updateFCMToken(token);
      _isInitialized = true;
    } catch (e) {
      LoggerService.error('FCM 서비스 초기화 중 오류 발생', e, null);
      _isInitialized = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> updateFCMToken(String token) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return;
    }

    final userId = session.user.id;

    try {
      final deviceType = await _getDeviceInfo();

      // 1. 먼저 기존 토큰 확인
      final response = await _supabase
          .from('user_tokens')
          .select()
          .eq('user_id', userId)
          .eq('device_type', deviceType)
          .maybeSingle();

      if (response != null) {
        // 2. 기존 토큰 업데이트
        await _supabase
            .from('user_tokens')
            .update({
              'fcm_token': token,
            })
            .eq('user_id', userId)
            .eq('device_type', deviceType);
      } else {
        // 3. 새 토큰 저장
        await _supabase.from('user_tokens').insert({
          'user_id': userId,
          'fcm_token': token,
          'device_type': deviceType,
        });
      }
    } catch (e) {
      LoggerService.error('FCM 토큰 저장 중 오류 발생', e, null);
      rethrow; // 상위 레벨에서 처리할 수 있도록 에러를 전파
    }
  }

  Future<String> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.name} ${iosInfo.systemVersion}';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.brand} ${androidInfo.model}';
    }
    return 'Unknown device';
  }

  Future<void> deleteToken() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return;
    }

    final userId = session.user.id;

    try {
      // 현재 디바이스의 토큰만 삭제
      await _supabase
          .from('user_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('device_type', await _getDeviceInfo());

      // Firebase에서 토큰 삭제
      await _messaging.deleteToken();
      _isInitialized = false;
    } catch (e) {
      LoggerService.error('FCM 토큰 삭제 실패', e, null);
    }
  }

  void handleNotificationClick(String payload) {
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
        if (NotificationService.navigatorKey?.currentState != null) {
          NotificationService.navigatorKey!.currentState!
              .pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
            arguments: {'initialIndex': 3}, // 알림 탭 인덱스
          );
        }
      });
    }
  }
}
