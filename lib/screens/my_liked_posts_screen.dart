import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../services/logger_service.dart';
import '../providers/user_data_provider.dart';
import '../widgets/post_card.dart';

class MyLikedPostsScreen extends StatefulWidget {
  const MyLikedPostsScreen({super.key});

  @override
  State<MyLikedPostsScreen> createState() => _MyLikedPostsScreenState();
}

class _MyLikedPostsScreenState extends State<MyLikedPostsScreen> {
  final _userDataProvider = UserDataProvider.instance;
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    try {
      // 게스트 모드 확인
      if (_userDataProvider.isGuestMode) {
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoading = false;
          });
        }
        return;
      }

      final userData = await _userDataProvider.getCurrentUser();

      // 사용자가 좋아요한 게시글 ID 목록을 가져옵니다
      final likedPostsResponse = await Supabase.instance.client
          .from('likes')
          .select('post_id')
          .eq('user_id', userData.authId);

      final likedPostIds = List<int>.from(
        likedPostsResponse.map((item) => item['post_id']),
      );

      if (likedPostIds.isEmpty) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
        return;
      }

      // 좋아요한 게시글의 상세 정보를 가져옵니다
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
          .inFilter('id', likedPostIds)
          .order('created_at', ascending: false);

      setState(() {
        _posts = List<Post>.from(
          postsResponse.map((post) => Post.fromJson(post)),
        );
        _isLoading = false;
      });
    } catch (e) {
      LoggerService.error('좋아요한 게시글 로드 중 에러 발생', e, null);
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
        title: const Text('내가 좋아요한 게시글'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userDataProvider.isGuestMode
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 60,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '로그인 후 이용 가능한 기능입니다',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('로그인하시면 게시글 좋아요 기능을\n이용하실 수 있습니다.'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          _userDataProvider.clear();
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        },
                        child: const Text('로그인하기'),
                      ),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? const Center(
                      child: Text('좋아요한 게시글이 없습니다.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLikedPosts,
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
