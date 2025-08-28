import 'package:flutter/material.dart';
import '../models/user_subscription.dart';
import '../services/vendor_growth_optimizer_service.dart';
import '../services/market_management_suite_service.dart';
import '../services/enterprise_analytics_service.dart';
import 'vendor_pro_dashboard.dart';
import 'market_organizer_pro_dashboard.dart';
import 'enterprise_dashboard.dart';
import '../../organizer/screens/vendor_directory_screen.dart';
// Additional imports for premium shopper features
import '../../shared/services/search_history_service.dart';
import '../../shopper/services/enhanced_search_service.dart';
import '../../vendor/services/vendor_following_service.dart';
import '../../shared/services/favorites_service.dart';
import '../../shared/models/user_favorite.dart';

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
      case SubscriptionTier.shopperPremium:
        return 4; // Overview, Search, Recommendations, Insights
      case SubscriptionTier.vendorPremium:
        return 4; // Overview, Growth, Analytics, Reports
      case SubscriptionTier.marketOrganizerPremium:
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
        case SubscriptionTier.shopperPremium:
          data = {
            'tier': 'shopperPremium',
            'userId': widget.userId,
            'enhancedSearchEnabled': true,
            'personalizedRecommendations': true,
            'favoriteVendors': [],
            'recentSearches': [],
            'seasonalInsights': {},
          };
          break;
        case SubscriptionTier.vendorPremium:
          data = await VendorGrowthOptimizerService.getVendorGrowthDashboard(widget.userId);
          break;
        case SubscriptionTier.marketOrganizerPremium:
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
      case SubscriptionTier.shopperPremium:
        return 'Shopper Pro Dashboard';
      case SubscriptionTier.vendorPremium:
        return 'Vendor Pro Dashboard';
      case SubscriptionTier.marketOrganizerPremium:
        return 'Market Organizer Pro';
      case SubscriptionTier.enterprise:
        return 'Enterprise Analytics';
      case SubscriptionTier.free:
        return 'Premium Features';
    }
  }

  Color _getPrimaryColorForTier() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPremium:
        return Colors.indigo.shade700;
      case SubscriptionTier.vendorPremium:
        return Colors.green.shade700;
      case SubscriptionTier.marketOrganizerPremium:
        return Colors.blue.shade700;
      case SubscriptionTier.enterprise:
        return Colors.purple.shade700;
      case SubscriptionTier.free:
        return Colors.grey.shade600;
    }
  }

  List<Widget> _buildTabs() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.shopperPremium:
        return [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'Search+', icon: Icon(Icons.search)),
          const Tab(text: 'Recommendations', icon: Icon(Icons.recommend)),
          const Tab(text: 'Insights', icon: Icon(Icons.insights)),
        ];
      case SubscriptionTier.vendorPremium:
        return [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'Sales Tracker', icon: Icon(Icons.attach_money)),
          const Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          const Tab(text: 'Items List', icon: Icon(Icons.inventory)),
        ];
      case SubscriptionTier.marketOrganizerPremium:
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
        'tier': SubscriptionTier.shopperPremium,
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
        'tier': SubscriptionTier.vendorPremium,
        'title': 'Vendor Pro',
        'price': '\$29.00/month',
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
        'tier': SubscriptionTier.marketOrganizerPremium,
        'title': 'Market Organizer Pro',
        'price': '\$69.00/month',
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
      case SubscriptionTier.shopperPremium:
        return [
          ShopperProOverviewTab(data: _dashboardData!),
          ShopperProSearchTab(data: _dashboardData!),
          ShopperProRecommendationsTab(data: _dashboardData!),
          ShopperProInsightsTab(data: _dashboardData!),
        ];
      case SubscriptionTier.vendorPremium:
        return [
          VendorProOverviewTab(data: _dashboardData!),
          VendorProGrowthTab(data: _dashboardData!),
          VendorProAnalyticsTab(data: _dashboardData!),
          VendorProReportsTab(data: _dashboardData!),
        ];
      case SubscriptionTier.marketOrganizerPremium:
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
                color: color.withValues(alpha: 0.1),
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

class ShopperProSearchTab extends StatefulWidget {
  final Map<String, dynamic> data;

  const ShopperProSearchTab({super.key, required this.data});

  @override
  State<ShopperProSearchTab> createState() => _ShopperProSearchTabState();
}

class _ShopperProSearchTabState extends State<ShopperProSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _selectedCategories = [];
  List<Map<String, dynamic>> _savedSearches = [];
  List<String> _recentSearches = [];
  List<String> _searchSuggestions = [];
  bool _isLoading = false;
  String? _selectedLocation;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSearchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchData() async {
    setState(() => _isLoading = true);
    try {
      final shopperId = widget.data['userId'] as String;
      
      final futures = await Future.wait([
        SearchHistoryService.getSavedSearches(shopperId),
        SearchHistoryService.getSearchHistory(shopperId: shopperId, limit: 15),
      ]);
      
      setState(() {
        _savedSearches = futures[0] as List<Map<String, dynamic>>;
        final searchHistory = futures[1] as List<Map<String, dynamic>>;
        _recentSearches = searchHistory
            .map((search) => search['query'] as String)
            .where((query) => query.isNotEmpty)
            .toList();
        _searchSuggestions = _recentSearches.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading search data: $e');
    }
  }

  Future<void> _performAdvancedSearch() async {
    if (_searchController.text.trim().isEmpty && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter search terms or select categories')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final shopperId = widget.data['userId'] as String;
      
      // Use the advanced search method with all filters
      final results = await EnhancedSearchService.advancedSearch(
        shopperId: shopperId,
        productQuery: _searchController.text.trim(),
        categories: _selectedCategories,
        location: _selectedLocation,
      );
      
      if (mounted) {
        _showSearchResults(results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSearchResults(List<Map<String, dynamic>> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search Results (${results.length})',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Results
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search filters',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: results.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return _buildSearchResultCard(result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: result['profileImageUrl'] != null
                      ? ClipOval(
                          child: Image.network(
                            result['profileImageUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.store,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.store,
                          color: Colors.indigo.shade700,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['businessName'] ?? 'Unknown Business',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result['location'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              result['location'],
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (result['rating'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          result['rating'].toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (result['description'] != null || result['bio'] != null) ...[
              const SizedBox(height: 12),
              Text(
                result['description'] ?? result['bio'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (result['categories'] != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (result['categories'] as List<dynamic>)
                    .take(4)
                    .map((cat) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Text(
                            cat.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to vendor profile
                      Navigator.pushNamed(
                        context,
                        '/vendor/profile',
                        arguments: {'vendorId': result['vendorId']},
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo.shade700,
                      side: BorderSide(color: Colors.indigo.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await FavoritesService.addFavorite(
                          userId: widget.data['userId'] as String,
                          itemId: result['vendorId'],
                          type: FavoriteType.vendor,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to favorites!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to add favorite: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.favorite, size: 16),
                    label: const Text('Favorite'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentSearch() async {
    if (_searchController.text.trim().isEmpty && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save - add search terms or categories')),
      );
      return;
    }
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save Search'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Search name',
                  hintText: 'e.g. "Fresh Produce in Virginia-Highland"',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Text(
                'Current search:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (_searchController.text.isNotEmpty)
                Text('Query: ${_searchController.text}'),
              if (_selectedCategories.isNotEmpty)
                Text('Categories: ${_selectedCategories.join(", ")}'),
              if (_selectedLocation != null)
                Text('Location: $_selectedLocation'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    
    if (name == null || name.isEmpty) return;
    
    try {
      final shopperId = widget.data['userId'] as String;
      
      await SearchHistoryService.saveSearch(
        shopperId: shopperId,
        name: name,
        query: _searchController.text.trim(),
        searchType: _selectedCategories.isNotEmpty 
            ? SearchType.categorySearch 
            : SearchType.productSearch,
        categories: _selectedCategories,
        location: _selectedLocation,
      );
      
      _loadSearchData(); // Refresh saved searches
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Search saved successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Scroll to saved searches section
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save search: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadSavedSearch(Map<String, dynamic> search) {
    setState(() {
      _searchController.text = search['query'] ?? '';
      _selectedCategories.clear();
      if (search['categories'] != null) {
        _selectedCategories.addAll(
          List<String>.from(search['categories'] as List<dynamic>),
        );
      }
      _selectedLocation = search['location'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSearchData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Search Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search+ Premium',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Advanced search with multiple filters and saved searches',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatChip('${_savedSearches.length}', 'Saved', Colors.white24),
                      const SizedBox(width: 12),
                      _buildStatChip('${_recentSearches.length}', 'Recent', Colors.white24),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Advanced Search Interface
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Search',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Search Input with Suggestions
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products, vendors, or keywords...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty || _selectedCategories.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.save_alt, color: Colors.indigo),
                                onPressed: _saveCurrentSearch,
                                tooltip: 'Save this search',
                              ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedCategories.clear();
                                  _selectedLocation = null;
                                  _showSuggestions = false;
                                });
                              },
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.indigo.shade300, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _showSuggestions = value.isNotEmpty && _searchSuggestions.isNotEmpty;
                        });
                      },
                      onSubmitted: (_) => _performAdvancedSearch(),
                    ),
                    
                    // Search Suggestions
                    if (_showSuggestions && _searchSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggestions from your search history:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _searchSuggestions.map((suggestion) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchController.text = suggestion;
                                      _showSuggestions = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.indigo.shade200),
                                    ),
                                    child: Text(
                                      suggestion,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.indigo.shade700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Location Filter
                    DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: InputDecoration(
                        labelText: 'Location (Optional)',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any location'),
                        ),
                        ...['Atlanta', 'Decatur', 'Virginia-Highland', 'Inman Park',
                        'Little Five Points', 'Piedmont Park', 'Buckhead', 'Midtown']
                            .map((location) => DropdownMenuItem<String>(
                              value: location,
                              child: Text(location),
                            )),
                      ],
                      onChanged: (value) => setState(() => _selectedLocation = value),
                    ),
                    const SizedBox(height: 20),
                    
                    // Category Multi-Select
                    Text(
                      'Categories (${_selectedCategories.length} selected)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EnhancedSearchService.vendorCategories.take(20).map((category) {
                          final isSelected = _selectedCategories.contains(category);
                          return FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                            },
                            selectedColor: Colors.indigo.shade100,
                            checkmarkColor: Colors.indigo.shade700,
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: isSelected ? Colors.indigo.shade300 : Colors.grey.shade300,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Search Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _performAdvancedSearch,
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search, size: 20),
                        label: Text(
                          _isLoading ? 'Searching...' : 'Search Now',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Saved Searches Section
            if (_savedSearches.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.bookmark, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Saved Searches (${_savedSearches.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _savedSearches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final search = _savedSearches[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.bookmark,
                          color: Colors.indigo.shade700,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        search['name'] ?? 'Unnamed Search',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (search['query'] != null && (search['query'] as String).isNotEmpty)
                            Text('Query: ${search['query']}'),
                          if (search['categories'] != null && (search['categories'] as List).isNotEmpty)
                            Text('Categories: ${(search['categories'] as List).join(", ")}'),
                          if (search['location'] != null)
                            Text('Location: ${search['location']}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            onPressed: () => _loadSavedSearch(search),
                            tooltip: 'Load this search',
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.green),
                            onPressed: () async {
                              try {
                                setState(() => _isLoading = true);
                                final results = await EnhancedSearchService.executeSavedSearch(
                                  shopperId: widget.data['userId'] as String,
                                  savedSearchId: search['id'],
                                );
                                if (mounted) {
                                  _showSearchResults(results);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Search failed: $e')),
                                  );
                                }
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                            tooltip: 'Run this search',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Search'),
                                  content: Text('Delete "${search['name']}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                try {
                                  await SearchHistoryService.deleteSavedSearch(search['id']);
                                  _loadSearchData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Search deleted')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            tooltip: 'Delete this search',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Recent Searches Section
            if (_recentSearches.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.history, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Searches',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tap any recent search to use it again',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentSearches.take(12).map((query) {
                          return ActionChip(
                            label: Text(query),
                            onPressed: () {
                              setState(() {
                                _searchController.text = query;
                                _showSuggestions = false;
                              });
                              _performAdvancedSearch();
                            },
                            avatar: const Icon(Icons.history, size: 16),
                            backgroundColor: Colors.orange.shade50,
                            side: BorderSide(color: Colors.orange.shade300),
                            labelStyle: TextStyle(color: Colors.orange.shade700),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Loading State
            if (_isLoading && _savedSearches.isEmpty && _recentSearches.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatChip(String value, String label, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ShopperProRecommendationsTab extends StatefulWidget {
  final Map<String, dynamic> data;

  const ShopperProRecommendationsTab({super.key, required this.data});

  @override
  State<ShopperProRecommendationsTab> createState() => _ShopperProRecommendationsTabState();
}

class _ShopperProRecommendationsTabState extends State<ShopperProRecommendationsTab> {
  List<Map<String, dynamic>> _followedVendors = [];
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _favoritesBasedRecs = [];
  List<String> _trendingCategories = [];
  bool _isLoading = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final shopperId = widget.data['userId'] as String;
      
      final futures = await Future.wait([
        VendorFollowingService.getFollowedVendors(shopperId),
        EnhancedSearchService.getPersonalizedRecommendations(
          shopperId: shopperId,
          limit: 15,
        ),
        EnhancedSearchService.getTrendingCategories(),
        _getFavoritesBasedRecommendations(shopperId),
      ]);
      
      setState(() {
        _followedVendors = futures[0] as List<Map<String, dynamic>>;
        _recommendations = futures[1] as List<Map<String, dynamic>>;
        _trendingCategories = futures[2] as List<String>;
        _favoritesBasedRecs = futures[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading recommendations: $e');
    }
  }

  List<Map<String, dynamic>> _getDemoRecommendations() {
    return [
      {
        'vendorId': 'rec1',
        'businessName': 'Sunrise Bakery',
        'categories': ['Baked Goods', 'Coffee & Tea'],
        'bio': 'Fresh baked goods and artisan coffee every morning',
        'location': 'Virginia-Highland, Atlanta',
        'rating': 4.9,
        'followerCount': 203,
      },
      {
        'vendorId': 'rec2',
        'businessName': 'Garden Fresh Organics',
        'categories': ['Fresh Produce', 'Organic Vegetables'],
        'bio': 'Certified organic produce from local farms',
        'location': 'Inman Park, Atlanta',
        'rating': 4.7,
        'followerCount': 156,
      },
      {
        'vendorId': 'rec3',
        'businessName': 'Wildflower Honey',
        'categories': ['Honey', 'Local Products'],
        'bio': 'Raw local honey and beeswax products',
        'location': 'Little Five Points, Atlanta',
        'rating': 4.8,
        'followerCount': 98,
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _getFavoritesBasedRecommendations(String shopperId) async {
    try {
      // Get categories from followed vendors
      final followedVendors = await VendorFollowingService.getFollowedVendors(shopperId);
      
      final allCategories = <String>{};
      for (final vendor in followedVendors) {
        final categories = vendor['categories'] as List<dynamic>? ?? [];
        allCategories.addAll(categories.cast<String>());
      }
      
      if (allCategories.isEmpty) {
        return _getDemoRecommendations();
      }
      
      // Search for vendors in similar categories
      final recommendations = await EnhancedSearchService.searchVendorsByCategories(
        categories: allCategories.take(5).toList(),
        shopperId: shopperId,
        limit: 10,
      );
      
      // Filter out already followed vendors
      final followedIds = followedVendors.map((v) => v['vendorId']).toSet();
      return recommendations
          .where((vendor) => !followedIds.contains(vendor['vendorId']))
          .toList();
    } catch (e) {
      debugPrint('Error getting favorites-based recommendations: $e');
      return _getDemoRecommendations();
    }
  }

  List<Map<String, dynamic>> _getFilteredRecommendations() {
    switch (_selectedFilter) {
      case 'following':
        return _favoritesBasedRecs;
      case 'trending':
        return _recommendations.where((vendor) {
          final categories = vendor['categories'] as List<dynamic>? ?? [];
          return categories.any((cat) => _trendingCategories.contains(cat));
        }).toList();
      case 'all':
      default:
        final allRecs = <String, Map<String, dynamic>>{};
        
        // Add personalized recommendations
        for (final rec in _recommendations) {
          allRecs[rec['vendorId']] = {...rec, 'source': 'personalized'};
        }
        
        // Add favorites-based recommendations
        for (final rec in _favoritesBasedRecs) {
          if (!allRecs.containsKey(rec['vendorId'])) {
            allRecs[rec['vendorId']] = {...rec, 'source': 'similar_to_favorites'};
          }
        }
        
        return allRecs.values.toList();
    }
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor, {String? source}) {
    final categories = vendor['categories'] as List<dynamic>? ?? [];
    final rating = vendor['rating'] as double? ?? 0.0;
    final followerCount = vendor['followerCount'] as int? ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: vendor['profileImageUrl'] != null
                      ? ClipOval(
                          child: Image.network(
                            vendor['profileImageUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.store,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.store,
                          color: Colors.indigo.shade700,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor['businessName'] ?? vendor['vendorName'] ?? 'Unknown Business',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (vendor['location'] != null)
                        Text(
                          vendor['location'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      if (source != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            source == 'personalized' 
                                ? 'For You'
                                : source == 'similar_to_favorites'
                                    ? 'Similar to Favorites'
                                    : source,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (rating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    if (followerCount > 0)
                      Text(
                        '$followerCount followers',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (vendor['bio'] != null && (vendor['bio'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                vendor['bio'],
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: categories.take(4).map((category) {
                  final isTrending = _trendingCategories.contains(category);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTrending ? Colors.orange.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: isTrending ? Border.all(color: Colors.orange.shade300) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTrending)
                          const Icon(
                            Icons.trending_up,
                            size: 12,
                            color: Colors.orange,
                          ),
                        if (isTrending) const SizedBox(width: 4),
                        Text(
                          category.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isTrending ? FontWeight.bold : FontWeight.normal,
                            color: isTrending ? Colors.orange.shade700 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await VendorFollowingService.followVendor(
                          shopperId: widget.data['userId'] as String,
                          vendorId: vendor['vendorId'],
                          vendorName: vendor['businessName'] ?? vendor['vendorName'] ?? '',
                          isPremium: true,
                        );
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vendor followed!')),
                          );
                          _loadRecommendations(); // Refresh recommendations
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to follow: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Follow'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo.shade700,
                      side: BorderSide(color: Colors.indigo.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to vendor profile
                      Navigator.pushNamed(
                        context,
                        '/vendor/profile',
                        arguments: {'vendorId': vendor['vendorId']},
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _recommendations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredRecommendations = _getFilteredRecommendations();

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Stats
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalized for You',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on your preferences and followed vendors',
                            style: TextStyle(color: Colors.indigo.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_followedVendors.length}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        Text(
                          'Following',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Recommendations', filteredRecommendations.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('following', 'Similar to Following', _favoritesBasedRecs.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('trending', 'Trending Now', 
                    _recommendations.where((vendor) {
                      final categories = vendor['categories'] as List<dynamic>? ?? [];
                      return categories.any((cat) => _trendingCategories.contains(cat));
                    }).length),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Trending Categories Section
            if (_trendingCategories.isNotEmpty) ...[
              Text(
                'Trending Categories',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _trendingCategories.take(8).map((category) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(category),
                        avatar: const Icon(Icons.trending_up, size: 16),
                        backgroundColor: Colors.orange.shade100,
                        labelStyle: TextStyle(color: Colors.orange.shade700),
                        onPressed: () async {
                          try {
                            setState(() => _isLoading = true);
                            final results = await EnhancedSearchService.searchVendorsByCategories(
                              categories: [category],
                              shopperId: widget.data['userId'] as String,
                            );
                            
                            if (mounted) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => DraggableScrollableSheet(
                                  expand: false,
                                  builder: (context, scrollController) => Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$category Vendors (${results.length})',
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: ListView.builder(
                                            controller: scrollController,
                                            itemCount: results.length,
                                            itemBuilder: (context, index) {
                                              return _buildVendorCard(results[index]);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Search failed: $e')),
                              );
                            }
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Recommendations List
            if (filteredRecommendations.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.recommend,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recommendations available',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow some vendors to get personalized recommendations',
                      style: TextStyle(color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: filteredRecommendations.map((vendor) {
                  return _buildVendorCard(vendor, source: vendor['source']);
                }).toList(),
              ),
              
            // Loading indicator at bottom
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
        }
      },
      selectedColor: Colors.indigo.shade100,
      checkmarkColor: Colors.indigo.shade700,
    );
  }
}

class ShopperProInsightsTab extends StatefulWidget {
  final Map<String, dynamic> data;

  const ShopperProInsightsTab({super.key, required this.data});

  @override
  State<ShopperProInsightsTab> createState() => _ShopperProInsightsTabState();
}

class _ShopperProInsightsTabState extends State<ShopperProInsightsTab> {
  Map<String, dynamic> _searchAnalytics = {};
  Map<String, int> _favoriteCounts = {};
  List<Map<String, dynamic>> _followedVendors = [];
  List<String> _trendingCategories = [];
  bool _isLoading = false;
  String _selectedPeriod = '30'; // days

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    try {
      final shopperId = widget.data['userId'] as String;
      
      final futures = await Future.wait([
        SearchHistoryService.getSearchAnalytics(shopperId),
        FavoritesService.getFavoriteCounts(shopperId),
        VendorFollowingService.getFollowedVendors(shopperId),
        EnhancedSearchService.getTrendingCategories(days: int.parse(_selectedPeriod)),
      ]);
      
      setState(() {
        _searchAnalytics = futures[0] as Map<String, dynamic>;
        _favoriteCounts = futures[1] as Map<String, int>;
        _followedVendors = futures[2] as List<Map<String, dynamic>>;
        _trendingCategories = futures[3] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading insights: $e');
    }
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    String? trend,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          value,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: trend.startsWith('+') ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trend,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trend.startsWith('+') ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget chart,
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTypeChart() {
    final searchesByType = _searchAnalytics['searchesByType'] as Map<String, int>? ?? {};
    
    if (searchesByType.isEmpty) {
      return const Center(
        child: Text('No search data available'),
      );
    }

    final total = searchesByType.values.fold<int>(0, (sum, count) => sum + count);
    
    return Column(
      children: searchesByType.entries.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        final color = _getSearchTypeColor(entry.key);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSearchTypeLabel(entry.key),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${entry.value} searches',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getSearchTypeColor(String type) {
    switch (type) {
      case 'productSearch':
        return Colors.blue;
      case 'categorySearch':
        return Colors.green;
      case 'vendorSearch':
        return Colors.orange;
      case 'locationSearch':
        return Colors.purple;
      case 'combinedSearch':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getSearchTypeLabel(String type) {
    switch (type) {
      case 'productSearch':
        return 'Product Search';
      case 'categorySearch':
        return 'Category Search';
      case 'vendorSearch':
        return 'Vendor Search';
      case 'locationSearch':
        return 'Location Search';
      case 'combinedSearch':
        return 'Advanced Search';
      default:
        return type;
    }
  }

  Widget _buildTopQueriesChart() {
    final topQueries = _searchAnalytics['topQueries'] as Map<String, int>? ?? {};
    
    if (topQueries.isEmpty) {
      return const Center(
        child: Text('No search queries recorded'),
      );
    }

    final maxCount = topQueries.values.fold<int>(0, (max, count) => count > max ? count : max);
    
    return Column(
      children: topQueries.entries.take(8).map((entry) {
        final percentage = maxCount > 0 ? (entry.value / maxCount) : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityCalendar() {
    final searchesByDay = _searchAnalytics['searchesByDay'] as Map<String, int>? ?? {};
    
    if (searchesByDay.isEmpty) {
      return const Center(
        child: Text('No activity data available'),
      );
    }

    final now = DateTime.now();
    final days = List.generate(30, (index) {
      final date = now.subtract(Duration(days: 29 - index));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return {
        'date': date,
        'count': searchesByDay[dateKey] ?? 0,
      };
    });
    
    final maxCount = days.fold<int>(0, (max, day) => 
      (day['count'] as int) > max ? (day['count'] as int) : max);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final count = day['count'] as int;
        final intensity = maxCount > 0 ? (count / maxCount) : 0.0;
        
        return Container(
          decoration: BoxDecoration(
            color: intensity > 0 
                ? Colors.indigo.shade200.withValues(alpha: 0.3 + (intensity * 0.7))
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              (day['date'] as DateTime).day.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: intensity > 0.5 ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _searchAnalytics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalSearches = _searchAnalytics['totalSearches'] as int? ?? 0;
    final averageResults = _searchAnalytics['averageResultsPerSearch'] as double? ?? 0.0;
    final lastSearchDate = _searchAnalytics['lastSearchDate'] as DateTime?;
    
    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Shopping Insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  items: const [
                    DropdownMenuItem(value: '7', child: Text('7 days')),
                    DropdownMenuItem(value: '30', child: Text('30 days')),
                    DropdownMenuItem(value: '90', child: Text('90 days')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPeriod = value);
                      _loadInsights();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Key Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildInsightCard(
                  title: 'Total Searches',
                  value: totalSearches.toString(),
                  icon: Icons.search,
                  color: Colors.blue,
                  subtitle: lastSearchDate != null 
                      ? 'Last: ${_formatDate(lastSearchDate)}'
                      : 'No searches yet',
                ),
                _buildInsightCard(
                  title: 'Avg Results',
                  value: averageResults.toStringAsFixed(1),
                  icon: Icons.analytics,
                  color: Colors.green,
                  subtitle: 'Per search query',
                ),
                _buildInsightCard(
                  title: 'Following',
                  value: _followedVendors.length.toString(),
                  icon: Icons.favorite,
                  color: Colors.red,
                  subtitle: 'Vendors you follow',
                  onTap: () {
                    // Navigate to following list
                    Navigator.pushNamed(context, '/following');
                  },
                ),
                _buildInsightCard(
                  title: 'Favorites',
                  value: (_favoriteCounts.values.fold<int>(0, (sum, count) => sum + count)).toString(),
                  icon: Icons.bookmark,
                  color: Colors.orange,
                  subtitle: '${_favoriteCounts['vendors'] ?? 0} vendors, ${_favoriteCounts['markets'] ?? 0} markets',
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Search Activity Calendar
            _buildChartCard(
              title: 'Search Activity',
              subtitle: 'Your search patterns over the last 30 days',
              chart: _buildActivityCalendar(),
            ),
            const SizedBox(height: 16),
            
            // Search Types Breakdown
            _buildChartCard(
              title: 'Search Types',
              subtitle: 'How you prefer to search',
              chart: _buildSearchTypeChart(),
            ),
            const SizedBox(height: 16),
            
            // Top Search Queries
            _buildChartCard(
              title: 'Your Top Searches',
              subtitle: 'Most frequently searched terms',
              chart: _buildTopQueriesChart(),
            ),
            const SizedBox(height: 16),
            
            // Trending Categories Insight
            if (_trendingCategories.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'What\'s Trending',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Popular categories in your area this ${_selectedPeriod == "7" ? "week" : "month"}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _trendingCategories.take(6).map((category) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Personalized Recommendations Summary
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.indigo.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Shopping Insights',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInsightTip(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightTip() {
    String tip = 'Keep exploring to get more personalized recommendations!';
    IconData icon = Icons.explore;
    
    final totalSearches = _searchAnalytics['totalSearches'] as int? ?? 0;
    if (totalSearches > 10 && _followedVendors.isEmpty) {
      tip = 'You search a lot! Try following some vendors to get personalized recommendations.';
      icon = Icons.person_add;
    } else if (_followedVendors.isNotEmpty && totalSearches < 5) {
      tip = 'Great vendor choices! Search more to discover similar vendors.';
      icon = Icons.search;
    } else if (_followedVendors.length > 5) {
      tip = 'You\'re following many vendors! Check out the recommendations tab for similar ones.';
      icon = Icons.recommend;
    } else if (_trendingCategories.isNotEmpty) {
      final firstTrending = _trendingCategories.first;
      tip = '$firstTrending is trending! Explore vendors in this category.';
      icon = Icons.trending_up;
    }
    
    return Row(
      children: [
        Icon(icon, color: Colors.indigo.shade600, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(color: Colors.indigo.shade700),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    
    return '${date.month}/${date.day}';
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
    // The VendorDirectoryScreen handles its own premium gating and UI
    return const VendorDirectoryScreen();
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