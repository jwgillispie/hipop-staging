import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/vendor/screens/vendor_sales_tracker_screen.dart';
import 'package:hipop/features/vendor/screens/vendor_analytics_screen.dart';
import 'package:hipop/features/premium/widgets/vendor_premium_dashboard_components.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class VendorPremiumDashboard extends StatefulWidget {
  const VendorPremiumDashboard({super.key});

  @override
  State<VendorPremiumDashboard> createState() => _VendorPremiumDashboardState();
}

class _VendorPremiumDashboardState extends State<VendorPremiumDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<List<VendorPost>>? _postsStream;
  Stream<Map<String, int>>? _analyticsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final vendorId = authState.user.uid;
      _postsStream = _getVendorPosts(vendorId);
      _analyticsStream = _getAnalytics(vendorId);
      debugPrint('🔍 Premium dashboard initialized for vendor: $vendorId');
    }
  }

  Stream<List<VendorPost>> _getVendorPosts(String vendorId) {
    return Stream.fromFuture(
      FirebaseFirestore.instance
        .collection('vendor_posts')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(50)
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

  Stream<Map<String, int>> _getAnalytics(String vendorId) {
    return Stream.fromFuture(
      FirebaseFirestore.instance
        .collection('analytics')
        .where('vendorId', isEqualTo: vendorId)
        .get()
        .timeout(const Duration(seconds: 10))
        .then((snapshot) {
          debugPrint('Loaded ${snapshot.docs.length} analytics records');
          final Map<String, int> analytics = {
            'totalViews': 0,
            'totalFavorites': 0,
            'totalPosts': 0,
          };
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            analytics['totalViews'] = (analytics['totalViews'] ?? 0) + (data['views'] as int? ?? 0);
            analytics['totalFavorites'] = (analytics['totalFavorites'] ?? 0) + (data['favorites'] as int? ?? 0);
          }
          
          return analytics;
        })
        .catchError((error) {
          debugPrint('Error loading analytics: $error');
          return <String, int>{
            'totalViews': 0,
            'totalFavorites': 0,
            'totalPosts': 0,
          };
        }),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: HiPopColors.premiumGold),
            SizedBox(width: 8),
            Text('Vendor Premium Dashboard'),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HiPopColors.secondarySoftSage,
                HiPopColors.accentMauve,
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Market Discovery', icon: Icon(Icons.search)),
            Tab(text: 'Sales Tracker', icon: Icon(Icons.attach_money)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Items List', icon: Icon(Icons.inventory)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMarketDiscoveryTab(),
          _buildSalesTrackerTab(),
          _buildAnalyticsTab(),
          _buildItemsListTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return PremiumDashboardLayout(
      children: [
        _buildSimplifiedValueProposition(),
        _buildQuickStatsGrid(),
        _buildPremiumFeaturesList(),
      ],
    );
  }

  Widget _buildSimplifiedValueProposition() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            color: Colors.green.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow your business',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Our goal is to get more people to your pop ups.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    return VendorPremiumDashboardComponents.buildAnalyticsGrid(
      metrics: [
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'This Month Revenue',
          value: '\$0.00',
          icon: Icons.attach_money,
          color: Colors.green,
          trend: '+0%',
          showTrend: true,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Markets Active',
          value: '0',
          icon: Icons.storefront,
          color: Colors.blue,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Products Listed',
          value: '0',
          icon: Icons.inventory,
          color: Colors.purple,
        ),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Total Views',
          value: '0',
          icon: Icons.visibility,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildPremiumFeaturesList() {
    return Column(
      children: [
        VendorPremiumDashboardComponents.buildPremiumFeatureCard(
          title: 'Advanced Analytics',
          description: 'Deep insights into customer behavior, peak sales times, and location performance to optimize your business strategy.',
          icon: Icons.analytics,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VendorAnalyticsScreen()),
          ),
        ),
        const SizedBox(height: 16),
        VendorPremiumDashboardComponents.buildPremiumFeatureCard(
          title: 'Market Discovery',
          description: 'AI-powered matching with markets actively seeking vendors in your category. Find the best opportunities in your area.',
          icon: Icons.search,
          color: Colors.amber,
          onTap: () => context.go('/vendor/market-discovery'),
        ),
        const SizedBox(height: 16),
        VendorPremiumDashboardComponents.buildPremiumFeatureCard(
          title: 'Sales Tracker',
          description: 'Comprehensive revenue tracking, daily sales monitoring, and financial insights to maximize profitability.',
          icon: Icons.attach_money,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VendorSalesTrackerScreen()),
          ),
        ),
        const SizedBox(height: 16),
        VendorPremiumDashboardComponents.buildPremiumFeatureCard(
          title: 'Master Product Catalog',
          description: 'Unlimited items per market, inventory tracking across multiple locations, and product performance analytics.',
          icon: Icons.inventory,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, '/vendor/products-management'),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketDiscoveryTab() {
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
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.search, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Market Discovery',
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
                    'Find markets actively seeking vendors with your product categories. Get matched with the best opportunities in your area.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.go('/vendor/market-discovery');
                      },
                      icon: const Icon(Icons.launch),
                      label: const Text('Discover Markets'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Market Discovery Features',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    'Smart matching based on your product categories',
                    'Distance-based filtering and location optimization',
                    'Market activity insights and vendor capacity analysis',
                    'Application deadline tracking and priority alerts',
                    'Estimated fees and commission rate transparency',
                    'Direct organizer contact information',
                  ].map((feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.amber[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrackerTab() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const LoadingWidget(message: 'Loading sales tracker...');
        }

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
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.attach_money, color: Colors.green, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Sales Tracker',
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
                        'Track daily sales, revenue, and product performance from your pop-ups.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VendorSalesTrackerScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.launch),
                          label: const Text('Open Sales Tracker'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSalesOverviewCards(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'This Month',
            '\$0.00',
            Icons.calendar_month,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'This Week',
            '\$0.00',
            Icons.date_range,
            Colors.blue,
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
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics, color: Colors.blue, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Analytics Dashboard',
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
                        'View detailed performance insights, engagement analytics, and location data.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VendorAnalyticsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.launch),
                          label: const Text('Open Analytics Dashboard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildAnalyticsPreview(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsPreview() {
    return _analyticsStream == null || _postsStream == null
        ? const LoadingWidget(message: 'Loading analytics preview...')
        : StreamBuilder<Map<String, int>>(
            stream: _analyticsStream!,
            builder: (context, analyticsSnapshot) {
              return StreamBuilder<List<VendorPost>>(
                stream: _postsStream!,
                builder: (context, postsSnapshot) {
                  final posts = postsSnapshot.data ?? [];
                  final analytics = analyticsSnapshot.data ?? {};
                  final activePosts = posts.where((p) => p.isActive).length;
                  final happeningNow = posts.where((p) => p.isHappening).length;

                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _buildMetricCard(
                        'Total Views',
                        '${analytics['totalViews'] ?? 0}',
                        Icons.visibility,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'Favorites',
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
                        'Live Now',
                        '$happeningNow',
                        Icons.play_circle_fill,
                        Colors.orange,
                      ),
                    ],
                  );
                },
              );
            },
          );
  }

  Widget _buildItemsListTab() {
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
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory, color: Colors.purple, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Master Items List',
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
                    'Create and manage your master product catalog for consistent inventory tracking.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/vendor/products-management');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/vendor/products-management');
                          },
                          icon: const Icon(Icons.import_export),
                          label: const Text('Manage'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple,
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
          Expanded(
            child: _buildItemsPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Product Catalog',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create and manage your product catalog with unlimited items',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Build Your Product Catalog',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create products once, use across multiple markets\nwith premium unlimited catalog',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/vendor/products-management');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}