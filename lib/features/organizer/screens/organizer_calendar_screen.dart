import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/market/services/market_calendar_service.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:table_calendar/table_calendar.dart';

class OrganizerCalendarScreen extends StatefulWidget {
  const OrganizerCalendarScreen({super.key});

  @override
  State<OrganizerCalendarScreen> createState() => _OrganizerCalendarScreenState();
}

class _OrganizerCalendarScreenState extends State<OrganizerCalendarScreen> {
  late final ValueNotifier<List<MarketEvent>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<Market> _markets = [];
  Map<DateTime, List<MarketEvent>> _events = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadMarkets();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) {
        throw Exception('User not authenticated');
      }

      // Get markets for the current organizer
      final userProfile = authState.userProfile;
      if (userProfile == null || !userProfile.isMarketOrganizer) {
        throw Exception('User is not a market organizer');
      }
      
      final managedMarketIds = userProfile.managedMarketIds;
      final markets = <Market>[];
      for (final marketId in managedMarketIds) {
        final market = await MarketService.getMarket(marketId);
        if (market != null) {
          markets.add(market);
        }
      }
      
      // Generate calendar events for the next 3 months
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now().add(const Duration(days: 90));
      
      final events = await MarketCalendarService.getMarketEventsForDateRange(
        markets,
        startDate,
        endDate,
      );

      final groupedEvents = MarketCalendarService.groupEventsByDate(events);

      setState(() {
        _markets = markets;
        _events = groupedEvents;
        _isLoading = false;
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<MarketEvent> _getEventsForDay(DateTime day) {
    return MarketCalendarService.getEventsForDay(_events, day);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Calendar'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarkets,
            tooltip: 'Refresh calendar',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(
              child: LoadingWidget(message: 'Loading market schedules...'),
            )
          else if (_error != null)
            Expanded(
              child: ErrorDisplayWidget.network(
                onRetry: _loadMarkets,
              ),
            )
          else if (_markets.isEmpty)
            Expanded(
              child: _buildEmptyState(),
            )
          else ...[
            // Market summary cards
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Markets',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _markets.length,
                      itemBuilder: (context, index) {
                        final market = _markets[index];
                        final isOpen = MarketCalendarService.isMarketCurrentlyOpen(market);
                        return _buildMarketSummaryCard(market, isOpen);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Calendar
            TableCalendar<MarketEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
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
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                markerDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                formatButtonTextStyle: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Events list
            Expanded(
              child: ValueListenableBuilder<List<MarketEvent>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: value.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildDayHeader(value);
                      }
                      
                      final event = value[index - 1];
                      return _buildEventCard(event);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Markets Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first market to see operating schedules here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketSummaryCard(Market market, bool isOpen) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      market.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOpen ? 'OPEN' : 'CLOSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${market.operatingDays.length} operating days',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              if (market.operatingDays.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  _formatOperatingDaysDisplay(market.operatingDays),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeader(List<MarketEvent> events) {
    final selectedDate = _selectedDay!;
    final dayName = MarketCalendarService.getDayName(selectedDate.weekday);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayName.toUpperCase()}, ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            events.isEmpty 
              ? 'No markets operating today'
              : '${events.length} market${events.length == 1 ? '' : 's'} operating',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(MarketEvent event) {
    final isToday = isSameDay(event.startTime, DateTime.now());
    final isCurrentlyOpen = isToday && MarketCalendarService.isMarketCurrentlyOpen(
      _markets.firstWhere((m) => m.id == event.marketId)
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrentlyOpen 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.storefront,
                color: isCurrentlyOpen ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.marketName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isCurrentlyOpen) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OPEN NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        MarketCalendarService.formatTimeRange(event.timeRange),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatOperatingDaysDisplay(Map<String, String> operatingDays) {
    final formatted = <String>[];
    
    for (final key in operatingDays.keys) {
      // Check if this is a specific date format (contains underscores and numbers)
      if (key.contains('_') && RegExp(r'_\d{4}_\d{1,2}_\d{1,2}$').hasMatch(key)) {
        // Parse specific date format: "sunday_2025_7_27"
        final parts = key.split('_');
        if (parts.length == 4) {
          final dayName = parts[0];
          final year = int.tryParse(parts[1]);
          final month = int.tryParse(parts[2]);
          final day = int.tryParse(parts[3]);
          
          if (year != null && month != null && day != null) {
            final monthName = _getMonthName(month);
            formatted.add('$monthName $day, $year');
          } else {
            formatted.add(dayName.toUpperCase());
          }
        } else {
          formatted.add(key.toUpperCase());
        }
      } else {
        // Regular recurring day format
        formatted.add(key.toUpperCase());
      }
    }
    
    return formatted.join(', ');
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return 'Month';
    }
  }
}