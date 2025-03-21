import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_formatter.dart';
import '../providers/user_data_provider.dart';

class CommentsSheet extends StatefulWidget {
  final int postId;
  final VoidCallback? onCommentUpdated;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.onCommentUpdated,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  final _userDataProvider = UserDataProvider.instance;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await _userDataProvider.getCurrentUser();
      final query = Supabase.instance.client.from('comments').select('''
            *,
            custom_users:user_id (
              auth_id,
              name,
              profile_picture
            )
          ''').eq('post_id', widget.postId);

      // 관리자가 아닌 경우 active가 true인 댓글만 표시
      final filteredQuery =
          !currentUser.canManage ? query.eq('active', true) : query;

      final response = await filteredQuery.order('created_at');

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글을 불러오는 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final currentUser = await _userDataProvider.getCurrentUser();
      await Supabase.instance.client.from('comments').insert({
        'post_id': widget.postId,
        'user_id': currentUser.authId,
        'content': _commentController.text.trim(),
      });

      _commentController.clear();
      _loadComments();
      widget.onCommentUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 작성 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime? dateTime) {
    return DateFormatter.formatTimeAgo(dateTime);
  }

  Future<bool> _isCurrentUser(dynamic userId) async {
    final currentUser = await _userDataProvider.getCurrentUser();
    return userId?.toString() == currentUser.authId;
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('comments')
          .delete()
          .eq('id', commentId);
      _loadComments();
      widget.onCommentUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 삭제 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final controller = TextEditingController(text: comment['content']);

    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '댓글을 입력하세요',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('수정'),
          ),
        ],
      ),
    );

    if (newContent == null || newContent.trim().isEmpty) return;

    try {
      await Supabase.instance.client
          .from('comments')
          .update({'content': newContent.trim()}).eq('id', comment['id']);
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 수정 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  Future<void> _toggleCommentVisibility(Map<String, dynamic> comment) async {
    final isActive = comment['active'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 상태 변경'),
        content: Text(isActive ? '이 댓글을 숨기시겠습니까?' : '이 댓글을 다시 표시하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isActive ? Colors.red : Colors.black,
            ),
            child: Text(isActive ? '숨기기' : '표시'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('comments')
            .update({'active': !isActive}).eq('id', comment['id']);

        // 로컬 상태 업데이트
        if (mounted) {
          setState(() {
            final index = _comments.indexWhere((c) => c['id'] == comment['id']);
            if (index != -1) {
              _comments[index] = {
                ..._comments[index],
                'active': !isActive,
              };
            }
          });
        }

        widget.onCommentUpdated?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isActive ? '댓글이 숨겨졌습니다.' : '댓글이 다시 표시됩니다.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('댓글 상태 변경 중 오류가 발생했습니다.'),
            ),
          );
        }
      }
    }
  }

  void _showCommentManageMenu(
    BuildContext context,
    Map<String, dynamic> comment,
    bool isCurrentUser,
  ) {
    final isHidden = comment['active'] != true;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentUser) ...[
              ListTile(
                leading: Icon(
                  isHidden ? Icons.visibility : Icons.visibility_off,
                  size: 24,
                  color: isHidden ? Colors.green : Colors.red,
                ),
                title: Text(
                  isHidden ? '댓글 표시하기' : '댓글 숨기기',
                  style: TextStyle(
                    color: isHidden ? Colors.green : Colors.red,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(context);
                  _toggleCommentVisibility(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, size: 24),
                title: const Text('댓글 수정하기'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(context);
                  _editComment(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, size: 24),
                title: const Text('댓글 삭제하기'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment['id']);
                },
              ),
            ] else if (_userDataProvider.userData?.canManage == true) ...[
              ListTile(
                leading: Icon(
                  isHidden ? Icons.visibility : Icons.visibility_off,
                  size: 24,
                  color: isHidden ? Colors.green : Colors.red,
                ),
                title: Text(
                  isHidden ? '댓글 표시하기' : '댓글 숨기기',
                  style: TextStyle(
                    color: isHidden ? Colors.green : Colors.red,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(context);
                  _toggleCommentVisibility(comment);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _userDataProvider,
      builder: (context, _) {
        final currentUser = _userDataProvider.userData;
        if (currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final user =
                            comment['custom_users'] as Map<String, dynamic>? ??
                                {};

                        // 숨겨진 댓글 스타일 적용
                        final isHidden = comment['active'] != true;
                        final commentStyle = isHidden
                            ? TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withAlpha(128),
                              )
                            : null;

                        return FutureBuilder<bool>(
                          future: _isCurrentUser(comment['user_id']),
                          builder: (context, snapshot) {
                            final isCurrentUser = snapshot.data ?? false;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: isHidden
                                  ? BoxDecoration(
                                      color: Colors.red.withAlpha(13),
                                      border: Border.all(
                                        color: Colors.red.withAlpha(26),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['profile_picture'] !=
                                          null
                                      ? NetworkImage(user['profile_picture'])
                                      : null,
                                  child: user['profile_picture'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(user['name'] ?? '알 수 없음'),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTimeAgo(DateTime.tryParse(
                                          comment['created_at'].toString())),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (isCurrentUser ||
                                        currentUser.canManage) ...[
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.more_horiz),
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          shape: const CircleBorder(),
                                        ),
                                        onPressed: () => _showCommentManageMenu(
                                          context,
                                          comment,
                                          isCurrentUser,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  comment['content'] ?? '',
                                  style: commentStyle,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 8.0,
                right: 8.0,
                bottom: 56.0 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _userDataProvider.isGuestMode
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '로그인 후 댓글을 작성할 수 있습니다',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              _userDataProvider.clear();
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('로그인'),
                          ),
                        ],
                      ),
                    )
                  : (currentUser.member ?? false) && currentUser.isInfoPublic
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: '댓글을 입력하세요...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _addComment,
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Text(
                            !(currentUser.member ?? false)
                                ? '교인 인증 후 댓글을 작성할 수 있습니다.'
                                : '정보 비공개 상태에서는 댓글을 작성할 수 없습니다.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}
