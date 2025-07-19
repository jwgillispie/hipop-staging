import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/favorites/favorites_bloc.dart';
import '../models/market.dart';
import '../services/market_service.dart';
import '../services/market_calendar_service.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

class ShopperCalendarScreen extends StatefulWidget {
  const ShopperCalendarScreen({super.key});

  @override
  State<ShopperCalendarScreen> createState() => _ShopperCalendarScreenState();
}

class _ShopperCalendarScreenState extends State<ShopperCalendarScreen>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<List<MarketEvent>> _selectedEvents;
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<Market> _favoriteMarkets = [];
  List<Market> _nearbyMarkets = [];
  Map<DateTime, List<MarketEvent>> _favoriteEvents = {};
  Map<DateTime, List<MarketEvent>> _nearbyEvents = {};
  bool _isLoading = true;
  String? _error;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMarkets();
    
    // Favorites are now automatically loaded when auth state changes in main.dart
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    }
  }

  Future<void> _loadMarkets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user from auth bloc
      final authState = context.read<AuthBloc>().state;
      
      // Load favorite markets from BLoC state instead of direct service call
      List<Market> favoriteMarkets = [];
      if (authState is Authenticated) {
        // Ensure favorites are loaded in BLoC
        context.read<FavoritesBloc>().add(LoadFavorites(userId: authState.user.uid));
        
        // Get favorites from BLoC state
        final favoritesState = context.read<FavoritesBloc>().state;
        for (final marketId in favoritesState.favoriteMarketIds) {
          try {
            final market = await MarketService.getMarket(marketId);
            if (market != null) {
              favoriteMarkets.add(market);
            }
          } catch (e) {
            // Continue loading other markets if one fails
            debugPrint('Error loading favorite market $marketId: $e');
          }
        }
      }

      // Load nearby markets (using Atlanta as default if no user city)
      String userCity = 'Atlanta'; // Default
      
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated && authState.userProfile != null) {
          // Try to get user's city from profile or use a default
          userCity = 'Atlanta'; // You could add city to user profile later
        }
      }
      
      final nearbyMarkets = await MarketService.getMarketsByCity(userCity);
      
      // Generate calendar events for the next 3 months
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now().add(const Duration(days: 90));
      
      final favoriteEvents = MarketCalendarService.getMarketEventsForDateRange(
        favoriteMarkets,
        startDate,
        endDate,
      );

      final nearbyEvents = MarketCalendarService.getMarketEventsForDateRange(
        nearbyMarkets,
        startDate,
        endDate,
      );

      final groupedFavoriteEvents = MarketCalendarService.groupEventsByDate(favoriteEvents);
      final groupedNearbyEvents = MarketCalendarService.groupEventsByDate(nearbyEvents);

      setState(() {
        _favoriteMarkets = favoriteMarkets;
        _nearbyMarkets = nearbyMarkets;
        _favoriteEvents = groupedFavoriteEvents;
        _nearbyEvents = groupedNearbyEvents;
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
    final events = _currentTabIndex == 0 
        ? MarketCalendarService.getEventsForDay(_favoriteEvents, day)
        : MarketCalendarService.getEventsForDay(_nearbyEvents, day);
    return events;
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
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarkets,
            tooltip: 'Refresh calendar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Favorites',
            ),
            Tab(
              icon: Icon(Icons.location_on),
              text: 'Nearby',
            ),
          ],
        ),
      ),
      body: BlocListener<FavoritesBloc, FavoritesState>(
        listener: (context, state) {
          // Reload markets when favorites change
          if (state.favoriteMarketIds.isNotEmpty || state.favoriteMarketIds.isEmpty) {
            _loadMarkets();
          }
        },
        child: Column(
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
            else ...[
            // Market summary
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.withValues(alpha: 0.1),
              child: _buildMarketSummary(),
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
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.green,
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
                  color: Colors.orange,
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
      ),
    );
  }

  Widget _buildMarketSummary() {
    final currentMarkets = _currentTabIndex == 0 ? _favoriteMarkets : _nearbyMarkets;
    final openMarkets = currentMarkets.where((market) => 
        MarketCalendarService.isMarketCurrentlyOpen(market)).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentTabIndex == 0 ? 'Your Favorite Markets' : 'Nearby Markets',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSummaryCard(
              '${currentMarkets.length}',
              'Total Markets',
              Icons.storefront,
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildSummaryCard(
              '$openMarkets',
              'Open Now',
              Icons.schedule,
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final market = (_currentTabIndex == 0 ? _favoriteMarkets : _nearbyMarkets)
        .firstWhere((m) => m.id == event.marketId);
    final isCurrentlyOpen = isToday && MarketCalendarService.isMarketCurrentlyOpen(market);
    
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
                      Expanded(
                        child: Text(
                          event.marketName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isCurrentlyOpen) ...[
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
                      if (_currentTabIndex == 0) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 16,
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
                  if (market.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            market.address,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}