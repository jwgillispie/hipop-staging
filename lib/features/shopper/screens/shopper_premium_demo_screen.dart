import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/features/shopper/services/enhanced_search_service.dart';
import 'package:hipop/features/vendor/services/vendor_following_service.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_follow_button.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

/// Demo screen showcasing premium shopper features
class ShopperPremiumDemoScreen extends StatefulWidget {
  const ShopperPremiumDemoScreen({super.key});

  @override
  State<ShopperPremiumDemoScreen> createState() => _ShopperPremiumDemoScreenState();
}

class _ShopperPremiumDemoScreenState extends State<ShopperPremiumDemoScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _productSearchController = TextEditingController();
  
  List<String> _selectedCategories = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _followedVendors = [];
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load followed vendors
      final followed = await VendorFollowingService.getFollowedVendors(authState.user.uid);
      
      // Load personalized recommendations
      final recs = await EnhancedSearchService.getPersonalizedRecommendations(
        shopperId: authState.user.uid,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _followedVendors = followed;
          _recommendations = recs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Shopper Premium Features'),
          ],
        ),
        backgroundColor: HiPopColors.shopperAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: HiPopColors.darkTextSecondary,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.search), text: 'Products'),
            Tab(icon: Icon(Icons.favorite), text: 'Following'),
            Tab(icon: Icon(Icons.recommend), text: 'For You'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategorySearchTab(),
          _buildProductSearchTab(),
          _buildFollowingTab(),
          _buildRecommendationsTab(),
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
                      Icon(Icons.filter_list, color: HiPopColors.shopperAccent),
                      SizedBox(width: 8),
                      Text(
                        'Advanced Category Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Select categories to find vendors:'),
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
                      child: const Text('Search Vendors'),
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
          ] else if (_selectedCategories.isNotEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No vendors found with selected categories.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductSearchTab() {
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
                      Icon(Icons.search, color: HiPopColors.primaryDeepSage),
                      SizedBox(width: 8),
                      Text(
                        'Product-Specific Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Search for specific products across all vendors:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _productSearchController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., sourdough bread, honey, tomatoes...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchByProduct(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _searchByProduct,
                      child: const Text('Search Products'),
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
              'Found ${_searchResults.length} matches:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._searchResults.map((result) => _buildProductResultCard(result)),
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
                      Icon(Icons.favorite, color: HiPopColors.errorPlum),
                      SizedBox(width: 8),
                      Text(
                        'Followed Vendors',
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
                        : 'You\'ll get notifications when these vendors post new pop-ups:',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_followedVendors.isEmpty)
            Card(
              child: Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                child: const Column(
                  children: [
                    Icon(Icons.favorite_border, size: 64, color: HiPopColors.darkTextSecondary),
                    SizedBox(height: 16),
                    Text(
                      'No followed vendors yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Browse vendors and tap the follow button to stay updated!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HiPopColors.darkTextSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._followedVendors.map((vendor) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.store),
                ),
                title: Text(vendor['vendorName'] ?? 'Unknown Vendor'),
                subtitle: Text('Following since ${_formatDate(vendor['followedAt'])}'),
                trailing: VendorFollowButton(
                  vendorId: vendor['vendorId'],
                  vendorName: vendor['vendorName'],
                  isCompact: true,
                ),
              ),
            )),
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
                      Icon(Icons.recommend, color: HiPopColors.shopperAccent),
                      SizedBox(width: 8),
                      Text(
                        'Personalized Recommendations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Vendors we think you\'ll love based on your interests:'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_recommendations.isNotEmpty)
            ..._recommendations.map((vendor) => _buildVendorCard(vendor))
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Follow some vendors to get personalized recommendations!'),
              ),
            ),
        ],
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

  Widget _buildProductResultCard(Map<String, dynamic> result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.shopping_bag),
        ),
        title: Text(result['businessName'] ?? 'Unknown Business'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result['specificProducts'] != null)
              Text(
                'Products: ${result['specificProducts']}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        // Assume it's a Firestore Timestamp
        date = timestamp.toDate();
      }
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}