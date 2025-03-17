import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';
import '../models/group_model.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  List<Group> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      setState(() => _isLoading = true);
      final response =
          await Supabase.instance.client.from('groups').select().order('name');

      _groups = (response as List).map((data) => Group.fromJson(data)).toList();
      setState(() => _isLoading = false);
    } catch (e) {
      LoggerService.error('그룹 로딩 중 에러 발생', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 목록을 불러오는데 실패했습니다.')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showGroupDialog([Group? group]) async {
    final TextEditingController nameController = TextEditingController(
      text: group?.name ?? '',
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group == null ? '그룹 추가' : '그룹 수정'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '그룹 이름',
            hintText: '그룹 이름을 입력하세요',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('그룹 이름을 입력해주세요.')),
                );
                return;
              }

              try {
                if (group == null) {
                  // 새 그룹 추가
                  await Supabase.instance.client.from('groups').insert({
                    'name': name,
                  });
                } else {
                  // 기존 그룹 수정
                  await Supabase.instance.client
                      .from('groups')
                      .update({'name': name}).eq('id', group.id);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadGroups();
              } catch (e) {
                LoggerService.error('그룹 저장 중 에러 발생', e, null);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('그룹 저장에 실패했습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(Group group) async {
    try {
      // 그룹 멤버 관계 먼저 삭제
      await Supabase.instance.client
          .from('user_groups')
          .delete()
          .eq('group_id', group.id);

      // 그룹 삭제
      await Supabase.instance.client.from('groups').delete().eq('id', group.id);

      _loadGroups();
    } catch (e) {
      LoggerService.error('그룹 삭제 중 에러 발생', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 삭제에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('그룹 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showGroupDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return ListTile(
                  title: Text(group.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showGroupDialog(group),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('그룹 삭제'),
                            content: Text('${group.name}을(를) 삭제하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteGroup(group);
                                },
                                child: const Text(
                                  '삭제',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/group-member',
                      arguments: {'group': group},
                    );
                  },
                );
              },
            ),
    );
  }
}
