import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/subscription/subscription_bloc.dart';
import 'package:hipop/blocs/subscription/subscription_state.dart';
import 'package:hipop/blocs/subscription/subscription_event.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/widgets/upgrade_to_premium_button.dart';
import 'package:hipop/features/premium/widgets/vendor_premium_dashboard_components.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  Stream<List<VendorPost>>? _postsStream;
  Stream<Map<String, dynamic>>? _revenueStream;
  Stream<Map<String, int>>? _analyticsStream;
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;
  String? _currentUserId;
  
  // Revenue tracking data
  final Map<String, double> _monthlyRevenue = {};
  final List<FlSpot> _revenueSpots = [];
  
  // Time period selection
  String _selectedPeriod = '30'; // days
  final List<String> _periods = ['7', '30', '90', '365'];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      _postsStream = _getVendorPosts(_currentUserId!);
      _analyticsStream = _getAnalytics(_currentUserId!);
      _revenueStream = _getRevenueAnalytics(_currentUserId!);
      _checkPremiumAccessWithBloc(_currentUserId!);
    }
  }

  Future<void> _checkPremiumAccessWithBloc(String vendorId) async {
    // Initialize subscription monitoring
    context.read<SubscriptionBloc>().add(SubscriptionInitialized(vendorId));
    
    // Check specific feature access
    context.read<SubscriptionBloc>().add(
      const FeatureAccessRequested('product_performance_analytics'),
    );
    
    // Fallback to service check
    final hasAccess = await SubscriptionService.hasFeature(
      vendorId,
      'product_performance_analytics',
    );
    if (mounted) {
      setState(() {
        _hasPremiumAccess = hasAccess;
        _isCheckingPremium = false;
      });
    }
  }

  Stream<List<VendorPost>> _getVendorPosts(String vendorId) {
    return Stream.fromFuture(
      FirebaseFirestore.instance
        .collection('vendor_posts')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit results to prevent large queries
        .get()
        .timeout(const Duration(seconds: 10))
        .then((snapshot) {
          debugPrint('Loaded ${snapshot.docs.length} vendor posts');
          return snapshot.docs
              .map((doc) => VendorPost.fromFirestore(doc))
              .toList();
        })
        .catchError((error) {
          debugPrint('Error loading vendor posts: $error');
          return <VendorPost>[];
        }),
    );
  }

  /// Enhanced revenue analytics stream with time-based filtering
  Stream<Map<String, dynamic>> _getRevenueAnalytics(String vendorId) {
    return Stream.fromFuture(
      FirebaseFirestore.instance
          .collection('vendor_revenue_analytics')
          .where('vendorId', isEqualTo: vendorId)
          .where('date', isGreaterThan: DateTime.now().subtract(Duration(days: int.parse(_selectedPeriod))))
          .orderBy('date')
          .get()
          .timeout(const Duration(seconds: 15))
          .then((snapshot) {
            final revenueData = <String, dynamic>{
              'dailyRevenue': <String, double>{},
              'totalRevenue': 0.0,
              'averageRevenue': 0.0,
              'revenueSpots': <FlSpot>[],
              'topProducts': <Map<String, dynamic>>[],
              'revenueGrowth': 0.0,
            };
            
            double totalRevenue = 0.0;
            final dailyRevenue = <String, double>{};
            final revenueSpots = <FlSpot>[];
            
            for (int i = 0; i < snapshot.docs.length; i++) {
              final doc = snapshot.docs[i];
              final data = doc.data();
              final date = (data['date'] as Timestamp).toDate();
              final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
              
              final dateKey = '${date.month}/${date.day}';
              dailyRevenue[dateKey] = revenue;
              totalRevenue += revenue;
              
              // Create spots for chart
              revenueSpots.add(FlSpot(i.toDouble(), revenue));
            }
            
            revenueData['dailyRevenue'] = dailyRevenue;
            revenueData['totalRevenue'] = totalRevenue;
            revenueData['averageRevenue'] = snapshot.docs.isNotEmpty 
                ? totalRevenue / snapshot.docs.length 
                : 0.0;
            revenueData['revenueSpots'] = revenueSpots;
            
            // Calculate growth (compare first half vs second half of period)
            if (snapshot.docs.length >= 4) {
              final midpoint = snapshot.docs.length ~/ 2;
              double firstHalfTotal = 0.0;
              double secondHalfTotal = 0.0;
              
              for (int i = 0; i < midpoint; i++) {
                firstHalfTotal += (snapshot.docs[i].data()['revenue'] as num?)?.toDouble() ?? 0.0;
              }
              for (int i = midpoint; i < snapshot.docs.length; i++) {
                secondHalfTotal += (snapshot.docs[i].data()['revenue'] as num?)?.toDouble() ?? 0.0;
              }
              
              if (firstHalfTotal > 0) {
                revenueData['revenueGrowth'] = ((secondHalfTotal - firstHalfTotal) / firstHalfTotal) * 100;
              }
            }
            
            return revenueData;
          })
          .catchError((error) {
            debugPrint('Error loading revenue analytics: $error');
            return <String, dynamic>{
              'dailyRevenue': <String, double>{},
              'totalRevenue': 0.0,
              'averageRevenue': 0.0,
              'revenueSpots': <FlSpot>[],
              'topProducts': <Map<String, dynamic>>[],
              'revenueGrowth': 0.0,
            };
          }),
    );
  }

  Stream<Map<String, int>> _getAnalytics(String vendorId) {
    return Stream.fromFuture(
      Future.wait([
        // Get aggregated daily analytics
        FirebaseFirestore.instance
          .collection('vendor_daily_analytics')
          .where('vendorId', isEqualTo: vendorId)
          .where('date', isGreaterThan: DateTime.now().subtract(Duration(days: int.parse(_selectedPeriod))))
          .get()
          .timeout(const Duration(seconds: 10)),
        // Get individual analytics events for more detailed analysis
        FirebaseFirestore.instance
          .collection('analytics')
          .where('vendorId', isEqualTo: vendorId)
          .where('timestamp', isGreaterThan: DateTime.now().subtract(Duration(days: int.parse(_selectedPeriod))))
          .limit(1000) // Limit to prevent large queries
          .get()
          .timeout(const Duration(seconds: 10)),
      ]).then((results) {
        final dailySnapshot = results[0];
        final eventsSnapshot = results[1];
        
        debugPrint('Loaded ${dailySnapshot.docs.length} daily analytics and ${eventsSnapshot.docs.length} events');
        
        // Sum up daily analytics
        int totalViews = 0;
        int totalFavorites = 0;
        int totalContacts = 0;
        int uniqueVisitors = 0;
        
        for (final doc in dailySnapshot.docs) {
          final data = doc.data();
          totalViews += (data['views'] as num? ?? 0).toInt();
          totalFavorites += (data['favorites'] as num? ?? 0).toInt();
          totalContacts += (data['contacts'] as num? ?? 0).toInt();
          uniqueVisitors += (data['unique_visitors'] as num? ?? 0).toInt();
        }
        
        // If no daily analytics, fall back to counting events
        if (dailySnapshot.docs.isEmpty && eventsSnapshot.docs.isNotEmpty) {
          final viewedPosts = <String>{};
          for (final doc in eventsSnapshot.docs) {
            final data = doc.data();
            final action = data['action'] as String?;
            final postId = data['postId'] as String?;
            
            if (action == 'view') {
              totalViews++;
              if (postId != null) viewedPosts.add(postId);
            }
            if (action == 'favorite') totalFavorites++;
            if (action == 'unfavorite') totalFavorites--;
            if (action == 'contact') totalContacts++;
          }
          uniqueVisitors = viewedPosts.length;
        }
        
        return <String, int>{
          'totalViews': totalViews,
          'totalFavorites': totalFavorites.clamp(0, double.infinity).toInt(),
          'totalContacts': totalContacts,
          'uniqueVisitors': uniqueVisitors,
          'totalPosts': 0, // Will be calculated from posts
        };
      })
      .catchError((error) {
        debugPrint('Error loading analytics: $error');
        return <String, int>{
          'totalViews': 0,
          'totalFavorites': 0,
          'totalContacts': 0,
          'uniqueVisitors': 0,
          'totalPosts': 0,
        };
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, subscriptionState) {
        
        if (authState is! Authenticated) {
          return const Scaffold(
            body: LoadingWidget(message: 'Loading analytics...'),
          );
        }

        // Update premium access based on subscription state
        if (subscriptionState is SubscriptionLoaded) {
          _hasPremiumAccess = subscriptionState.hasFeature('product_performance_analytics');
          _isCheckingPremium = false;
        } else if (subscriptionState is FeatureAccessResult) {
          if (subscriptionState.featureName == 'product_performance_analytics') {
            _hasPremiumAccess = subscriptionState.hasAccess;
            _isCheckingPremium = false;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Analytics Dashboard'),
                const Spacer(),
                if (_hasPremiumAccess) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (_hasPremiumAccess) ...[
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedPeriod = value;
                      // Refresh data for new period
                      if (_currentUserId != null) {
                        _analyticsStream = _getAnalytics(_currentUserId!);
                        _revenueStream = _getRevenueAnalytics(_currentUserId!);
                      }
                    });
                  },
                  itemBuilder: (context) => _periods.map((period) =>
                    PopupMenuItem<String>(
                      value: period,
                      child: Text(
                        period == '7' ? '7 Days' :
                        period == '30' ? '30 Days' :
                        period == '90' ? '3 Months' : '1 Year'
                      ),
                    ),
                  ).toList(),
                  icon: const Icon(Icons.date_range),
                ),
              ],
            ],
          ),
          body: _buildAnalyticsBody(subscriptionState),
        );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsBody(SubscriptionState subscriptionState) {
    if (_analyticsStream == null || _postsStream == null) {
      return const LoadingWidget(message: 'Loading your analytics...');
    }

    if (_hasPremiumAccess) {
      return _buildPremiumAnalyticsView();
    } else if (!_isCheckingPremium) {
      return _buildFreeAnalyticsView();
    } else {
      return const LoadingWidget(message: 'Checking subscription...');
    }
  }

  Widget _buildPremiumAnalyticsView() {
    return StreamBuilder<Map<String, int>>(
      stream: _analyticsStream!,
      builder: (context, analyticsSnapshot) {
        return StreamBuilder<List<VendorPost>>(
          stream: _postsStream!,
          builder: (context, postsSnapshot) {
            return StreamBuilder<Map<String, dynamic>>(
              stream: _revenueStream!,
              builder: (context, revenueSnapshot) {
                if (postsSnapshot.connectionState == ConnectionState.waiting ||
                    analyticsSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget(message: 'Loading premium analytics...');
                }

                final posts = postsSnapshot.data ?? [];
                final analytics = analyticsSnapshot.data ?? {};
                final revenueData = revenueSnapshot.data ?? {};

                return PremiumDashboardLayout(
                  children: [
                    VendorPremiumDashboardComponents.buildPremiumHeader(
                      context,
                      title: 'Vendor Pro Analytics',
                      subtitle: 'Advanced insights for your business growth',
                    ),
                    _buildPremiumOverviewSection(analytics, posts, revenueData),
                    _buildRevenueChart(revenueData),
                    _buildEngagementAnalytics(analytics, posts),
                    _buildPostPerformanceSection(posts),
                    _buildLocationInsights(posts),
                    _buildGrowthInsights(revenueData),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFreeAnalyticsView() {
    return StreamBuilder<Map<String, int>>(
      stream: _analyticsStream!,
      builder: (context, analyticsSnapshot) {
        return StreamBuilder<List<VendorPost>>(
          stream: _postsStream!,
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingWidget(message: 'Loading your analytics...');
            }

            if (postsSnapshot.hasError) {
              debugPrint('Vendor analytics error: ${postsSnapshot.error}');
              return _buildEmptyAnalyticsState();
            }

            final posts = postsSnapshot.data ?? [];
            final analytics = analyticsSnapshot.data ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPremiumOnlyMessage(),
                  const SizedBox(height: 24),
                  _buildBasicOverviewSection(analytics, posts),
                  const SizedBox(height: 24),
                  VendorPremiumDashboardComponents.buildUpgradePrompt(
                    context,
                    customMessage: 'Unlock advanced analytics to grow your vendor business!',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Premium overview section with enhanced metrics
  Widget _buildPremiumOverviewSection(Map<String, int> analytics, List<VendorPost> posts, Map<String, dynamic> revenueData) {
    final activePosts = posts.where((p) => p.isActive).length;
    final happeningNow = posts.where((p) => p.isHappening).length;
    final totalRevenue = revenueData['totalRevenue'] as double? ?? 0.0;
    final revenueGrowth = revenueData['revenueGrowth'] as double? ?? 0.0;
    
    return VendorPremiumDashboardComponents.buildAnalyticsGrid(
      metrics: [
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Total Revenue',
          value: '\$${totalRevenue.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: Colors.green,
          trend: revenueGrowth > 0 ? '+${revenueGrowth.toStringAsFixed(1)}%' : '${revenueGrowth.toStringAsFixed(1)}%',
          showTrend: true,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Total Views',
          value: '${analytics['totalViews'] ?? 0}',
          icon: Icons.visibility,
          color: Colors.blue,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Customer Contacts',
          value: '${analytics['totalContacts'] ?? 0}',
          icon: Icons.phone,
          color: Colors.orange,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Unique Visitors',
          value: '${analytics['uniqueVisitors'] ?? 0}',
          icon: Icons.people,
          color: Colors.purple,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Active Pop-ups',
          value: '$activePosts',
          icon: Icons.event_available,
          color: Colors.green,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Live Now',
          value: '$happeningNow',
          icon: Icons.play_circle_fill,
          color: Colors.red,
        ),
      ],
    );
  }

  /// Revenue chart using fl_chart
  Widget _buildRevenueChart(Map<String, dynamic> revenueData) {
    final revenueSpots = revenueData['revenueSpots'] as List<FlSpot>? ?? [];
    
    if (revenueSpots.isEmpty) {
      return VendorPremiumDashboardComponents.buildPremiumFeatureCard(
        title: 'Revenue Tracking',
        description: 'Start tracking sales to see revenue trends over time',
        icon: Icons.trending_up,
        color: Colors.green,
        onTap: () {},
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Revenue Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Last ${_selectedPeriod} days',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: revenueSpots.length > 7 ? (revenueSpots.length / 7).ceil().toDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < revenueSpots.length) {
                            final dayOffset = DateTime.now().subtract(Duration(days: int.parse(_selectedPeriod) - value.toInt()));
                            return Text(
                              '${dayOffset.month}/${dayOffset.day}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: revenueSpots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green.shade600,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade200.withValues(alpha: 0.3),
                            Colors.green.shade100.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Enhanced engagement analytics with conversion rates
  Widget _buildEngagementAnalytics(Map<String, int> analytics, List<VendorPost> posts) {
    final totalViews = analytics['totalViews'] ?? 0;
    final totalContacts = analytics['totalContacts'] ?? 0;
    final totalFavorites = analytics['totalFavorites'] ?? 0;
    
    final contactRate = totalViews > 0 ? (totalContacts / totalViews * 100) : 0.0;
    final favoriteRate = totalViews > 0 ? (totalFavorites / totalViews * 100) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Engagement Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildEngagementMetric(
                    'Contact Rate',
                    '${contactRate.toStringAsFixed(1)}%',
                    Icons.phone,
                    Colors.orange,
                    contactRate / 100,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEngagementMetric(
                    'Favorite Rate',
                    '${favoriteRate.toStringAsFixed(1)}%',
                    Icons.favorite,
                    Colors.red,
                    favoriteRate / 100,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementMetric(String title, String value, IconData icon, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  /// Growth insights with recommendations
  Widget _buildGrowthInsights(Map<String, dynamic> revenueData) {
    final revenueGrowth = revenueData['revenueGrowth'] as double? ?? 0.0;
    final totalRevenue = revenueData['totalRevenue'] as double? ?? 0.0;

    return VendorPremiumDashboardComponents.buildPremiumFeatureCard(
      title: 'Growth Insights',
      description: revenueGrowth > 0 
          ? 'Revenue is trending upward by ${revenueGrowth.toStringAsFixed(1)}%. Keep up the great work!'
          : revenueGrowth < 0
              ? 'Revenue has declined by ${revenueGrowth.abs().toStringAsFixed(1)}%. Consider optimizing your pricing or expanding to new markets.'
              : 'Revenue is stable. Consider strategies to boost growth.',
      icon: revenueGrowth > 0 ? Icons.trending_up : revenueGrowth < 0 ? Icons.trending_down : Icons.trending_flat,
      color: revenueGrowth > 0 ? Colors.green : revenueGrowth < 0 ? Colors.red : Colors.orange,
      onTap: () {
        // Navigate to growth strategies
      },
    );
  }

  /// Basic overview for free users
  Widget _buildBasicOverviewSection(Map<String, int> analytics, List<VendorPost> posts) {
    final activePosts = posts.where((p) => p.isActive).length;
    final happeningNow = posts.where((p) => p.isHappening).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildBasicMetricCard(
              'Total Views',
              '${analytics['totalViews'] ?? 0}',
              Icons.visibility,
              Colors.blue,
            ),
            _buildBasicMetricCard(
              'Total Favorites',
              '${analytics['totalFavorites'] ?? 0}',
              Icons.favorite,
              Colors.red,
            ),
            _buildBasicMetricCard(
              'Active Pop-ups',
              '$activePosts',
              Icons.event_available,
              Colors.green,
            ),
            _buildBasicMetricCard(
              'Happening Now',
              '$happeningNow',
              Icons.play_circle_fill,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAnalyticsState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show demo analytics with zero values
          _buildBasicOverviewSection({'totalViews': 0, 'totalFavorites': 0}, []),
          const SizedBox(height: 24),
          
          // Empty state message
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Analytics Data Yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start creating pop-ups to see your analytics here!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Premium prompt if not premium
          if (!_hasPremiumAccess && !_isCheckingPremium) ...[
            VendorPremiumDashboardComponents.buildUpgradePrompt(context),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewSection(Map<String, int> analytics, List<VendorPost> posts) {
    final activePosts = posts.where((p) => p.isActive).length;
    final happeningNow = posts.where((p) => p.isHappening).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildMetricCard(
              'Total Views',
              '${analytics['totalViews'] ?? 0}',
              Icons.visibility,
              Colors.blue,
            ),
            _buildMetricCard(
              'Total Favorites',
              '${analytics['totalFavorites'] ?? 0}',
              Icons.favorite,
              Colors.red,
            ),
            _buildMetricCard(
              'Active Pop-ups',
              '$activePosts',
              Icons.event_available,
              Colors.green,
            ),
            _buildMetricCard(
              'Happening Now',
              '$happeningNow',
              Icons.play_circle_fill,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostPerformanceSection(List<VendorPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptySection(
        'No Posts Yet',
        'Create your first pop-up to see performance metrics!',
        Icons.add_box,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Post Performance',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        ...posts.take(5).map((post) => _buildPostPerformanceCard(post)),
      ],
    );
  }

  Widget _buildPostPerformanceCard(VendorPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.location,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.isHappening 
                        ? Colors.green 
                        : post.isUpcoming 
                            ? Colors.orange 
                            : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    post.isHappening 
                        ? 'Live' 
                        : post.isUpcoming 
                            ? 'Upcoming' 
                            : 'Past',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPerformanceMetric(Icons.visibility, '0', 'Views'),
                const SizedBox(width: 24),
                _buildPerformanceMetric(Icons.favorite, '0', 'Favorites'),
                const Spacer(),
                Text(
                  post.formattedDateTime,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementInsights(List<VendorPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptySection(
        'No Engagement Data',
        'Create more pop-ups to see engagement insights!',
        Icons.insights,
      );
    }

    // Calculate real insights from posts data
    final Map<String, int> dayOfWeekCounts = {};
    final Map<int, int> hourOfDayCounts = {};
    int totalFavorites = 0;
    
    for (final post in posts) {
      // Count posts by day of week
      final dayOfWeek = _getDayOfWeekName(post.popUpStartDateTime.weekday);
      dayOfWeekCounts[dayOfWeek] = (dayOfWeekCounts[dayOfWeek] ?? 0) + 1;
      
      // Count posts by hour of day
      final hour = post.popUpStartDateTime.hour;
      hourOfDayCounts[hour] = (hourOfDayCounts[hour] ?? 0) + 1;
    }

    // Find most popular day
    final mostPopularDay = dayOfWeekCounts.isEmpty 
        ? 'No data yet' 
        : dayOfWeekCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Find best time to post (most common hour)
    final bestHour = hourOfDayCounts.isEmpty 
        ? 'No data yet'
        : '${hourOfDayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key}:00';

    // Calculate average engagement (this would ideally come from analytics collection)
    final avgEngagement = posts.isEmpty ? 'No data yet' : '${(totalFavorites / posts.length).toStringAsFixed(1)} avg per post';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engagement Insights',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInsightRow(
                  'Best Time to Post',
                  bestHour,
                  Icons.schedule,
                  Colors.blue,
                ),
                const Divider(),
                _buildInsightRow(
                  'Most Popular Day',
                  mostPopularDay,
                  Icons.calendar_today,
                  Colors.green,
                ),
                const Divider(),
                _buildInsightRow(
                  'Average Engagement',
                  avgEngagement,
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDayOfWeekName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 
      'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }

  Widget _buildLocationInsights(List<VendorPost> posts) {
    final locationCounts = <String, int>{};
    for (final post in posts) {
      locationCounts[post.location] = (locationCounts[post.location] ?? 0) + 1;
    }

    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Locations',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        if (sortedLocations.isEmpty)
          _buildEmptySection(
            'No Location Data',
            'Start creating pop-ups to see which locations work best!',
            Icons.location_on,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: sortedLocations
                    .take(5)
                    .map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.orange[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${entry.value} pop-ups',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInsightRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection(String title, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOnlyMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Icon(
                Icons.analytics,
                size: 64,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Analytics Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analytics is a premium feature exclusively available to Vendor Pro subscribers.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade to unlock detailed insights about your pop-up performance, customer engagement, and growth opportunities.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPrompt() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Unlock Vendor Pro Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Vendor Pro (\$29/month) to unlock:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Detailed engagement insights & timing analytics'),
                SizedBox(height: 4),
                Text('📍 Location performance comparison'),
                SizedBox(height: 4),
                Text('📈 Revenue tracking & seasonal trends'),
                SizedBox(height: 4),
                Text('🎯 Customer demographics & behavior'),
                SizedBox(height: 4),
                Text('🚀 Multi-market management tools'),
              ],
            ),
            const SizedBox(height: 20),
            UpgradeToPremiumButton(
              userType: 'vendor',
              onSuccess: () {
                // Refresh premium status after successful upgrade
                final authState = context.read<AuthBloc>().state;
                if (authState is Authenticated) {
                  _checkPremiumAccessWithBloc(authState.user.uid);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}