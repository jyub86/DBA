import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../providers/user_data_provider.dart';
import '../constants/terms_constants.dart';
import '../widgets/add_message_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dba/services/logger_service.dart';
import '../utils/phone_formatter.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

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

    if (mounted) {
      setState(() => _isLoading = true);
    }

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
    // ThemeProvider 접근
    final themeProvider = Provider.of<ThemeProvider>(context);

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
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로필 카드
                        Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _pickAndUploadImage,
                                      child: CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: _profileUrl != null
                                            ? CachedNetworkImageProvider(
                                                _profileUrl!,
                                              )
                                            : null,
                                        child: _profileUrl == null
                                            ? const Icon(
                                                Icons.person,
                                                size: 40,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userData.name ?? '이름 없음',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            userData.email ?? '',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            userData.phone ?? '전화번호 없음',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () =>
                                      _showProfileEditDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                  child: const Text('프로필 수정'),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 환경 설정
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            '환경 설정',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        // 다크 모드 설정 카드 추가
                        Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: SwitchListTile(
                            title: Row(
                              children: [
                                Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                const Text('다크 모드'),
                              ],
                            ),
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              themeProvider.toggleTheme();
                            },
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.favorite),
                          title: const Text('좋아요'),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/my-liked-posts',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.comment),
                          title: const Text('댓글'),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/my-commented-posts',
                          ),
                        ),
                        if (userData.canManage) const Divider(),
                        if (userData.canManage)
                          ListTile(
                            leading: const Icon(Icons.image),
                            title: const Text('배너 설정'),
                            subtitle: const Text('관리자 모드'),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/banner-settings',
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
                              Navigator.pushNamed(
                                context,
                                '/group-management',
                              );
                            },
                          ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('문의사항'),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/inquiry',
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
        );
      },
    );
  }

  Future<void> _showProfileEditDialog(BuildContext context) async {
    final userData = await _userDataProvider.getCurrentUser();
    bool isInfoPublic = userData.isInfoPublic;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9;

    return showDialog(
      context: context,
      builder: (profileDialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: SizedBox(
            width: dialogWidth,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 정보 변경',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        hintText: '실명을 입력해주세요',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: '전화번호',
                        hintText: '010-1234-5678',
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        final formatted = PhoneFormatter.format(value);
                        if (formatted != value) {
                          _phoneController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '정보 공개 여부',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Row(
                              children: [
                                Text(
                                  isInfoPublic ? '공개' : '비공개',
                                  style: TextStyle(
                                    color: isInfoPublic
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: isInfoPublic,
                                  onChanged: (value) {
                                    setState(() {
                                      isInfoPublic = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!isInfoPublic) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '개인 정보 공개를 허용해주세요. 정보 공개 시, 글쓰기 및 주소록 서비스를 사용할 수 있습니다. 정보 비공개로 변경 시, 기존에 작성했던 게시글 및 댓글도 비공개로 변경됩니다. 또한 일부 서비스(게시 글 작성 및 주소록 서비스) 사용에 제한을 받을 수 있습니다.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(profileDialogContext),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            // 전화번호 형식 검증
                            if (!PhoneFormatter.isValid(
                                _phoneController.text)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('올바른 전화번호 형식이 아닙니다.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            // 이름 검증
                            final name = _nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('이름을 입력해주세요.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            _updateProfile(
                              profileDialogContext,
                              name,
                              _phoneController.text,
                              isInfoPublic,
                            );
                          },
                          child: const Text('저장'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          // 내 정보 변경 다이얼로그를 먼저 닫음
                          Navigator.pop(profileDialogContext);
                          // 계정 삭제 다이얼로그를 표시
                          await _showDeleteAccountConfirmDialog(context);
                        },
                        icon: Icon(
                          Icons.delete_forever,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(
                          '계정 삭제',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile(
    BuildContext context,
    String name,
    String phone,
    bool isInfoPublic,
  ) async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 사용자 정보 업데이트
      await _userDataProvider.updateUserInfo({
        'name': name,
        'phone': phone,
        'is_info_public': isInfoPublic,
      });

      // UserDataProvider 초기화
      await _userDataProvider.initialize(currentUser.id);

      if (!context.mounted) return;
      Navigator.pop(context); // 로딩 닫기
      Navigator.pop(context); // 다이얼로그 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 업데이트되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      LoggerService.error('프로필 업데이트 중 에러 발생', e, null);
      if (!context.mounted) return;
      Navigator.pop(context); // 로딩 닫기
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
    Navigator.of(context).pushNamed(
      '/terms-webview',
      arguments: {
        'assetPath': TermsConstants.termsOfServicePath,
        'title': '이용약관',
      },
    );
  }

  Future<void> _showPrivacyDialog(BuildContext context) async {
    Navigator.of(context).pushNamed(
      '/terms-webview',
      arguments: {
        'assetPath': TermsConstants.privacyPolicyPath,
        'title': '개인정보 처리방침',
      },
    );
  }

  Future<void> _showDeleteAccountConfirmDialog(BuildContext context) async {
    bool understood = false;
    bool isLoading = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => WillPopScope(
          onWillPop: () async => !isLoading,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                const Text('계정 삭제'),
              ],
            ),
            content: isLoading
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('계정 삭제 중...'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '계정을 삭제하면 다음과 같은 데이터가 영구적으로 삭제되며 복구할 수 없습니다:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('• 작성한 모든 게시물'),
                      const Text('• 작성한 모든 댓글'),
                      const Text('• 좋아요 표시한 게시물'),
                      const Text('• 프로필 정보 및 설정'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: understood,
                            onChanged: (value) {
                              setState(() {
                                understood = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              '위 내용을 이해했으며, 계정 삭제에 동의합니다.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            actions: isLoading
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: understood
                          ? () async {
                              setState(() {
                                isLoading = true;
                              });

                              try {
                                final success =
                                    await AuthService().deleteAccount(context);
                                if (!success) {
                                  throw Exception('계정 삭제에 실패했습니다.');
                                }

                                // 계정 삭제 성공 시 로그인 화면으로 이동
                                if (!context.mounted) return;
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (route) => false,
                                );
                              } catch (e) {
                                LoggerService.error('계정 삭제 중 에러 발생', e, null);
                                if (!context.mounted) return;
                                Navigator.pop(dialogContext); // 다이얼로그 닫기
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '계정 삭제 중 오류가 발생했습니다. 관리자에게 문의해주세요.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('삭제'),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
