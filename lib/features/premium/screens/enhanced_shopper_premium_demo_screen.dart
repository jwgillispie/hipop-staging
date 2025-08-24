import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/shared/services/search_history_service.dart';
import 'package:hipop/features/shopper/services/enhanced_search_service.dart';
import 'package:hipop/features/shopper/services/personalized_recommendation_service.dart';
import 'package:hipop/features/shopper/services/shopper_notification_service.dart';
import 'package:hipop/features/vendor/services/vendor_following_service.dart';
import 'package:hipop/features/vendor/services/vendor_insights_service.dart';
import '../../vendor/widgets/vendor/vendor_follow_button.dart';

/// Enhanced demo screen showcasing comprehensive premium shopper features
class EnhancedShopperPremiumDemoScreen extends StatefulWidget {
  const EnhancedShopperPremiumDemoScreen({super.key});

  @override
  State<EnhancedShopperPremiumDemoScreen> createState() => _EnhancedShopperPremiumDemoScreenState();
}

class _EnhancedShopperPremiumDemoScreenState extends State<EnhancedShopperPremiumDemoScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _advancedSearchController = TextEditingController();
  
  List<String> _selectedCategories = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _followedVendors = [];
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _searchHistory = [];
  List<Map<String, dynamic>> _savedSearches = [];
  List<Map<String, dynamic>> _notifications = [];
  Map<String, dynamic>? _shoppingInsights;
  bool _isLoading = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // Increased tabs
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSearchController.dispose();
    _advancedSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    _currentUserId = authState.user.uid;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load all premium features data in parallel
      final futures = await Future.wait([
        VendorFollowingService.getFollowedVendors(_currentUserId),
        PersonalizedRecommendationService.generateRecommendations(
          shopperId: _currentUserId,
          limit: 15,
        ),
        SearchHistoryService.getSearchHistory(shopperId: _currentUserId, limit: 20),
        SearchHistoryService.getSavedSearches(_currentUserId),
        ShopperNotificationService.getUnreadNotifications(_currentUserId),
        _loadShoppingInsights(),
      ]);

      if (mounted) {
        setState(() {
          _followedVendors = futures[0] as List<Map<String, dynamic>>;
          _recommendations = futures[1] as List<Map<String, dynamic>>;
          _searchHistory = futures[2] as List<Map<String, dynamic>>;
          _savedSearches = futures[3] as List<Map<String, dynamic>>;
          _notifications = futures[4] as List<Map<String, dynamic>>;
          _shoppingInsights = futures[5] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading premium features: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _loadShoppingInsights() async {
    try {
      return await VendorInsightsService.getShoppingInsights(
        shopperId: _currentUserId,
        months: 3,
        isPremium: false, // Shoppers have free access
      );
    } catch (e) {
      debugPrint('Error loading shopping insights: $e');
      return null;
    }
  }

  Future<void> _searchByCategories() async {
    if (_selectedCategories.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await EnhancedSearchService.searchVendorsByCategories(
        categories: _selectedCategories,
        shopperId: _currentUserId,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Search failed: $e');
      }
    }
  }

  Future<void> _searchByProduct() async {
    final query = _productSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await EnhancedSearchService.searchByProduct(
        productQuery: query,
        shopperId: _currentUserId,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Product search failed: $e');
      }
    }
  }

  Future<void> _advancedSearch() async {
    final query = _advancedSearchController.text.trim();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await EnhancedSearchService.advancedSearch(
        shopperId: _currentUserId,
        productQuery: query.isNotEmpty ? query : null,
        categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Advanced search failed: $e');
      }
    }
  }

  Future<void> _saveCurrentSearch() async {
    if (_selectedCategories.isEmpty && _productSearchController.text.trim().isEmpty) {
      _showErrorSnackBar('No search criteria to save');
      return;
    }

    final searchName = await _showSaveSearchDialog();
    if (searchName == null || searchName.isEmpty) return;

    try {
      await SearchHistoryService.saveSearch(
        shopperId: _currentUserId,
        name: searchName,
        query: _productSearchController.text.trim(),
        searchType: _selectedCategories.isNotEmpty 
            ? SearchType.categorySearch 
            : SearchType.productSearch,
        categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
      );

      // Refresh saved searches
      final savedSearches = await SearchHistoryService.getSavedSearches(_currentUserId);
      setState(() {
        _savedSearches = savedSearches;
      });

      _showSuccessSnackBar('Search saved successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to save search: $e');
    }
  }

  Future<String?> _showSaveSearchDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Search'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter search name...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Shopper Features'),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_notifications.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '${_notifications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showNotificationsDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Smart Search'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.favorite), text: 'Following'),
            Tab(icon: Icon(Icons.recommend), text: 'For You'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSmartSearchTab(),
          _buildCategorySearchTab(),
          _buildFollowingTab(),
          _buildRecommendationsTab(),
          _buildSearchHistoryTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildSmartSearchTab() {
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
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Advanced Smart Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Combine products, categories, and filters for precise results:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _advancedSearchController,
                    decoration: const InputDecoration(
                      hintText: 'Search for products (e.g., organic honey, sourdough bread)...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _advancedSearch(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Optional: Add categories to refine search:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EnhancedSearchService.vendorCategories.take(8).map((category) {
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
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _advancedSearch,
                          child: const Text('Advanced Search'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saveCurrentSearch,
                        icon: const Icon(Icons.bookmark_add),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_savedSearches.isNotEmpty) ...[
            const Text(
              'Saved Searches:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _savedSearches.length,
                itemBuilder: (context, index) {
                  final savedSearch = _savedSearches[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.bookmark, size: 16),
                      label: Text(savedSearch['name']),
                      onPressed: () => _executeSavedSearch(savedSearch['id']),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty) ...[
            Text(
              'Found ${_searchResults.length} results:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._searchResults.map((result) => _buildSearchResultCard(result)),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySearchTab() {
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
                  const Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Category-Based Discovery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Find vendors by their specialties:'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EnhancedSearchService.vendorCategories.map((category) {
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
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedCategories.isEmpty ? null : _searchByCategories,
                      child: const Text('Find Vendors'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty) ...[
            Text(
              'Found ${_searchResults.length} vendors:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._searchResults.map((vendor) => _buildVendorCard(vendor)),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
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
                  const Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Your Followed Vendors',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _followedVendors.isEmpty
                        ? 'Start following vendors to get notified when they post new locations!'
                        : 'You\'ll get premium notifications when these vendors post new pop-ups:',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_followedVendors.isEmpty)
            _buildEmptyFollowingState()
          else
            ..._followedVendors.map((vendor) => _buildFollowedVendorCard(vendor)),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
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
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Personalized For You',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('AI-powered recommendations based on your preferences:'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_recommendations.isNotEmpty)
            ..._recommendations.map((vendor) => _buildRecommendationCard(vendor))
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Start following vendors and searching to get personalized recommendations!'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchHistoryTab() {
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
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Search History & Saved Searches',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Your recent searches and saved queries:'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_savedSearches.isNotEmpty) ...[
            const Text(
              'Saved Searches:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._savedSearches.map((search) => _buildSavedSearchCard(search)),
            const SizedBox(height: 16),
          ],
          if (_searchHistory.isNotEmpty) ...[
            const Text(
              'Recent Searches:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._searchHistory.take(10).map((search) => _buildSearchHistoryCard(search)),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No search history yet. Start searching to see your history here!'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
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
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Your Shopping Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Discover your local shopping patterns and preferences:'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_shoppingInsights != null)
            _buildShoppingInsightsContent()
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Start shopping with local vendors to see your personalized insights!'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShoppingInsightsContent() {
    final insights = _shoppingInsights!;
    final summary = insights['summary'] as Map<String, dynamic>;
    final personalizedInsights = List<Map<String, dynamic>>.from(
      insights['personalizedInsights'] ?? []
    );

    return Column(
      children: [
        // Summary stats
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Local Impact Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Spent',
                        '\$${(summary['totalSpent'] as double).toStringAsFixed(2)}',
                        Icons.payments,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Vendors Supported',
                        '${summary['uniqueVendors']}',
                        Icons.store,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Avg Transaction',
                        '\$${(summary['averageTransactionAmount'] as double).toStringAsFixed(2)}',
                        Icons.receipt,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Diversity Score',
                        '${((summary['diversityScore'] as double) * 100).round()}%',
                        Icons.explore,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Personalized insights
        if (personalizedInsights.isNotEmpty) ...[
          const Text(
            'Personalized Insights',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...personalizedInsights.map((insight) => _buildInsightCard(insight)),
        ],
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    final iconMap = {
      'shopping_bag': Icons.shopping_bag,
      'category': Icons.category,
      'favorite': Icons.favorite,
      'explore': Icons.explore,
      'trending_up': Icons.trending_up,
      'star': Icons.star,
      'refresh': Icons.refresh,
      'eco': Icons.eco,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Icon(
            iconMap[insight['icon']] ?? Icons.info,
            color: Colors.blue,
          ),
        ),
        title: Text(insight['title']),
        subtitle: Text(insight['description']),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: vendor['profileImageUrl'] != null
              ? NetworkImage(vendor['profileImageUrl'])
              : null,
          child: vendor['profileImageUrl'] == null
              ? const Icon(Icons.store)
              : null,
        ),
        title: Text(vendor['businessName'] ?? 'Unknown Business'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendor['bio'] != null && vendor['bio'].isNotEmpty)
              Text(
                vendor['bio'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (vendor['categories'] != null && (vendor['categories'] as List).isNotEmpty)
              Wrap(
                spacing: 4,
                children: (vendor['categories'] as List<String>).take(3).map((category) =>
                  Chip(
                    label: Text(category),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ).toList(),
              ),
          ],
        ),
        trailing: VendorFollowButton(
          vendorId: vendor['vendorId'],
          vendorName: vendor['businessName'] ?? 'Unknown',
          isCompact: true,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> vendor) {
    final reason = vendor['reasonDetails'] as String?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: vendor['profileImageUrl'] != null
              ? NetworkImage(vendor['profileImageUrl'])
              : null,
          child: vendor['profileImageUrl'] == null
              ? const Icon(Icons.auto_awesome)
              : null,
        ),
        title: Text(vendor['businessName'] ?? 'Unknown Business'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reason != null)
              Text(
                reason,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.blue,
                ),
              ),
            if (vendor['bio'] != null && vendor['bio'].isNotEmpty)
              Text(
                vendor['bio'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: VendorFollowButton(
          vendorId: vendor['vendorId'],
          vendorName: vendor['businessName'] ?? 'Unknown',
          isCompact: true,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildFollowedVendorCard(Map<String, dynamic> vendor) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.store),
        ),
        title: Text(vendor['vendorName'] ?? 'Unknown Vendor'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Following since ${_formatDate(vendor['followedAt'])}'),
            if (vendor['bio'] != null && vendor['bio'].isNotEmpty)
              Text(
                vendor['bio'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: VendorFollowButton(
          vendorId: vendor['vendorId'],
          vendorName: vendor['vendorName'],
          isCompact: true,
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.search),
        ),
        title: Text(result['businessName'] ?? 'Unknown Business'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result['description'] != null)
              Text(
                result['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text('📍 ${result['location'] ?? 'Location TBD'}'),
          ],
        ),
        trailing: VendorFollowButton(
          vendorId: result['vendorId'],
          vendorName: result['businessName'] ?? 'Unknown',
          isCompact: true,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildSavedSearchCard(Map<String, dynamic> search) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bookmark),
        title: Text(search['name']),
        subtitle: Text('Query: ${search['query']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _executeSavedSearch(search['id']),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteSavedSearch(search['id']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistoryCard(Map<String, dynamic> search) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(search['query']),
        subtitle: Text(
          'Type: ${search['searchType']} • ${_formatTimestamp(search['timestamp'])}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _repeatSearch(search),
        ),
      ),
    );
  }

  Widget _buildEmptyFollowingState() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: const Column(
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No followed vendors yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Explore vendors in other tabs and tap follow to stay updated!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return ListTile(
                      title: Text(notification['title']),
                      subtitle: Text(notification['body']),
                      leading: const Icon(Icons.notifications),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSavedSearch(String savedSearchId) async {
    try {
      final results = await EnhancedSearchService.executeSavedSearch(
        shopperId: _currentUserId,
        savedSearchId: savedSearchId,
      );

      setState(() {
        _searchResults = results;
      });

      // Switch to smart search tab to show results
      _tabController.animateTo(0);
      
      _showSuccessSnackBar('Saved search executed successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to execute saved search: $e');
    }
  }

  Future<void> _deleteSavedSearch(String savedSearchId) async {
    try {
      await SearchHistoryService.deleteSavedSearch(savedSearchId);
      
      // Refresh saved searches
      final savedSearches = await SearchHistoryService.getSavedSearches(_currentUserId);
      setState(() {
        _savedSearches = savedSearches;
      });

      _showSuccessSnackBar('Saved search deleted');
    } catch (e) {
      _showErrorSnackBar('Failed to delete saved search: $e');
    }
  }

  void _repeatSearch(Map<String, dynamic> search) {
    final query = search['query'] as String;
    final searchType = search['searchType'] as String;
    
    if (searchType == 'productSearch') {
      _productSearchController.text = query;
      _searchByProduct();
    } else if (searchType == 'categorySearch') {
      final categories = List<String>.from(search['categories'] ?? []);
      setState(() {
        _selectedCategories = categories;
      });
      _searchByCategories();
    }
    
    // Switch to appropriate tab
    if (searchType == 'productSearch' || searchType == 'combinedSearch') {
      _tabController.animateTo(0);
    } else if (searchType == 'categorySearch') {
      _tabController.animateTo(1);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inMinutes}m ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}