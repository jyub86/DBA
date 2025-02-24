import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../services/logger_service.dart';
import '../providers/user_data_provider.dart';
import '../widgets/post_card.dart';

class MyCommentedPostsScreen extends StatefulWidget {
  const MyCommentedPostsScreen({super.key});

  @override
  State<MyCommentedPostsScreen> createState() => _MyCommentedPostsScreenState();
}

class _MyCommentedPostsScreenState extends State<MyCommentedPostsScreen> {
  final _userDataProvider = UserDataProvider.instance;
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommentedPosts();
  }

  Future<void> _loadCommentedPosts() async {
    try {
      final userData = await _userDataProvider.getCurrentUser();

      // 사용자가 댓글을 작성한 게시글 ID 목록을 가져옵니다
      final commentedPostsResponse = await Supabase.instance.client
          .from('comments')
          .select('post_id')
          .eq('user_id', userData.authId)
          .order('created_at', ascending: false);

      final commentedPostIds = List<int>.from(
        commentedPostsResponse.map((item) => item['post_id']),
      );

      if (commentedPostIds.isEmpty) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
        return;
      }

      // 댓글을 작성한 게시글의 상세 정보를 가져옵니다
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select('''
            *,
            custom_users (
              auth_id,
              name,
              office,
              profile_picture
            ),
            categories (
              name
            )
          ''')
          .inFilter('id', commentedPostIds)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = List<Post>.from(
            postsResponse.map((post) => Post.fromJson(post)),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('댓글 작성한 게시글 로드 중 에러 발생', e, null);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글을 불러오는 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 댓글 단 게시글'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(
                  child: Text('댓글을 작성한 게시글이 없습니다.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadCommentedPosts,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return PostCard(
                        post: post,
                        onPostUpdated: (updatedPost) {
                          setState(() {
                            _posts[index] = updatedPost;
                          });
                        },
                        onPostDeleted: () {
                          setState(() {
                            _posts.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
