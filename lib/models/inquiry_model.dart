class Inquiry {
  final int id;
  final String title;
  final String content;
  final String userId;
  final String? answer;
  final String? answeredBy;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final bool isResolved;

  Inquiry({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
    this.answer,
    this.answeredBy,
    required this.createdAt,
    this.answeredAt,
    required this.isResolved,
  });

  factory Inquiry.fromMap(Map<String, dynamic> map) {
    return Inquiry(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      userId: map['user_id'],
      answer: map['answer'],
      answeredBy: map['answered_by'],
      createdAt: DateTime.parse(map['created_at']),
      answeredAt: map['answered_at'] != null
          ? DateTime.parse(map['answered_at'])
          : null,
      isResolved: map['is_resolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'user_id': userId,
      'answer': answer,
      'answered_by': answeredBy,
      'answered_at': answeredAt?.toIso8601String(),
      'is_resolved': isResolved,
    };
  }
}
