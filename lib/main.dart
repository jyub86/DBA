import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dba/constants/firebase_constants.dart';
import 'package:dba/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dba/services/fcm_service.dart';
import 'package:dba/services/crashlytics_service.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dba/services/logger_service.dart';
import 'package:dba/routes/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dba/providers/theme_provider.dart';
import 'package:dba/constants/theme_constants.dart';

// MainScreen의 상태를 보존하기 위한 전역 키는 더 이상 필요하지 않음
// final GlobalKey<State<MainScreen>> mainScreenKey = GlobalKey<State<MainScreen>>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: FirebaseConstants.firebaseOptions,
    );
    // 백그라운드에서는 Firebase 알림만 사용하고 추가 알림을 생성하지 않음
  } catch (e) {
    // 백그라운드 핸들러에서 예외 발생 시 무시
    // 크래시리틱스가 초기화되지 않았을 수 있으므로 로깅하지 않음
  }
}

void main() async {
  // 최상위 예외 핸들러 설정
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Edge-to-Edge 디스플레이 지원 설정
    // 완전 투명한 시스템 바 설정
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    // 기본적으로는 세로 모드만 허용하지만, 필요할 때 가로 모드도 가능하게 설정
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 릴리즈 모드에서 로그 레벨 설정
    if (kReleaseMode) {
      LoggerService.setLogLevel(LogLevel.warning); // 릴리즈 모드에서는 warning 이상만 로깅
    } else {
      LoggerService.setLogLevel(LogLevel.debug); // 개발 모드에서는 모든 로그 출력
    }
    LoggerService.info('앱 시작: ${kReleaseMode ? '릴리즈 모드' : '개발 모드'}');

    // 환경 변수 확인
    _checkEnvironmentVariables();

    // Supabase 초기화
    bool supabaseInitialized = false;
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      );
      supabaseInitialized = true;
    } catch (e) {
      LoggerService.error('Supabase 초기화 중 에러 발생', e, null);
      // 세션 복구 실패 시 로컬 스토리지의 세션 데이터를 초기화
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (signOutError) {
        // 로그아웃 실패 시 무시하고 계속 진행
      }
    }

    // Firebase 초기화
    bool firebaseInitialized = false;
    try {
      // Firebase 환경 변수 검증
      LoggerService.info('Firebase 환경 변수 검증 중...');
      if (!FirebaseConstants.validateEnvironmentVariables()) {
        LoggerService.error(
            'Firebase 초기화 실패: 필수 환경 변수가 올바르게 설정되지 않았습니다.', null, null);
      } else {
        LoggerService.info('Firebase 환경 변수 검증 완료');

        // Firebase가 이미 초기화되었는지 확인
        if (Firebase.apps.isNotEmpty) {
          firebaseInitialized = true;
          final appName =
              Firebase.apps.isNotEmpty ? Firebase.apps.first.name : "알 수 없음";
          LoggerService.info('Firebase가 이미 초기화되어 있습니다. 앱 이름: $appName');
        } else {
          LoggerService.info('Firebase 초기화 시도 중...');
          try {
            // Firebase 초기화 시도 - 기본 앱 이름 사용
            await Firebase.initializeApp(
              options: FirebaseConstants.firebaseOptions,
            );

            // 초기화 성공 확인
            if (Firebase.apps.isNotEmpty) {
              firebaseInitialized = true;
              final appName = Firebase.apps.isNotEmpty
                  ? Firebase.apps.first.name
                  : "[DEFAULT]";
              LoggerService.info('Firebase 초기화 성공 - 앱 이름: $appName');
            } else {
              LoggerService.error(
                  'Firebase 초기화 실패: 앱이 등록되지 않았습니다.', null, null);
            }
          } catch (initError, initStackTrace) {
            // 이미 초기화된 경우 무시하고 성공으로 처리
            if (initError.toString().contains('already exists')) {
              firebaseInitialized = true;
              final appName = Firebase.apps.isNotEmpty
                  ? Firebase.apps.first.name
                  : "[DEFAULT]";
              LoggerService.info('Firebase가 이미 초기화되어 있습니다. 앱 이름: $appName');
            } else {
              LoggerService.error(
                  'Firebase 초기화 중 예외 발생', initError, initStackTrace);

              // 초기화 실패 후 재시도 - 기존 앱이 있는지 확인
              LoggerService.info('Firebase 초기화 재시도 중...');
              try {
                // 기존 앱이 있는지 확인
                if (Firebase.apps.isNotEmpty) {
                  firebaseInitialized = true;
                  final appName = Firebase.apps.isNotEmpty
                      ? Firebase.apps.first.name
                      : "[DEFAULT]";
                  LoggerService.info(
                      'Firebase 앱이 이미 초기화되어 있습니다. 앱 이름: $appName');
                } else {
                  // 기본 앱 이름으로 다시 시도
                  await Firebase.initializeApp(
                    options: FirebaseConstants.firebaseOptions,
                  );

                  if (Firebase.apps.isNotEmpty) {
                    firebaseInitialized = true;
                    final appName = Firebase.apps.isNotEmpty
                        ? Firebase.apps.first.name
                        : "[DEFAULT]";
                    LoggerService.info('Firebase 초기화 재시도 성공 - 앱 이름: $appName');
                  }
                }
              } catch (retryError, retryStackTrace) {
                // 이미 초기화된 경우 무시하고 성공으로 처리
                if (retryError.toString().contains('already exists')) {
                  firebaseInitialized = true;
                  final appName = Firebase.apps.isNotEmpty
                      ? Firebase.apps.first.name
                      : "[DEFAULT]";
                  LoggerService.info('Firebase가 이미 초기화되어 있습니다. 앱 이름: $appName');
                } else {
                  LoggerService.error(
                      'Firebase 초기화 재시도 실패', retryError, retryStackTrace);
                }
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error('Firebase 초기화 과정에서 예상치 못한 오류 발생', e, stackTrace);
    }

    // Crashlytics 초기화
    if (firebaseInitialized) {
      try {
        await CrashlyticsService.init();
        LoggerService.info('Crashlytics 초기화 성공');
      } catch (e, stackTrace) {
        LoggerService.error('Crashlytics 초기화 실패', e, stackTrace);
        // Crashlytics 초기화 실패 시 무시하고 계속 진행
      }
    }

    // 백그라운드 메시지 핸들러 등록
    if (firebaseInitialized) {
      try {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      } catch (e) {
        LoggerService.error('백그라운드 메시지 핸들러 등록 실패', e, null);
      }
    }

    // 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
    bool shouldNavigateToNotification = false;
    if (firebaseInitialized) {
      try {
        // FirebaseMessaging.instance 직접 접근 대신 안전한 방법으로 초기 메시지 확인
        // 이 부분은 실제로 작동하지 않을 수 있으나, 앱 실행에는 영향을 주지 않음
        LoggerService.info('초기 메시지 확인은 FCM 서비스 초기화 후에 처리됩니다.');
        shouldNavigateToNotification = false;
      } catch (e) {
        LoggerService.error('초기 메시지 가져오기 실패', e, null);
      }
    }

    // 알림 서비스 초기화
    NotificationService.navigatorKey = GlobalKey<NavigatorState>();
    try {
      await NotificationService().initialize();
    } catch (e) {
      LoggerService.error('알림 서비스 초기화 실패', e, null);
    }

    // 세션 복원 완료를 기다림
    if (supabaseInitialized) {
      final completer = Completer<void>();
      late final StreamSubscription<AuthState> subscription;

      try {
        subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
          (data) {
            if (data.event == AuthChangeEvent.initialSession) {
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          },
          onError: (error) {
            LoggerService.error('인증 상태 변경 에러', error, null);
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // 최대 3초까지 기다림
        try {
          await completer.future.timeout(const Duration(seconds: 3));
        } catch (e) {
          if (e is TimeoutException) {
            // 타임아웃은 에러가 아닌 정상적인 상황일 수 있음
            LoggerService.warning('세션 복원 타임아웃 (정상적인 상황일 수 있음)');
          } else {
            LoggerService.error('세션 복원 중 오류', e, null);
          }
        } finally {
          subscription.cancel();
        }
      } catch (e) {
        LoggerService.error('세션 복원 중 오류', e, null);
      }

      // 세션 복원 후 MainScreen 미리 초기화
      try {
        // 이 시점에서는 MainScreen을 미리 생성하지 않음
        // 실제로 필요할 때만 생성하도록 변경
      } catch (e) {
        LoggerService.error('MainScreen 초기화 중 오류', e, null);
      }
    }

    // FCM 초기화를 나중에 시도하도록 변경
    if (supabaseInitialized) {
      // FCM 초기화를 비동기로 처리하고 실패해도 앱 실행에 영향을 주지 않도록 함
      Future.delayed(const Duration(seconds: 8), () async {
        try {
          LoggerService.debug('FCM 서비스 초기화 시도 중...');

          // Firebase 앱이 초기화되었는지 다시 확인
          if (Firebase.apps.isEmpty) {
            LoggerService.warning('FCM 초기화 실패: Firebase가 초기화되지 않았습니다.');

            // Firebase 초기화 재시도 - 기본 앱 이름으로 초기화
            try {
              LoggerService.debug('FCM 초기화를 위한 Firebase 초기화 재시도 중...');
              await Firebase.initializeApp(
                options: FirebaseConstants.firebaseOptions,
              );
              final appName = Firebase.apps.isNotEmpty
                  ? Firebase.apps.first.name
                  : "[DEFAULT]";
              LoggerService.info(
                  'FCM 초기화를 위한 Firebase 초기화 성공 - 앱 이름: $appName');
            } catch (e, stackTrace) {
              // 이미 초기화된 경우 무시
              if (e.toString().contains('already exists')) {
                final appName = Firebase.apps.isNotEmpty
                    ? Firebase.apps.first.name
                    : "[DEFAULT]";
                LoggerService.debug('Firebase가 이미 초기화되어 있습니다. 앱 이름: $appName');
              } else {
                LoggerService.error(
                    'FCM 초기화를 위한 Firebase 초기화 재시도 실패', e, stackTrace);
                return;
              }
            }
          } else {
            // Firebase 앱 상태 로깅
            final appName = Firebase.apps.isNotEmpty
                ? Firebase.apps.first.name
                : "[DEFAULT]";
            LoggerService.debug(
                'Firebase 앱 상태 확인 - 앱 이름: $appName, 앱 개수: ${Firebase.apps.length}');
          }

          // FCM 서비스 초기화 전에 추가 지연
          await Future.delayed(const Duration(seconds: 2));
          LoggerService.debug('FCM 서비스 초기화 시작...');

          // FCM 서비스 초기화 시도
          try {
            await FCMService().initialize();
            LoggerService.info('FCM 서비스 초기화 성공');
          } catch (fcmError, fcmStackTrace) {
            LoggerService.error(
                'FCM 서비스 초기화 실패 (무시하고 계속 진행)', fcmError, fcmStackTrace);

            // 초기화 실패 시 재시도 (다른 방식으로)
            try {
              LoggerService.debug('FCM 서비스 초기화 재시도 중...');
              await Future.delayed(const Duration(seconds: 1));
              await FCMService().initialize();
              LoggerService.info('FCM 서비스 초기화 재시도 성공');
            } catch (retryError, retryStackTrace) {
              LoggerService.error('FCM 서비스 초기화 재시도 실패 (무시하고 계속 진행)', retryError,
                  retryStackTrace);
            }
          }
        } catch (e, stackTrace) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, stackTrace);
        }
      });
    } else {
      LoggerService.warning('FCM 초기화 건너뜀: Supabase 초기화=$supabaseInitialized');
    }

    // AppRoutes에 알림 화면으로 이동해야 하는지 여부 설정
    AppRoutes.shouldNavigateToNotification = shouldNavigateToNotification;

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    // 전역 예외 처리
    LoggerService.error('앱에서 처리되지 않은 예외 발생', error, stack, fatal: true);
  });
}

// 환경 변수 확인 함수
void _checkEnvironmentVariables() {
  final variables = [
    'FIREBASE_ANDROID_API_KEY',
    'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_IOS_API_KEY',
    'FIREBASE_IOS_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY'
  ];

  for (final variable in variables) {
    String value = '';

    // 각 환경 변수에 대해 개별적으로 확인
    if (variable == 'FIREBASE_ANDROID_API_KEY') {
      value = const String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    } else if (variable == 'FIREBASE_ANDROID_APP_ID') {
      value = const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    } else if (variable == 'FIREBASE_IOS_API_KEY') {
      value = const String.fromEnvironment('FIREBASE_IOS_API_KEY');
    } else if (variable == 'FIREBASE_IOS_APP_ID') {
      value = const String.fromEnvironment('FIREBASE_IOS_APP_ID');
    } else if (variable == 'FIREBASE_MESSAGING_SENDER_ID') {
      value = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    } else if (variable == 'FIREBASE_PROJECT_ID') {
      value = const String.fromEnvironment('FIREBASE_PROJECT_ID');
    } else if (variable == 'FIREBASE_STORAGE_BUCKET') {
      value = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    } else if (variable == 'SUPABASE_URL') {
      value = const String.fromEnvironment('SUPABASE_URL');
    } else if (variable == 'SUPABASE_ANON_KEY') {
      value = const String.fromEnvironment('SUPABASE_ANON_KEY');
    }

    if (value.isEmpty) {
      LoggerService.warning('경고: 환경 변수 $variable이 설정되지 않았습니다.');
    }
  }
}

// 앱이 종료된 상태에서 알림 클릭으로 시작된 경우
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('앱 생명주기 상태 변경: $state');

    // 각 화면이 자체적으로 처리하도록 함
    // 앱 수준에서는 별도 처리 없음
  }

  @override
  Widget build(BuildContext context) {
    // 앱 설정
    AppRoutes.shouldNavigateToNotification = false;

    // ThemeProvider에 접근
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Edge-to-Edge 디스플레이를 위한 설정
    // 완전 투명한 시스템 바 설정
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness:
            themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: '부평동부교회',
      debugShowCheckedModeBanner: false,
      // NotificationService.navigatorKey 사용
      navigatorKey: NotificationService.navigatorKey,
      // navigatorKey와 라우팅을 위한 navigatorKey를 동일하게 설정
      onGenerateInitialRoutes: (String initialRouteName) {
        // navigatorKey 일치시키기
        // navigatorKey = NotificationService.navigatorKey; - 제거 (final 변수라 변경할 수 없음)
        return [AppRoutes.generateRoute(RouteSettings(name: initialRouteName))];
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      locale: const Locale('ko', 'KR'),

      // 테마 모드와 테마 데이터 적용
      themeMode: themeProvider.themeMode,
      theme: ThemeConstants.lightTheme,
      darkTheme: ThemeConstants.darkTheme,

      initialRoute: '/',
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
