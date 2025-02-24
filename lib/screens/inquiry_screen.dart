import 'package:flutter/material.dart';
import '../models/inquiry_model.dart';
import '../services/inquiry_service.dart';
import '../providers/user_data_provider.dart';
import '../services/logger_service.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final InquiryService _inquiryService = InquiryService();
  final _userDataProvider = UserDataProvider.instance;
  List<Inquiry> _inquiries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInquiries();
  }

  Future<void> _loadInquiries() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _userDataProvider.getCurrentUser();
      final inquiries = userData.canManage
          ? await _inquiryService.getAdminInquiries()
          : await _inquiryService.getInquiries(userData.authId);

      if (mounted) {
        setState(() {
          _inquiries = inquiries;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('Error loading inquiries', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('문의사항을 불러오는데 실패했습니다: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문의사항'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInquiries,
              child: _inquiries.isEmpty
                  ? const Center(child: Text('문의사항이 없습니다.'))
                  : ListView.builder(
                      itemCount: _inquiries.length,
                      itemBuilder: (context, index) {
                        final inquiry = _inquiries[index];
                        return InquiryCard(
                          inquiry: inquiry,
                          onRefresh: _loadInquiries,
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateInquiryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateInquiryDialog(BuildContext context) async {
    final userData = await _userDataProvider.getCurrentUser();
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      builder: (context) => CreateInquiryDialog(
        userId: userData.authId,
        onInquiryCreated: _loadInquiries,
      ),
    );
  }
}

class InquiryCard extends StatelessWidget {
  final Inquiry inquiry;
  final VoidCallback onRefresh;

  const InquiryCard({
    super.key,
    required this.inquiry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: inquiry.isResolved
                    ? Colors.green.withAlpha(26)
                    : Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                inquiry.isResolved ? '답변완료' : '답변대기',
                style: TextStyle(
                  fontSize: 12,
                  color: inquiry.isResolved ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                inquiry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 14),
              const SizedBox(width: 4),
              Text(
                inquiry.createdAt.toLocal().toString().split('.')[0],
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '문의내용',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(77),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inquiry.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (inquiry.answer != null) ...[
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.question_answer, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '답변',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(77),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inquiry.answer!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '답변일시: ${inquiry.answeredAt?.toLocal().toString().split('.')[0]}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                FutureBuilder(
                  future: UserDataProvider.instance.getCurrentUser(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final userData = snapshot.data!;
                    if (!userData.canManage || inquiry.isResolved) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAnswerDialog(
                          context,
                          inquiry,
                          userData.authId,
                          onRefresh,
                        ),
                        icon: const Icon(Icons.reply),
                        label: const Text('답변하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnswerDialog(
    BuildContext context,
    Inquiry inquiry,
    String answeredBy,
    VoidCallback onRefresh,
  ) {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('답변 작성'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '답변',
            hintText: '답변 내용을 입력하세요',
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('답변 내용을 입력해주세요.')),
                );
                return;
              }
              try {
                await InquiryService().answerInquiry(
                  id: inquiry.id.toString(),
                  answer: controller.text.trim(),
                  answeredBy: answeredBy,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  onRefresh();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('답변 등록에 실패했습니다.')),
                  );
                }
              }
            },
            child: const Text('답변'),
          ),
        ],
      ),
    );
  }
}

class CreateInquiryDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onInquiryCreated;

  const CreateInquiryDialog({
    super.key,
    required this.userId,
    required this.onInquiryCreated,
  });

  @override
  State<CreateInquiryDialog> createState() => _CreateInquiryDialogState();
}

class _CreateInquiryDialogState extends State<CreateInquiryDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목을 입력해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('내용을 입력해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await InquiryService().createInquiry(
        title: title,
        content: content,
        userId: widget.userId,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      widget.onInquiryCreated();
    } catch (e, stackTrace) {
      LoggerService.error('Error creating inquiry', e, stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('문의사항 등록에 실패했습니다: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('문의사항 작성'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '문의사항 제목을 입력하세요',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '문의사항 내용을 입력하세요',
              ),
              maxLines: 5,
              maxLength: 1000,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('등록'),
        ),
      ],
    );
  }
}
