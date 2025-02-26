import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // StreamSubscription을 위한 import 추가
import '../services/fcm_service.dart';
import '../constants/supabase_constants.dart';
import '../providers/user_data_provider.dart';
import 'package:dba/services/logger_service.dart';
import '../screens/signup_screen.dart';
import '../screens/login_screen.dart';
import '../screens/kakao_login_webview.dart';

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

      // OAuth URL 생성
      final authResponse =
          await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.kakao,
        redirectTo: redirectUrl ?? SupabaseConstants.redirectUrl,
        queryParams: {
          'prompt': 'login',
        },
      );

      if (!context.mounted) return;

      // 웹뷰로 로그인 진행
      final success = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => KakaoLoginWebView(
          initialUrl: authResponse.url,
        ),
      );

      if (success == true) {
        // 로그인 성공 시 세션 확인 및 다음 단계 진행
        await Future.delayed(const Duration(seconds: 1));
        if (!context.mounted) return;

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          await _handleSignedIn(session);
          if (context.mounted) {
            await checkAndNavigate(context);
          }
        }
      } else if (success == false) {
        // 명시적으로 취소된 경우
        LoggerService.info('카카오 로그인이 취소되었습니다.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 취소되었습니다.')),
          );
        }
      }
      // success가 null인 경우는 무시 (백버튼 등으로 인한 닫힘)
    } catch (e, stackTrace) {
      LoggerService.error('카카오 로그인 처리 중 오류 발생', e, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 처리 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  /// 계정 삭제 처리
  Future<void> deleteAccount(BuildContext context) async {
    try {
      // 현재 사용자 정보 가져오기
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      await Supabase.instance.client.rpc(
        'delete_user_data',
        params: {'p_user_id': currentUser.id},
      );

      _userDataProvider.clear();
      dispose();

      if (!context.mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정이 성공적으로 삭제되었습니다.')),
        );
      }
    } catch (e) {
      LoggerService.error('계정 삭제 실패', e, null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계정 삭제 중 오류가 발생했습니다. 관리자에게 문의해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
