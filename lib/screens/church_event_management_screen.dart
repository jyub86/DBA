import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/church_event.dart';
import '../utils/date_formatter.dart';
import 'church_event_form_screen.dart';

class ChurchEventManagementScreen extends StatefulWidget {
  const ChurchEventManagementScreen({super.key});

  @override
  State<ChurchEventManagementScreen> createState() =>
      _ChurchEventManagementScreenState();
}

class _ChurchEventManagementScreenState
    extends State<ChurchEventManagementScreen> {
  List<ChurchEvent> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('church_events')
          .select()
          .order('start_date', ascending: false);

      setState(() {
        _events = response.map((json) => ChurchEvent.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정을 불러오는 중 오류가 발생했습니다.')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await Supabase.instance.client
          .from('church_events')
          .delete()
          .eq('id', eventId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다.')),
        );
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 일정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChurchEventFormScreen(),
                ),
              ).then((value) {
                if (value == true) _loadEvents();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event.eventColor,
                      ),
                    ),
                    title: Text(event.title),
                    subtitle: Text(
                      event.isAllDay
                          ? '${DateFormatter.formatDate(event.startDate)} ~ ${DateFormatter.formatDate(event.endDate)}'
                          : '${DateFormatter.formatDateTime(event.startDate)} ~ ${DateFormatter.formatDateTime(event.endDate)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChurchEventFormScreen(event: event),
                              ),
                            ).then((value) {
                              if (value == true) _loadEvents();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('일정 삭제'),
                                content: const Text('이 일정을 삭제하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteEvent(event.id);
                                    },
                                    child: const Text(
                                      '삭제',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
