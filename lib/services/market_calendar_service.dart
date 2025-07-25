import 'package:flutter/foundation.dart';
import '../models/market.dart';
import '../models/market_schedule.dart';
import 'market_service.dart';

class MarketEvent {
  final String id;
  final String marketId;
  final String marketName;
  final DateTime startTime;
  final DateTime endTime;
  final String day;
  final String timeRange;
  final bool isRecurring;

  const MarketEvent({
    required this.id,
    required this.marketId,
    required this.marketName,
    required this.startTime,
    required this.endTime,
    required this.day,
    required this.timeRange,
    this.isRecurring = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MarketCalendarService {
  /// Convert market operating days and schedules to calendar events for a specific date range
  static Future<List<MarketEvent>> getMarketEventsForDateRange(
    List<Market> markets,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<MarketEvent> events = [];
    
    for (final market in markets) {
      // Handle new schedule system first
      if (market.scheduleIds != null && market.scheduleIds!.isNotEmpty) {
        try {
          final schedules = await MarketService.getMarketSchedules(market.id);
          
          // Generate events for each day in the range using schedules
          final currentDate = DateTime(startDate.year, startDate.month, startDate.day);
          final lastDate = DateTime(endDate.year, endDate.month, endDate.day);
          
          for (var date = currentDate; 
               date.isBefore(lastDate) || date.isAtSameMomentAs(lastDate); 
               date = date.add(const Duration(days: 1))) {
            
            for (final schedule in schedules) {
              if (schedule.isOperatingOn(date)) {
                final times = _parseTimeRange(schedule.timeRange, date);
                
                if (times != null) {
                  events.add(MarketEvent(
                    id: '${market.id}_${schedule.id}_${date.millisecondsSinceEpoch}',
                    marketId: market.id,
                    marketName: market.name,
                    startTime: times.start,
                    endTime: times.end,
                    day: getDayName(date.weekday).toLowerCase(),
                    timeRange: schedule.timeRange,
                    isRecurring: schedule.type == ScheduleType.recurring,
                  ));
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading schedules for market ${market.id}: $e');
        }
      }
      // Fall back to old operating days system
      else if (market.operatingDays.isNotEmpty) {
        // Generate events for each day in the range
        final currentDate = DateTime(startDate.year, startDate.month, startDate.day);
        final lastDate = DateTime(endDate.year, endDate.month, endDate.day);
        
        for (var date = currentDate; 
             date.isBefore(lastDate) || date.isAtSameMomentAs(lastDate); 
             date = date.add(const Duration(days: 1))) {
          
          final dayName = getDayName(date.weekday).toLowerCase();
          
          if (market.operatingDays.containsKey(dayName)) {
            final timeRange = market.operatingDays[dayName]!;
            final times = _parseTimeRange(timeRange, date);
            
            if (times != null) {
              events.add(MarketEvent(
                id: '${market.id}_${date.millisecondsSinceEpoch}',
                marketId: market.id,
                marketName: market.name,
                startTime: times.start,
                endTime: times.end,
                day: dayName,
                timeRange: timeRange,
                isRecurring: true,
              ));
            }
          }
        }
      }
    }
    
    return events;
  }

  /// Get market events for a specific date
  static Future<List<MarketEvent>> getMarketEventsForDate(
    List<Market> markets,
    DateTime date,
  ) {
    return getMarketEventsForDateRange(markets, date, date);
  }

  /// Parse time range string into start and end times
  static ({DateTime start, DateTime end})? _parseTimeRange(
    String timeRange,
    DateTime date,
  ) {
    try {
      // Handle various time formats by trying multiple regex patterns
      final patterns = [
        // "8:00 AM - 1:00 PM" or "8:00am - 1:00pm"
        RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)\s*[-–]\s*(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)', caseSensitive: false),
        // "9AM-2PM" or "9am-2pm"
        RegExp(r'(\d{1,2})(AM|PM|am|pm)\s*[-–]\s*(\d{1,2})(AM|PM|am|pm)', caseSensitive: false),
        // "8:00 AM - 1:00 PM" (with spaces)
        RegExp(r'(\d{1,2}):(\d{2})\s+(AM|PM|am|pm)\s*[-–]\s*(\d{1,2}):(\d{2})\s+(AM|PM|am|pm)', caseSensitive: false),
        // "9:00am - 2:00pm" (no spaces around AM/PM)
        RegExp(r'(\d{1,2}):(\d{2})(AM|PM|am|pm)\s*[-–]\s*(\d{1,2}):(\d{2})(AM|PM|am|pm)', caseSensitive: false),
      ];

      RegExpMatch? match;
      int patternIndex = -1;
      
      for (int i = 0; i < patterns.length; i++) {
        match = patterns[i].firstMatch(timeRange.trim());
        if (match != null) {
          patternIndex = i;
          break;
        }
      }
      
      if (match == null) {
        // Try to parse single time and assume 6-hour duration
        final singleTimePattern = RegExp(r'(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)', caseSensitive: false);
        final singleMatch = singleTimePattern.firstMatch(timeRange.trim());
        
        if (singleMatch != null) {
          debugPrint('Parsing single time "$timeRange" - assuming 6-hour duration');
          final hour = int.parse(singleMatch.group(1)!);
          final minute = int.parse(singleMatch.group(2) ?? '0');
          final amPm = singleMatch.group(3)!.toLowerCase();
          
          final start24Hour = _convertTo24Hour(hour, amPm);
          final end24Hour = (start24Hour + 6) % 24; // Add 6 hours
          
          final startTime = DateTime(date.year, date.month, date.day, start24Hour, minute);
          final endTime = DateTime(date.year, date.month, date.day, end24Hour, minute);
          
          return (start: startTime, end: endTime);
        }
        
        debugPrint('Failed to parse time range: "$timeRange" - no valid pattern found');
        debugPrint('Expected formats: "8:00 AM - 1:00 PM", "9AM-2PM", "9:00am - 2:00pm", etc.');
        return null;
      }
      
      int startHour, startMinute, endHour, endMinute;
      String startAmPm, endAmPm;
      
      switch (patternIndex) {
        case 0: // "8:00 AM - 1:00 PM"
        case 2: // "8:00 AM - 1:00 PM" (with spaces)
        case 3: // "9:00am - 2:00pm"
          startHour = int.parse(match.group(1)!);
          startMinute = int.parse(match.group(2)!);
          startAmPm = match.group(3)!.toLowerCase();
          endHour = int.parse(match.group(4)!);
          endMinute = int.parse(match.group(5)!);
          endAmPm = match.group(6)!.toLowerCase();
          break;
        case 1: // "9AM-2PM"
          startHour = int.parse(match.group(1)!);
          startMinute = 0;
          startAmPm = match.group(2)!.toLowerCase();
          endHour = int.parse(match.group(3)!);
          endMinute = 0;
          endAmPm = match.group(4)!.toLowerCase();
          break;
        default:
          debugPrint('Unknown pattern matched for: $timeRange');
          return null;
      }
      
      // Convert to 24-hour format
      final start24Hour = _convertTo24Hour(startHour, startAmPm);
      final end24Hour = _convertTo24Hour(endHour, endAmPm);
      
      final startTime = DateTime(
        date.year,
        date.month,
        date.day,
        start24Hour,
        startMinute,
      );
      
      final endTime = DateTime(
        date.year,
        date.month,
        date.day,
        end24Hour,
        endMinute,
      );
      
      return (start: startTime, end: endTime);
    } catch (e) {
      debugPrint('Error parsing time range "$timeRange": $e');
      return null;
    }
  }

  /// Convert hour to 24-hour format based on AM/PM
  static int _convertTo24Hour(int hour, String amPm) {
    if (amPm.isEmpty) return hour; // No AM/PM specified, assume already 24-hour
    
    if (amPm == 'pm' && hour != 12) {
      return hour + 12;
    } else if (amPm == 'am' && hour == 12) {
      return 0;
    }
    return hour;
  }

  /// Get day name from weekday number
  static String getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'unknown';
    }
  }

  /// Check if a market is currently operating
  static bool isMarketCurrentlyOpen(Market market) {
    final now = DateTime.now();
    final todayName = getDayName(now.weekday).toLowerCase();
    
    if (!market.operatingDays.containsKey(todayName)) {
      return false;
    }
    
    final timeRange = market.operatingDays[todayName]!;
    final times = _parseTimeRange(timeRange, now);
    
    if (times == null) return false;
    
    return now.isAfter(times.start) && now.isBefore(times.end);
  }

  /// Get next opening time for a market
  static DateTime? getNextOpeningTime(Market market) {
    final now = DateTime.now();
    
    // Check remaining days in current week
    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = getDayName(checkDate.weekday).toLowerCase();
      
      if (market.operatingDays.containsKey(dayName)) {
        final timeRange = market.operatingDays[dayName]!;
        final times = _parseTimeRange(timeRange, checkDate);
        
        if (times != null) {
          // If it's today, check if we're before opening time
          if (i == 0 && now.isBefore(times.start)) {
            return times.start;
          }
          // If it's a future day, return the opening time
          else if (i > 0) {
            return times.start;
          }
        }
      }
    }
    
    return null;
  }

  /// Get formatted time string for display
  static String formatTimeRange(String timeRange) {
    // Standardize time format for display
    return timeRange.replaceAllMapped(
      RegExp(r'(\d{1,2}):?(\d{2})?\s*(AM|PM)', caseSensitive: false),
      (match) {
        final hour = match.group(1)!;
        final minute = match.group(2) ?? '00';
        final ampm = match.group(3)!.toUpperCase();
        return '$hour:$minute $ampm';
      },
    );
  }

  /// Group events by date for calendar display
  static Map<DateTime, List<MarketEvent>> groupEventsByDate(
    List<MarketEvent> events,
  ) {
    final Map<DateTime, List<MarketEvent>> groupedEvents = {};
    
    for (final event in events) {
      final dateKey = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      
      if (!groupedEvents.containsKey(dateKey)) {
        groupedEvents[dateKey] = [];
      }
      
      groupedEvents[dateKey]!.add(event);
    }
    
    // Sort events within each day by start time
    for (final eventsList in groupedEvents.values) {
      eventsList.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    
    return groupedEvents;
  }

  /// Get events for table_calendar
  static List<MarketEvent> getEventsForDay(
    Map<DateTime, List<MarketEvent>> groupedEvents,
    DateTime day,
  ) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return groupedEvents[dateKey] ?? [];
  }
}