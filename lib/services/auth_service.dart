import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // StreamSubscription을 위한 import 추가
import '../services/fcm_service.dart';
import '../constants/supabase_constants.dart';
import '../providers/user_data_provider.dart';
import 'package:dba/services/logger_service.dart';
import '../screens/signup_screen.dart';
import '../screens/login_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  // FCM 서비스를 지연 초기화
  FCMService? _fcmServiceInstance;
  FCMService get _fcmService {
    _fcmServiceInstance ??= FCMService();
    return _fcmServiceInstance!;
  }

  final _userDataProvider = UserDataProvider.instance;
  final _client = Supabase.instance.client;

  // 딥링크 리스너
  StreamSubscription<AuthState>? _authStateSubscription;
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

      // 기존 사용자 데이터 초기화
      await _userDataProvider.initialize(user.id);

      // FCM 초기화는 별도로 처리
      _initializeFCMLater();

      // 중복 네비게이션 방지를 위해 checkAndNavigate에서만 처리하도록 수정
      // if (_lastContext != null && _lastContext!.mounted) {
      //   Navigator.pushNamedAndRemoveUntil(
      //     _lastContext!,
      //     '/main',
      //     (route) => false,
      //   );
      // }
    } catch (e, stackTrace) {
      LoggerService.error('로그인 처리 중 오류 발생', e, stackTrace);
      rethrow;
    }
  }

  /// 현재 사용자의 인증 상태를 확인하고 적절한 화면으로 이동
  Future<void> checkAndNavigate(BuildContext context) async {
    if (_isHandlingDeepLink) return; // 이미 처리 중이면 중복 실행 방지
    _isHandlingDeepLink = true;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _isHandlingDeepLink = false;
        return;
      }

      final user = session.user;
      final existingUser = await Supabase.instance.client
          .from('custom_users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (existingUser == null) {
        // custom_users에 데이터가 없는 경우에만 회원가입 화면으로 이동
        String? userName = user.userMetadata?['name'] as String?;

        // 애플 로그인의 경우 이름이 null일 수 있음
        if (userName == null &&
            user.identities?.any((identity) => identity.provider == 'apple') ==
                true) {
          LoggerService.info('애플 로그인: 이름 정보 없음');
        }

        if (!context.mounted) {
          _isHandlingDeepLink = false;
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SignUpScreen(
              email: user.email ?? '',
              profileUrl: '',
              name: userName,
            ),
          ),
        );
      } else {
        // 기존 사용자 데이터 초기화
        await _userDataProvider.initialize(user.id);

        // FCM 초기화는 별도로 처리
        _initializeFCMLater();

        // 메인 화면으로 이동
        if (!context.mounted) {
          _isHandlingDeepLink = false;
          return;
        }

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('사용자 상태 확인 중 오류 발생', e, stackTrace);
      if (!context.mounted) {
        _isHandlingDeepLink = false;
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 상태 확인 중 오류가 발생했습니다.')),
      );
    } finally {
      _isHandlingDeepLink = false;
    }
  }

  /// FCM 초기화를 지연 실행
  void _initializeFCMLater() {
    // 게스트 모드인 경우 FCM 초기화 하지 않음
    if (_userDataProvider.isGuestMode) {
      LoggerService.info('게스트 모드: FCM 초기화 생략');
      return;
    }

    Future.delayed(const Duration(seconds: 1), () async {
      try {
        await _fcmService.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('FCM 초기화 시간 초과');
          },
        );
      } catch (e) {
        LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
      }
    });
  }

  /// 로그아웃을 위한 리스너 설정
  void addAuthStateListener(BuildContext context) {
    dispose(); // 기존 리스너 정리
    setupDeepLinkListener(context);
  }

  /// 세션 복구 시도
  Future<void> recoverSession() async {
    try {
      final currentSession = _client.auth.currentSession;
      if (currentSession?.refreshToken != null) {
        await _client.auth.recoverSession(currentSession!.refreshToken!);
      }
    } catch (e) {
      LoggerService.error('세션 복구 실패', e, null);
      // 세션 복구 실패 시 자동 로그아웃 처리
      await _handleSessionRecoveryFailure();
    }
  }

  /// 세션 복구 실패 처리
  Future<void> _handleSessionRecoveryFailure() async {
    try {
      await _client.auth.signOut();
      _userDataProvider.clear();

      // FCM 토큰 삭제 시도 - 실패해도 계속 진행
      try {
        await _fcmService.deleteToken().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            LoggerService.warning('세션 복구 실패 처리 중 FCM 토큰 삭제 시간 초과');
            return;
          },
        );
      } catch (e) {
        LoggerService.error('세션 복구 실패 처리 중 FCM 토큰 삭제 실패', e, null);
      }
    } catch (e) {
      LoggerService.error('세션 복구 실패 처리 중 에러 발생', e, null);
    }
  }

  /// 로그아웃 처리
  Future<void> signOut(BuildContext context) async {
    try {
      // 1. 먼저 리스너 비활성화
      dispose();
      _isHandlingDeepLink = true; // 추가 이벤트 처리 방지

      // 2. 모든 상태 및 데이터 정리
      try {
        // FCM 토큰 삭제 시도 - 실패해도 계속 진행
        await _fcmService.deleteToken().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            LoggerService.warning('FCM 토큰 삭제 시간 초과 (무시하고 계속 진행)');
            return;
          },
        );
      } catch (e) {
        // FCM 토큰 삭제 실패는 무시하고 계속 진행
        LoggerService.error('FCM 토큰 삭제 실패 (무시하고 계속 진행)', e, null);
      }

      // Supabase 로그아웃 처리
      await _client.auth.signOut();
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
  }

  /// 카카오 로그인 처리
  Future<void> handleKakaoLogin(
      BuildContext context, String? redirectUrl) async {
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
        OAuthProvider.kakao,
        redirectTo: redirectUrl ?? SupabaseConstants.redirectUrl,
        queryParams: {
          'prompt': 'login',
        },
      );

      if (!success) {
        throw Exception('카카오 로그인을 시작할 수 없습니다.');
      }
    } catch (e, stackTrace) {
      LoggerService.error('카카오 로그인 처리 중 오류 발생', e, stackTrace);
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

  /// 계정 삭제 처리
  Future<bool> deleteAccount(BuildContext context) async {
    try {
      // 현재 사용자 정보 가져오기
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 1. 먼저 리스너 비활성화 및 상태 변수 설정
      dispose();
      _isHandlingDeepLink = true;

      // 2. Edge Function 호출하여 계정 삭제
      await _client.functions
          .invoke('delete-account', body: {'user_id': currentUser.id});

      // 3. 모든 상태 및 데이터 정리
      _userDataProvider.clear();
      await _client.auth.signOut();

      return true;
    } catch (e) {
      _isHandlingDeepLink = false;
      LoggerService.error('계정 삭제 실패', e, null);
      return false;
    }
  }

  /// 애플 로그인 처리
  Future<void> handleAppleLogin(BuildContext context) async {
    if (_isHandlingDeepLink) return;

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

      _isHandlingDeepLink = true;

      // 현재 세션이 있다면 로그아웃
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        await Supabase.instance.client.auth.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 상태 초기화
      dispose();
      _isHandlingDeepLink = false;

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

      // 애플 로그인에서 이름 정보 로깅
      LoggerService.info(
          '애플 로그인 이름 정보: ${credential.givenName ?? "없음"} ${credential.familyName ?? ""}');

      // Supabase Apple 로그인 실행
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );

      if (response.session == null) {
        throw Exception('로그인 세션을 생성하지 못했습니다.');
      }

      if (context.mounted) {
        await checkAndNavigate(context);
      }
    } catch (e) {
      LoggerService.error('애플 로그인 중 오류 발생', e, null);
      if (context.mounted) {
        String errorMessage = '로그인 처리 중 오류가 발생했습니다.';
        if (e.toString().contains('canceled')) {
          errorMessage = '로그인이 취소되었습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isHandlingDeepLink = false;
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

  /// 이메일/비밀번호 로그인 처리
  Future<void> handleEmailLogin(
      BuildContext context, String email, String password) async {
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

      // 이메일/비밀번호로 로그인
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw Exception('로그인에 실패했습니다.');
      }

      if (context.mounted) {
        await checkAndNavigate(context);
      }
    } catch (e, stackTrace) {
      LoggerService.error('이메일 로그인 처리 중 오류 발생', e, stackTrace);
      if (context.mounted) {
        String errorMessage = '로그인 처리 중 오류가 발생했습니다.';
        if (e.toString().contains('Invalid login credentials')) {
          errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
        } else if (e.toString().contains('Email not confirmed')) {
          errorMessage = '이메일 인증이 완료되지 않았습니다. 이메일을 확인해주세요.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      _isHandlingDeepLink = false;
    }
  }

  /// 이메일 회원가입 처리
  Future<void> handleEmailSignUp(
      BuildContext context, String email, String password) async {
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

      // 이메일/비밀번호로 회원가입
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.session == null) {
        // 이메일 인증이 필요한 경우
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가입 확인 이메일이 발송되었습니다. 이메일을 확인해주세요.')),
          );
        }
      } else {
        // 이메일 인증 없이 바로 로그인되는 경우
        if (context.mounted) {
          await checkAndNavigate(context);
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error('이메일 회원가입 처리 중 오류 발생', e, stackTrace);
      if (context.mounted) {
        String errorMessage = '회원가입 처리 중 오류가 발생했습니다.';
        if (e.toString().contains('User already registered')) {
          errorMessage = '이미 등록된 이메일입니다.';
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
