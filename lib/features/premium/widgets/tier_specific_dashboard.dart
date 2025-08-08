import 'package:flutter/material.dart';
import '../models/user_subscription.dart';
import '../services/vendor_growth_optimizer_service.dart';
import '../services/market_management_suite_service.dart';
import '../services/enterprise_analytics_service.dart';
import 'vendor_pro_dashboard.dart';
import 'market_organizer_pro_dashboard.dart';
import 'enterprise_dashboard.dart';

/// Tier-specific dashboard widget that displays appropriate premium features
/// based on the user's subscription tier
class TierSpecificDashboard extends StatefulWidget {
  final String userId;
  final UserSubscription subscription;

  const TierSpecificDashboard({
    super.key,
    required this.userId,
    required this.subscription,
  });

  @override
  State<TierSpecificDashboard> createState() => _TierSpecificDashboardState();
}

class _TierSpecificDashboardState extends State<TierSpecificDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _loadDashboardData();
  }

  void _initializeTabController() {
    final tabCount = _getTabCount();
    _tabController = TabController(length: tabCount, vsync: this);
  }

  int _getTabCount() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPro:
        return 4; // Overview, Search, Recommendations, Insights
      case SubscriptionTier.vendorPro:
        return 4; // Overview, Growth, Analytics, Reports
      case SubscriptionTier.marketOrganizerPro:
        return 5; // Overview, Markets, Vendors, Finance, Intelligence
      case SubscriptionTier.enterprise:
        return 6; // Overview, Analytics, Reporting, API, White-label, Settings
      case SubscriptionTier.free:
        return 1; // Upgrade prompt only
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Map<String, dynamic> data;
      switch (widget.subscription.tier) {
        case SubscriptionTier.shopperPro:
          data = {
            'tier': 'shopperPro',
            'userId': widget.userId,
            'enhancedSearchEnabled': true,
            'personalizedRecommendations': true,
            'favoriteVendors': [],
            'recentSearches': [],
            'seasonalInsights': {},
          };
          break;
        case SubscriptionTier.vendorPro:
          data = await VendorGrowthOptimizerService.getVendorGrowthDashboard(widget.userId);
          break;
        case SubscriptionTier.marketOrganizerPro:
          data = await MarketManagementSuiteService.getMultiMarketDashboard(widget.userId);
          break;
        case SubscriptionTier.enterprise:
          data = await EnterpriseAnalyticsService.getEnterpriseAnalyticsDashboard(widget.userId);
          break;
        case SubscriptionTier.free:
          data = {'tier': 'free', 'upgradeRequired': true};
          break;
      }

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_getTitleForTier()),
      backgroundColor: _getPrimaryColorForTier(),
      foregroundColor: Colors.white,
      bottom: widget.subscription.tier != SubscriptionTier.free
          ? TabBar(
              controller: _tabController,
              tabs: _buildTabs(),
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
            )
          : null,
    );
  }

  String _getTitleForTier() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPro:
        return 'Shopper Pro Dashboard';
      case SubscriptionTier.vendorPro:
        return 'Vendor Pro Dashboard';
      case SubscriptionTier.marketOrganizerPro:
        return 'Market Organizer Pro';
      case SubscriptionTier.enterprise:
        return 'Enterprise Analytics';
      case SubscriptionTier.free:
        return 'Premium Features';
    }
  }

  Color _getPrimaryColorForTier() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPro:
        return Colors.indigo.shade700;
      case SubscriptionTier.vendorPro:
        return Colors.green.shade700;
      case SubscriptionTier.marketOrganizerPro:
        return Colors.blue.shade700;
      case SubscriptionTier.enterprise:
        return Colors.purple.shade700;
      case SubscriptionTier.free:
        return Colors.grey.shade600;
    }
  }

  List<Widget> _buildTabs() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPro:
        return [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'Search+', icon: Icon(Icons.search)),
          const Tab(text: 'Recommendations', icon: Icon(Icons.recommend)),
          const Tab(text: 'Insights', icon: Icon(Icons.insights)),
        ];
      case SubscriptionTier.vendorPro:
        return [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'Growth', icon: Icon(Icons.trending_up)),
          const Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          const Tab(text: 'Reports', icon: Icon(Icons.assessment)),
        ];
      case SubscriptionTier.marketOrganizerPro:
        return [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'Markets', icon: Icon(Icons.store)),
          const Tab(text: 'Vendors', icon: Icon(Icons.people)),
          const Tab(text: 'Finance', icon: Icon(Icons.attach_money)),
          const Tab(text: 'Intelligence', icon: Icon(Icons.insights)),
        ];
      case SubscriptionTier.enterprise:
        return [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          const Tab(text: 'Reports', icon: Icon(Icons.assessment)),
          const Tab(text: 'API', icon: Icon(Icons.api)),
          const Tab(text: 'Branding', icon: Icon(Icons.palette)),
          const Tab(text: 'Settings', icon: Icon(Icons.settings)),
        ];
      default:
        return [];
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading premium dashboard...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (widget.subscription.tier == SubscriptionTier.free) {
      return _buildUpgradePrompt();
    }

    return TabBarView(
      controller: _tabController,
      children: _buildTabViews(),
    );
  }

  Widget _buildUpgradePrompt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_border,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 24),
          Text(
            'Unlock Premium Features',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose the plan that\'s right for your business',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildTierCards(),
        ],
      ),
    );
  }

  Widget _buildTierCards() {
    final tiers = [
      {
        'tier': SubscriptionTier.shopperPro,
        'title': 'Shopper Pro',
        'price': '\$4.00/month',
        'description': 'Enhanced search, unlimited favorites, personalized recommendations',
        'color': Colors.indigo,
        'features': [
          'Enhanced search & filtering',
          'Unlimited favorites',
          'Vendor following',
          'Personalized recommendations',
          'Exclusive deals access',
          'Priority notifications',
        ],
      },
      {
        'tier': SubscriptionTier.vendorPro,
        'title': 'Vendor Pro',
        'price': '\$19.99/month',
        'description': 'Full vendor analytics, unlimited markets, sales tracking',
        'color': Colors.green,
        'features': [
          'Full vendor analytics',
          'Unlimited markets',
          'Sales tracking',
          'Customer acquisition analysis',
          'Profit optimization',
          'Market expansion recommendations',
        ],
      },
      {
        'tier': SubscriptionTier.marketOrganizerPro,
        'title': 'Market Organizer Pro',
        'price': '\$49.99/month',
        'description': 'Multi-market management, vendor analytics, reporting',
        'color': Colors.blue,
        'features': [
          'Multi-market management',
          'Vendor analytics dashboard',
          'Financial reporting',
          'Vendor performance ranking',
          'Automated recruitment',
          'Budget planning tools',
        ],
      },
      {
        'tier': SubscriptionTier.enterprise,
        'title': 'Enterprise',
        'price': '\$199.99/month',
        'description': 'White-label, API access, custom reporting',
        'color': Colors.purple,
        'features': [
          'White-label analytics',
          'API access',
          'Custom reporting',
          'Custom branding',
          'Dedicated account manager',
          'Advanced data export',
        ],
      },
    ];

    return Column(
      children: tiers.map((tierData) => 
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildTierCard(tierData),
        ),
      ).toList(),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tierData) {
    final tier = tierData['tier'] as SubscriptionTier;
    final color = tierData['color'] as MaterialColor;

    return Card(
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.shade50, color.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevent overflow
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tierData['title'],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tierData['price'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tierData['description'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              ...((tierData['features'] as List<String>).take(3).map((feature) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _upgradeTo(tier),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Upgrade to ${tierData['title']}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabViews() {
    if (_dashboardData == null) {
      return [const SizedBox()];
    }

    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPro:
        return [
          ShopperProOverviewTab(data: _dashboardData!),
          ShopperProSearchTab(data: _dashboardData!),
          ShopperProRecommendationsTab(data: _dashboardData!),
          ShopperProInsightsTab(data: _dashboardData!),
        ];
      case SubscriptionTier.vendorPro:
        return [
          VendorProOverviewTab(data: _dashboardData!),
          VendorProGrowthTab(data: _dashboardData!),
          VendorProAnalyticsTab(data: _dashboardData!),
          VendorProReportsTab(data: _dashboardData!),
        ];
      case SubscriptionTier.marketOrganizerPro:
        return [
          MarketOrganizerOverviewTab(data: _dashboardData!),
          MarketOrganizerMarketsTab(data: _dashboardData!),
          MarketOrganizerVendorsTab(data: _dashboardData!),
          MarketOrganizerFinanceTab(data: _dashboardData!),
          MarketOrganizerIntelligenceTab(data: _dashboardData!),
        ];
      case SubscriptionTier.enterprise:
        return [
          EnterpriseOverviewTab(data: _dashboardData!),
          EnterpriseAnalyticsTab(data: _dashboardData!),
          EnterpriseReportsTab(data: _dashboardData!),
          EnterpriseApiTab(data: _dashboardData!),
          EnterpriseBrandingTab(data: _dashboardData!),
          EnterpriseSettingsTab(data: _dashboardData!),
        ];
      default:
        return [const SizedBox()];
    }
  }

  void _upgradeTo(SubscriptionTier tier) {
    Navigator.pushNamed(
      context,
      '/premium/upgrade',
      arguments: {
        'targetTier': tier,
        'currentSubscription': widget.subscription,
      },
    );
  }
}

// Individual tab widgets for different tiers and sections

// Shopper Pro tabs
class ShopperProOverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const ShopperProOverviewTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Shopper Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            'Enhanced Search',
            'Find exactly what you\'re looking for with advanced filters',
            Icons.search,
            Colors.indigo,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            'Unlimited Favorites',
            'Save all your favorite vendors and markets',
            Icons.favorite,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            'Personalized Recommendations',
            'Discover new vendors based on your preferences',
            Icons.recommend,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            'Exclusive Access',
            'Get priority access to special events and deals',
            Icons.star,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String description, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
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
}

class ShopperProSearchTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const ShopperProSearchTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Enhanced Search Features - Coming Soon'),
    );
  }
}

class ShopperProRecommendationsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const ShopperProRecommendationsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Personalized Recommendations - Coming Soon'),
    );
  }
}

class ShopperProInsightsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const ShopperProInsightsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Shopping Insights - Coming Soon'),
    );
  }
}

// Individual tab widgets for different tiers and sections

class VendorProOverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const VendorProOverviewTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return VendorProDashboard(data: data);
  }
}

class VendorProGrowthTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const VendorProGrowthTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Opportunities',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMarketExpansionCard(context),
          const SizedBox(height: 16),
          _buildCustomerAcquisitionCard(context),
          const SizedBox(height: 16),
          _buildProfitOptimizationCard(context),
        ],
      ),
    );
  }

  Widget _buildMarketExpansionCard(BuildContext context) {
    final expansionData = data['marketExpansion'] as Map<String, dynamic>?;
    final opportunities = expansionData?['opportunities'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Market Expansion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${opportunities.length} expansion opportunities identified',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...opportunities.take(2).map((opportunity) => 
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(opportunity['marketName'] ?? 'Unknown Market'),
                subtitle: Text('Expansion Score: ${opportunity['expansionScore']?.toStringAsFixed(1) ?? '0'}'),
                trailing: Text(
                  '\$${opportunity['estimatedRevenue']?.toStringAsFixed(0) ?? '0'}/mo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAcquisitionCard(BuildContext context) {
    final cacData = data['customerAcquisition'] as Map<String, dynamic>?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Customer Acquisition',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CAC', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '\$${cacData?['cac']?.toStringAsFixed(2) ?? '0.00'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLV', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '\$${cacData?['clv']?.toStringAsFixed(2) ?? '0.00'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Performance', style: Theme.of(context).textTheme.bodySmall),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPerformanceColor(cacData?['performance']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        cacData?['performance'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitOptimizationCard(BuildContext context) {
    final profitData = data['profitOptimization'] as Map<String, dynamic>?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Profit Optimization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Margin', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '${profitData?['currentMargin']?.toStringAsFixed(1) ?? '0.0'}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potential Increase', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '+\$${profitData?['potentialIncrease']?.toStringAsFixed(0) ?? '0'}/mo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (profitData?['topStrategy'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Top Strategy: ${profitData!['topStrategy']['strategy'] ?? 'Optimize pricing'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPerformanceColor(String? performance) {
    switch (performance) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.blue;
      case 'Fair':
        return Colors.orange;
      case 'Needs Improvement':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class VendorProAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const VendorProAnalyticsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Advanced Analytics View - Coming Soon'),
    );
  }
}

class VendorProReportsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const VendorProReportsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Custom Reports View - Coming Soon'),
    );
  }
}

// Market Organizer Pro tabs
class MarketOrganizerOverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const MarketOrganizerOverviewTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MarketOrganizerProDashboard(data: data);
  }
}

class MarketOrganizerMarketsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const MarketOrganizerMarketsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Multi-Market Management View - Coming Soon'),
    );
  }
}

class MarketOrganizerVendorsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const MarketOrganizerVendorsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Vendor Ranking & Management View - Coming Soon'),
    );
  }
}

class MarketOrganizerFinanceTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const MarketOrganizerFinanceTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Financial Forecasting View - Coming Soon'),
    );
  }
}

class MarketOrganizerIntelligenceTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const MarketOrganizerIntelligenceTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Market Intelligence View - Coming Soon'),
    );
  }
}

// Enterprise tabs
class EnterpriseOverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseOverviewTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return EnterpriseDashboard(data: data);
  }
}

class EnterpriseAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseAnalyticsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Enterprise Analytics View - Coming Soon'),
    );
  }
}

class EnterpriseReportsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseReportsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Custom Enterprise Reports View - Coming Soon'),
    );
  }
}

class EnterpriseApiTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseApiTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('API Management View - Coming Soon'),
    );
  }
}

class EnterpriseBrandingTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseBrandingTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('White-Label Branding View - Coming Soon'),
    );
  }
}

class EnterpriseSettingsTab extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseSettingsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Enterprise Settings View - Coming Soon'),
    );
  }
}