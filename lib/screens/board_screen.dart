import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/category_model.dart';
import '../widgets/post_card.dart';
import '../services/category_service.dart';
import '../providers/user_data_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/supabase_constants.dart';
import '../services/logger_service.dart';
import '../screens/main_screen.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class BoardScreen extends StatefulWidget {
  final int? initialCategoryId;

  const BoardScreen({
    super.key,
    this.initialCategoryId,
  });

  @override
  State<BoardScreen> createState() => BoardScreenState();
}

class BoardScreenState extends State<BoardScreen> {
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _userDataProvider = UserDataProvider.instance;
  String? _searchQuery;
  List<CategoryModel> _categories = [];
  late int _selectedCategoryId;
  bool _showScrollToTop = false;
  bool _isDisposed = false;

  void updateCategory(int categoryId) {
    if (categoryId != _selectedCategoryId) {
      if (mounted) {
        setState(() {
          _selectedCategoryId = categoryId;
          _posts.clear();
          _hasMore = true;
          _searchQuery = null;
          _searchController.clear();
        });
      }
      _loadPosts();
    }
  }

  void _performSearch() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _posts.clear();
        _hasMore = true;
      });
    }
    _loadPosts();
  }

  void _clearSearch() {
    if (mounted) {
      setState(() {
        _searchQuery = null;
        _searchController.clear();
        _posts.clear();
        _hasMore = true;
      });
    }
    _loadPosts();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId ?? 0;
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _loadPosts();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.instance.getCategories();
      if (mounted) {
        setState(() {
          _categories = [
            CategoryModel(
              id: 0,
              name: '전체',
              order: -1,
              active: true,
              allowedLevel: 999,
            ),
            ...categories,
          ];
        });
      }
    } catch (e) {
      LoggerService.error('카테고리 로드 중 에러 발생', e, null);
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading || !_hasMore || _isDisposed) return;

    final userData = _userDataProvider.userData;
    if (userData == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      var query = Supabase.instance.client.from('posts').select('''
            *,
            categories(name),
            custom_users (
              auth_id,
              name,
              office,
              profile_picture
            )
          ''');

      if (_selectedCategoryId != 0) {
        query = query.eq('category_id', _selectedCategoryId.toString());
      }

      if (_searchQuery?.isNotEmpty == true) {
        final userIds = await Supabase.instance.client
            .from('custom_users')
            .select('auth_id')
            .ilike('name', '%$_searchQuery%');

        final List<String> matchedUserIds =
            userIds.map((user) => user['auth_id'].toString()).toList();

        query = query.or(
            'title.ilike.%$_searchQuery%,content.ilike.%$_searchQuery%${matchedUserIds.isNotEmpty ? ',user_id.in.(${matchedUserIds.join(',')})' : ''}');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(_posts.length, _posts.length + _pageSize - 1);

      if (_isDisposed) return;

      final newPosts = response.map((post) => Post.fromJson(post)).toList();

      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _hasMore = newPosts.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('게시물 로드 중 에러 발생', e, null);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.offset >= 1000 && !_showScrollToTop) {
      if (mounted) {
        setState(() => _showScrollToTop = true);
      }
    } else if (_scrollController.offset < 1000 && _showScrollToTop) {
      if (mounted) {
        setState(() => _showScrollToTop = false);
      }
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 테마 제공자를 통해 현재 테마 상태 가져오기
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return ListenableBuilder(
      listenable: _userDataProvider,
      builder: (context, _) {
        final userData = _userDataProvider.userData;
        if (userData == null) {
          return const SizedBox.shrink();
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, dynamic result) {
            if (!didPop) {
              final mainScreen =
                  context.findAncestorWidgetOfExactType<MainScreen>();
              if (mainScreen != null) {
                final mainScreenState =
                    context.findAncestorStateOfType<MainScreenState>();
                mainScreenState?.updateIndex(0, null);
              } else {
                Navigator.pushReplacementNamed(
                  context,
                  '/main',
                  arguments: {'initialIndex': 0},
                );
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(
                  isDarkMode
                      ? SupabaseConstants.backgroundImageDark
                      : SupabaseConstants.backgroundImage,
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    setState(() {
                      _showScrollToTop = _scrollController.offset > 300;
                    });
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _posts.clear();
                      _hasMore = true;
                    });
                    await _loadPosts();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black12
                          : Colors.black.withAlpha(20),
                    ),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: false,
                          floating: true,
                          snap: true,
                          toolbarHeight: 52,
                          backgroundColor: isDarkMode
                              ? Colors.grey.shade900.withAlpha(200)
                              : Colors.white.withAlpha(179),
                          title: Row(
                            children: [
                              Container(
                                height: 36,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey.shade800.withAlpha(230)
                                      : Colors.white.withAlpha(230),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedCategoryId,
                                    items: _categories.map((category) {
                                      return DropdownMenuItem<int>(
                                        value: category.id,
                                        child: Text(
                                          category.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      updateCategory(value!);
                                    },
                                    dropdownColor: isDarkMode
                                        ? Colors.grey.shade800.withAlpha(230)
                                        : Colors.white.withAlpha(230),
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      size: 18,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    isDense: true,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade800.withAlpha(230)
                                        : Colors.white.withAlpha(179),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: isDarkMode
                                            ? Colors.grey.shade700
                                            : Colors.white.withAlpha(77)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(20),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: '검색어를 입력하세요',
                                      hintStyle: TextStyle(
                                        fontSize: 11,
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.black54,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        size: 18,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      suffixIcon: _searchController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                size: 16,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                              onPressed: _clearSearch,
                                              padding: const EdgeInsets.all(4),
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: isDarkMode
                                              ? Colors.grey.shade700
                                              : Colors.white.withAlpha(77),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: isDarkMode
                                              ? Colors.grey.shade700
                                              : Colors.white.withAlpha(77),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: isDarkMode
                                              ? Colors.grey.shade600
                                              : Colors.white.withAlpha(130),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 0,
                                        horizontal: 8,
                                      ),
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => _performSearch(),
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                height: 36,
                                width: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _searchController.text.isEmpty
                                        ? isDarkMode
                                            ? Colors.grey.shade700.withAlpha(60)
                                            : Colors.grey.withAlpha(60)
                                        : isDarkMode
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withAlpha(200)
                                            : Theme.of(context)
                                                .primaryColor
                                                .withAlpha(230),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(20),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: _searchController.text.isEmpty
                                        ? null
                                        : _performSearch,
                                    icon: const Icon(
                                      Icons.search,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_searchQuery?.isNotEmpty == true)
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SearchResultHeaderDelegate(
                              searchQuery: _searchQuery!,
                              onClear: _clearSearch,
                            ),
                          ),
                        _buildPostList(),
                      ],
                    ),
                  ),
                ),
              ),
              floatingActionButton: AnimatedOpacity(
                opacity: _showScrollToTop ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _showScrollToTop ? _scrollToTop : null,
                  child: const Icon(Icons.arrow_upward),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostList() {
    if (_posts.isEmpty && !_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _searchQuery?.isNotEmpty == true ? '검색 결과가 없습니다.' : '게시물이 없습니다',
              ),
              if (_searchQuery?.isNotEmpty == true)
                TextButton(
                  onPressed: _clearSearch,
                  child: const Text('검색 초기화'),
                ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _posts.length) {
            if (_hasMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return null;
          }

          return PostCard(
            key: ValueKey('post_${_posts[index].id}'),
            post: _posts[index],
            heroTagPrefix: 'board',
            onPostDeleted: () {
              if (mounted) {
                setState(() {
                  _posts.removeWhere((p) => p.id == _posts[index].id);
                });
              }
            },
            onPostUpdated: (updatedPost) {
              if (mounted) {
                setState(() {
                  _posts[index] = updatedPost;
                });
              }
            },
          );
        },
        childCount: _posts.length + (_hasMore ? 1 : 0),
      ),
    );
  }
}

class _SearchResultHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String searchQuery;
  final VoidCallback onClear;

  _SearchResultHeaderDelegate({
    required this.searchQuery,
    required this.onClear,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Text(
            '"$searchQuery" 검색 결과',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
            child: const Text('검색 초기화'),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
