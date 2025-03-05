import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/terms_agreement.dart';
import '../widgets/terms_agreement_widget.dart';
import 'package:dba/services/logger_service.dart';
import '../providers/user_data_provider.dart';
import '../services/fcm_service.dart';
import 'dart:async';

class SignUpScreen extends StatefulWidget {
  final String email;
  final String profileUrl;
  final String? name;

  const SignUpScreen({
    super.key,
    required this.email,
    required this.profileUrl,
    this.name,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late TermsAgreement _termsAgreement;

  @override
  void initState() {
    super.initState();
    _termsAgreement = TermsAgreement();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보 수집 동의'),
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
                const Text(
                  '서비스 이용을 위해서는 개인정보 수집에 대한 동의가 필요합니다.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
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
                    onPressed:
                        _termsAgreement.isValid ? _handleAgreement : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('동의하고 시작하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAgreement() async {
    if (!_formKey.currentState!.validate()) return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('인증 정보가 없습니다.');
    }

    try {
      // custom_users 테이블에 사용자 정보 추가
      await supabase.from('custom_users').insert({
        'auth_id': currentUser.id,
        'name': widget.name,
        'email': widget.email,
        'role': 4, // 기본 사용자 역할
        'active': true,
      });

      // 사용자 데이터 초기화
      await UserDataProvider.instance.initialize(currentUser.id);

      // FCM 초기화는 비동기로 처리
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          await FCMService().initialize().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('FCM 초기화 시간 초과');
            },
          );
        } catch (e) {
          LoggerService.error('FCM 초기화 실패 (무시하고 계속 진행)', e, null);
        }
      });

      if (mounted) {
        // 메인 화면으로 직접 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
        );
      }
    } catch (e) {
      LoggerService.error('동의 처리 중 오류 발생', e, null);
      if (mounted) {
        String errorMessage = '처리 중 오류가 발생했습니다.';
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
