import 'package:flutter/material.dart';
import '../models/market_schedule.dart';
import '../widgets/date_selection_calendar.dart';

class MarketScheduleForm extends StatefulWidget {
  final Function(List<MarketSchedule>) onSchedulesChanged;
  final List<MarketSchedule> initialSchedules;

  const MarketScheduleForm({
    super.key,
    required this.onSchedulesChanged,
    this.initialSchedules = const [],
  });

  @override
  State<MarketScheduleForm> createState() => _MarketScheduleFormState();
}

class _MarketScheduleFormState extends State<MarketScheduleForm> {
  ScheduleType _scheduleType = ScheduleType.specificDates;
  
  // Time selection
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  
  // Specific dates
  List<DateTime> _selectedDates = [];
  
  // Recurring schedule
  RecurrencePattern _recurrencePattern = RecurrencePattern.weekly;
  List<int> _selectedDaysOfWeek = [];
  DateTime? _recurrenceStartDate;
  DateTime? _recurrenceEndDate;
  int _intervalWeeks = 1;
  bool _hasEndDate = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSchedules.isNotEmpty) {
      _loadFromExistingSchedules();
    }
  }

  void _loadFromExistingSchedules() {
    // For now, load the first schedule for editing
    final schedule = widget.initialSchedules.first;
    _scheduleType = schedule.type;
    
    // Parse time
    _parseTime(schedule.startTime, true);
    _parseTime(schedule.endTime, false);
    
    if (schedule.type == ScheduleType.specificDates && schedule.specificDates != null) {
      _selectedDates = List.from(schedule.specificDates!);
    } else if (schedule.type == ScheduleType.recurring) {
      _recurrencePattern = schedule.recurrencePattern ?? RecurrencePattern.weekly;
      _selectedDaysOfWeek = List.from(schedule.daysOfWeek ?? []);
      _recurrenceStartDate = schedule.recurrenceStartDate;
      _recurrenceEndDate = schedule.recurrenceEndDate;
      _intervalWeeks = schedule.intervalWeeks ?? 1;
      _hasEndDate = schedule.recurrenceEndDate != null;
    }
  }

  void _parseTime(String timeString, bool isStart) {
    // Parse time strings like "9:00 AM" or "2:00 PM"
    final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
    final match = regex.firstMatch(timeString);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      final time = TimeOfDay(hour: hour, minute: minute);
      if (isStart) {
        _startTime = time;
      } else {
        _endTime = time;
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _generateSchedules() {
    final schedules = <MarketSchedule>[];
    final startTimeStr = _formatTimeOfDay(_startTime);
    final endTimeStr = _formatTimeOfDay(_endTime);

    if (_scheduleType == ScheduleType.specificDates && _selectedDates.isNotEmpty) {
      schedules.add(MarketSchedule.specificDates(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        marketId: '', // Will be set when market is created
        startTime: startTimeStr,
        endTime: endTimeStr,
        dates: _selectedDates,
      ));
    } else if (_scheduleType == ScheduleType.recurring && _selectedDaysOfWeek.isNotEmpty) {
      schedules.add(MarketSchedule.recurring(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        marketId: '', // Will be set when market is created
        startTime: startTimeStr,
        endTime: endTimeStr,
        pattern: _recurrencePattern,
        daysOfWeek: _selectedDaysOfWeek,
        startDate: _recurrenceStartDate ?? DateTime.now(),
        endDate: _hasEndDate ? _recurrenceEndDate : null,
        intervalWeeks: _recurrencePattern == RecurrencePattern.custom ? _intervalWeeks : null,
      ));
    }

    widget.onSchedulesChanged(schedules);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Market Schedule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Schedule type toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _scheduleType == ScheduleType.recurring 
                        ? Icons.repeat 
                        : Icons.event,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recurring Schedule',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _scheduleType == ScheduleType.recurring
                              ? 'Weekly, monthly, etc.'
                              : 'Select specific dates',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _scheduleType == ScheduleType.recurring,
                    onChanged: (value) {
                      setState(() {
                        _scheduleType = value 
                            ? ScheduleType.recurring 
                            : ScheduleType.specificDates;
                      });
                      _generateSchedules();
                    },
                    activeColor: Colors.blue[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Time selection
            Text(
              'Operating Hours',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Start Time', style: TextStyle(color: Colors.black)),
                    subtitle: Text(_formatTimeOfDay(_startTime), style: const TextStyle(color: Colors.black)),
                    leading: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                        });
                        _generateSchedules();
                      }
                    },
                    dense: true,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('End Time', style: TextStyle(color: Colors.black)),
                    subtitle: Text(_formatTimeOfDay(_endTime), style: const TextStyle(color: Colors.black)),
                    leading: const Icon(Icons.access_time_filled),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() {
                          _endTime = time;
                        });
                        _generateSchedules();
                      }
                    },
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Schedule-specific configuration
            if (_scheduleType == ScheduleType.specificDates) ...[
              DateSelectionCalendar(
                title: 'Select Market Dates',
                initialSelectedDates: _selectedDates,
                onDatesChanged: (dates) {
                  setState(() {
                    _selectedDates = dates;
                  });
                  _generateSchedules();
                },
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365)),
              ),
            ] else if (_scheduleType == ScheduleType.recurring) ...[
              _buildRecurringScheduleForm(),
            ],

            const SizedBox(height: 16),
            _buildSchedulePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringScheduleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recurrence Pattern',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrencePattern>(
          value: _recurrencePattern,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Pattern',
            labelStyle: TextStyle(color: Colors.black),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: RecurrencePattern.weekly, child: Text('Weekly', style: TextStyle(color: Colors.black))),
            DropdownMenuItem(value: RecurrencePattern.biweekly, child: Text('Every 2 weeks', style: TextStyle(color: Colors.black))),
            DropdownMenuItem(value: RecurrencePattern.monthly, child: Text('Monthly', style: TextStyle(color: Colors.black))),
            DropdownMenuItem(value: RecurrencePattern.custom, child: Text('Custom interval', style: TextStyle(color: Colors.black))),
          ],
          onChanged: (value) {
            setState(() {
              _recurrencePattern = value!;
            });
            _generateSchedules();
          },
        ),
        const SizedBox(height: 16),

        if (_recurrencePattern == RecurrencePattern.custom) ...[
          TextFormField(
            initialValue: _intervalWeeks.toString(),
            style: const TextStyle(color: Colors.black),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Repeat every X weeks',
              labelStyle: TextStyle(color: Colors.black),
              suffixText: 'weeks',
              suffixStyle: TextStyle(color: Colors.black),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              _intervalWeeks = int.tryParse(value) ?? 1;
              _generateSchedules();
            },
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Days of the Week',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (int i = 1; i <= 7; i++)
              FilterChip(
                label: Text(_getDayName(i), style: TextStyle(color: _selectedDaysOfWeek.contains(i) ? Colors.white : Colors.black)),
                selected: _selectedDaysOfWeek.contains(i),
                backgroundColor: Colors.white,
                selectedColor: Colors.blue,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDaysOfWeek.add(i);
                    } else {
                      _selectedDaysOfWeek.remove(i);
                    }
                    _selectedDaysOfWeek.sort();
                  });
                  _generateSchedules();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Start Date',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            title: Text(
              _recurrenceStartDate != null 
                  ? '${_recurrenceStartDate!.month}/${_recurrenceStartDate!.day}/${_recurrenceStartDate!.year}'
                  : 'Select start date',
              style: const TextStyle(color: Colors.black),
            ),
            leading: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _recurrenceStartDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _recurrenceStartDate = date;
                });
                _generateSchedules();
              }
            },
          ),
        ),
        const SizedBox(height: 16),

        CheckboxListTile(
          title: const Text('Set end date', style: TextStyle(color: Colors.black)),
          subtitle: const Text('Otherwise, market will continue indefinitely', style: TextStyle(color: Colors.grey)),
          value: _hasEndDate,
          onChanged: (value) {
            setState(() {
              _hasEndDate = value!;
              if (!_hasEndDate) {
                _recurrenceEndDate = null;
              }
            });
            _generateSchedules();
          },
        ),

        if (_hasEndDate) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListTile(
              title: Text(
                _recurrenceEndDate != null 
                    ? '${_recurrenceEndDate!.month}/${_recurrenceEndDate!.day}/${_recurrenceEndDate!.year}'
                    : 'Select end date',
                style: const TextStyle(color: Colors.black),
              ),
              leading: const Icon(Icons.event),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _recurrenceEndDate ?? (_recurrenceStartDate?.add(const Duration(days: 365)) ?? DateTime.now().add(const Duration(days: 365))),
                  firstDate: _recurrenceStartDate ?? DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (date != null) {
                  setState(() {
                    _recurrenceEndDate = date;
                  });
                  _generateSchedules();
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSchedulePreview() {
    final isValid = (_scheduleType == ScheduleType.specificDates && _selectedDates.isNotEmpty) ||
                   (_scheduleType == ScheduleType.recurring && _selectedDaysOfWeek.isNotEmpty && _recurrenceStartDate != null);

    if (!isValid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Please complete the schedule configuration',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                'Schedule Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hours: ${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 4),
          if (_scheduleType == ScheduleType.specificDates) ...[
            Text(
              '${_selectedDates.length} specific dates selected',
              style: TextStyle(color: Colors.green[700]),
            ),
          ] else if (_scheduleType == ScheduleType.recurring) ...[
            Text(
              _getRecurrenceDescription(),
              style: TextStyle(color: Colors.green[700]),
            ),
          ],
        ],
      ),
    );
  }

  String _getRecurrenceDescription() {
    final daysNames = _selectedDaysOfWeek.map(_getDayName).join(', ');
    final patternDesc = switch (_recurrencePattern) {
      RecurrencePattern.weekly => 'Weekly',
      RecurrencePattern.biweekly => 'Every 2 weeks',
      RecurrencePattern.monthly => 'Monthly',
      RecurrencePattern.custom => 'Every $_intervalWeeks weeks',
    };
    
    String desc = '$patternDesc on $daysNames';
    if (_recurrenceStartDate != null) {
      desc += '\nStarting ${_recurrenceStartDate!.month}/${_recurrenceStartDate!.day}/${_recurrenceStartDate!.year}';
    }
    if (_hasEndDate && _recurrenceEndDate != null) {
      desc += '\nEnding ${_recurrenceEndDate!.month}/${_recurrenceEndDate!.day}/${_recurrenceEndDate!.year}';
    }
    return desc;
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
}