class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final String senderId;
  final String senderName;
  final String? groupId;
  final DateTime createdAt;
  final bool isRead;
  final String userId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.senderId,
    required this.senderName,
    this.groupId,
    required this.createdAt,
    required this.isRead,
    required this.userId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      groupId: json['group_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'sender_id': senderId,
      'sender_name': senderName,
      if (groupId != null) 'group_id': groupId,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'user_id': userId,
    };
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    String? senderId,
    String? senderName,
    String? groupId,
    DateTime? createdAt,
    bool? isRead,
    String? userId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      userId: userId ?? this.userId,
    );
  }
}
