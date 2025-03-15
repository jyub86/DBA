import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dba/constants/firebase_constants.dart';
import 'package:dba/screens/login_screen.dart';
import 'package:dba/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dba/screens/main_screen.dart';
import 'package:dba/services/fcm_service.dart';
import 'package:dba/services/crashlytics_service.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dba/services/logger_service.dart';

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
      // Firebase가 이미 초기화되었는지 확인
      if (Firebase.apps.isNotEmpty) {
        firebaseInitialized = true;
      } else {
        await Firebase.initializeApp(
          options: FirebaseConstants.firebaseOptions,
        );
        firebaseInitialized = true;
      }
    } catch (e) {
      LoggerService.error('Firebase 초기화 중 에러 발생', e, null);
    }

    // Crashlytics 초기화
    if (firebaseInitialized) {
      try {
        await CrashlyticsService.init();
      } catch (e) {
        LoggerService.error('Crashlytics 초기화 실패', e, null);
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
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          // 앱 시작 후 알림 화면으로 이동하기 위한 플래그 설정
          shouldNavigateToNotification = true;
        }
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
    Session? session;
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
        LoggerService.error('세션 복원 과정 중 오류', e, null);
      }
    }

    // FCM 초기화를 나중에 시도하도록 변경
    if (firebaseInitialized && supabaseInitialized && session != null) {
      // FCM 초기화를 비동기로 처리하고 실패해도 앱 실행에 영향을 주지 않도록 함
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await FCMService().initialize();
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }
      });
    } else {
      LoggerService.warning(
          'FCM 초기화 건너뜀: Firebase 초기화=$firebaseInitialized, Supabase 초기화=$supabaseInitialized, 세션=${session != null}');
    }

    runApp(MyApp(shouldNavigateToNotification: shouldNavigateToNotification));
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
class MyApp extends StatelessWidget {
  final bool shouldNavigateToNotification;

  const MyApp({super.key, this.shouldNavigateToNotification = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: '부평동부교회',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      locale: const Locale('ko', 'KR'),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: Colors.grey.shade800,
          onPrimary: Colors.white,
          secondary: Colors.grey.shade600,
          onSecondary: Colors.white,
          surface: Colors.white,
          error: Colors.red.shade400,
          onSurface: Colors.grey.shade900,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey.shade900,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.grey.shade900),
          actionsIconTheme: IconThemeData(color: Colors.grey.shade900),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade800,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade800,
          ),
        ),
        iconTheme: IconThemeData(
          color: Colors.grey.shade800,
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.grey.shade800),
          bodyMedium: TextStyle(color: Colors.grey.shade700),
          bodySmall: TextStyle(color: Colors.grey.shade600),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade200,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade700),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) {
                if (shouldNavigateToNotification) {
                  return const MainScreen(initialIndex: 3);
                }
                return const LoginScreen();
              },
              settings: settings,
            );

          case '/login-callback':
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: settings,
            );

          case '/main':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => MainScreen(
                initialIndex: args?['initialIndex'] ?? 0,
                initialCategoryId: args?['initialCategoryId'],
              ),
              settings: settings,
            );

          case '/notification':
            return MaterialPageRoute(
              builder: (context) => const MainScreen(
                initialIndex: 3,
              ),
              settings: settings,
            );

          default:
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: settings,
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
