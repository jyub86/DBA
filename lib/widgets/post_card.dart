import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_formatter.dart';
import '../screens/board_screen.dart';
import '../providers/user_data_provider.dart';
import '../models/user_model.dart';
import 'package:dba/services/logger_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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
  String? _youtubeVideoId;
  YoutubePlayerController? _youtubeController;
  bool _isExpanded = false;
  List<String> _youtubeVideoIds = [];

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _getLikesCount();
    _getCommentsCount();
    _checkYoutubeVideos();
  }

  void _checkYoutubeVideos() {
    if (!mounted) return;

    _youtubeVideoIds = [];
    for (final url in widget.post.mediaUrls) {
      final videoId = _getYouTubeVideoId([url]);
      if (videoId != null) {
        _youtubeVideoIds.add(videoId);
      }
    }

    if (_youtubeVideoIds.isNotEmpty) {
      setState(() {
        _isYoutubeVideo = true;
        _youtubeVideoId = _youtubeVideoIds.first;
        _initYoutubeController(_youtubeVideoId!);
      });
    }
  }

  void _initYoutubeController(String videoId) {
    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: true,
        enableCaption: false,
        useHybridComposition: true,
      ),
    );
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
      // 게스트 모드면 항상 좋아요 안 한 상태로 설정
      if (_userDataProvider.isGuestMode) {
        if (mounted) {
          setState(() {
            _isLiked = false;
          });
        }
        return;
      }

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
      // 게스트 모드 체크
      if (_userDataProvider.isGuestMode) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('로그인 후 좋아요 기능을 이용할 수 있습니다.'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: '로그인',
                onPressed: () {
                  _userDataProvider.clear();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      final userData = _userDataProvider.userData;
      if (userData == null) return;

      // 멤버 여부와 정보 공개 여부 확인
      if (userData.member != true || userData.isInfoPublic != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('멤버 인증 및 정보 공개 설정이 필요한 기능입니다.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

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
    // 게스트 모드 체크
    if (_userDataProvider.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로그인 후 댓글 기능을 이용할 수 있습니다.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '로그인',
            onPressed: () {
              _userDataProvider.clear();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/comments',
      arguments: {
        'postId': widget.post.id,
        'onCommentUpdated': () {
          if (mounted) {
            _getCommentsCount();
          }
        },
      },
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
                        _buildYouTubeVideos(context)
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

  Widget _buildYouTubeVideos(BuildContext context) {
    if (_youtubeVideoIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleVideoIds =
        _isExpanded ? _youtubeVideoIds : [_youtubeVideoIds.first];
    final hasMoreVideos = _youtubeVideoIds.length > 1;

    return Column(
      children: [
        Column(
          children: visibleVideoIds.map((videoId) {
            // 현재 비디오가 첫 번째가 아니면 컨트롤러 생성
            if (videoId != _youtubeVideoId) {
              final controller = YoutubePlayerController(
                initialVideoId: videoId,
                flags: const YoutubePlayerFlags(
                  autoPlay: false,
                  mute: false,
                  disableDragSeek: false,
                  loop: false,
                  isLive: false,
                  forceHD: true,
                  enableCaption: false,
                  useHybridComposition: true,
                ),
              );

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: YoutubePlayer(
                    controller: controller,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.red,
                    progressColors: const ProgressBarColors(
                      playedColor: Colors.red,
                      handleColor: Colors.redAccent,
                    ),
                    onReady: () {},
                    onEnded: (metaData) {},
                    bottomActions: [
                      const SizedBox(width: 8.0),
                      const CurrentPosition(),
                      const SizedBox(width: 8.0),
                      const ProgressBar(
                        isExpanded: true,
                        colors: ProgressBarColors(
                          playedColor: Colors.red,
                          handleColor: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      const RemainingDuration(),
                      const SizedBox(width: 8.0),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.white),
                        onPressed: () {
                          final position = controller.value.position;
                          final seconds = position.inSeconds;
                          controller.pause();

                          if (context.mounted) {
                            Navigator.pushNamed(
                              context,
                              '/youtube-player',
                              arguments: {
                                'videoId': videoId,
                                'startSeconds': seconds,
                              },
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            // 첫 번째 비디오는 기존에 초기화된 컨트롤러 사용
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    YoutubePlayer(
                      controller: _youtubeController!,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: Colors.red,
                      progressColors: const ProgressBarColors(
                        playedColor: Colors.red,
                        handleColor: Colors.redAccent,
                      ),
                      onReady: () {},
                      onEnded: (metaData) {},
                      bottomActions: [
                        const SizedBox(width: 8.0),
                        const CurrentPosition(),
                        const SizedBox(width: 8.0),
                        const ProgressBar(
                          isExpanded: true,
                          colors: ProgressBarColors(
                            playedColor: Colors.red,
                            handleColor: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        const RemainingDuration(),
                        const SizedBox(width: 8.0),
                        IconButton(
                          icon:
                              const Icon(Icons.fullscreen, color: Colors.white),
                          onPressed: () async {
                            final position = _youtubeController!.value.position;
                            final seconds = position.inSeconds;
                            _youtubeController!.pause();

                            if (_youtubeVideoId != null && context.mounted) {
                              Navigator.pushNamed(
                                context,
                                '/youtube-player',
                                arguments: {
                                  'videoId': _youtubeVideoId,
                                  'startSeconds': seconds,
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (hasMoreVideos && !_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = true;
                  });
                },
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                label: Text(
                  '펼쳐 보기 (${_youtubeVideoIds.length - 1})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    final List<String> mediaUrls = widget.post.mediaUrls;
    if (mediaUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleUrls = _isExpanded ? mediaUrls : [mediaUrls.first];
    final hasMoreImages = mediaUrls.length > 1;

    return Column(
      children: [
        Column(
          children: visibleUrls.map((url) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () {
                    // 이미지를 클릭하면 전체 화면으로 볼 수 있는 갤러리를 표시
                    final int initialIndex = mediaUrls.indexOf(url);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _ImageGalleryView(
                          imageUrls: mediaUrls,
                          initialIndex: initialIndex,
                        ),
                      ),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (hasMoreImages && !_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = true;
                  });
                },
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                label: Text(
                  '펼쳐 보기 (${mediaUrls.length - 1})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    // 내용이 없으면 빈 위젯 반환
    if (widget.post.content == null || widget.post.content!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 텍스트 스타일 정의
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final Color textColor = textStyle?.color ?? Colors.black;

    // 최대 라인 수 정의
    const int maxLines = 10;

    // TextPainter를 사용하여 실제 텍스트의 줄 수를 계산
    final textSpan = TextSpan(
      text: widget.post.content!,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: maxLines + 1,
    );

    // 화면 너비에 맞게 layout 계산
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 32.0; // 좌우 패딩 (16 + 16)
    textPainter.layout(maxWidth: screenWidth - padding);

    // 실제 텍스트가 maxLines보다 적거나 같은지 확인
    final bool isTextShort = textPainter.didExceedMaxLines == false;

    // 짧은 텍스트는 확장이 필요 없으므로 단순 텍스트로 표시
    if (isTextShort) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.post.content!,
          style: textStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: !_isExpanded
                ? ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          textColor,
                          textColor,
                          textColor.withOpacity(0.3),
                        ],
                        stops: const [0.0, 0.8, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Text(
                      widget.post.content!,
                      style: textStyle,
                      maxLines: maxLines,
                    ),
                  )
                : Text(
                    widget.post.content!,
                    style: textStyle,
                  ),
          ),
          if (!_isExpanded)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = true;
                  });
                },
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                label: const Text('더 보기',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          if (_isExpanded)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                label: const Text('접기',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
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
    _youtubeController?.dispose();
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
                  Navigator.pushNamed(
                    parentContext,
                    '/create-post',
                    arguments: {'editPost': widget.post},
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

// 전체 화면 이미지 갤러리 위젯
class _ImageGalleryView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _ImageGalleryView({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryView> createState() => _ImageGalleryViewState();
}

class _ImageGalleryViewState extends State<_ImageGalleryView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.imageUrls[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            heroAttributes:
                PhotoViewHeroAttributes(tag: widget.imageUrls[index]),
          );
        },
        itemCount: widget.imageUrls.length,
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        pageController: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
