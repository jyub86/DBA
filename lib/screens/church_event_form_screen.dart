import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/church_event.dart';
import '../utils/date_formatter.dart';
import '../services/logger_service.dart';

class ChurchEventFormScreen extends StatefulWidget {
  final ChurchEvent? event;

  const ChurchEventFormScreen({super.key, this.event});

  @override
  State<ChurchEventFormScreen> createState() => _ChurchEventFormScreenState();
}

class _ChurchEventFormScreenState extends State<ChurchEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  DateTime? _recurrenceEndDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      // 수정 모드
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description ?? '';
      _locationController.text = widget.event!.location ?? '';
      _startDate = widget.event!.startDate;
      _endDate = widget.event!.endDate;
      _startTime = TimeOfDay.fromDateTime(widget.event!.startDate);
      _endTime = TimeOfDay.fromDateTime(widget.event!.endDate);
      _isAllDay = widget.event!.isAllDay;
      _recurrenceType = widget.event!.recurrenceType;
      _recurrenceEndDate = widget.event!.recurrenceEndDate;
    } else {
      // 추가 모드
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(hours: 1));
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1)),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2025, 12, 31),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _startTime.hour,
            _startTime.minute,
          );
          // 시작일이 종료일보다 늦으면 종료일 자동 조정
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate.add(const Duration(hours: 1));
            _endTime = TimeOfDay.fromDateTime(_endDate);
          }
        } else {
          _endDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _endTime.hour,
            _endTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    if (_isAllDay) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _startDate = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            picked.hour,
            picked.minute,
          );
          // 시작 시간이 종료 시간보다 늦으면 종료 시간 자동 조정
          final startDateTime = _startDate;
          final endDateTime = _endDate;
          if (startDateTime.isAfter(endDateTime)) {
            _endDate = startDateTime.add(const Duration(hours: 1));
            _endTime = TimeOfDay.fromDateTime(_endDate);
          }
        } else {
          _endTime = picked;
          _endDate = DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            picked.hour,
            picked.minute,
          );
        }
      });
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    if (_recurrenceType == RecurrenceType.none) {
      setState(() => _recurrenceEndDate = null);
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2025, 12, 31),
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'location':
            _locationController.text.isEmpty ? null : _locationController.text,
        'start_date': _startDate.toUtc().toIso8601String(),
        'end_date': _endDate.toUtc().toIso8601String(),
        'is_all_day': _isAllDay,
        'recurrence_type': _recurrenceType.toString().split('.').last,
        'recurrence_end_date': _recurrenceEndDate?.toUtc().toIso8601String(),
      };

      if (widget.event != null) {
        // 수정
        await Supabase.instance.client
            .from('church_events')
            .update(data)
            .eq('id', widget.event!.id)
            .select()
            .single();
      } else {
        // 추가
        await Supabase.instance.client
            .from('church_events')
            .insert(data)
            .select()
            .single();
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      LoggerService.error('일정 저장 중 오류', e, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event != null
                  ? '일정 수정 중 오류가 발생했습니다.'
                  : '일정 추가 중 오류가 발생했습니다.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? '일정 수정' : '새 일정'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 제목
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 종일 여부
            SwitchListTile(
              title: const Text('종일'),
              value: _isAllDay,
              onChanged: (bool value) {
                setState(() => _isAllDay = value);
              },
            ),

            // 시작일/시간
            ListTile(
              title: const Text('시작'),
              subtitle: Text(
                _isAllDay
                    ? DateFormatter.formatDate(_startDate)
                    : DateFormatter.formatDateTime(_startDate),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(true),
                  ),
                  if (!_isAllDay)
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _selectTime(true),
                    ),
                ],
              ),
            ),

            // 종료일/시간
            ListTile(
              title: const Text('종료'),
              subtitle: Text(
                _isAllDay
                    ? DateFormatter.formatDate(_endDate)
                    : DateFormatter.formatDateTime(_endDate),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(false),
                  ),
                  if (!_isAllDay)
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _selectTime(false),
                    ),
                ],
              ),
            ),

            const Divider(),

            // 반복 설정
            ListTile(
              title: const Text('반복'),
              trailing: DropdownButton<RecurrenceType>(
                value: _recurrenceType,
                items: const [
                  DropdownMenuItem(
                    value: RecurrenceType.none,
                    child: Text('반복 없음'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.weekly,
                    child: Text('매주'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.monthly,
                    child: Text('매월'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.yearly,
                    child: Text('매년'),
                  ),
                ],
                onChanged: (RecurrenceType? value) {
                  if (value != null) {
                    setState(() => _recurrenceType = value);
                    if (value == RecurrenceType.none) {
                      setState(() => _recurrenceEndDate = null);
                    } else {
                      _selectRecurrenceEndDate();
                    }
                  }
                },
              ),
            ),

            // 반복 종료일
            if (_recurrenceType != RecurrenceType.none)
              ListTile(
                title: const Text('반복 종료일'),
                subtitle: Text(
                  _recurrenceEndDate != null
                      ? DateFormatter.formatDate(_recurrenceEndDate!)
                      : '설정되지 않음',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectRecurrenceEndDate,
                ),
              ),

            const Divider(),

            // 장소
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '장소',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 설명
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
