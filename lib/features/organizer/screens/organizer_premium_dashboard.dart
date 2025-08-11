import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/organizer/screens/organizer_analytics_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final organizerId = authState.user.uid;
      _marketPostsStream = _getMarketPosts(organizerId);
      _marketAnalyticsStream = _getMarketAnalytics(organizerId);
      debugPrint('🔍 Organizer premium dashboard initialized for organizer: $organizerId');
    }
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
            Tab(text: 'Communications', icon: Icon(Icons.campaign)),
            Tab(text: 'Vendor Discovery', icon: Icon(Icons.search)),
            Tab(text: 'Vendor Management', icon: Icon(Icons.people_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAnalyticsTab(),
          _buildCommunicationsTab(),
          _buildVendorDiscoveryTab(),
          _buildVendorManagementTab(),
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
      '🔍 Vendor Discovery Engine - Find and invite qualified vendors with smart matching',
      '📊 Market Performance Analytics - Track vendor performance, revenue trends',
      '📧 Bulk Communication Suite - Professional messaging to all vendors at once',
      '👥 Vendor Management Dashboard - Application scoring, performance ranking',
      '💰 Revenue Analytics - Commission tracking, financial reporting',
      '📈 Growth Insights - Market expansion opportunities and trends',
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
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'This Month Revenue',
            '\$0.00',
            Icons.attach_money,
            Colors.green,
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
                              color: Colors.deepPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics, color: Colors.deepPurple, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Market Analytics Dashboard',
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
                        'View detailed market performance, vendor analytics, and revenue insights.',
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
                                builder: (context) => const OrganizerAnalyticsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.launch),
                          label: const Text('Open Analytics Dashboard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
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

  Widget _buildVendorDiscoveryTab() {
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
                        child: const Icon(Icons.search, color: Colors.deepPurple, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Vendor Discovery Engine',
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
                    'Find and invite qualified vendors based on intelligent matching algorithms.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.go('/organizer/vendor-discovery');
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Open Vendor Discovery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Discovery Features Preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discovery Features',
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
                        'Smart Matching',
                        'Find vendors based on your market categories and requirements',
                        Icons.psychology,
                        Colors.purple,
                      ),
                      _buildFeatureCard(
                        'Vendor Analytics',
                        'See vendor ratings, experience, and performance metrics',
                        Icons.analytics,
                        Colors.blue,
                      ),
                      _buildFeatureCard(
                        'Bulk Invitations',
                        'Send invitations to multiple qualified vendors at once',
                        Icons.send,
                        Colors.green,
                      ),
                      _buildFeatureCard(
                        'Response Tracking',
                        'Track invitation responses and follow-up with vendors',
                        Icons.track_changes,
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
                  final totalEvents = posts.length;
                  final totalRevenue = analytics['totalRevenue'] ?? 0;

                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _buildMetricCard(
                        'Total Vendors',
                        '$totalVendors',
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'Active Markets',
                        '$activeMarkets',
                        Icons.store,
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'Total Events',
                        '$totalEvents',
                        Icons.event,
                        Colors.orange,
                      ),
                      _buildMetricCard(
                        'Revenue',
                        '\$${totalRevenue.toString()}',
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ],
                  );
                },
              );
            },
          );
  }

  Widget _buildVendorManagementTab() {
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
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.people_alt, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Vendor Management Suite',
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
                    'Advanced tools for managing vendor applications, performance tracking, and market optimization.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showComingSoonDialog();
                          },
                          icon: const Icon(Icons.score),
                          label: const Text('Application Scoring'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showComingSoonDialog();
                          },
                          icon: const Icon(Icons.trending_up),
                          label: const Text('Performance'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
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
            child: _buildVendorPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendor Applications & Performance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Advanced tools for vendor management coming soon',
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
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Vendor Data Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start managing vendors to see\napplication scoring and performance tracking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showComingSoonDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vendor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon!'),
        content: const Text(
          'Advanced vendor management features are currently under development. They will include:\n\n• Application scoring system\n• Performance tracking\n• Automated vendor communications\n• Market optimization tools',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
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

  Widget _buildCommunicationsTab() {
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
                          'Vendor Communication Suite',
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
                    'Professional bulk messaging system to communicate efficiently with all your vendors.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.go('/organizer/vendor-communications');
                      },
                      icon: const Icon(Icons.campaign),
                      label: const Text('Open Communication Suite'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Communication Features Preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Communication Features',
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
                        'Bulk Messaging',
                        'Send professional messages to hundreds of vendors at once',
                        Icons.mail_outline,
                        Colors.blue,
                      ),
                      _buildFeatureCard(
                        'Message Templates',
                        'Pre-built templates for events, policies, and announcements',
                        Icons.article,
                        Colors.green,
                      ),
                      _buildFeatureCard(
                        'Smart Targeting',
                        'Target vendors by market, category, or custom selection',
                        Icons.filter_list,
                        Colors.orange,
                      ),
                      _buildFeatureCard(
                        'Analytics & Tracking',
                        'Monitor delivery rates and vendor engagement metrics',
                        Icons.analytics,
                        Colors.purple,
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
}