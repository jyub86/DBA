import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/login_settings_service.dart';
import '../services/logger_service.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true; // true: 로그인 모드, false: 회원가입 모드
  bool _isLoading = true;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();
  final LoginSettingsService _loginSettingsService = LoginSettingsService();

  @override
  void initState() {
    super.initState();
    // 화면이 표시되면 로그인 설정을 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginSetting();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 이메일 로그인 설정 확인
  Future<void> _checkLoginSetting() async {
    try {
      final isEnabled =
          await _loginSettingsService.isLoginMethodEnabled('email');

      if (!isEnabled) {
        // 이메일 로그인이 비활성화된 경우 메인 로그인 화면으로 리다이렉트
        LoggerService.warning('이메일 로그인이 비활성화되어 있어 메인 로그인 화면으로 리다이렉트합니다.');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }

      // 활성화된 경우 로딩 상태 해제
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      // 오류 발생 시 기본적으로 이메일 로그인 허용
      LoggerService.error('로그인 설정 확인 중 오류 발생', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식이 아닙니다';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (!_isLogin && value.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다';
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isLogin) {
          // 로그인 처리
          await _authService.handleEmailLogin(
            context,
            _emailController.text.trim(),
            _passwordController.text,
          );
        } else {
          // 회원가입 처리
          await _authService.handleEmailSignUp(
            context,
            _emailController.text.trim(),
            _passwordController.text,
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? '이메일로 로그인' : '이메일로 회원가입'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: '이메일',
                                hintText: 'example@example.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              enabled: !_isLoading,
                              autofocus: true,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: _validatePassword,
                              enabled: !_isLoading,
                              onFieldSubmitted: (_) => _submitForm(),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _isLogin ? '로그인' : '회원가입',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading ? null : _toggleMode,
                              child: Text(
                                _isLogin
                                    ? '계정이 없으신가요? 회원가입'
                                    : '이미 계정이 있으신가요? 로그인',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            if (_isLogin) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          // 비밀번호 재설정 이메일 보내기
                                          if (_emailController.text.isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    '비밀번호를 재설정할 이메일을 입력해주세요.'),
                                              ),
                                            );
                                            return;
                                          }

                                          setState(() => _isLoading = true);
                                          Supabase.instance.client.auth
                                              .resetPasswordForEmail(
                                            _emailController.text.trim(),
                                          )
                                              .then((_) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    '비밀번호 재설정 링크가 이메일로 발송되었습니다.'),
                                              ),
                                            );
                                          }).catchError((error) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '비밀번호 재설정 중 오류가 발생했습니다: ${error.toString()}'),
                                              ),
                                            );
                                          }).whenComplete(() {
                                            if (mounted) {
                                              setState(
                                                  () => _isLoading = false);
                                            }
                                          });
                                        },
                                  child: const Text('비밀번호를 잊으셨나요?'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
    );
  }
}
