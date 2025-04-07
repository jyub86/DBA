import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';
import '../providers/user_data_provider.dart';
import '../services/login_settings_service.dart';
import '../services/logger_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final UserDataProvider _userDataProvider = UserDataProvider.instance;
  final LoginSettingsService _loginSettingsService = LoginSettingsService();
  bool _isLoading = false;
  Map<String, bool> _loginMethods = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authService.dispose();
      _authService.setupDeepLinkListener(context);
      _loadLoginSettings();
    });
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  /// 로그인 설정 로딩
  Future<void> _loadLoginSettings() async {
    try {
      final settings = await _loginSettingsService.getLoginSettings();
      if (mounted) {
        setState(() {
          _loginMethods = settings;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('로그인 설정 로딩 실패', e, stackTrace);
      if (mounted) {
        setState(() {
          // 오류 시 기본값으로 모든 로그인 방식 활성화
          _loginMethods = {
            'email': true,
            'kakao': true,
            'google': true,
            'apple': Platform.isIOS // 애플 로그인은 iOS에서만 기본 활성화
          };
          _isLoading = false;
        });
      }
    }
  }

  void _continueAsGuest() {
    _userDataProvider.setGuestMode();

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
    );
  }

  Future<void> _handleKakaoLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _authService.handleKakaoLogin(context, null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _authService.handleAppleLogin(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);
      await _authService.handleGoogleLogin(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEmailLogin() {
    Navigator.pushNamed(context, '/email-login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/images/church_logo.png',
                    width: 200,
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // 이메일 로그인 버튼 (설정에 따라 표시)
                        if (_loginMethods['email'] == true) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _navigateToEmailLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue with Email',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 카카오 로그인 버튼 (설정에 따라 표시)
                        if (_loginMethods['kakao'] == true) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleKakaoLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFE500),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue with Kakao',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 애플 로그인 버튼 (iOS 및 설정에 따라 표시)
                        if (Platform.isIOS &&
                            _loginMethods['apple'] == true) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAppleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue with Apple',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 구글 로그인 버튼 (설정에 따라 표시)
                        if (_loginMethods['google'] == true) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleGoogleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                'Continue with Google',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 게스트 로그인 버튼 (항상 표시)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _isLoading ? null : _continueAsGuest,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              '게스트로 계속하기',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '로그인하지 않으면 일부 기능이 제한됩니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
