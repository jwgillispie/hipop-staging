import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ScheduleType {
  specificDates,
  recurring,
}

enum RecurrencePattern {
  weekly,
  biweekly,
  monthly,
  custom,
}

class MarketSchedule extends Equatable {
  final String id;
  final String marketId;
  final ScheduleType type;
  final String startTime; // e.g., "9:00 AM"
  final String endTime;   // e.g., "2:00 PM"
  
  // For specific dates
  final List<DateTime>? specificDates;
  
  // For recurring schedules
  final RecurrencePattern? recurrencePattern;
  final List<int>? daysOfWeek; // 1=Monday, 7=Sunday
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? intervalWeeks; // For biweekly, every N weeks
  
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MarketSchedule({
    required this.id,
    required this.marketId,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.specificDates,
    this.recurrencePattern,
    this.daysOfWeek,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.intervalWeeks,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketSchedule.specificDates({
    required String id,
    required String marketId,
    required String startTime,
    required String endTime,
    required List<DateTime> dates,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return MarketSchedule(
      id: id,
      marketId: marketId,
      type: ScheduleType.specificDates,
      startTime: startTime,
      endTime: endTime,
      specificDates: dates,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MarketSchedule.recurring({
    required String id,
    required String marketId,
    required String startTime,
    required String endTime,
    required RecurrencePattern pattern,
    required List<int> daysOfWeek,
    required DateTime startDate,
    DateTime? endDate,
    int? intervalWeeks,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return MarketSchedule(
      id: id,
      marketId: marketId,
      type: ScheduleType.recurring,
      startTime: startTime,
      endTime: endTime,
      recurrencePattern: pattern,
      daysOfWeek: daysOfWeek,
      recurrenceStartDate: startDate,
      recurrenceEndDate: endDate,
      intervalWeeks: intervalWeeks,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MarketSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MarketSchedule(
      id: doc.id,
      marketId: data['marketId'] ?? '',
      type: ScheduleType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ScheduleType.specificDates,
      ),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      specificDates: data['specificDates'] != null
          ? (data['specificDates'] as List)
              .map((timestamp) => (timestamp as Timestamp).toDate())
              .toList()
          : null,
      recurrencePattern: data['recurrencePattern'] != null
          ? RecurrencePattern.values.firstWhere(
              (e) => e.name == data['recurrencePattern'],
              orElse: () => RecurrencePattern.weekly,
            )
          : null,
      daysOfWeek: data['daysOfWeek'] != null
          ? List<int>.from(data['daysOfWeek'])
          : null,
      recurrenceStartDate: data['recurrenceStartDate'] != null
          ? (data['recurrenceStartDate'] as Timestamp).toDate()
          : null,
      recurrenceEndDate: data['recurrenceEndDate'] != null
          ? (data['recurrenceEndDate'] as Timestamp).toDate()
          : null,
      intervalWeeks: data['intervalWeeks'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'type': type.name,
      'startTime': startTime,
      'endTime': endTime,
      if (specificDates != null)
        'specificDates': specificDates!.map((date) => Timestamp.fromDate(date)).toList(),
      if (recurrencePattern != null) 'recurrencePattern': recurrencePattern!.name,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (recurrenceStartDate != null)
        'recurrenceStartDate': Timestamp.fromDate(recurrenceStartDate!),
      if (recurrenceEndDate != null)
        'recurrenceEndDate': Timestamp.fromDate(recurrenceEndDate!),
      if (intervalWeeks != null) 'intervalWeeks': intervalWeeks,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MarketSchedule copyWith({
    String? id,
    String? marketId,
    ScheduleType? type,
    String? startTime,
    String? endTime,
    List<DateTime>? specificDates,
    RecurrencePattern? recurrencePattern,
    List<int>? daysOfWeek,
    DateTime? recurrenceStartDate,
    DateTime? recurrenceEndDate,
    int? intervalWeeks,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MarketSchedule(
      id: id ?? this.id,
      marketId: marketId ?? this.marketId,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      specificDates: specificDates ?? this.specificDates,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      recurrenceStartDate: recurrenceStartDate ?? this.recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      intervalWeeks: intervalWeeks ?? this.intervalWeeks,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Helper methods
  String get timeRange => '$startTime - $endTime';

  bool isOperatingOn(DateTime date) {
    if (!isActive) return false;

    switch (type) {
      case ScheduleType.specificDates:
        return specificDates?.any((d) => 
          d.year == date.year && d.month == date.month && d.day == date.day
        ) ?? false;
        
      case ScheduleType.recurring:
        if (recurrenceStartDate != null && date.isBefore(recurrenceStartDate!)) {
          return false;
        }
        if (recurrenceEndDate != null && date.isAfter(recurrenceEndDate!)) {
          return false;
        }
        
        // Check if the day of week matches
        if (daysOfWeek?.contains(date.weekday) != true) {
          return false;
        }
        
        // For weekly pattern, always true if day matches
        if (recurrencePattern == RecurrencePattern.weekly) {
          return true;
        }
        
        // For biweekly and custom intervals
        if (recurrencePattern == RecurrencePattern.biweekly ||
            recurrencePattern == RecurrencePattern.custom) {
          final weeks = intervalWeeks ?? 2;
          final daysSinceStart = date.difference(recurrenceStartDate!).inDays;
          final weeksSinceStart = daysSinceStart ~/ 7;
          return weeksSinceStart % weeks == 0;
        }
        
        // For monthly pattern
        if (recurrencePattern == RecurrencePattern.monthly) {
          // Check if it's the same week of the month and same day of week
          final startWeekOfMonth = ((recurrenceStartDate!.day - 1) ~/ 7) + 1;
          final currentWeekOfMonth = ((date.day - 1) ~/ 7) + 1;
          return startWeekOfMonth == currentWeekOfMonth;
        }
        
        return false;
    }
  }

  List<DateTime> getUpcomingDates({int daysToLookAhead = 30}) {
    final today = DateTime.now();
    final upcomingDates = <DateTime>[];

    for (int i = 0; i <= daysToLookAhead; i++) {
      final checkDate = today.add(Duration(days: i));
      if (isOperatingOn(checkDate)) {
        upcomingDates.add(checkDate);
      }
    }

    return upcomingDates;
  }

  String get scheduleDescription {
    switch (type) {
      case ScheduleType.specificDates:
        final count = specificDates?.length ?? 0;
        return count == 1 
            ? '1 specific date'
            : '$count specific dates';
            
      case ScheduleType.recurring:
        final daysNames = daysOfWeek?.map(_getDayName).join(', ') ?? '';
        final patternDesc = switch (recurrencePattern) {
          RecurrencePattern.weekly => 'Weekly',
          RecurrencePattern.biweekly => 'Every 2 weeks',
          RecurrencePattern.monthly => 'Monthly',
          RecurrencePattern.custom => intervalWeeks != null 
              ? 'Every $intervalWeeks weeks' 
              : 'Custom',
          null => 'Recurring',
        };
        return '$patternDesc on $daysNames';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  @override
  List<Object?> get props => [
        id,
        marketId,
        type,
        startTime,
        endTime,
        specificDates,
        recurrencePattern,
        daysOfWeek,
        recurrenceStartDate,
        recurrenceEndDate,
        intervalWeeks,
        isActive,
        createdAt,
        updatedAt,
      ];
}