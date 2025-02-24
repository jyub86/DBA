import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';

class GroupMemberScreen extends StatefulWidget {
  final Group group;

  const GroupMemberScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupMemberScreen> createState() => _GroupMemberScreenState();
}

class _GroupMemberScreenState extends State<GroupMemberScreen> {
  List<UserData> _members = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final List<UserData> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      setState(() => _isLoading = true);
      final response =
          await Supabase.instance.client.from('user_groups').select('''
            *,
            custom_users:user_id(*)
          ''').eq('group_id', widget.group.id);

      _members = (response as List)
          .where((data) => data['custom_users'] != null)
          .map((data) {
            final userData = data['custom_users'];
            try {
              return UserData.fromJson(userData);
            } catch (e) {
              LoggerService.error('Error parsing UserData', e, null);
              return null;
            }
          })
          .whereType<UserData>()
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      LoggerService.error('멤버 로딩 중 에러 발생', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('멤버 목록을 불러오는데 실패했습니다.')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMembers(List<UserData> users) async {
    try {
      // 모든 사용자의 데이터를 한 번에 추가하기 위한 배열
      final userGroupData = users
          .map((user) => {
                'user_id': user.authId,
                'group_id': widget.group.id,
              })
          .toList();

      // 한 번의 쿼리로 모든 사용자를 추가
      await Supabase.instance.client.from('user_groups').insert(userGroupData);

      setState(() {
        _members.addAll(users);
        for (var user in users) {
          _searchResults.removeWhere((u) => u.authId == user.authId);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${users.length}명의 멤버가 그룹에 추가되었습니다.')),
        );
      }
    } catch (e) {
      LoggerService.error('멤버 일괄 추가 중 에러 발생', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('멤버 추가에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _removeMember(UserData user) async {
    try {
      await Supabase.instance.client
          .from('user_groups')
          .delete()
          .eq('user_id', user.authId)
          .eq('group_id', widget.group.id);

      setState(() {
        _members.removeWhere((m) => m.authId == user.authId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name}님이 그룹에서 제거되었습니다.')),
        );
      }
    } catch (e) {
      LoggerService.error('멤버 제거 중 에러 발생', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('멤버 제거에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _showAddMembersDialog() async {
    final TextEditingController searchController = TextEditingController();
    List<UserData> allUsers = [];
    List<UserData> filteredUsers = [];
    Set<String> selectedUserIds = {};
    bool isLoading = true;

    try {
      // 다이얼로그를 표시하기 전에 사용자 목록을 먼저 로드
      final response = await Supabase.instance.client
          .from('custom_users')
          .select()
          .order('name');

      allUsers = (response as List)
          .map((data) => UserData.fromJson(data))
          .where(
              (user) => !_members.any((member) => member.authId == user.authId))
          .toList();

      // 이름순으로 정렬 (null 처리 포함)
      allUsers.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      filteredUsers = allUsers;
      isLoading = false;
    } catch (e) {
      LoggerService.error('사용자 목록 로딩 중 에러 발생', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 목록을 불러오는데 실패했습니다.')),
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Text('멤버 추가'),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: '사용자 검색',
                    hintText: '이름 또는 직책으로 검색',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (query) {
                    setState(() {
                      if (query.isEmpty) {
                        filteredUsers = allUsers;
                      } else {
                        filteredUsers = allUsers.where((user) {
                          final nameLower = user.name?.toLowerCase() ?? '';
                          final officeLower = user.office?.toLowerCase() ?? '';
                          final searchLower = query.toLowerCase();
                          return nameLower.contains(searchLower) ||
                              officeLower.contains(searchLower);
                        }).toList();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isSelected =
                                selectedUserIds.contains(user.authId);
                            return CheckboxListTile(
                              secondary: CircleAvatar(
                                backgroundImage: user.profilePicture != null
                                    ? NetworkImage(user.profilePicture!)
                                    : null,
                                child: user.profilePicture == null
                                    ? Text(user.name?[0] ?? '?')
                                    : null,
                              ),
                              title: Text(user.name ?? '이름 없음'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user.office != null)
                                    Text(
                                      user.office!,
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  Text(user.email ?? '이메일 없음'),
                                ],
                              ),
                              isThreeLine: user.office != null,
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedUserIds.add(user.authId);
                                  } else {
                                    selectedUserIds.remove(user.authId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: selectedUserIds.isEmpty
                  ? null
                  : () {
                      final selectedUsers = filteredUsers
                          .where(
                              (user) => selectedUserIds.contains(user.authId))
                          .toList();
                      Navigator.pop(context, selectedUsers);
                    },
              child: Text('${selectedUserIds.length}명 추가'),
            ),
          ],
        ),
      ),
    ).then((selectedUsers) async {
      if (selectedUsers != null) {
        final users = selectedUsers as List<UserData>;
        await _addMembers(users);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group.name} 멤버 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddMembersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: member.profilePicture != null
                          ? NetworkImage(member.profilePicture!)
                          : null,
                      child: member.profilePicture == null
                          ? Text(member.name?[0] ?? '?')
                          : null,
                    ),
                    title: Text(member.name ?? '이름 없음'),
                    subtitle: Text(member.email ?? '이메일 없음'),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.person_remove,
                      ),
                      tooltip: '멤버 제거',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('멤버 제거'),
                          content: Text('${member.name}님을 그룹에서 제거하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _removeMember(member);
                              },
                              child: const Text(
                                '제거',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
