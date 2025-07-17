import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../models/analytics.dart';
import '../services/analytics_service.dart';
import '../widgets/vendor_registrations_chart.dart';

class OrganizerAnalyticsScreen extends StatefulWidget {
  const OrganizerAnalyticsScreen({super.key});

  @override
  State<OrganizerAnalyticsScreen> createState() => _OrganizerAnalyticsScreenState();
}

class _OrganizerAnalyticsScreenState extends State<OrganizerAnalyticsScreen> {
  AnalyticsTimeRange _selectedTimeRange = AnalyticsTimeRange.month;
  bool _isLoading = true;
  AnalyticsSummary? _summary;
  Map<String, dynamic>? _realTimeMetrics;
  String? _error;
  String? _currentMarketId;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      
      if (authState is! Authenticated || authState.userProfile?.isMarketOrganizer != true) {
        setState(() {
          _isLoading = false;
          _error = 'Not authenticated as market organizer';
        });
        return;
      }
      
      final managedMarketIds = authState.userProfile!.managedMarketIds;
      
      if (managedMarketIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No managed markets found';
        });
        return;
      }
      
      // Use the first managed market for now, or could aggregate across all
      final marketId = managedMarketIds.first;
      
      final summary = await AnalyticsService.getAnalyticsSummary(
        marketId,
        _selectedTimeRange,
      );
      final realTimeMetrics = await AnalyticsService.getRealTimeMetrics(marketId);

      setState(() {
        _currentMarketId = marketId;
        _summary = summary;
        _realTimeMetrics = realTimeMetrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Analytics Dashboard'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAnalytics,
              ),
              PopupMenuButton<AnalyticsTimeRange>(
                onSelected: (timeRange) {
                  setState(() {
                    _selectedTimeRange = timeRange;
                  });
                  _loadAnalytics();
                },
                itemBuilder: (context) => AnalyticsTimeRange.values
                    .map((range) => PopupMenuItem(
                          value: range,
                          child: Text(range.displayName),
                        ))
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedTimeRange.displayName),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading analytics...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading analytics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_summary == null || _realTimeMetrics == null) {
      return const Center(
        child: Text('No analytics data available'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time range header
            _buildTimeRangeHeader(),
            const SizedBox(height: 24),

            // Key metrics overview
            _buildKeyMetrics(),
            const SizedBox(height: 24),

            // Vendor analytics
            _buildVendorAnalytics(),
            const SizedBox(height: 24),

            // Event analytics
            _buildEventAnalytics(),
            const SizedBox(height: 24),

            // Recipe analytics
            _buildRecipeAnalytics(),
            const SizedBox(height: 24),

            // Favorites analytics
            _buildFavoritesAnalytics(),
            const SizedBox(height: 24),

            // Charts and trends
            _buildChartsSection(),
            const SizedBox(height: 24),

            // Performance insights
            _buildPerformanceInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Data for the last ${_selectedTimeRange.displayName.toLowerCase()}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (_summary!.growthRate != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _summary!.growthRate > 0 ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _summary!.growthRate > 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: _summary!.growthRate > 0 ? Colors.green[800] : Colors.red[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_summary!.growthRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _summary!.growthRate > 0 ? Colors.green[800] : Colors.red[800],
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

  Widget _buildKeyMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Vendors',
              _summary!.totalVendors.toString(),
              Icons.store,
              Colors.blue,
            ),
            _buildMetricCard(
              'Total Events',
              _summary!.totalEvents.toString(),
              Icons.event,
              Colors.purple,
            ),
            _buildMetricCard(
              'Total Recipes',
              _summary!.totalRecipes.toString(),
              Icons.restaurant_menu,
              Colors.orange,
            ),
            _buildMetricCard(
              'Total Favorites',
              _summary!.totalFavorites.toString(),
              Icons.favorite,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorAnalytics() {
    final vendorMetrics = (_realTimeMetrics!['vendors'] as Map<String, dynamic>?) ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vendor Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Active',
                        vendorMetrics['active']?.toString() ?? '0',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Pending',
                        vendorMetrics['pending']?.toString() ?? '0',
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Rejected',
                        vendorMetrics['rejected']?.toString() ?? '0',
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_summary!.vendorApplicationsByStatus.isNotEmpty)
                  _buildStatusBreakdown(
                    'Vendor Applications',
                    _summary!.vendorApplicationsByStatus,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventAnalytics() {
    final eventMetrics = (_realTimeMetrics!['events'] as Map<String, dynamic>?) ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Upcoming',
                        eventMetrics['upcoming']?.toString() ?? '0',
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Published',
                        eventMetrics['published']?.toString() ?? '0',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Avg Occupancy',
                        '${(eventMetrics['averageOccupancy'] ?? 0.0).toStringAsFixed(0)}%',
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_summary!.eventsByStatus.isNotEmpty)
                  _buildStatusBreakdown(
                    'Event Status',
                    _summary!.eventsByStatus,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeAnalytics() {
    final recipeMetrics = (_realTimeMetrics!['recipes'] as Map<String, dynamic>?) ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipe Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Public',
                        recipeMetrics['public']?.toString() ?? '0',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Featured',
                        recipeMetrics['featured']?.toString() ?? '0',
                        Colors.amber,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Total Likes',
                        _formatNumber(recipeMetrics['likes'] ?? 0),
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Saves',
                        _formatNumber(recipeMetrics['saves'] ?? 0),
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Shares',
                        _formatNumber(recipeMetrics['shares'] ?? 0),
                        Colors.purple,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(String title, Map<String, int> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...data.entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(entry.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                entry.value.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trends & Charts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        VendorRegistrationsChart(
          marketId: _currentMarketId ?? '',
          monthsBack: _selectedTimeRange == AnalyticsTimeRange.week ? 3 :
                      _selectedTimeRange == AnalyticsTimeRange.month ? 6 :
                      _selectedTimeRange == AnalyticsTimeRange.quarter ? 12 : 12,
        ),
      ],
    );
  }

  Widget _buildPerformanceInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Insights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightItem(
                  Icons.trending_up,
                  'Growth Rate',
                  '${_summary!.growthRate.toStringAsFixed(1)}% increase in vendors over ${_selectedTimeRange.displayName.toLowerCase()}',
                  _summary!.growthRate > 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _buildInsightItem(
                  Icons.restaurant_menu,
                  'Recipe Engagement',
                  'Average of ${(_summary!.totalRecipes > 0 ? (_realTimeMetrics!['recipes']['likes'] ?? 0) / _summary!.totalRecipes : 0).toStringAsFixed(1)} likes per recipe',
                  Colors.purple,
                ),
                const Divider(),
                _buildInsightItem(
                  Icons.event,
                  'Event Performance',
                  'Average occupancy rate of ${(((_realTimeMetrics!['events']['averageOccupancy'] ?? 0.0) as double)).toStringAsFixed(0)}%',
                  Colors.blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'published':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildFavoritesAnalytics() {
    final favoritesMetrics = (_realTimeMetrics!['favorites'] as Map<String, dynamic>?) ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorites Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Market Favorites',
                        favoritesMetrics['totalMarketFavorites']?.toString() ?? '0',
                        Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Vendor Favorites',
                        favoritesMetrics['totalVendorFavorites']?.toString() ?? '0',
                        Colors.pink,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Total Favorites',
                        ((favoritesMetrics['totalMarketFavorites'] ?? 0) + (favoritesMetrics['totalVendorFavorites'] ?? 0)).toString(),
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'New Market Favorites Today',
                        favoritesMetrics['newMarketFavoritesToday']?.toString() ?? '0',
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'New Vendor Favorites Today',
                        favoritesMetrics['newVendorFavoritesToday']?.toString() ?? '0',
                        Colors.cyan,
                      ),
                    ),
                    const Expanded(child: SizedBox()), // Empty space for alignment
                  ],
                ),
                const SizedBox(height: 16),
                if (_summary!.favoritesByType.isNotEmpty)
                  _buildStatusBreakdown(
                    'Favorites by Type',
                    _summary!.favoritesByType,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}