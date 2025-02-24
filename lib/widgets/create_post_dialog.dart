import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostDialog extends StatefulWidget {
  const CreatePostDialog({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreatePostDialog(),
    );
  }

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<TextEditingController> _mediaUrlControllers = [
    TextEditingController()
  ];
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .eq('active', true)
          .order('name');

      if (!mounted) return;

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories[0]['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _categories = [];
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (var controller in _mediaUrlControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addMediaUrlField() {
    setState(() {
      _mediaUrlControllers.add(TextEditingController());
    });
  }

  void _removeMediaUrlField(int index) {
    if (_mediaUrlControllers.length > 1) {
      setState(() {
        _mediaUrlControllers[index].dispose();
        _mediaUrlControllers.removeAt(index);
      });
    }
  }

  List<String> _getMediaUrls() {
    return _mediaUrlControllers
        .map((controller) => controller.text.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text('새 게시물 작성'),
        content: _isLoading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: '제목'),
                    ),
                    const SizedBox(height: 16),
                    if (_categories.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: '카테고리'),
                        items: _categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['id'] as int,
                            child: Text(category['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategoryId = value),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(labelText: '내용'),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('미디어 URL'),
                        const SizedBox(height: 8),
                        ..._mediaUrlControllers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      hintText: '미디어 URL을 입력하세요',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_mediaUrlControllers.length > 1)
                                  IconButton(
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                    onPressed: () =>
                                        _removeMediaUrlField(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 20,
                                  ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: _addMediaUrlField,
                          icon: const Icon(Icons.add),
                          label: const Text('URL 추가'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          if (!_isLoading)
            TextButton(
              onPressed: () {
                if (_selectedCategoryId == null) return;
                Navigator.of(context).pop({
                  'title': _titleController.text,
                  'category_id': _selectedCategoryId,
                  'content': _contentController.text,
                  'media_urls': _getMediaUrls(),
                });
              },
              child: const Text('저장'),
            ),
        ],
      ),
    );
  }
}
