import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/church_event.dart';
import '../utils/date_formatter.dart';
import '../providers/user_data_provider.dart';

class ChurchCalendarScreen extends StatefulWidget {
  const ChurchCalendarScreen({super.key});

  @override
  State<ChurchCalendarScreen> createState() => _ChurchCalendarScreenState();
}

class _ChurchCalendarScreenState extends State<ChurchCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final Map<DateTime, List<ChurchEvent>> _events = {};
  List<ChurchEvent> _selectedEvents = [];
  bool _isLoading = false;
  final _userDataProvider = UserDataProvider.instance;
  List<ChurchEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('church_events')
          .select()
          .order('start_date');

      _allEvents = response.map((json) => ChurchEvent.fromJson(json)).toList();
      _updateEventsForMonth(_focusedDay);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정을 불러오는 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _updateEventsForMonth(DateTime month) {
    final eventMap = <DateTime, List<ChurchEvent>>{};

    // 해당 월의 시작일과 마지막 날을 계산
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    for (final event in _allEvents) {
      // 1. 기본 일정 처리
      if (event.recurrenceType == RecurrenceType.none) {
        final date = DateTime(
          event.startDate.year,
          event.startDate.month,
          event.startDate.day,
        );

        if (eventMap[date] == null) {
          eventMap[date] = [];
        }
        eventMap[date]!.add(event);

        // 연속된 일정인 경우 종료일까지의 모든 날짜에 이벤트 추가
        var currentDate = date.add(const Duration(days: 1));
        final endDate = DateTime(
          event.endDate.year,
          event.endDate.month,
          event.endDate.day,
        );

        while (currentDate.isBefore(endDate) ||
            currentDate.isAtSameMomentAs(endDate)) {
          if (eventMap[currentDate] == null) {
            eventMap[currentDate] = [];
          }
          eventMap[currentDate]!.add(event);
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
      // 2. 반복 일정 처리
      else {
        // 현재 달의 모든 날짜에 대해 반복 일정 확인
        var currentDate = firstDay;
        while (!currentDate.isAfter(lastDay)) {
          if (event.isOccurringOn(currentDate)) {
            if (eventMap[currentDate] == null) {
              eventMap[currentDate] = [];
            }
            eventMap[currentDate]!.add(event);
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }

    setState(() {
      _events.clear();
      _events.addAll(eventMap);
      _selectedEvents = _getEventsForDay(_selectedDay);
    });
  }

  List<ChurchEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedEvents = _getEventsForDay(selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교회 일정'),
        actions: [
          if (_userDataProvider.userData?.canManage ?? false)
            IconButton(
              icon: const Icon(Icons.event_note),
              tooltip: '일정 관리',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/church-event-management',
                ).then((_) => _loadEvents());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<ChurchEvent>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {
              CalendarFormat.month: '월',
            },
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.red),
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              selectedTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
              _updateEventsForMonth(focusedDay);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;

                // 종일 일정과 일반 일정 분리
                final allDayEvents = events.where((e) => e.isAllDay).toList();
                final normalEvents = events.where((e) => !e.isAllDay).toList();

                return Stack(
                  children: [
                    // 일반 일정 표시 (점으로)
                    if (normalEvents.isNotEmpty)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: normalEvents.first.eventColor.withAlpha(179),
                          ),
                        ),
                      ),

                    // 종일 일정 표시
                    if (allDayEvents.isNotEmpty)
                      ...allDayEvents.asMap().entries.map((entry) {
                        final event = entry.value;
                        final index = entry.key;

                        // 이전 날짜와 다음 날짜에도 같은 일정이 있는지 확인
                        final previousDay =
                            DateTime(date.year, date.month, date.day - 1);
                        final nextDay =
                            DateTime(date.year, date.month, date.day + 1);

                        // 이 날짜가 해당 이벤트의 시작일인지 확인
                        final isStartDay = DateTime(
                          date.year,
                          date.month,
                          date.day,
                        ).isAtSameMomentAs(DateTime(
                          event.startDate.year,
                          event.startDate.month,
                          event.startDate.day,
                        ));

                        final hasPrevious = !isStartDay &&
                            (_events[previousDay]
                                    ?.any((e) => e.id == event.id) ??
                                false);
                        final hasNext =
                            _events[nextDay]?.any((e) => e.id == event.id) ??
                                false;

                        return Positioned(
                          bottom: 3.0 + (index * 8),
                          left: hasPrevious ? 0 : 4,
                          right: hasNext ? 0 : 4,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: event.eventColor.withAlpha(179),
                              borderRadius: BorderRadius.horizontal(
                                left: hasPrevious
                                    ? Radius.zero
                                    : const Radius.circular(3),
                                right: hasNext
                                    ? Radius.zero
                                    : const Radius.circular(3),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
              dowBuilder: (context, day) {
                final text = DateFormat.E('ko_KR').format(day);
                return Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: day.weekday == DateTime.sunday
                          ? Colors.red
                          : day.weekday == DateTime.saturday
                              ? Colors.blue
                              : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final event = _selectedEvents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목 행
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: event.eventColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (event.isAllDay)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '종일',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 날짜/시간 정보
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      event.isAllDay
                                          ? '${DateFormatter.formatDate(event.startDate)} ~ ${DateFormatter.formatDate(event.endDate)}'
                                          : '${DateFormatter.formatDateTime(event.startDate)} ~ ${DateFormatter.formatTime(event.endDate)}',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              // 반복 정보
                              if (event.recurrenceType !=
                                  RecurrenceType.none) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.repeat,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      switch (event.recurrenceType) {
                                        RecurrenceType.weekly => '매주',
                                        RecurrenceType.monthly => '매월',
                                        RecurrenceType.yearly => '매년',
                                        RecurrenceType.none => '',
                                      },
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                    if (event.recurrenceEndDate != null) ...[
                                      Text(
                                        ' (${DateFormatter.formatDate(event.recurrenceEndDate!)}까지)',
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              // 장소 정보
                              if (event.location != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      event.location!,
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                              // 설명
                              if (event.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  event.description!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
