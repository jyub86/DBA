import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // StreamSubscription을 위한 import 추가
import '../services/fcm_service.dart';
import '../constants/supabase_constants.dart';
import '../providers/user_data_provider.dart';
import 'package:dba/services/logger_service.dart';
import '../screens/signup_screen.dart';
import '../screens/login_screen.dart';

// 신규 사용자 정보를 임시 저장하기 위한 클래스
class _PendingUser {
  final String email;
  final String profileUrl;
  _PendingUser({required this.email, required this.profileUrl});
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final _fcmService = FCMService();
  final _userDataProvider = UserDataProvider.instance;

  // 딥링크 리스너
  StreamSubscription<AuthState>? _authStateSubscription;
  _PendingUser? _pendingNewUser;
  BuildContext? _lastContext;
  bool _isHandlingDeepLink = false;

  AuthService._internal();

  void setupDeepLinkListener(BuildContext context) {
    try {
      _lastContext = context;
      _authStateSubscription?.cancel();
      _authStateSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) async {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          // 이미 처리 중인 경우 무시
          if (_isHandlingDeepLink) {
            return;
          }

          _isHandlingDeepLink = true;

          try {
            // 로그아웃 이벤트는 무시 (signOut 메서드에서 직접 처리)
            if (event == AuthChangeEvent.signedOut) {
              return;
            }

            if (session != null) {
              await _handleSignedIn(session);

              if (_lastContext != null && _lastContext!.mounted) {
                await checkAndNavigate(_lastContext!);
              }
            }
          } catch (e, stackTrace) {
            LoggerService.error('이벤트 처리 중 오류 발생', e, stackTrace);
          } finally {
            _isHandlingDeepLink = false;
          }
        },
        onError: (error, stackTrace) {
          LoggerService.error('Auth 리스너 에러 발생', error, stackTrace);
          _isHandlingDeepLink = false;
        },
        cancelOnError: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error('리스너 설정 중 오류 발생', e, stackTrace);
      _isHandlingDeepLink = false;
    }
  }

  Future<void> _handleSignedIn(Session session) async {
    try {
      final user = session.user;
      // custom_users 테이블에서 사용자 조회
      final existingUser = await Supabase.instance.client
          .from('custom_users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (existingUser == null) {
        // 신규 사용자 정보를 임시 저장
        _pendingNewUser = _PendingUser(
          email: user.email ?? '',
          profileUrl: user.userMetadata?['avatar_url'] ?? '',
        );
      } else {
        // 기존 사용자 데이터 초기화
        await _userDataProvider.initialize(user.id);
        _pendingNewUser = null;

        // 사용자 데이터가 초기화된 후에만 FCM 초기화 시도
        try {
          await _fcmService.initialize();
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error('로그인 처리 중 오류 발생', e, stackTrace);
      rethrow;
    }
  }

  /// 현재 사용자의 인증 상태를 확인하고 적절한 화면으로 이동
  Future<void> checkAndNavigate(BuildContext context) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      final user = session.user;
      final existingUser = await Supabase.instance.client
          .from('custom_users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (existingUser == null) {
        if (_pendingNewUser != null) {
          // 신규 사용자 등록 화면으로 이동
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SignUpScreen(
                email: _pendingNewUser!.email,
                profileUrl: _pendingNewUser!.profileUrl,
              ),
            ),
          );
        }
      } else {
        // 기존 사용자 데이터 초기화
        await _userDataProvider.initialize(user.id);

        // 사용자 데이터가 초기화된 후에 FCM 초기화 시도
        try {
          await _fcmService.initialize();
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }

        // 메인 화면으로 이동
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('사용자 상태 확인 중 오류 발생', e, stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 상태 확인 중 오류가 발생했습니다.')),
      );
    }
  }

  /// 로그아웃을 위한 리스너 설정
  void addAuthStateListener(BuildContext context) {
    dispose(); // 기존 리스너 정리
    setupDeepLinkListener(context);
  }

  /// 로그아웃 처리
  Future<void> signOut(BuildContext context) async {
    try {
      // 1. 먼저 리스너 비활성화
      dispose();
      _isHandlingDeepLink = true; // 추가 이벤트 처리 방지

      // 2. 모든 상태 및 데이터 정리
      await Future.wait([
        _fcmService.deleteToken(),
        Supabase.instance.client.auth.signOut(),
      ]);
      _userDataProvider.clear();

      // 3. UI 업데이트
      if (!context.mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );

      // 4. 로그아웃 완료 후 리스너 재설정
      if (context.mounted) {
        _isHandlingDeepLink = false;
        setupDeepLinkListener(context);
      }
    } catch (e) {
      _isHandlingDeepLink = false;
      LoggerService.error('로그아웃 실패', e, null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다.')),
      );
    }
  }

  void dispose() {
    ('AuthService 상태 초기화');
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    _lastContext = null;
    _isHandlingDeepLink = false;
    _pendingNewUser = null;
  }

  /// 카카오 로그인 처리
  Future<void> handleKakaoLogin(
      BuildContext context, String? redirectUrl) async {
    try {
      // 현재 세션이 있다면 로그아웃
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        await Supabase.instance.client.auth.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 상태 초기화
      dispose();

      // 딥링크 리스너 설정
      setupDeepLinkListener(context);
      final res = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: redirectUrl ?? SupabaseConstants.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          'prompt': 'login',
        },
      );

      if (!res) {
        LoggerService.info('카카오 로그인 실패: OAuth 프로세스가 시작되지 않았습니다.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오 로그인을 시작할 수 없습니다. 다시 시도해주세요.')),
          );
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error('카카오 로그인 시작 중 오류 발생', e, stackTrace);
      _isHandlingDeepLink = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('로그인을 시작할 수 없습니다.\n잠시 후 다시 시도해주세요.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () {
                handleKakaoLogin(context, redirectUrl);
              },
            ),
          ),
        );
      }
    }
  }
}
