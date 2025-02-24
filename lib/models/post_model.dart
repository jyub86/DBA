import '../services/logger_service.dart';

class Author {
  final String id;
  final String name;
  final String? office;
  final String? profilePicture;

  Author({
    required this.id,
    required this.name,
    this.office,
    this.profilePicture,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    try {
      // auth_id 필수 필드 검증
      final authId = json['auth_id'];
      if (authId == null) {
        throw const FormatException('필수 필드가 누락되었습니다: auth_id');
      }

      // name이 없는 경우 기본값 사용
      final String userName = json['name']?.toString() ?? '익명';

      return Author(
        id: authId.toString(),
        name: userName,
        office: json['office']?.toString(),
        profilePicture: json['profile_picture']?.toString(),
      );
    } catch (e, stackTrace) {
      LoggerService.error('Author.fromJson 에러', e, stackTrace);
      LoggerService.error('원본 데이터', json, null);
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'auth_id': id,
      'name': name,
      if (office != null) 'office': office,
      if (profilePicture != null) 'profile_picture': profilePicture,
    };
  }
}

class Post {
  final int id;
  final String title;
  final String? content;
  final Author? author;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final int commentCount;
  String userName;
  String? profilePicture;
  final int categoryId;
  final List<String> mediaUrls;
  final bool active;
  final String? userId;
  final String categoryName;

  Post({
    required this.id,
    required this.title,
    this.content,
    this.author,
    this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.userName = '',
    this.profilePicture,
    required this.categoryId,
    this.mediaUrls = const [],
    this.active = true,
    this.userId,
    this.categoryName = '',
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      // 필수 필드 검증
      if (json['id'] == null) {
        throw const FormatException('필수 필드가 누락되었습니다: id');
      }
      if (json['title'] == null) {
        throw const FormatException('필수 필드가 누락되었습니다: title');
      }

      // ID 변환
      int postId;
      try {
        postId = json['id'] is String
            ? int.parse(json['id'] as String)
            : json['id'] as int;
      } catch (e) {
        throw FormatException('ID 형식이 잘못되었습니다: ${json['id']}');
      }

      // 카테고리 ID 변환
      int categoryId;
      try {
        categoryId = json['category_id'] is String
            ? int.parse(json['category_id'] as String)
            : json['category_id'] as int? ?? 0;
      } catch (e) {
        throw FormatException('카테고리 ID 형식이 잘못되었습니다: ${json['category_id']}');
      }

      // 좋아요 수 변환
      int likeCount;
      try {
        likeCount = json['like_count'] is String
            ? int.parse(json['like_count'] as String)
            : json['like_count'] as int? ?? 0;
      } catch (e) {
        likeCount = 0;
      }

      // 댓글 수 변환
      int commentCount;
      try {
        commentCount = json['comment_count'] is String
            ? int.parse(json['comment_count'] as String)
            : json['comment_count'] as int? ?? 0;
      } catch (e) {
        commentCount = 0;
      }

      // 미디어 URL 변환
      List<String> mediaUrls;
      try {
        mediaUrls = (json['media_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      } catch (e) {
        mediaUrls = [];
      }

      // 사용자 데이터 처리
      final userData = json['custom_users'] as Map<String, dynamic>?;
      Author? author;
      String userName = '';
      String? profilePicture;

      if (userData != null) {
        try {
          author = Author.fromJson(userData);
          userName = userData['name']?.toString() ?? '';
          profilePicture = userData['profile_picture']?.toString();
        } catch (e, stackTrace) {
          LoggerService.error('사용자 데이터 처리 중 에러 발생', e, stackTrace);
        }
      }

      return Post(
        id: postId,
        title: json['title'] as String,
        content: json['content']?.toString(),
        author: author,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        likeCount: likeCount,
        commentCount: commentCount,
        userName: userName,
        profilePicture: profilePicture,
        categoryId: categoryId,
        mediaUrls: mediaUrls,
        active: json['active'] is String
            ? json['active'].toString().toLowerCase() == 'true'
            : json['active'] as bool? ?? true,
        userId: json['user_id']?.toString(),
        categoryName: json['categories']?['name']?.toString() ?? '',
      );
    } catch (e, stackTrace) {
      LoggerService.error('Post.fromJson 에러', e, stackTrace);
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (content != null) 'content': content,
      'author': author?.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'like_count': likeCount,
      'comment_count': commentCount,
      'user_name': userName,
      if (profilePicture != null) 'profile_picture': profilePicture,
      'category_id': categoryId,
      'media_urls': mediaUrls,
      'active': active,
      if (userId != null) 'user_id': userId,
      'category_name': categoryName,
    };
  }

  Post copyWith({
    int? id,
    String? title,
    String? content,
    Author? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    int? commentCount,
    String? userName,
    String? profilePicture,
    int? categoryId,
    List<String>? mediaUrls,
    bool? active,
    String? userId,
    String? categoryName,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      userName: userName ?? this.userName,
      profilePicture: profilePicture ?? this.profilePicture,
      categoryId: categoryId ?? this.categoryId,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      active: active ?? this.active,
      userId: userId ?? this.userId,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}
