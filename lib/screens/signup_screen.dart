import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/phone_formatter.dart';
import '../models/terms_agreement.dart';
import '../widgets/terms_agreement_widget.dart';
import 'package:dba/services/logger_service.dart';
import '../providers/user_data_provider.dart';
import '../services/fcm_service.dart';

class SignUpScreen extends StatefulWidget {
  final String email;
  final String profileUrl;

  const SignUpScreen({
    super.key,
    required this.email,
    required this.profileUrl,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late TermsAgreement _termsAgreement;
  bool _isInfoPublic = true;

  @override
  void initState() {
    super.initState();
    _termsAgreement = TermsAgreement();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final navigator = Navigator.of(context);
            AuthService().signOut(context).then((_) {
              navigator.pushNamedAndRemoveUntil('/', (route) => false);
            }).catchError((e) {
              LoggerService.error('로그아웃 중 에러 발생', e, null);
              navigator.pushNamedAndRemoveUntil('/', (route) => false);
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '이름',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: '전화번호',
                    hintText: '010-1234-5678',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '전화번호를 입력해주세요';
                    }
                    if (!PhoneFormatter.isValid(value!)) {
                      return '올바른 전화번호 형식이 아닙니다';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final formatted = PhoneFormatter.format(value);
                    if (formatted != value) {
                      _phoneController.value = TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '정보 공개 여부',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Switch(
                            value: _isInfoPublic,
                            onChanged: (value) {
                              setState(() {
                                _isInfoPublic = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '정보 미공개 시 일부 서비스(글 작성 및 주소록 서비스) 사용에 제한을 받을 수 있습니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TermsAgreementWidget(
                  agreement: _termsAgreement,
                  onAgreementChanged: (agreement) {
                    setState(() {
                      _termsAgreement = agreement;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _termsAgreement.isValid ? _handleSignUp : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('가입하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('인증 정보가 없습니다.');
    }

    try {
      final formattedPhone = PhoneFormatter.format(_phoneController.text);

      // 기본 사용자 데이터 준비
      final userData = {
        'auth_id': currentUser.id,
        'email': widget.email,
        'name': _nameController.text,
        'phone': formattedPhone,
        'active': true,
        'is_info_public': _isInfoPublic,
      };

      // 1. 먼저 auth_id로 기존 사용자 확인
      final existingAuthUser = await supabase
          .from('custom_users')
          .select()
          .eq('auth_id', currentUser.id)
          .maybeSingle();

      if (existingAuthUser != null) {
        throw Exception('이미 가입된 사용자입니다.');
      }

      // 2. 이름과 전화번호로 기존 사용자 확인
      final existingUser = await supabase
          .from('custom_users')
          .select()
          .eq('name', _nameController.text)
          .eq('phone', formattedPhone)
          .maybeSingle();

      if (existingUser != null) {
        // 이미 가입된 사용자가 있는 경우 에러 문구 출력 후 종료
        if (existingUser['active'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 가입된 사용자입니다.'),
            ),
          );
          return;
        }

        // 업데이트할 데이터에서 unique 제약조건이 있는 필드들만 선택적으로 업데이트
        final updateData = {
          'auth_id': currentUser.id,
          'email': widget.email,
          'active': true,
          'is_info_public': _isInfoPublic,
        };

        // 기존 사용자 정보 업데이트
        await supabase
            .from('custom_users')
            .update(updateData)
            .eq('id', existingUser['id']);

        // UserDataProvider 초기화
        await UserDataProvider.instance.initialize(currentUser.id);

        // FCM 초기화 (사용자 데이터 초기화 후)
        try {
          await FCMService().initialize();
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }

        if (mounted) {
          await AuthService().checkAndNavigate(context);
        }
      } else {
        // 새 사용자 등록
        await supabase.from('custom_users').insert(userData);

        // UserDataProvider 초기화
        await UserDataProvider.instance.initialize(currentUser.id);

        // FCM 초기화 (사용자 데이터 초기화 후)
        try {
          await FCMService().initialize();
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }

        if (mounted) {
          await AuthService().checkAndNavigate(context);
        }
      }
    } catch (e) {
      LoggerService.error('회원가입 처리 중 오류 발생', e, null);
      if (mounted) {
        String errorMessage = '회원가입 처리 중 오류가 발생했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
