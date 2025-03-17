import 'package:flutter/material.dart';
import '../widgets/comments_sheet.dart';

class CommentsScreen extends StatelessWidget {
  final int postId;
  final VoidCallback? onCommentUpdated;

  const CommentsScreen({
    super.key,
    required this.postId,
    this.onCommentUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('댓글'),
      ),
      body: CommentsSheet(
        postId: postId,
        onCommentUpdated: onCommentUpdated,
      ),
    );
  }
}
