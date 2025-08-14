import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/organizer/screens/organizer_analytics_screen.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/screens/premium_onboarding_screen.dart';

class OrganizerPremiumDashboard extends StatefulWidget {
  const OrganizerPremiumDashboard({super.key});

  @override
  State<OrganizerPremiumDashboard> createState() => _OrganizerPremiumDashboardState();
}

class _OrganizerPremiumDashboardState extends State<OrganizerPremiumDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<List<VendorPost>>? _marketPostsStream;
  Stream<Map<String, int>>? _marketAnalyticsStream;
  bool _hasAdvancedAnalytics = false;
  bool _hasMarketIntelligence = false;
  bool _isLoadingSubscription = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _userId = authState.user.uid;
      _checkSubscriptionFeatures(_userId!);
      _marketPostsStream = _getMarketPosts(_userId!);
      _marketAnalyticsStream = _getMarketAnalytics(_userId!);
      debugPrint('🔍 Organizer premium dashboard initialized for organizer: $_userId');
    }
  }

  Future<void> _checkSubscriptionFeatures(String userId) async {
    try {
      final results = await Future.wait([
        SubscriptionService.hasFeature(userId, 'advanced_analytics'),
        SubscriptionService.hasFeature(userId, 'market_intelligence'),
      ]);
      
      setState(() {
        _hasAdvancedAnalytics = results[0];
        _hasMarketIntelligence = results[1];
        _isLoadingSubscription = false;
      });
    } catch (e) {
      debugPrint('Error checking subscription features: $e');
      setState(() {
        _isLoadingSubscription = false;
      });
    }
  }

  void _showUpgradeDialog(String featureName, String featureDescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            const Text('Upgrade Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock $featureName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(featureDescription),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.deepPurple, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Advanced Analytics Dashboard')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.deepPurple, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Market Intelligence Reports')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.deepPurple, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Vendor Performance Tracking')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.deepPurple, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Revenue Forecasting Tools')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PremiumOnboardingScreen(
                      userId: _userId!,
                      userType: 'market_organizer',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<VendorPost>> _getMarketPosts(String organizerId) {
    return Stream.fromFuture(
      _getOrganizerMarketIds(organizerId).then((marketIds) async {
        if (marketIds.isEmpty) {
          debugPrint('No markets found for organizer: $organizerId');
          return <VendorPost>[];
        }
        
        final snapshot = await FirebaseFirestore.instance
          .collection('vendor_posts')
          .where('marketId', whereIn: marketIds)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));
          
        debugPrint('Loaded ${snapshot.docs.length} market posts for ${marketIds.length} markets');
        return snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList();
      }).catchError((error) {
        debugPrint('Error loading market posts: $error');
        return <VendorPost>[];
      }),
    );
  }

  Future<List<String>> _getOrganizerMarketIds(String organizerId) async {
    try {
      final marketsQuery = await FirebaseFirestore.instance
        .collection('markets')
        .where('organizerId', isEqualTo: organizerId)
        .get();
      
      final marketIds = marketsQuery.docs.map((doc) => doc.id).toList();
      debugPrint('Found ${marketIds.length} markets for organizer: $organizerId');
      return marketIds;
    } catch (e) {
      debugPrint('Error getting organizer markets: $e');
      return [];
    }
  }

  Stream<Map<String, int>> _getMarketAnalytics(String organizerId) {
    return Stream.fromFuture(
      _generateRealAnalytics(organizerId).then((analytics) {
        debugPrint('Generated real analytics for organizer: $organizerId');
        return analytics;
      }).catchError((error) {
        debugPrint('Error loading market analytics: $error');
        return <String, int>{
          'totalVendors': 0,
          'activeMarkets': 0,
          'totalEvents': 0,
            'totalRevenue': 0,
          };
        }),
    );
  }

  Future<Map<String, int>> _generateRealAnalytics(String organizerId) async {
    try {
      // Get organizer's markets
      final marketIds = await _getOrganizerMarketIds(organizerId);
      
      // Count active markets
      final activeMarkets = marketIds.length;
      
      // Count vendor applications across all markets
      int totalVendors = 0;
      if (marketIds.isNotEmpty) {
        final vendorAppsQuery = await FirebaseFirestore.instance
          .collection('vendor_applications')
          .where('marketId', whereIn: marketIds)
          .where('status', isEqualTo: 'approved')
          .get();
        totalVendors = vendorAppsQuery.docs.length;
      }
      
      // Count events across all markets  
      int totalEvents = 0;
      if (marketIds.isNotEmpty) {
        final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('marketId', whereIn: marketIds)
          .get();
        totalEvents = eventsQuery.docs.length;
      }
      
      return {
        'totalVendors': totalVendors,
        'activeMarkets': activeMarkets,
        'totalEvents': totalEvents,
        'totalRevenue': 0, // Revenue tracking not implemented yet
      };
    } catch (e) {
      debugPrint('Error generating real analytics: $e');
      return {
        'totalVendors': 0,
        'activeMarkets': 0,
        'totalEvents': 0,
        'totalRevenue': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber),
            SizedBox(width: 8),
            Text('Organizer Pro Dashboard'),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Vendor Posts', icon: Icon(Icons.campaign)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAnalyticsTab(),
          _buildVendorPostsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Organizer Pro! 🎉',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You now have access to:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildMarketOverviewCards(),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      '📊 Advanced Market Analytics - Track vendor performance, revenue trends, and market insights',
      '🎯 "Looking for Vendors" Posts - Create targeted posts that appear in vendor market discovery',
      '📈 Vendor Post Analytics - Track views, responses, and conversion rates for your posts',
      '🔍 Smart Vendor Matching - Your posts are automatically matched to relevant vendors',
      '💬 Response Management - Efficiently manage vendor inquiries and applications',
      '📱 Integrated Discovery - Seamless integration with vendor premium discovery features',
    ];

    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                feature,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildMarketOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Active Vendors',
            '0',
            Icons.people,
            Colors.blue,
            isLocked: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'This Month Revenue',
            _hasAdvancedAnalytics ? '\$0.00' : '•••',
            Icons.attach_money,
            Colors.green,
            isLocked: !_hasAdvancedAnalytics,
            onTap: !_hasAdvancedAnalytics ? () => _showUpgradeDialog(
              'Advanced Analytics',
              'Track your revenue trends, forecasting, and financial insights.',
            ) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const LoadingWidget(message: 'Loading analytics...');
        }

        if (_isLoadingSubscription) {
          return const LoadingWidget(message: 'Checking subscription features...');
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Analytics Card (Always Available)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bar_chart, color: Colors.blue, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Basic Analytics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              'Free',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'View basic market metrics and vendor post statistics.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Advanced Analytics Card (Premium Gated)
              Card(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.analytics, color: Colors.deepPurple, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Advanced Analytics Dashboard',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Text(
                                  'Premium',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Advanced market performance, vendor analytics, revenue insights, and forecasting tools.',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _hasAdvancedAnalytics ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const OrganizerAnalyticsScreen(),
                                  ),
                                );
                              } : () {
                                _showUpgradeDialog(
                                  'Advanced Analytics',
                                  'Get detailed insights into your market performance, vendor analytics, revenue trends, and forecasting tools.',
                                );
                              },
                              icon: Icon(_hasAdvancedAnalytics ? Icons.launch : Icons.lock),
                              label: Text(_hasAdvancedAnalytics ? 'Open Advanced Dashboard' : 'Upgrade to Access'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasAdvancedAnalytics ? Colors.deepPurple : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_hasAdvancedAnalytics)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Analytics Preview
              Expanded(
                child: _buildAnalyticsPreview(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVendorPostsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.campaign, color: Colors.deepPurple, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '"Looking for Vendors" Posts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.amber.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create targeted posts to attract qualified vendors. Your posts appear directly in vendor market discovery feeds.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.go('/organizer/vendor-posts/create');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.go('/organizer/vendor-posts');
                          },
                          icon: const Icon(Icons.list),
                          label: const Text('Manage Posts'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Vendor Posts Features Preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vendor Post Features',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildFeatureCard(
                        'Smart Targeting',
                        'Posts automatically appear to vendors in matching categories',
                        Icons.gps_fixed,
                        Colors.purple,
                      ),
                      _buildFeatureCard(
                        'Response Management',
                        'View and manage vendor inquiries and applications',
                        Icons.inbox,
                        Colors.blue,
                      ),
                      _buildFeatureCard(
                        'Performance Analytics',
                        'Track views, response rates, and conversion metrics',
                        Icons.analytics,
                        Colors.green,
                      ),
                      _buildFeatureCard(
                        'Integration Benefits',
                        'Seamlessly integrates with vendor discovery system',
                        Icons.integration_instructions,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsPreview() {
    return _marketAnalyticsStream == null || _marketPostsStream == null
        ? const LoadingWidget(message: 'Loading analytics preview...')
        : StreamBuilder<Map<String, int>>(
            stream: _marketAnalyticsStream!,
            builder: (context, analyticsSnapshot) {
              return StreamBuilder<List<VendorPost>>(
                stream: _marketPostsStream!,
                builder: (context, postsSnapshot) {
                  final posts = postsSnapshot.data ?? [];
                  final analytics = analyticsSnapshot.data ?? {};
                  final totalVendors = analytics['totalVendors'] ?? 0;
                  final activeMarkets = analytics['activeMarkets'] ?? 0;
                  // Removed unused totalEvents variable
                  final totalRevenue = analytics['totalRevenue'] ?? 0;

                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      // Free metrics - always visible
                      _buildMetricCard(
                        'Total Vendors',
                        '$totalVendors',
                        Icons.people,
                        Colors.blue,
                        isLocked: false,
                      ),
                      _buildMetricCard(
                        'Active Markets',
                        '$activeMarkets',
                        Icons.store,
                        Colors.green,
                        isLocked: false,
                      ),
                      
                      // Premium metrics - gated
                      _buildMetricCard(
                        'Vendor Posts',
                        _hasMarketIntelligence ? '${posts.length}' : '•••',
                        Icons.campaign,
                        Colors.orange,
                        isLocked: !_hasMarketIntelligence,
                        onTap: !_hasMarketIntelligence ? () => _showUpgradeDialog(
                          'Market Intelligence',
                          'Track vendor post performance, engagement metrics, and response analytics.',
                        ) : null,
                      ),
                      _buildMetricCard(
                        'Revenue Insights',
                        _hasAdvancedAnalytics ? '\$${totalRevenue.toString()}' : '•••',
                        Icons.attach_money,
                        Colors.purple,
                        isLocked: !_hasAdvancedAnalytics,
                        onTap: !_hasAdvancedAnalytics ? () => _showUpgradeDialog(
                          'Advanced Analytics',
                          'Access detailed revenue tracking, forecasting, and financial insights.',
                        ) : null,
                      ),
                    ],
                  );
                },
              );
            },
          );
  }

  Widget _buildMetricCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    bool isLocked = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon, 
                    size: 32, 
                    color: isLocked ? Colors.grey.shade400 : color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey.shade400 : color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLocked ? Colors.grey.shade400 : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
