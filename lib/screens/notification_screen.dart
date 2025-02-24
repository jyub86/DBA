import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/date_formatter.dart';
import '../providers/user_data_provider.dart';
import '../services/notification_service.dart';
import '../constants/supabase_constants.dart';
import '../services/logger_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final _userDataProvider = UserDataProvider.instance;
  String? _searchQuery;
  String _selectedMessageType = 'all';
  final List<Map<String, String>> _messageTypes = [
    {'id': 'all', 'name': '전체'},
    {'id': 'global', 'name': '공지사항'},
    {'id': 'personal', 'name': '개인 메시지'},
    {'id': 'group', 'name': '그룹 메시지'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      _loadMessages();
      // 알림 화면이 열릴 때 배지 카운트 초기화
      NotificationService().clearBadgeCount();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _messages.clear();
      _hasMore = true;
    });
    _loadMessages();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = null;
      _searchController.clear();
      _messages.clear();
      _hasMore = true;
    });
    _loadMessages();
  }

  void _updateMessageType(String type) {
    if (_selectedMessageType != type) {
      setState(() {
        _selectedMessageType = type;
        _messages.clear();
        _hasMore = true;
        _searchQuery = null;
        _searchController.clear();
      });
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (_isLoading || !_hasMore) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client.from('messages').select('''
        *,
        groups:group_id (
          id,
          name
        )
      ''');

      if (_selectedMessageType != 'all') {
        query = query.eq('message_type', _selectedMessageType);
      }

      if (_searchQuery?.isNotEmpty == true) {
        query = query.ilike('message', '%$_searchQuery%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(_messages.length, _messages.length + _pageSize - 1);

      if (response.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
        return;
      }

      // 발신자 정보 가져오기
      final List<Map<String, dynamic>> messagesWithSender = [];
      for (var message in response) {
        if (message['sender_id'] != null) {
          try {
            final senderResponse = await Supabase.instance.client
                .from('custom_users')
                .select('name')
                .eq('auth_id', message['sender_id'])
                .single();

            message['sender_name'] = senderResponse['name'];

            // 그룹 메시지인 경우 그룹 이름 설정
            if (message['message_type'] == 'group' &&
                message['groups'] != null) {
              message['group_name'] = message['groups']['name'];
            }
          } catch (e) {
            LoggerService.error('NotificationScreen - 발신자 정보 조회 실패', e, null);
            message['sender_name'] = '알 수 없음';
          }
        }
        messagesWithSender.add(Map<String, dynamic>.from(message));
      }

      if (mounted) {
        setState(() {
          _messages.addAll(messagesWithSender);
          _hasMore = response.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('NotificationScreen - 메시지 로드 중 에러 발생', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지를 불러오는 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  Future<void> _refreshMessages() async {
    if (_isLoading) return;

    setState(() {
      _messages.clear();
      _hasMore = true;
      _isLoading = true;
    });

    try {
      var query = Supabase.instance.client.from('messages').select('''
        *,
        groups:group_id (
          id,
          name
        )
      ''');

      if (_selectedMessageType != 'all') {
        query = query.eq('message_type', _selectedMessageType);
      }

      if (_searchQuery?.isNotEmpty == true) {
        query = query.ilike('message', '%$_searchQuery%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      final List<Map<String, dynamic>> messagesWithSender = [];
      for (var message in response) {
        if (message['sender_id'] != null) {
          try {
            final senderResponse = await Supabase.instance.client
                .from('custom_users')
                .select('name')
                .eq('auth_id', message['sender_id'])
                .single();

            message['sender_name'] = senderResponse['name'];

            // 그룹 메시지인 경우 그룹 이름 설정
            if (message['message_type'] == 'group' &&
                message['groups'] != null) {
              message['group_name'] = message['groups']['name'];
            }
          } catch (e) {
            LoggerService.error('NotificationScreen - 발신자 정보 조회 실패', e, null);
            message['sender_name'] = '알 수 없음';
          }
        }
        messagesWithSender.add(Map<String, dynamic>.from(message));
      }

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messagesWithSender);
          _hasMore = response.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('NotificationScreen - 새로고침 중 에러 발생', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로고침 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMessages();
    }
  }

  IconData _getMessageIcon(String type) {
    switch (type) {
      case 'global':
        return Icons.info;
      case 'personal':
        return Icons.message;
      case 'group':
        return Icons.group;
      default:
        return Icons.notifications;
    }
  }

  String _getMessageTitle(Map<String, dynamic> message) {
    final senderName = message['sender_name'] ?? '알 수 없음';
    switch (message['message_type']) {
      case 'global':
        return '공지사항';
      case 'personal':
        return '$senderName님의 메시지';
      case 'group':
        return '${message['group_name'] ?? '그룹'} 메시지';
      default:
        return '알림';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _userDataProvider,
      builder: (context, _) {
        final userData = _userDataProvider.userData;
        if (userData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: CachedNetworkImageProvider(
                SupabaseConstants.backgroundImage,
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  if (_scrollController.position.pixels >=
                      _scrollController.position.maxScrollExtent - 200) {
                    _loadMessages();
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () async {
                  await _refreshMessages();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      pinned: false,
                      floating: true,
                      snap: true,
                      toolbarHeight: 52,
                      backgroundColor: Colors.white.withAlpha(179),
                      title: Row(
                        children: [
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(179),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: Colors.white.withAlpha(77)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedMessageType,
                                items: _messageTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type['id']!,
                                    child: Text(
                                      type['name']!,
                                      style: const TextStyle(
                                          color: Colors.black87),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  _updateMessageType(value!);
                                },
                                dropdownColor: Colors.white.withAlpha(230),
                                style: const TextStyle(color: Colors.black87),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                                isDense: true,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(179),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: '검색어를 입력하세요',
                                  hintStyle: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                    color: Colors.black87,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 16,
                                            color: Colors.black87,
                                          ),
                                          onPressed: _clearSearch,
                                          padding: const EdgeInsets.all(4),
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(77),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(77),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(130),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 8,
                                  ),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _performSearch(),
                                onChanged: (value) {
                                  setState(() {});
                                },
                                style: const TextStyle(color: Colors.black87),
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
                                    ? Colors.grey.withAlpha(60)
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
                    _buildMessageList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty && !_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _searchQuery?.isNotEmpty == true ? '검색 결과가 없습니다.' : '알림이 없습니다.',
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
          if (index >= _messages.length) {
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

          final message = _messages[index];
          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            color: Colors.white.withAlpha(179),
            elevation: 4,
            child: ListTile(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[${_getMessageTitle(message)}]',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message['title'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.formatTimeAgo(
                      DateTime.parse(message['created_at'] as String),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message['message'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Icon(
                  _getMessageIcon(message['message_type'] as String),
                  color: Colors.white,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          );
        },
        childCount: _messages.length + (_hasMore ? 1 : 0),
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
