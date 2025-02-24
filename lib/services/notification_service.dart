import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static GlobalKey<NavigatorState>? navigatorKey;

  // Flutter Local Notifications 플러그인 초기화
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Flutter Local Notifications 초기화
    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'high_importance_channel',
              actions: [
                DarwinNotificationAction.plain('id_1', 'Action 1'),
              ],
              options: {
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
                DarwinNotificationCategoryOption.allowAnnouncement,
              },
            )
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    // Android 알림 채널 설정
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: '이 채널은 중요한 알림에 사용됩니다.',
      importance: Importance.high,
      enableLights: true,
      enableVibration: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _handleNotificationTap(String? payload) {
    if (payload != null && navigatorKey?.currentState != null) {
      _navigateToScreen(payload);
    }
  }

  void _navigateToScreen(String payload) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamedAndRemoveUntil(
        '/notification',
        (route) => false,
      );
    }
  }

  // 배지 카운트 초기화 메서드 추가
  Future<void> clearBadgeCount() async {
    // 모든 알림 취소
    await flutterLocalNotificationsPlugin.cancelAll();

    if (Theme.of(navigatorKey!.currentContext!).platform ==
        TargetPlatform.iOS) {
      // iOS에서만 배지 초기화를 위한 빈 알림 전송
      await flutterLocalNotificationsPlugin.show(
        0,
        '',
        '',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            badgeNumber: 0,
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
      );
    }

    // Android는 cancelAll()만으로 충분함
  }
}
