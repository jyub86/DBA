import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';

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
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  return _users.where((user) {
                    final name = user['name']?.toString().toLowerCase() ?? '';
                    final office =
                        user['office']?.toString().toLowerCase() ?? '';
                    final searchText = textEditingValue.text.toLowerCase();
                    return name.contains(searchText) ||
                        office.contains(searchText);
                  });
                },
                displayStringForOption: (user) {
                  final office = user['office']?.toString();
                  return office != null && office.isNotEmpty
                      ? '${user['name']} ($office)'
                      : user['name'].toString();
                },
                onSelected: (user) {
                  setState(() {
                    _selectedUserId = user['auth_id'].toString();
                  });
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
