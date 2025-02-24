class TermsAgreement {
  final bool termsOfService;
  final bool privacyPolicy;
  final bool allAgreed;

  TermsAgreement({
    this.termsOfService = false,
    this.privacyPolicy = false,
    this.allAgreed = false,
  });

  TermsAgreement copyWith({
    bool? termsOfService,
    bool? privacyPolicy,
    bool? allAgreed,
  }) {
    return TermsAgreement(
      termsOfService: termsOfService ?? this.termsOfService,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      allAgreed: allAgreed ?? this.allAgreed,
    );
  }

  bool get isValid => termsOfService && privacyPolicy;
}
