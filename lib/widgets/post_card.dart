import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../screens/create_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/comments_sheet.dart';
import '../utils/date_formatter.dart';
import '../screens/board_screen.dart';
import '../providers/user_data_provider.dart';
import '../models/user_model.dart';
import '../screens/youtube_player_screen.dart';
import 'package:dba/services/logger_service.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String? heroTagPrefix;
  final VoidCallback? onPostDeleted;
  final Function(Post)? onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    this.heroTagPrefix,
    this.onPostDeleted,
    this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String get _heroTag => '${widget.heroTagPrefix ?? "post"}_${widget.post.id}';
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  final _userDataProvider = UserDataProvider.instance;
  bool _isYoutubeVideo = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _getLikesCount();
    _getCommentsCount();
    _checkYoutubeVideo();
  }

  void _checkYoutubeVideo() {
    if (!mounted) return;

    final videoId = _getYouTubeVideoId(widget.post.mediaUrls);
    if (videoId != null) {
      setState(() {
        _isYoutubeVideo = true;
      });
    }
  }

  String? _getYouTubeVideoId(List<String> urls) {
    if (urls.isEmpty) return null;

    for (final url in urls) {
      final uri = Uri.tryParse(url);
      if (uri == null) continue;

      if (uri.host.contains('youtube.com') &&
          uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      } else if (uri.host == 'youtu.be') {
        return uri.pathSegments.first;
      }
    }
    return null;
  }

  String _formatTimeAgo(DateTime? dateTime) {
    return DateFormatter.formatTimeAgo(dateTime);
  }

  Future<void> _checkIfLiked() async {
    try {
      final userData = _userDataProvider.userData;
      if (userData == null) return;

      final response = await Supabase.instance.client
          .from('likes')
          .select()
          .eq('post_id', widget.post.id)
          .eq('user_id', userData.authId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isLiked = response != null;
        });
      }
    } catch (e) {
      LoggerService.error('좋아요 상태 확인 중 에러 발생', e, null);
      if (mounted) {
        setState(() {
          _isLiked = false;
        });
      }
    }
  }

  Future<void> _getLikesCount() async {
    try {
      final response = await Supabase.instance.client
          .from('likes')
          .select()
          .eq('post_id', widget.post.id);

      if (mounted) {
        setState(() {
          _likeCount = (response as List).length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likeCount = 0;
        });
      }
    }
  }

  Future<void> _getCommentsCount() async {
    try {
      final response = await Supabase.instance.client
          .from('comments')
          .select()
          .eq('post_id', widget.post.id);

      if (mounted) {
        setState(() {
          _commentCount = (response as List).length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _commentCount = 0;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      final userData = _userDataProvider.userData;
      if (userData == null) return;

      if (_isLiked) {
        // 좋아요 삭제
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('post_id', widget.post.id)
            .eq('user_id', userData.authId);
      } else {
        // 좋아요 추가
        await Supabase.instance.client.from('likes').insert({
          'post_id': widget.post.id,
          'user_id': userData.authId,
        });
      }

      // UI 업데이트
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('좋아요 처리 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _showComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('댓글'),
          ),
          body: CommentsSheet(
            postId: widget.post.id,
            onCommentUpdated: () {
              if (mounted) {
                _getCommentsCount();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _togglePostVisibility() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 상태 변경'),
        content: Text(
            widget.post.active ? '이 게시글을 숨기시겠습니까?' : '이 게시글을 다시 표시하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: widget.post.active ? Colors.red : Colors.black,
            ),
            child: Text(widget.post.active ? '숨기기' : '표시'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('posts')
            .update({'active': !widget.post.active}).eq('id', widget.post.id);

        if (context.mounted) {
          // 부모 위젯에 상태 업데이트 알림
          final updatedPost = widget.post.copyWith(
            active: !widget.post.active,
          );
          widget.onPostUpdated?.call(updatedPost);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(widget.post.active ? '게시글이 숨겨졌습니다.' : '게시글이 다시 표시됩니다.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시글 상태 변경 중 오류가 발생했습니다.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return ListenableBuilder(
          listenable: _userDataProvider,
          builder: (context, _) {
            final userData = _userDataProvider.userData;
            if (userData == null) {
              return const SizedBox.shrink();
            }

            if (!widget.post.active && !userData.canManage) {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              elevation: 4,
              color: !widget.post.active
                  ? Theme.of(context).cardTheme.color?.withAlpha(179)
                  : Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: !widget.post.active
                    ? BorderSide(
                        color: Colors.red.withAlpha(128),
                        width: 1,
                      )
                    : BorderSide.none,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, userData),
                      _buildTitle(context),
                      if (widget.post.content?.isNotEmpty == true)
                        _buildContent(context),
                      if (_isYoutubeVideo)
                        _buildYouTubeThumbnail(context)
                      else if (widget.post.mediaUrls.isNotEmpty)
                        _buildMediaPreview(context),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActions(context, userData),
                          ),
                          if (widget.post.userId?.toString() ==
                                  userData.authId ||
                              userData.canManage)
                            IconButton(
                              onPressed: () => _showManageMenu(context),
                              icon: const Icon(Icons.more_horiz),
                              iconSize: 24,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                shape: const CircleBorder(),
                              ),
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                  if (!widget.post.active)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(128),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withAlpha(26),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_off,
                              size: 16,
                              color: Colors.red.withAlpha(128),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '숨겨진 게시물',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.withAlpha(128),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UserData userData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 프로필 이미지
              Hero(
                tag: '${_heroTag}_profile',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  backgroundImage: widget.post.profilePicture != null
                      ? NetworkImage(widget.post.profilePicture!)
                      : null,
                  child: widget.post.profilePicture == null
                      ? Icon(Icons.person,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // 작성자 이름과 시간
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.post.userName,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTimeAgo(widget.post.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // 카테고리
              if (widget.post.categoryName.isNotEmpty)
                InkWell(
                  onTap: () {
                    final boardScreen =
                        context.findAncestorStateOfType<BoardScreenState>();
                    boardScreen?.updateCategory(widget.post.categoryId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.post.categoryName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        widget.post.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildYouTubeThumbnail(BuildContext context) {
    final videoId = _getYouTubeVideoId(widget.post.mediaUrls);
    if (videoId == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YoutubePlayerScreen(
              videoId: videoId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                      fit: BoxFit.cover,
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    return Column(
      children: widget.post.mediaUrls.map((url) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        widget.post.content!,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActions(BuildContext context, UserData userData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 좋아요 버튼
          InkWell(
            onTap: _toggleLike,
            child: Row(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_likeCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(153),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 댓글 버튼
          InkWell(
            onTap: _showComments,
            child: Row(
              children: [
                Icon(
                  Icons.comment_outlined,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_commentCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(153),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _deletePost(BuildContext context) async {
    if (!context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed == false) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    try {
      // 게시물에 포함된 이미지 중 Supabase Storage에 저장된 이미지 삭제
      final userData = _userDataProvider.userData;
      if (userData == null) return;

      final List<String> storagePathsToDelete = [];

      for (final url in widget.post.mediaUrls) {
        if (url.contains('supabase.co/storage/v1/object/public/posts/') &&
            url.contains('/${userData.authId}/')) {
          try {
            // URL에서 posts/ 이후의 전체 경로를 추출 (사용자 ID 폴더 포함)
            final startIndex = url.indexOf('posts/') + 'posts/'.length;
            final fullPath = url.substring(startIndex);
            final cleanPath =
                fullPath.startsWith('/') ? fullPath.substring(1) : fullPath;
            storagePathsToDelete.add(cleanPath);
          } catch (e) {
            LoggerService.error('이미지 URL 처리 중 에러 발생', e, null);
          }
        }
      }

      // 한 번의 요청으로 모든 이미지 삭제
      if (storagePathsToDelete.isNotEmpty) {
        try {
          final List<FileObject> deletedFiles = await Supabase
              .instance.client.storage
              .from('posts')
              .remove(storagePathsToDelete);

          if (deletedFiles.length != storagePathsToDelete.length) {
            LoggerService.warning(
                '일부 파일만 삭제됨: ${deletedFiles.length}/${storagePathsToDelete.length}');
          }
        } catch (storageError) {
          LoggerService.error('이미지 일괄 삭제 실패', storageError, null);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('이미지 삭제에 실패했습니다: $storageError'),
              ),
            );
          }
        }
      }

      // 게시물 삭제
      await Supabase.instance.client
          .from('posts')
          .delete()
          .eq('id', widget.post.id)
          .select();

      if (!context.mounted) {
        LoggerService.warning('삭제 완료 후 context가 mounted 상태가 아닙니다.');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물이 삭제되었습니다.')),
      );
      widget.onPostDeleted?.call();
    } catch (e, stackTrace) {
      LoggerService.error('게시물 삭제 중 에러 발생', e, stackTrace);

      if (!context.mounted) {
        LoggerService.warning('에러 발생 후 context가 mounted 상태가 아닙니다.');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('게시물 삭제 중 오류가 발생했습니다.\n$e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showManageMenu(BuildContext parentContext) {
    final bool isAuthor =
        widget.post.userId?.toString() == _userDataProvider.userData?.authId;

    showModalBottomSheet(
      context: parentContext,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit, size: 24),
                title: const Text('게시물 수정하기'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (context) => CreatePostScreen(
                        editPost: widget.post,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, size: 24),
                title: const Text('게시물 삭제하기'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  // 약간의 지연을 주어 context가 안정화되도록 함
                  Future.microtask(() {
                    if (parentContext.mounted) {
                      _deletePost(parentContext);
                    }
                  });
                },
              ),
              ListTile(
                leading: Icon(
                  widget.post.active ? Icons.visibility_off : Icons.visibility,
                  size: 24,
                  color: widget.post.active ? Colors.red : Colors.green,
                ),
                title: Text(
                  widget.post.active ? '게시물 숨기기' : '게시물 표시하기',
                  style: TextStyle(
                    color: widget.post.active ? Colors.red : Colors.green,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _togglePostVisibility();
                },
              ),
            ],
            if (_userDataProvider.userData?.canManage == true && !isAuthor)
              ListTile(
                leading: Icon(
                  widget.post.active ? Icons.visibility_off : Icons.visibility,
                  size: 24,
                  color: widget.post.active ? Colors.red : Colors.green,
                ),
                title: Text(
                  widget.post.active ? '게시물 숨기기' : '게시물 표시하기',
                  style: TextStyle(
                    color: widget.post.active ? Colors.red : Colors.green,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _togglePostVisibility();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
