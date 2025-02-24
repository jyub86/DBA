import 'package:flutter/material.dart';

enum RecurrenceType {
  none, // 반복 없음
  weekly, // 매주
  monthly, // 매월
  yearly // 매년
}

class ChurchEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final bool isAllDay;
  final String? location;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final RecurrenceType recurrenceType;
  final DateTime? recurrenceEndDate; // 반복 종료일
  final int? dayOfWeek; // 요일 (1: 월요일 ~ 7: 일요일)
  final int? dayOfMonth; // 월 중 일자 (1-31)
  final int? monthOfYear; // 연중 월 (1-12)

  const ChurchEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.isAllDay = false,
    this.location,
    required this.createdAt,
    this.updatedAt,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceEndDate,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
  });

  factory ChurchEvent.fromJson(Map<String, dynamic> json) {
    // UTC 시간을 로컬 시간으로 변환
    DateTime parseAndLocalizeTime(String? dateString) {
      if (dateString == null) return DateTime.now();
      final utcTime = DateTime.parse(dateString);
      return utcTime.toLocal();
    }

    return ChurchEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startDate: parseAndLocalizeTime(json['start_date']),
      endDate: parseAndLocalizeTime(json['end_date']),
      isAllDay: json['is_all_day'] ?? false,
      location: json['location'],
      createdAt: parseAndLocalizeTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? parseAndLocalizeTime(json['updated_at'])
          : null,
      recurrenceType: json['recurrence_type'] != null
          ? RecurrenceType.values.firstWhere(
              (e) => e.toString().split('.').last == json['recurrence_type'],
              orElse: () => RecurrenceType.none,
            )
          : RecurrenceType.none,
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? parseAndLocalizeTime(json['recurrence_end_date'])
          : null,
      dayOfWeek: json['day_of_week'],
      dayOfMonth: json['day_of_month'],
      monthOfYear: json['month_of_year'],
    );
  }

  Map<String, dynamic> toJson() {
    // 로컬 시간을 UTC로 변환
    String convertToUtc(DateTime dateTime) {
      return dateTime.toUtc().toIso8601String();
    }

    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': convertToUtc(startDate),
      'end_date': convertToUtc(endDate),
      'is_all_day': isAllDay,
      'location': location,
      'created_at': convertToUtc(createdAt),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'recurrence_type': recurrenceType != RecurrenceType.none
          ? recurrenceType.toString().split('.').last
          : null,
      'recurrence_end_date': recurrenceEndDate?.toUtc().toIso8601String(),
      'day_of_week': dayOfWeek,
      'day_of_month': dayOfMonth,
      'month_of_year': monthOfYear,
    };
  }

  Color get eventColor {
    // 반복 일정인 경우 주황색
    if (recurrenceType != RecurrenceType.none) {
      return Colors.orange.shade300;
    }

    // 연속 일정인 경우 파란색 (시작일과 종료일이 다른 경우)
    if (startDate.year != endDate.year ||
        startDate.month != endDate.month ||
        startDate.day != endDate.day) {
      return Colors.blue.shade300;
    }

    // 단일 일정인 경우 초록색
    return Colors.green.shade300;
  }

  /// 특정 날짜가 이 이벤트의 반복 일정에 포함되는지 확인
  bool isOccurringOn(DateTime date) {
    // 기본 일정인 경우 시작일과 종료일 사이에 있는지 확인
    if (recurrenceType == RecurrenceType.none) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
      return !normalizedDate.isBefore(normalizedStart) &&
          !normalizedDate.isAfter(normalizedEnd);
    }

    // 반복 종료일을 넘어선 경우
    if (recurrenceEndDate != null && date.isAfter(recurrenceEndDate!)) {
      return false;
    }

    // 시작일 이전인 경우
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    if (normalizedDate.isBefore(normalizedStart)) {
      return false;
    }

    // 시작일인 경우
    if (normalizedDate.isAtSameMomentAs(normalizedStart)) {
      return true;
    }

    switch (recurrenceType) {
      case RecurrenceType.weekly:
        return date.weekday == startDate.weekday;

      case RecurrenceType.monthly:
        return date.day == startDate.day;

      case RecurrenceType.yearly:
        return date.month == startDate.month && date.day == startDate.day;

      case RecurrenceType.none:
        return false;
    }
  }
}
