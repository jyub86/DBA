import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/custom_user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_data_provider.dart';
import 'package:dba/services/logger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class YearbookScreen extends StatefulWidget {
  const YearbookScreen({super.key});

  @override
  State<YearbookScreen> createState() => _YearbookScreenState();
}

class _YearbookScreenState extends State<YearbookScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _userDataProvider = UserDataProvider.instance;
  List<UserData> _users = [];
  List<UserData> _filteredUsers = [];
  bool _isLoading = true;
  bool _showOnlyNonMembers = false;
  String _sortBy = 'name'; // 정렬 기준
  bool _isAscending = true; // 오름차순/내림차순

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호가 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cleanNumber = phoneNumber.replaceAll('-', '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전화를 걸 수 없습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendSMS(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호가 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cleanNumber = phoneNumber.replaceAll('-', '');
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: cleanNumber,
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('문자를 보낼 수 없습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      // 사용자 정보 로드
      final users = await CustomUserService.instance.getCustomUsers();

      // 그룹 정보 로드
      final groupsResponse = await Supabase.instance.client
          .from('user_groups')
          .select('user_id, groups(id, name)')
          .order('user_id');

      // 사용자별 그룹 정보 매핑
      final userGroups = <String, List<String>>{};

      for (final data in groupsResponse as List) {
        final userId = data['user_id'] as String;
        final groupData = data['groups'] as Map<String, dynamic>?;

        if (groupData != null) {
          if (!userGroups.containsKey(userId)) {
            userGroups[userId] = [];
          }

          final groupName = groupData['name'] as String?;
          if (groupName != null) {
            userGroups[userId]!.add(groupName);
          }
        }
      }

      if (mounted) {
        setState(() {
          _users = users.map((user) {
            final userGroupList = userGroups[user.authId] ?? [];
            return user.copyWith(groups: List<String>.from(userGroupList));
          }).toList();

          // 초기 데이터를 이름순으로 정렬
          _users.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
          _filteredUsers = _users;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('교인 연락처 데이터 로딩 실패', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터를 불러오는데 실패했습니다: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      List<UserData> tempUsers = _users;

      if (_showOnlyNonMembers) {
        tempUsers = tempUsers.where((user) => !(user.member ?? true)).toList();
      }

      if (query.isNotEmpty) {
        tempUsers = tempUsers.where((user) {
          final nameLower = user.name?.toLowerCase() ?? '';
          final officeLower = user.office?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          // 그룹 이름 검색 추가
          final hasMatchingGroup = user.groups
              .any((group) => group.toLowerCase().contains(searchLower));

          return nameLower.contains(searchLower) ||
              officeLower.contains(searchLower) ||
              hasMatchingGroup;
        }).toList();
      }

      // 정렬 적용
      tempUsers.sort((a, b) {
        if (_sortBy == 'name') {
          final comparison = (a.name ?? '').compareTo(b.name ?? '');
          return _isAscending ? comparison : -comparison;
        } else if (_sortBy == 'office') {
          // 직분이 없는 경우 맨 뒤로 정렬
          if (a.office == null && b.office == null) return 0;
          if (a.office == null) return _isAscending ? 1 : -1;
          if (b.office == null) return _isAscending ? -1 : 1;

          final comparison = a.office!.compareTo(b.office!);
          // 직분이 같은 경우 이름으로 2차 정렬
          if (comparison == 0) {
            return (a.name ?? '').compareTo(b.name ?? '');
          }
          return _isAscending ? comparison : -comparison;
        }
        return 0;
      });

      _filteredUsers = tempUsers;
    });
  }

  Future<void> _showEditDialog(UserData user) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    final officeController = TextEditingController(text: user.office);
    final emailController = TextEditingController(text: user.email);
    DateTime? selectedBirthDate = user.birthDate;
    String? selectedGender = user.gender;
    bool isMember = user.member ?? false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Text('성도 정보 수정'),
              if (!user.isInfoPublic) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.secondary.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '비공개',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withAlpha(179),
                    ),
                  ),
                ),
              ],
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: '전화번호'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: officeController,
                  decoration: const InputDecoration(labelText: '직분'),
                ),
                const SizedBox(height: 16),
                const Text('성별'),
                DropdownButton<String>(
                  value: selectedGender,
                  isExpanded: true,
                  hint: const Text('성별 선택'),
                  items: const [
                    DropdownMenuItem(value: '남', child: Text('남성')),
                    DropdownMenuItem(value: '여', child: Text('여성')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('생년월일'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedBirthDate != null
                        ? '${selectedBirthDate!.year}년 ${selectedBirthDate!.month}월 ${selectedBirthDate!.day}일'
                        : '생년월일 선택',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedBirthDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('ko', 'KR'),
                    );
                    if (date != null) {
                      setState(() {
                        selectedBirthDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('교인 여부'),
                    const SizedBox(width: 8),
                    Switch(
                      value: isMember,
                      onChanged: (value) {
                        setState(() {
                          isMember = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'office': officeController.text.trim(),
                  'gender': selectedGender,
                  'birth_date': selectedBirthDate?.toIso8601String(),
                  'member': isMember,
                });
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final updatedUser = user.copyWith(
          name: result['name'],
          email: result['email'],
          phone: result['phone'],
          office: result['office'],
          gender: result['gender'],
          birthDate: result['birth_date'] != null
              ? DateTime.parse(result['birth_date'])
              : null,
          member: result['member'],
        );

        await CustomUserService.instance.updateUserInfo(
            updatedUser.toUpdateJson(),
            authId: updatedUser.authId);

        // 현재 필터 상태 저장
        final currentFilter = _showOnlyNonMembers;
        final currentQuery = _searchController.text;

        // 데이터 새로고침
        await _loadUsers();

        // 필터 상태 복원 및 재적용
        setState(() {
          _showOnlyNonMembers = currentFilter;
        });
        _filterUsers(currentQuery);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('성도 정보가 수정되었습니다.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('성도 정보 수정 중 오류가 발생했습니다: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showUserInfoDialog(UserData user, bool isManager) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: user.profilePicture != null
                  ? CachedNetworkImageProvider(user.profilePicture!)
                  : null,
              child:
                  user.profilePicture == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name ?? '이름 없음',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!user.isInfoPublic && isManager) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '비공개',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withAlpha(179),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.office != null)
                    Text(
                      user.office!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withAlpha(179),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.email != null && user.email!.isNotEmpty) ...[
                const Text(
                  '이메일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(user.email!),
                const SizedBox(height: 16),
              ],
              if (user.phone != null && user.phone!.isNotEmpty) ...[
                const Text(
                  '연락처',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(user.phone!),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.phone),
                      onPressed: () => _makePhoneCall(user.phone),
                      color: Theme.of(context).primaryColor,
                    ),
                    IconButton(
                      icon: const Icon(Icons.message),
                      onPressed: () => _sendSMS(user.phone),
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (isManager) ...[
                if (user.gender != null) ...[
                  const Text(
                    '성별',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(user.gender == '남' ? '남성' : '여성'),
                  const SizedBox(height: 16),
                ],
                if (user.birthDate != null) ...[
                  const Text(
                    '생년월일',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user.birthDate!.year}년 ${user.birthDate!.month}월 ${user.birthDate!.day}일',
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (isManager)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditDialog(user);
              },
              child: const Text('수정'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교인 연락처'),
        elevation: 0,
        actions: [
          // 정렬 기준 선택 드롭다운
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '정렬 기준 선택',
            onSelected: (String value) {
              setState(() {
                _sortBy = value;
                _filterUsers(_searchController.text);
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'name',
                child: Text('이름순'),
              ),
              const PopupMenuItem<String>(
                value: 'office',
                child: Text('직분순'),
              ),
            ],
          ),
          IconButton(
            icon:
                Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _isAscending = !_isAscending;
                _filterUsers(_searchController.text);
              });
            },
            tooltip: _isAscending ? '오름차순' : '내림차순',
          ),
          ListenableBuilder(
            listenable: _userDataProvider,
            builder: (context, _) {
              final currentUser = _userDataProvider.userData;
              final isManager = currentUser?.canManage ?? false;

              if (!isManager) return const SizedBox.shrink();

              return IconButton(
                icon: Icon(
                  _showOnlyNonMembers ? Icons.person_off : Icons.person,
                  color: _showOnlyNonMembers
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                onPressed: () {
                  setState(() {
                    _showOnlyNonMembers = !_showOnlyNonMembers;
                    _filterUsers(_searchController.text);
                  });
                },
                tooltip: _showOnlyNonMembers ? '전체 보기' : '비멤버만 보기',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이름, 직분 또는 그룹으로 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _filterUsers,
            ),
          ),
          if (_showOnlyNonMembers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '비멤버만 표시 중',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다.'))
                    : ListenableBuilder(
                        listenable: _userDataProvider,
                        builder: (context, _) {
                          final currentUser = _userDataProvider.userData;
                          final isManager = currentUser?.canManage ?? false;

                          return ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              final isNonMember = !(user.member ?? true);
                              final isPrivate = !user.isInfoPublic;

                              return ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundImage:
                                          user.profilePicture != null
                                              ? CachedNetworkImageProvider(
                                                  user.profilePicture!)
                                              : null,
                                      child: user.profilePicture == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    if (isNonMember)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withAlpha(26),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.person_off,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      user.name ?? '이름 없음',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isNonMember) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error
                                              .withAlpha(26),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '비멤버',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withAlpha(179),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (isPrivate && isManager) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withAlpha(26),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '비공개',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withAlpha(179),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: user.office != null
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.office!,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withAlpha(179),
                                            ),
                                          ),
                                          if (user.groups.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: user.groups
                                                  .map((group) => Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Theme.of(
                                                                  context)
                                                              .primaryColor
                                                              .withAlpha(26),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          group,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Theme.of(
                                                                    context)
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                      ))
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (user.phone != null &&
                                        user.phone!.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.phone),
                                        onPressed: () =>
                                            _makePhoneCall(user.phone),
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.message),
                                        onPressed: () => _sendSMS(user.phone),
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () =>
                                    _showUserInfoDialog(user, isManager),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
