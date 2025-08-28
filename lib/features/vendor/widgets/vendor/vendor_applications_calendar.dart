import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../../models/vendor_application.dart';

class VendorApplicationsCalendar extends StatefulWidget {
  final List<VendorApplication> applications;
  final Function(VendorApplication)? onApplicationTap;
  
  const VendorApplicationsCalendar({
    super.key,
    required this.applications,
    this.onApplicationTap,
  });

  @override
  State<VendorApplicationsCalendar> createState() => _VendorApplicationsCalendarState();
}

class _VendorApplicationsCalendarState extends State<VendorApplicationsCalendar> {
  late final ValueNotifier<List<VendorApplication>> _selectedApplications;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedApplications = ValueNotifier(_getApplicationsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedApplications.dispose();
    super.dispose();
  }

  List<VendorApplication> _getApplicationsForDay(DateTime day) {
    // For the new 1:1 market-event system, we need to match applications by market's event date
    // Since we don't have market info here, we'll return all applications for now
    // TODO: Update this to fetch market data and compare event dates
    return widget.applications;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<VendorApplication>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: _getApplicationsForDay,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(color: Colors.red),
            holidayTextStyle: TextStyle(color: Colors.red),
          ),
          onDaySelected: _onDaySelected,
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, applications) {
              if (applications.isNotEmpty) {
                return Container(
                  decoration: BoxDecoration(
                    color: HiPopColors.warningAmber,
                    shape: BoxShape.circle,
                  ),
                  width: 16,
                  height: 16,
                  child: Center(
                    child: Text(
                      '${applications.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ValueListenableBuilder<List<VendorApplication>>(
            valueListenable: _selectedApplications,
            builder: (context, value, _) {
              return ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final application = value[index];
                  return _buildApplicationCard(application);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedApplications.value = _getApplicationsForDay(selectedDay);
    }
  }

  Widget _buildApplicationCard(VendorApplication application) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(application.status),
          child: Text(
            application.vendorBusinessName.isNotEmpty 
                ? application.vendorBusinessName[0].toUpperCase()
                : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          application.vendorBusinessName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${application.status.name.toUpperCase()}'),
            if (application.specialMessage?.isNotEmpty == true)
              Text(
                application.specialMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: _buildStatusChip(application.status),
        onTap: () {
          if (widget.onApplicationTap != null) {
            widget.onApplicationTap!(application);
          }
        },
      ),
    );
  }

  Widget _buildStatusChip(ApplicationStatus status) {
    return Chip(
      label: Text(
        status.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _getStatusColor(status),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return HiPopColors.warningAmber;
      case ApplicationStatus.approved:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.waitlisted:
        return Colors.blue;
    }
  }
}