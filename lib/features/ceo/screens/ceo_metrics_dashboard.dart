import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import '../services/ceo_metrics_service.dart';

class CEOMetricsDashboard extends StatefulWidget {
  const CEOMetricsDashboard({super.key});

  @override
  State<CEOMetricsDashboard> createState() => _CEOMetricsDashboardState();
}

class _CEOMetricsDashboardState extends State<CEOMetricsDashboard> 
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _metrics = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  late TabController _tabController;
  
  // Real-time activity stream
  StreamSubscription? _activitySubscription;
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadMetrics();
    _startActivityStream();
    
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadMetrics();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _activitySubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    if (!mounted) return;
    
    final metrics = await CEOMetricsService.getPlatformMetrics();
    final trends = await CEOMetricsService.getGrowthTrends();
    
    if (mounted) {
      setState(() {
        _metrics = {...metrics, 'trends': trends};
        _isLoading = false;
      });
    }
  }

  void _startActivityStream() {
    _activitySubscription = CEOMetricsService.getActivityStream().listen((activity) {
      if (mounted) {
        setState(() {
          _recentActivity = activity;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check CEO access
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('CEO Metrics')),
            body: const Center(child: Text('Please sign in to access this dashboard')),
          );
        }

        final userProfile = state.userProfile;
        if (userProfile == null || userProfile.email != 'jordangillispie@outlook.com') {
          return Scaffold(
            appBar: AppBar(title: const Text('CEO Metrics')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 64, color: HiPopColors.darkTextTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This dashboard is only accessible to the CEO.',
                    style: TextStyle(color: HiPopColors.darkTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CEO Metrics Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _metrics['lastUpdated'] != null 
                  ? 'Last updated: ${_formatTime(DateTime.parse(_metrics['lastUpdated']))}'
                  : 'Loading...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        backgroundColor: HiPopColors.primaryDeepSage,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Engagement'),
            Tab(text: 'Revenue'),
            Tab(text: 'Activity'),
            Tab(text: 'Errors'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildEngagementTab(),
                _buildRevenueTab(),
                _buildActivityTab(),
                _buildErrorsTab(),
              ],
            ),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    final users = _metrics['users'] ?? {};
    final vendors = _metrics['vendors'] ?? {};
    final markets = _metrics['markets'] ?? {};
    final engagement = _metrics['engagement'] ?? {};
    final revenue = _metrics['revenue'] ?? {};
    
    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  'Total Users',
                  '${users['total'] ?? 0}',
                  Icons.people,
                  HiPopColors.primaryDeepSage,
                  subtitle: '+${users['newUsers']?['today'] ?? 0} today',
                ),
                _buildMetricCard(
                  'Active Vendors',
                  '${vendors['active'] ?? 0}',
                  Icons.store,
                  HiPopColors.secondarySoftSage,
                  subtitle: '${vendors['total'] ?? 0} total',
                ),
                _buildMetricCard(
                  'Total Favorites',
                  '${engagement['favorites']?['total'] ?? 0}',
                  Icons.favorite,
                  HiPopColors.accentMauve,
                  subtitle: '${engagement['shares'] ?? 0} shares',
                ),
                _buildMetricCard(
                  'MRR',
                  '\$${(revenue['mrr'] ?? 0).toStringAsFixed(2)}',
                  Icons.attach_money,
                  HiPopColors.successGreen,
                  subtitle: '${revenue['activeSubscriptions'] ?? 0} subs',
                ),
                _buildMetricCard(
                  'Active Markets',
                  '${markets['active'] ?? 0}',
                  Icons.location_on,
                  HiPopColors.infoBlueGray,
                  subtitle: '${markets['upcoming'] ?? 0} upcoming',
                ),
                _buildMetricCard(
                  'Total Views',
                  '${_formatNumber(engagement['views']?['total'] ?? 0)}',
                  Icons.visibility,
                  HiPopColors.warningAmber,
                  subtitle: '${engagement['sessions'] ?? 0} sessions',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // User Type Breakdown
            _buildSectionTitle('User Distribution'),
            const SizedBox(height: 12),
            _buildUserTypeChart(users['byType'] ?? {}),
            
            const SizedBox(height: 24),
            
            // Subscription Breakdown
            _buildSectionTitle('Active Subscriptions'),
            const SizedBox(height: 12),
            _buildSubscriptionBreakdown(users['subscriptions'] ?? {}),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final users = _metrics['users'] ?? {};
    final newUsers = users['newUsers'] ?? {};
    final activeUsers = users['activeUsers'] ?? {};
    final subscriptions = users['subscriptions'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Growth Chart
          _buildSectionTitle('User Growth (30 Days)'),
          const SizedBox(height: 12),
          _buildGrowthChart(),
          
          const SizedBox(height: 24),
          
          // New Users Stats
          _buildSectionTitle('New Users'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today',
                  '${newUsers['today'] ?? 0}',
                  HiPopColors.primaryDeepSage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'This Week',
                  '${newUsers['week'] ?? 0}',
                  HiPopColors.secondarySoftSage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'This Month',
                  '${newUsers['month'] ?? 0}',
                  HiPopColors.accentMauve,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Active Users Stats
          _buildSectionTitle('Active Users'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today',
                  '${activeUsers['today'] ?? 0}',
                  HiPopColors.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'This Week',
                  '${activeUsers['week'] ?? 0}',
                  HiPopColors.infoBlueGray,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'This Month',
                  '${activeUsers['month'] ?? 0}',
                  HiPopColors.warningAmber,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // User Details List
          _buildSectionTitle('User Breakdown'),
          const SizedBox(height: 12),
          _buildDetailsList([
            {'label': 'Total Users', 'value': '${users['total'] ?? 0}'},
            {'label': 'Verified Users', 'value': '${users['verified'] ?? 0}'},
            {'label': 'Premium Users', 'value': '${users['premium'] ?? 0}'},
            {'label': 'Vendors', 'value': '${users['byType']?['vendors'] ?? 0}'},
            {'label': 'Organizers', 'value': '${users['byType']?['organizers'] ?? 0}'},
            {'label': 'Shoppers', 'value': '${users['byType']?['shoppers'] ?? 0}'},
          ]),
        ],
      ),
    );
  }

  Widget _buildEngagementTab() {
    final engagement = _metrics['engagement'] ?? {};
    final favorites = engagement['favorites'] ?? {};
    final views = engagement['views'] ?? {};
    final content = _metrics['content'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Engagement Overview
          _buildSectionTitle('Engagement Overview'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard(
                'Total Favorites',
                '${favorites['total'] ?? 0}',
                Icons.favorite,
                HiPopColors.accentMauve,
              ),
              _buildMetricCard(
                'Total Shares',
                '${engagement['shares'] ?? 0}',
                Icons.share,
                HiPopColors.primaryDeepSage,
              ),
              _buildMetricCard(
                'Total Views',
                _formatNumber(views['total'] ?? 0),
                Icons.visibility,
                HiPopColors.infoBlueGray,
              ),
              _buildMetricCard(
                'Sessions',
                '${engagement['sessions'] ?? 0}',
                Icons.access_time,
                HiPopColors.warningAmber,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Favorites Breakdown
          _buildSectionTitle('Favorites by Type'),
          const SizedBox(height: 12),
          _buildDetailsList([
            {'label': 'Vendor Favorites', 'value': '${favorites['vendors'] ?? 0}'},
            {'label': 'Market Favorites', 'value': '${favorites['markets'] ?? 0}'},
            {'label': 'Event Favorites', 'value': '${favorites['events'] ?? 0}'},
          ]),
          
          const SizedBox(height: 24),
          
          // Views Breakdown
          _buildSectionTitle('Views by Type'),
          const SizedBox(height: 12),
          _buildDetailsList([
            {'label': 'Profile Views', 'value': _formatNumber(views['profiles'] ?? 0)},
            {'label': 'Market Views', 'value': _formatNumber(views['markets'] ?? 0)},
            {'label': 'Total Interactions', 'value': '${engagement['interactions'] ?? 0}'},
          ]),
          
          const SizedBox(height: 24),
          
          // Content Metrics
          _buildSectionTitle('Content Metrics'),
          const SizedBox(height: 12),
          _buildDetailsList([
            {'label': 'Active Vendor Posts', 'value': '${content['vendorPosts']?['active'] ?? 0}'},
            {'label': 'Total Vendor Posts', 'value': '${content['vendorPosts']?['total'] ?? 0}'},
            {'label': 'Products Listed', 'value': '${content['products'] ?? 0}'},
            {'label': 'Market Items', 'value': '${content['marketItems'] ?? 0}'},
          ]),
        ],
      ),
    );
  }

  Widget _buildRevenueTab() {
    final revenue = _metrics['revenue'] ?? {};
    final trends = _metrics['trends'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Overview
          _buildSectionTitle('Revenue Metrics'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard(
                'MRR',
                '\$${(revenue['mrr'] ?? 0).toStringAsFixed(2)}',
                Icons.trending_up,
                HiPopColors.successGreen,
              ),
              _buildMetricCard(
                'ARR',
                '\$${(revenue['arr'] ?? 0).toStringAsFixed(2)}',
                Icons.show_chart,
                HiPopColors.primaryDeepSage,
              ),
              _buildMetricCard(
                'Today',
                '\$${(revenue['todayRevenue'] ?? 0).toStringAsFixed(2)}',
                Icons.today,
                HiPopColors.infoBlueGray,
              ),
              _buildMetricCard(
                'This Week',
                '\$${(revenue['weekRevenue'] ?? 0).toStringAsFixed(2)}',
                Icons.date_range,
                HiPopColors.warningAmber,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Revenue Chart
          _buildSectionTitle('Revenue Trend (30 Days)'),
          const SizedBox(height: 12),
          _buildRevenueChart(trends['dailyRevenue'] ?? {}),
          
          const SizedBox(height: 24),
          
          // Revenue Details
          _buildSectionTitle('Revenue Details'),
          const SizedBox(height: 12),
          _buildDetailsList([
            {'label': 'Active Subscriptions', 'value': '${revenue['activeSubscriptions'] ?? 0}'},
            {'label': 'Average Revenue', 'value': '\$${(revenue['averageRevenue'] ?? 0).toStringAsFixed(2)}'},
            {'label': 'Month Revenue', 'value': '\$${(revenue['monthRevenue'] ?? 0).toStringAsFixed(2)}'},
            {'label': 'Total Revenue', 'value': '\$${(revenue['totalRevenue'] ?? 0).toStringAsFixed(2)}'},
          ]),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    final activity = _metrics['activity'] ?? {};
    final feedback = activity['feedback'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Stats
          _buildSectionTitle('Activity Overview'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Events Today',
                  '${activity['todayEvents'] ?? 0}',
                  HiPopColors.primaryDeepSage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Last Hour',
                  '${activity['lastHourEvents'] ?? 0}',
                  HiPopColors.warningAmber,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // User Feedback
          _buildSectionTitle('User Feedback'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Positive',
                  '${feedback['positive'] ?? 0}',
                  HiPopColors.successGreen,
                  icon: Icons.sentiment_satisfied,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Neutral',
                  '${feedback['neutral'] ?? 0}',
                  HiPopColors.infoBlueGray,
                  icon: Icons.sentiment_neutral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Negative',
                  '${feedback['negative'] ?? 0}',
                  HiPopColors.errorPlum,
                  icon: Icons.sentiment_dissatisfied,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Activity Stream
          _buildSectionTitle('Live Activity Stream'),
          const SizedBox(height: 12),
          _buildActivityStream(),
        ],
      ),
    );
  }

  Widget _buildErrorsTab() {
    final errors = _metrics['errors'] ?? {};
    final alerts = errors['alerts'] ?? {};
    final recentErrors = errors['recentErrors'] ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error Overview
          _buildSectionTitle('System Health'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Critical',
                  '${alerts['critical'] ?? 0}',
                  HiPopColors.errorPlum,
                  icon: Icons.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Warnings',
                  '${alerts['warnings'] ?? 0}',
                  HiPopColors.warningAmber,
                  icon: Icons.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Info',
                  '${alerts['info'] ?? 0}',
                  HiPopColors.infoBlueGray,
                  icon: Icons.info,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Errors
          _buildSectionTitle('Recent Errors'),
          const SizedBox(height: 12),
          ...recentErrors.map((error) => _buildErrorCard(error)),
          
          if (recentErrors.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HiPopColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: HiPopColors.successGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No recent errors',
                      style: TextStyle(
                        color: HiPopColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: HiPopColors.darkTextSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: HiPopColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDetailsList(List<Map<String, String>> items) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items.map((item) => ListTile(
          title: Text(
            item['label']!,
            style: TextStyle(color: HiPopColors.darkTextSecondary),
          ),
          trailing: Text(
            item['value']!,
            style: TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildUserTypeChart(Map<String, dynamic> userTypes) {
    final total = (userTypes['vendors'] ?? 0) + 
                  (userTypes['organizers'] ?? 0) + 
                  (userTypes['shoppers'] ?? 0);
    
    if (total == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No user data available'),
        ),
      );
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: (userTypes['vendors'] ?? 0).toDouble(),
                    title: 'Vendors\n${userTypes['vendors'] ?? 0}',
                    color: HiPopColors.primaryDeepSage,
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: (userTypes['organizers'] ?? 0).toDouble(),
                    title: 'Organizers\n${userTypes['organizers'] ?? 0}',
                    color: HiPopColors.secondarySoftSage,
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: (userTypes['shoppers'] ?? 0).toDouble(),
                    title: 'Shoppers\n${userTypes['shoppers'] ?? 0}',
                    color: HiPopColors.accentMauve,
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBreakdown(Map<String, dynamic> subscriptions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSubscriptionRow('Vendor Basic', subscriptions['vendorBasic'] ?? 0, HiPopColors.primaryDeepSage),
          _buildSubscriptionRow('Vendor Growth', subscriptions['vendorGrowth'] ?? 0, HiPopColors.secondarySoftSage),
          _buildSubscriptionRow('Vendor Premium', subscriptions['vendorPremium'] ?? 0, HiPopColors.accentMauve),
          _buildSubscriptionRow('Organizer Basic', subscriptions['organizerBasic'] ?? 0, HiPopColors.infoBlueGray),
          _buildSubscriptionRow('Organizer Pro', subscriptions['organizerPro'] ?? 0, HiPopColors.warningAmber),
          _buildSubscriptionRow('Shopper Premium', subscriptions['shopperPremium'] ?? 0, HiPopColors.successGreen),
        ],
      ),
    );
  }

  Widget _buildSubscriptionRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final vendors = _metrics['vendors'] ?? {};
    final markets = _metrics['markets'] ?? {};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildQuickStat('Pending Apps', '${vendors['applications']?['pending'] ?? 0}'),
              _buildQuickStat('Featured Vendors', '${vendors['featured'] ?? 0}'),
              _buildQuickStat('Recruiting Markets', '${markets['recruiting'] ?? 0}'),
              _buildQuickStat('Vendor Posts', '${vendors['posts'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: HiPopColors.darkTextSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthChart() {
    final trends = _metrics['trends'] ?? {};
    final dailyNewUsers = trends['dailyNewUsers'] ?? {};
    
    if (dailyNewUsers.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No growth data available'),
        ),
      );
    }
    
    final sortedDates = dailyNewUsers.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDates.length; i++) {
      final count = (dailyNewUsers[sortedDates[i]] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: HiPopColors.primaryDeepSage,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: HiPopColors.primaryDeepSage.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> dailyRevenue) {
    if (dailyRevenue.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No revenue data available'),
        ),
      );
    }
    
    final sortedDates = dailyRevenue.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDates.length; i++) {
      final amount = (dailyRevenue[sortedDates[i]] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), amount));
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: HiPopColors.successGreen,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: HiPopColors.successGreen.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStream() {
    if (_recentActivity.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No recent activity',
            style: TextStyle(color: HiPopColors.darkTextSecondary),
          ),
        ),
      );
    }
    
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        itemCount: _recentActivity.length,
        itemBuilder: (context, index) {
          final activity = _recentActivity[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: HiPopColors.primaryDeepSage.withValues(alpha: 0.2),
              child: Icon(
                _getActivityIcon(activity['eventType']),
                color: HiPopColors.primaryDeepSage,
                size: 16,
              ),
            ),
            title: Text(
              activity['eventType'] ?? 'Unknown Event',
              style: TextStyle(
                color: HiPopColors.darkTextPrimary,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${activity['userEmail'] ?? 'Unknown User'} • ${_formatTime(DateTime.tryParse(activity['timestamp'] ?? '') ?? DateTime.now())}',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> error) {
    final severity = error['severity'] ?? 'info';
    Color color = HiPopColors.infoBlueGray;
    IconData icon = Icons.info;
    
    if (severity == 'critical') {
      color = HiPopColors.errorPlum;
      icon = Icons.error;
    } else if (severity == 'warning') {
      color = HiPopColors.warningAmber;
      icon = Icons.warning;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error['message'] ?? 'Unknown error',
                  style: TextStyle(
                    color: HiPopColors.darkTextPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(DateTime.tryParse(error['timestamp'] ?? '') ?? DateTime.now()),
                  style: TextStyle(
                    color: HiPopColors.darkTextSecondary,
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

  // Helper Methods
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  IconData _getActivityIcon(String? eventType) {
    if (eventType == null) return Icons.circle;
    
    if (eventType.contains('login')) return Icons.login;
    if (eventType.contains('logout')) return Icons.logout;
    if (eventType.contains('favorite')) return Icons.favorite;
    if (eventType.contains('share')) return Icons.share;
    if (eventType.contains('view')) return Icons.visibility;
    if (eventType.contains('purchase')) return Icons.shopping_cart;
    if (eventType.contains('vendor')) return Icons.store;
    if (eventType.contains('market')) return Icons.location_on;
    
    return Icons.circle;
  }
}