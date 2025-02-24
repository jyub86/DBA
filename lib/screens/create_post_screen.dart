import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../services/category_service.dart';
import '../models/post_model.dart';
import '../models/category_model.dart';
import '../screens/main_screen.dart';
import '../providers/user_data_provider.dart';
import '../services/logger_service.dart';

class CreatePostScreen extends StatefulWidget {
  final Post? editPost; // 수정할 게시물

  const CreatePostScreen({
    super.key,
    this.editPost,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<TextEditingController> _mediaUrlControllers = [
    TextEditingController()
  ];
  final _contentController = TextEditingController();
  final _categoryService = CategoryService.instance;
  final _userDataProvider = UserDataProvider.instance;
  final List<File> _selectedImages = [];
  final _imagePicker = ImagePicker();
  List<CategoryModel> _availableCategories = [];
  int? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.editPost != null) {
      _initializeEditPost();
    }
  }

  void _initializeEditPost() {
    final post = widget.editPost!;
    _titleController.text = post.title;
    _contentController.text = post.content ?? '';

    // categoryId 초기화
    _selectedCategoryId = post.categoryId;

    // 미디어 URL 초기화
    if (post.mediaUrls.isNotEmpty) {
      _mediaUrlControllers.clear();
      for (final url in post.mediaUrls) {
        _mediaUrlControllers.add(TextEditingController(text: url));
      }
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

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      final userData = await _userDataProvider.getCurrentUser();
      final userLevel = userData.role.level;

      if (mounted) {
        setState(() {
          _availableCategories = categories.where((category) {
            return (category.allowedLevel <= userLevel);
          }).toList();

          // 수정 모드일 때 현재 카테고리가 사용 가능한지 확인
          if (widget.editPost != null) {
            final currentCategory = categories.firstWhere(
              (category) => category.id == widget.editPost!.categoryId,
              orElse: () => CategoryModel(
                id: 0,
                name: '없음',
                order: -1,
                active: false,
                allowedLevel: 999,
              ),
            );

            // 현재 카테고리가 사용 불가능하면 선택 해제
            if (currentCategory.allowedLevel > userLevel) {
              _selectedCategoryId = null;
            }
          }
        });
      }
    } catch (e) {
      LoggerService.error('카테고리 로드 중 에러 발생', e, null);
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최대 10개의 이미지만 업로드할 수 있습니다.')),
        );
      }
      return;
    }

    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (images.isEmpty) return;

    setState(() {
      for (var image in images) {
        if (_selectedImages.length < 10) {
          _selectedImages.add(File(image.path));
        }
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    final List<String> uploadedUrls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < _selectedImages.length; i++) {
      final file = _selectedImages[i];
      final extension = path.extension(file.path).toLowerCase();

      if (!['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
        continue;
      }

      final imagePath =
          '/${await _userDataProvider.getCurrentUser().then((user) => user.authId)}/posts_${timestamp}_$i$extension';

      try {
        await Supabase.instance.client.storage.from('posts').upload(
              imagePath,
              file,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: true),
            );

        final imageUrl = Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(imagePath);

        uploadedUrls.add(imageUrl);
      } catch (e) {
        debugPrint('이미지 업로드 중 에러 발생: $e');
      }
    }

    return uploadedUrls;
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 카테고리는 필수 입력 항목입니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _userDataProvider.getCurrentUser();
      // 이미지 업로드
      final uploadedImageUrls = await _uploadImages();

      final postData = {
        'title': _titleController.text,
        'category_id': _selectedCategoryId,
        'user_id': userData.authId,
      };

      // 내용이 있는 경우에만 추가
      if (_contentController.text.isNotEmpty) {
        postData['content'] = _contentController.text;
      }

      // 미디어 URL이 있는 경우에만 추가
      final mediaUrls = [
        ...uploadedImageUrls,
        ..._getMediaUrls(),
      ];
      if (mediaUrls.isNotEmpty) {
        postData['media_urls'] = mediaUrls;
      }

      if (widget.editPost != null) {
        // 게시물 수정
        await Supabase.instance.client
            .from('posts')
            .update(postData)
            .eq('id', widget.editPost!.id);
      } else {
        // 새 게시물 생성
        await Supabase.instance.client.from('posts').insert(postData);
      }

      if (mounted) {
        // MainScreen으로 이동하면서 스택 정리
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              initialIndex: 1, // 게시판 탭으로 이동
              initialCategoryId: _selectedCategoryId, // 선택된 카테고리로 이동
            ),
          ),
          (route) => false, // 모든 이전 화면 제거
        );
      }
    } catch (e) {
      debugPrint('게시물 저장 중 에러 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시물 저장 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editPost != null ? '게시물 수정' : '새 게시물'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 80, // 하단 버튼을 위한 여백
              ),
              children: [
                DropdownButtonFormField<int?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: _availableCategories.map((category) {
                    return DropdownMenuItem<int?>(
                      value: category.id,
                      child: Text(
                        category.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategoryId = value),
                  validator: (value) {
                    if (value == null) {
                      return '카테고리를 선택해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '제목을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 8,
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('이미지'),
                        TextButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('이미지 추가'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_selectedImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
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
                              child: TextFormField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: '미디어 URL을 입력하세요',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_mediaUrlControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 18),
                                onPressed: () => _removeMediaUrlField(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 18,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.editPost != null ? '수정하기' : '게시하기',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
