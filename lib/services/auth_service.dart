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
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

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
      dispose(); // 기존 상태 초기화
      _lastContext = context;
      _isHandlingDeepLink = false;

      _authStateSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) async {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          // 이미 처리 중인 경우 무시
          if (_isHandlingDeepLink) {
            return;
          }

          try {
            // 로그아웃 이벤트는 무시
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
      _isHandlingDeepLink = false; // 명시적으로 상태 리셋

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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 취소되었습니다.')),
          );
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error('카카오 로그인 처리 중 오류 발생', e, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 처리 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      _isHandlingDeepLink = false; // 항상 상태 리셋
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

  /// 애플 로그인 처리
  Future<void> handleAppleLogin(BuildContext context) async {
    try {
      // iOS 플랫폼 체크
      if (!Platform.isIOS) {
        throw Exception('애플 로그인은 iOS에서만 사용 가능합니다.');
      }

      // 애플 로그인 사용 가능 여부 체크
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('이 기기에서는 애플 로그인을 사용할 수 없습니다.');
      }

      // 현재 세션이 있다면 로그아웃
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        await Supabase.instance.client.auth.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 상태 초기화
      dispose();
      _isHandlingDeepLink = false; // 명시적으로 상태 리셋

      // 딥링크 리스너 설정
      setupDeepLinkListener(context);

      // Apple Sign In 실행
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        throw Exception('애플 로그인 인증 토큰을 받지 못했습니다.');
      }

      // Supabase Apple 로그인 실행
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );

      if (response.session != null) {
        await _handleSignedIn(response.session!);
        if (context.mounted) {
          await checkAndNavigate(context);
        }
      } else {
        throw Exception('로그인 세션을 생성하지 못했습니다.');
      }
    } catch (e, stackTrace) {
      LoggerService.error('애플 로그인 처리 중 오류 발생', e, stackTrace);
      if (context.mounted) {
        String errorMessage = '로그인 처리 중 오류가 발생했습니다.';
        if (e.toString().contains('canceled')) {
          errorMessage = '로그인이 취소되었습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      _isHandlingDeepLink = false; // 항상 상태 리셋
    }
  }

  /// 구글 로그인 처리
  Future<void> handleGoogleLogin(BuildContext context) async {
    if (_isHandlingDeepLink) return;

    try {
      _isHandlingDeepLink = true;

      // 현재 세션이 있다면 로그아웃
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        await Supabase.instance.client.auth.signOut();
      }

      // 상태 초기화
      dispose();
      _isHandlingDeepLink = false;

      // 딥링크 리스너 설정
      setupDeepLinkListener(context);

      // Supabase OAuth 로그인 실행
      final success = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConstants.redirectUrl,
        queryParams: {
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );

      if (!success) {
        throw Exception('구글 로그인을 시작할 수 없습니다.');
      }
    } catch (e, stackTrace) {
      LoggerService.error('구글 로그인 처리 중 오류 발생', e, stackTrace);
      if (context.mounted) {
        String errorMessage = '로그인 처리 중 오류가 발생했습니다.';
        if (e.toString().contains('canceled') || e.toString().contains('취소')) {
          errorMessage = '로그인이 취소되었습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      _isHandlingDeepLink = false;
    }
  }
}
