class UserToken {
  final String userId;
  final String fcmToken;
  final String? deviceType;
  final DateTime createdAt;

  UserToken({
    required this.userId,
    required this.fcmToken,
    this.deviceType,
    required this.createdAt,
  });

  factory UserToken.fromJson(Map<String, dynamic> json) {
    return UserToken(
      userId: json['user_id'] as String,
      fcmToken: json['fcm_token'] as String,
      deviceType: json['device_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'fcm_token': fcmToken,
      'device_type': deviceType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
