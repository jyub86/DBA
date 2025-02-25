import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../constants/terms_constants.dart';
import '../widgets/terms_webview.dart';
import 'banner_settings_screen.dart';
import '../services/auth_service.dart';
import '../providers/user_data_provider.dart';
import 'inquiry_screen.dart';
import 'package:dba/services/logger_service.dart';
import 'group_management_screen.dart';
import 'my_liked_posts_screen.dart';
import 'my_commented_posts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  String? _profileUrl;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _userDataProvider = UserDataProvider.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await _userDataProvider.getCurrentUser();
    if (mounted) {
      setState(() {
        _profileUrl = userData.profilePicture;
        _nameController.text = userData.name ?? '';
        _phoneController.text = userData.phone ?? '';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (image == null) return;

    // 이미지 파일 확장자 검증
    final extension = path.extension(image.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png'].contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JPG 또는 PNG 이미지만 업로드 가능합니다.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _userDataProvider.getCurrentUser();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '/${userData.authId}/profile_$timestamp$extension';

      // 기존 이미지가 있다면 삭제
      if (_profileUrl != null) {
        try {
          final oldPath = Uri.parse(_profileUrl!).pathSegments.last;
          await Supabase.instance.client.storage
              .from('profiles')
              .remove(['${userData.authId}/$oldPath']);
        } catch (e) {
          LoggerService.error('기존 이미지 삭제 실패', e, null);
        }
      }

      // Storage에 이미지 업로드
      await Supabase.instance.client.storage.from('profiles').upload(
            imagePath,
            File(image.path),
            fileOptions: const FileOptions(cacheControl: '0', upsert: true),
          );

      // 이미지 URL 생성
      final String imageUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(imagePath);

      // 사용자 정보 업데이트
      await _userDataProvider.updateUserInfo({'profile_picture': imageUrl});

      if (mounted) {
        setState(() {
          _profileUrl = imageUrl;
          _isLoading = false;
        });

        CachedNetworkImage.evictFromCache(_profileUrl!);
      }
    } catch (e) {
      LoggerService.error('이미지 업로드 중 에러 발생', e, null);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 업로드에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

        return Drawer(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('더보기'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // 프로필 이미지 섹션
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                backgroundImage: _profileUrl != null
                                    ? NetworkImage(_profileUrl!)
                                    : null,
                                child: _profileUrl == null
                                    ? Icon(Icons.person,
                                        size: 50,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)
                                    : null,
                              ),
                              if (_isLoading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black26,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap:
                                      _isLoading ? null : _pickAndUploadImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userData.name ?? '이름 없음',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userData.email ?? '이메일 없음',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('내 정보 변경'),
                      onTap: () => _showProfileEditDialog(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.favorite),
                      title: const Text('좋아요'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyLikedPostsScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.comment),
                      title: const Text('댓글'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyCommentedPostsScreen(),
                        ),
                      ),
                    ),
                    if (userData.canManage) const Divider(),
                    if (userData.canManage)
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('배너 설정'),
                        subtitle: const Text('관리자 모드'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BannerSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    if (userData.canManage)
                      ListTile(
                        leading: const Icon(Icons.campaign),
                        title: const Text('메시지 추가'),
                        subtitle: const Text('관리자 모드'),
                        onTap: () => _showAddMessageDialog(context),
                      ),
                    if (userData.canManage)
                      ListTile(
                        leading: const Icon(Icons.group),
                        title: const Text('그룹 관리'),
                        subtitle: const Text('관리자 모드'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GroupManagementScreen(),
                            ),
                          );
                        },
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('문의사항'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InquiryScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('이용약관'),
                      onTap: () => _showTermsDialog(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('개인정보 처리방침'),
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.logout,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(
                        '로그아웃',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      onTap: () => _handleLogout(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProfileEditDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 정보 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: '전화번호'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => _updateProfile(
              context,
              _nameController.text,
              _phoneController.text,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile(
    BuildContext context,
    String name,
    String phone,
  ) async {
    try {
      await _userDataProvider.updateUserInfo({
        'name': name,
        'phone': phone,
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 업데이트되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      LoggerService.error('프로필 업데이트 중 에러 발생', e, null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 업데이트 중 오류가 발생했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await AuthService().signOut(context);
    } catch (e) {
      LoggerService.error('로그아웃 중 에러 발생', e, null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _showAddMessageDialog(BuildContext context) async {
    final userData = await _userDataProvider.getCurrentUser();
    return showDialog<void>(
      context: context,
      builder: (context) => AddMessageDialog(userData: userData),
    );
  }

  Future<void> _showTermsDialog(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TermsWebView(
          assetPath: TermsConstants.termsOfServicePath,
          title: '이용약관',
        ),
      ),
    );
  }

  Future<void> _showPrivacyDialog(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TermsWebView(
          assetPath: TermsConstants.privacyPolicyPath,
          title: '개인정보 처리방침',
        ),
      ),
    );
  }
}

class AddMessageDialog extends StatefulWidget {
  final UserData userData;

  const AddMessageDialog({
    super.key,
    required this.userData,
  });

  @override
  State<AddMessageDialog> createState() => _AddMessageDialogState();
}

class _AddMessageDialogState extends State<AddMessageDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late final TextEditingController _searchController;
  String _selectedMessageType = 'global';
  String? _selectedGroupId;
  String? _selectedUserId;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _messageController = TextEditingController();
    _searchController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 그룹 목록 로드
      final groupsResponse = await Supabase.instance.client
          .from('groups')
          .select('id, name')
          .order('name');

      // 사용자 목록 로드
      final usersResponse = await Supabase.instance.client
          .from('custom_users')
          .select('auth_id, name, office')
          .order('name');

      if (mounted) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(groupsResponse);
          _users = List<Map<String, dynamic>>.from(usersResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('데이터 로드 중 에러 발생', e, null);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    final trimmedTitle = _titleController.text.trim();
    final trimmedMessage = _messageController.text.trim();

    if (trimmedTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    if (trimmedMessage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }

    if (_selectedMessageType == 'group' && _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹을 선택해주세요.')),
      );
      return;
    }

    if (_selectedMessageType == 'personal' && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수신자를 선택해주세요.')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('messages').insert({
        'title': trimmedTitle,
        'message': trimmedMessage,
        'message_type': _selectedMessageType,
        'sender_id': widget.userData.authId,
        'receiver_id':
            _selectedMessageType == 'personal' ? _selectedUserId : null,
        'group_id': _selectedMessageType == 'group' ? _selectedGroupId : null,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지가 추가되었습니다.')),
      );
    } catch (e) {
      LoggerService.error('메시지 추가 중 에러 발생', e, null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지 추가 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('메시지 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedMessageType,
              decoration: const InputDecoration(
                labelText: '메시지 타입',
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'global',
                  child: Text('전체 알림'),
                ),
                DropdownMenuItem<String>(
                  value: 'group',
                  child: Text('그룹 알림'),
                ),
                DropdownMenuItem<String>(
                  value: 'personal',
                  child: Text('개인 알림'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMessageType = value!;
                  _selectedGroupId = null;
                  _selectedUserId = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedMessageType == 'group' && _groups.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: '그룹 선택',
                ),
                items: _groups.map((group) {
                  return DropdownMenuItem<String>(
                    value: group['id'].toString(),
                    child: Text(group['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGroupId = value);
                },
              ),
            if (_selectedMessageType == 'personal')
              Autocomplete<Map<String, dynamic>>(
                initialValue: _selectedUserId != null
                    ? TextEditingValue(
                        text: _users
                            .firstWhere(
                              (user) => user['auth_id'] == _selectedUserId,
                              orElse: () => {'name': ''},
                            )['name']
                            .toString(),
                      )
                    : const TextEditingValue(),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _users;
                  }
                  return _users.where((user) {
                    final name = user['name']?.toString().toLowerCase() ?? '';
                    final office =
                        user['office']?.toString().toLowerCase() ?? '';
                    final searchQuery = textEditingValue.text.toLowerCase();
                    return name.contains(searchQuery) ||
                        office.contains(searchQuery);
                  });
                },
                displayStringForOption: (user) {
                  final office = user['office']?.toString();
                  return office != null && office.isNotEmpty
                      ? '${user['name']} ($office)'
                      : user['name'].toString();
                },
                onSelected: (user) {
                  setState(() => _selectedUserId = user['auth_id']);
                },
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: '수신자 검색/선택',
                      hintText: '이름 또는 직분으로 검색',
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final user = options.elementAt(index);
                            final office = user['office']?.toString();
                            return ListTile(
                              title: Text(
                                office != null && office.isNotEmpty
                                    ? '${user['name']} ($office)'
                                    : user['name'].toString(),
                              ),
                              onTap: () => onSelected(user),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '메시지 제목을 입력하세요',
              ),
              maxLines: 1,
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '메시지 내용을 입력하세요',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          TextButton(
            onPressed: _handleSubmit,
            child: const Text('추가'),
          ),
      ],
    );
  }
}
