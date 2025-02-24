import 'package:flutter/material.dart';
import '../models/terms_agreement.dart';
import '../constants/terms_constants.dart';

class TermsAgreementWidget extends StatelessWidget {
  final TermsAgreement agreement;
  final Function(TermsAgreement) onAgreementChanged;

  const TermsAgreementWidget({
    super.key,
    required this.agreement,
    required this.onAgreementChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAllAgreeCheckbox(context),
            const Divider(height: 24),
            _buildTermsCheckbox(context),
            _buildPrivacyCheckbox(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAllAgreeCheckbox(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agreement.allAgreed,
          onChanged: (value) {
            if (value != null) {
              onAgreementChanged(TermsAgreement(
                termsOfService: value,
                privacyPolicy: value,
                allAgreed: value,
              ));
            }
          },
        ),
        Expanded(
          child: Text(
            '모든 약관에 동의합니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agreement.termsOfService,
          onChanged: (value) {
            if (value != null) {
              onAgreementChanged(agreement.copyWith(
                termsOfService: value,
                allAgreed: value && agreement.privacyPolicy,
              ));
            }
          },
        ),
        Expanded(
          child: Row(
            children: [
              Text(
                '[필수] 이용약관 동의',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('이용약관'),
                      content: const SingleChildScrollView(
                        child: Text(TermsConstants.termsOfService),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('보기'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyCheckbox(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agreement.privacyPolicy,
          onChanged: (value) {
            if (value != null) {
              onAgreementChanged(agreement.copyWith(
                privacyPolicy: value,
                allAgreed: value && agreement.termsOfService,
              ));
            }
          },
        ),
        Expanded(
          child: Row(
            children: [
              Text(
                '[필수] 개인정보 처리방침 동의',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('개인정보 처리방침'),
                      content: const SingleChildScrollView(
                        child: Text(TermsConstants.privacyPolicy),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('보기'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
