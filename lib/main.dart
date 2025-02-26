import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dba/constants/supabase_constants.dart';
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
  await Firebase.initializeApp(
    options: FirebaseConstants.firebaseOptions,
  );
  // 백그라운드에서는 Firebase 알림만 사용하고 추가 알림을 생성하지 않음
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase 초기화
    await Firebase.initializeApp(
      options: FirebaseConstants.firebaseOptions,
    );

    // Crashlytics 초기화
    await CrashlyticsService.init();

    // 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // 앱 시작 후 알림 화면으로 이동하기 위한 플래그 설정
      _shouldNavigateToNotification = true;
    }

    NotificationService.navigatorKey = GlobalKey<NavigatorState>();
    await NotificationService().initialize();

    // Supabase 초기화
    await Supabase.initialize(
      url: SupabaseConstants.projectUrl,
      anonKey: SupabaseConstants.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      debug: false,
    );

    // 세션 복원 완료를 기다림
    final completer = Completer<void>();
    late final StreamSubscription<AuthState> subscription;

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
      } else {
        LoggerService.error('세션 복원 중 오류', e, null);
      }
    } finally {
      subscription.cancel();
    }

    // 현재 세션 상태 확인
    final session = Supabase.instance.client.auth.currentSession;

    // FCM 초기화를 나중에 시도하도록 변경
    if (session != null) {
      // FCM 초기화를 비동기로 처리하고 실패해도 앱 실행에 영향을 주지 않도록 함
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await FCMService().initialize();
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }
      });
    }

    runApp(const MyApp());
  } catch (e, stackTrace) {
    LoggerService.error('초기화 중 오류 발생', e, stackTrace);
  }
}

// 앱이 종료된 상태에서 알림 클릭으로 시작된 경우
bool _shouldNavigateToNotification = false;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
                if (_shouldNavigateToNotification) {
                  _shouldNavigateToNotification = false;
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
