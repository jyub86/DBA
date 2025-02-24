import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../models/banner_model.dart';
import 'package:dba/services/logger_service.dart';

class BannerSettingsScreen extends StatefulWidget {
  const BannerSettingsScreen({super.key});

  @override
  State<BannerSettingsScreen> createState() => _BannerSettingsScreenState();
}

class _BannerSettingsScreenState extends State<BannerSettingsScreen> {
  List<BannerModel> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      final response = await Supabase.instance.client
          .from('banners')
          .select()
          .order('created_at');

      setState(() {
        _banners = response.map((json) => BannerModel.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      LoggerService.error('배너 로드 중 에러 발생', e, null);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배너 로드 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  Future<void> _addBanner() async {
    final result = await showDialog<BannerModel>(
      context: context,
      builder: (context) => const BannerEditDialog(),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final response = await Supabase.instance.client
            .from('banners')
            .insert(result.toJson())
            .select()
            .single();

        setState(() {
          _banners.add(BannerModel.fromJson(response));
          _isLoading = false;
        });
      } catch (e) {
        LoggerService.error('배너 추가 중 에러 발생', e, null);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('배너 추가 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  Future<void> _editBanner(BannerModel banner) async {
    final result = await showDialog<BannerModel>(
      context: context,
      builder: (context) => BannerEditDialog(banner: banner),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final response = await Supabase.instance.client
            .from('banners')
            .update(result.toJson())
            .eq('id', banner.id as Object)
            .select()
            .single();

        setState(() {
          final index = _banners.indexWhere((b) => b.id == banner.id);
          if (index != -1) {
            _banners[index] = BannerModel.fromJson(response);
          }
          _isLoading = false;
        });
      } catch (e) {
        LoggerService.error('배너 수정 중 에러 발생', e, null);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('배너 수정 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  Future<void> _deleteBanner(BannerModel banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배너 삭제'),
        content: const Text('이 배너를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // 이미지 삭제
        final imagePath = Uri.parse(banner.imageUrl).pathSegments.last;
        await Supabase.instance.client.storage
            .from('banners')
            .remove([imagePath]);

        // 배너 데이터 삭제
        await Supabase.instance.client
            .from('banners')
            .delete()
            .eq('id', banner.id as Object);

        setState(() {
          _banners.removeWhere((b) => b.id == banner.id);
          _isLoading = false;
        });
      } catch (e) {
        LoggerService.error('배너 삭제 중 에러 발생', e, null);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('배너 삭제 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('배너 설정'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Image.network(
                        banner.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      ListTile(
                        title: Text(banner.title ?? '제목 없음'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: banner.active,
                              onChanged: (value) => _editBanner(
                                banner.copyWith(active: value),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editBanner(banner),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _deleteBanner(banner),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBanner,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class BannerEditDialog extends StatefulWidget {
  final BannerModel? banner;

  const BannerEditDialog({super.key, this.banner});

  @override
  State<BannerEditDialog> createState() => _BannerEditDialogState();
}

class _BannerEditDialogState extends State<BannerEditDialog> {
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  bool _isLoading = false;
  String? _imageUrl;
  XFile? _selectedImage; // 선택된 이미지 파일
  bool _active = true;

  @override
  void initState() {
    super.initState();
    if (widget.banner != null) {
      _titleController.text = widget.banner!.title ?? '';
      _linkController.text = widget.banner!.link ?? '';
      _imageUrl = widget.banner!.imageUrl;
      _active = widget.banner!.active;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image == null) return;

    final extension = path.extension(image.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png'].contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JPG 또는 PNG 이미지만 업로드 가능합니다.')),
        );
      }
      return;
    }

    setState(() {
      _selectedImage = image;
    });
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _imageUrl; // 이미지가 변경되지 않은 경우

    try {
      final extension = path.extension(_selectedImage!.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = 'banner_$timestamp$extension';

      await Supabase.instance.client.storage.from('banners').upload(
            imagePath,
            File(_selectedImage!.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return Supabase.instance.client.storage
          .from('banners')
          .getPublicUrl(imagePath);
    } catch (e) {
      LoggerService.error('이미지 업로드 중 에러 발생', e, null);
      rethrow;
    }
  }

  Future<void> _save() async {
    if (_imageUrl == null && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 선택해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uploadedImageUrl = await _uploadImage();
      if (uploadedImageUrl == null) return;

      final banner = BannerModel(
        id: widget.banner?.id,
        imageUrl: uploadedImageUrl,
        title: _titleController.text.isEmpty ? null : _titleController.text,
        link: _linkController.text.isEmpty ? null : _linkController.text,
        active: _active,
      );

      Navigator.pop(context, banner);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
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
    return AlertDialog(
      title: Text(widget.banner == null ? '배너 추가' : '배너 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(File(_selectedImage!.path)),
                            fit: BoxFit.cover,
                          )
                        : _imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (_selectedImage == null && _imageUrl == null)
                          ? const Center(child: Icon(Icons.add_photo_alternate))
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '배너 제목을 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('활성화'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
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
          onPressed: _isLoading ? null : _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
