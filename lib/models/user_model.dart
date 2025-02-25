class UserData {
  final String id;
  final String authId;
  final String? email;
  final String? name;
  final String? phone;
  final String? profilePicture;
  final int roleId;
  final bool active;
  final Role role;
  final String? gender;
  final DateTime? birthDate;
  final String? office;
  final bool? member;
  final List<String> groups;
  final bool isInfoPublic;

  const UserData({
    required this.id,
    required this.authId,
    this.email,
    this.name,
    this.phone,
    this.profilePicture,
    required this.roleId,
    required this.active,
    required this.role,
    this.gender,
    this.birthDate,
    this.office,
    this.member,
    this.groups = const [],
    this.isInfoPublic = false,
  });

  factory UserData.empty(
      {required String id, required String authId, String? email}) {
    return UserData(
      id: id,
      authId: authId,
      email: email,
      roleId: 4,
      active: true,
      role: const Role(
        code: 'user',
        name: '사용자',
        level: 10,
      ),
      isInfoPublic: false,
    );
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    final roleData = (json['roles'] as Map<String, dynamic>?) ??
        {
          'code': 'user',
          'name': '사용자',
          'level': 10,
        };
    return UserData(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      profilePicture: json['profile_picture'] as String?,
      roleId: json['role'] as int? ?? 4,
      active: json['active'] as bool? ?? true,
      role: Role.fromJson(roleData),
      gender: json['gender'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      office: json['office'] as String?,
      member: json['member'] as bool?,
      groups: const [],
      isInfoPublic: json['is_info_public'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'email': email,
      'name': name,
      'phone': phone,
      'profile_picture': profilePicture,
      'role': roleId,
      'gender': gender,
      'birth_date': birthDate?.toIso8601String(),
      'office': office,
      'member': member,
      'is_info_public': isInfoPublic,
    };
  }

  /// 사용자 정보 업데이트를 위한 JSON 생성
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'phone': phone,
      'profile_picture': profilePicture,
      'gender': gender,
      'birth_date': birthDate?.toIso8601String(),
      'office': office,
      'member': member,
      'is_info_public': isInfoPublic,
    };
  }

  /// 업데이트 가능한 필드인지 확인
  static bool isUpdatableField(String field) {
    return [
      'name',
      'phone',
      'profile_picture',
      'gender',
      'birth_date',
      'office',
      'member',
      'is_info_public',
    ].contains(field);
  }

  bool get canManage => role.level >= 50;

  UserData copyWith({
    String? id,
    String? authId,
    String? email,
    String? name,
    String? phone,
    String? profilePicture,
    int? roleId,
    bool? active,
    Role? role,
    String? gender,
    DateTime? birthDate,
    String? office,
    bool? member,
    List<String>? groups,
    bool? isInfoPublic,
  }) {
    return UserData(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profilePicture: profilePicture ?? this.profilePicture,
      roleId: roleId ?? this.roleId,
      active: active ?? this.active,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      office: office ?? this.office,
      member: member ?? this.member,
      groups: groups ?? this.groups,
      isInfoPublic: isInfoPublic ?? this.isInfoPublic,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserData &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.phone == phone &&
        other.profilePicture == profilePicture &&
        other.roleId == roleId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        name.hashCode ^
        phone.hashCode ^
        profilePicture.hashCode ^
        roleId.hashCode;
  }
}

class Role {
  final String code;
  final String name;
  final int level;

  const Role({
    required this.code,
    required this.name,
    required this.level,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      code: json['code'] as String,
      name: json['name'] as String,
      level: json['level'] as int,
    );
  }
}
