import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/features/shopper/services/enhanced_search_service.dart';
import '../services/subscription_service.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../widgets/upgrade_to_premium_button.dart';
import '../../vendor/widgets/vendor/vendor_follow_button.dart';
import '../../shared/services/user_profile_service.dart';
import '../../shared/widgets/common/unified_location_search.dart';
import '../../shared/services/places_service.dart';

/// Production-ready premium search widget that integrates advanced search
/// directly into the main search experience with natural upgrade prompts
class PremiumSearchWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSearchResults;
  final String? initialLocation;

  const PremiumSearchWidget({
    super.key,
    required this.onSearchResults,
    this.initialLocation,
  });

  @override
  State<PremiumSearchWidget> createState() => _PremiumSearchWidgetState();
}

class _PremiumSearchWidgetState extends State<PremiumSearchWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _selectedCategories = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  bool _hasPremiumAccess = false;
  bool _showAdvancedOptions = false;
  String _currentUserId = '';
  PlaceDetails? _selectedLocation;
  String _locationSearchText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _checkPremiumAccess();
    
    // Initialize with any provided location
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _locationSearchText = widget.initialLocation!;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh premium status when app becomes active
      _checkPremiumAccess();
    }
  }

  Future<void> _checkPremiumAccess() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      
      // Check both feature access AND user profile premium status (dual-check system)
      final futures = await Future.wait([
        SubscriptionService.hasFeature(_currentUserId, 'enhanced_search'),
        _checkUserProfilePremiumStatus(_currentUserId),
      ]);
      
      final hasFeatureAccess = futures[0];
      final hasProfilePremium = futures[1];
      
      // User is premium if either check returns true
      final hasAccess = hasFeatureAccess || hasProfilePremium;
      
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
        });
        
        if (hasAccess) {
          _loadPersonalizedRecommendations();
        }
      }
    }
  }
  
  Future<bool> _checkUserProfilePremiumStatus(String userId) async {
    try {
      final userProfileService = UserProfileService();
      return await userProfileService.hasPremiumAccess(userId);
    } catch (e) {
      debugPrint('Error checking user profile premium status: $e');
      return false;
    }
  }

  Future<void> _loadPersonalizedRecommendations() async {
    if (!_hasPremiumAccess || _currentUserId.isEmpty) return;

    try {
      final recs = await EnhancedSearchService.getPersonalizedRecommendations(
        shopperId: _currentUserId,
        limit: 5,
      );
      
      if (mounted) {
        setState(() {
          _recommendations = recs;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && _selectedCategories.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> results;
      
      if (_hasPremiumAccess && (_selectedCategories.isNotEmpty || query.isNotEmpty || _locationSearchText.isNotEmpty)) {
        // Premium advanced search with location
        results = await EnhancedSearchService.advancedSearch(
          shopperId: _currentUserId,
          productQuery: query.isNotEmpty ? query : null,
          categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
          location: _locationSearchText.isNotEmpty ? _locationSearchText : null,
          limit: 20,
        );
      } else if (query.isNotEmpty || _locationSearchText.isNotEmpty) {
        // Basic search for non-premium users (includes location search as main feature)
        if (query.isNotEmpty) {
          // Product search with optional location
          results = await EnhancedSearchService.searchByProduct(
            productQuery: query,
            location: _locationSearchText.isNotEmpty ? _locationSearchText : null,
            limit: 15,
          );
        } else if (_locationSearchText.isNotEmpty) {
          // Location-only search - use advanced search with just location
          results = await EnhancedSearchService.advancedSearch(
            shopperId: _currentUserId,
            location: _locationSearchText,
            limit: 15,
          );
        } else {
          results = [];
        }
      } else {
        results = [];
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        widget.onSearchResults(results);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Main search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _hasPremiumAccess 
                              ? 'Search by location, products, vendors, or categories...'
                              : 'Search by location...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _hasPremiumAccess
                              ? IconButton(
                                  icon: Icon(_showAdvancedOptions 
                                      ? Icons.expand_less 
                                      : Icons.tune),
                                  onPressed: () {
                                    setState(() {
                                      _showAdvancedOptions = !_showAdvancedOptions;
                                    });
                                  },
                                  tooltip: 'Advanced Search Options',
                                )
                              : IconButton(
                                  icon: const Icon(Icons.star_border, color: Colors.amber),
                                  onPressed: _showPremiumUpgradeDialog,
                                  tooltip: 'Unlock Premium Search',
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _hasPremiumAccess ? Colors.blue : Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _hasPremiumAccess ? Colors.blue : Colors.orange,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasPremiumAccess ? Colors.blue : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
                
                // Premium advanced options
                if (_hasPremiumAccess && _showAdvancedOptions) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Premium Advanced Search',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Filter by categories:'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: EnhancedSearchService.vendorCategories.take(8).map((category) {
                            final isSelected = _selectedCategories.contains(category);
                            return FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              selectedColor: Colors.blue.shade200,
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
                        const Text('Search in specific location:'),
                        const SizedBox(height: 8),
                        UnifiedLocationSearch(
                          hintText: 'Enter city or location...',
                          initialLocation: _locationSearchText,
                          onPlaceSelected: (placeDetails) {
                            setState(() {
                              _selectedLocation = placeDetails;
                              _locationSearchText = placeDetails.formattedAddress;
                            });
                          },
                          onTextSearch: (searchText) {
                            setState(() {
                              _locationSearchText = searchText;
                              _selectedLocation = null;
                            });
                          },
                          onCleared: () {
                            setState(() {
                              _selectedLocation = null;
                              _locationSearchText = '';
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter city or location...',
                            prefixIcon: const Icon(Icons.location_on, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.blue.shade50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Non-premium upgrade hint
                if (!_hasPremiumAccess && _searchController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Get unlimited results + category & location filters with Premium',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _showPremiumUpgradeDialog,
                          child: Text(
                            'Upgrade',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Search results section
          if (_searchResults.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Search Results',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_searchResults.length} found',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.take(5).length, // Show max 5 results
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return _buildSearchResultCard(result);
                    },
                  ),
                  if (_searchResults.length > 5) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '+${_searchResults.length - 5} more results',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          // Premium recommendations section
          if (_hasPremiumAccess && _recommendations.isNotEmpty && _searchResults.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended For You',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recommendations.length,
                      itemBuilder: (context, index) {
                        final vendor = _recommendations[index];
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        child: Icon(Icons.store, size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          vendor['businessName'] ?? 'Vendor',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    vendor['bio'] ?? 'Great local vendor',
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  VendorFollowButton(
                                    vendorId: vendor['vendorId'],
                                    vendorName: vendor['businessName'] ?? 'Vendor',
                                    isCompact: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Unlock Premium Search'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upgrade to Premium Shopper to unlock:'),
            const SizedBox(height: 16),
            _buildFeatureItem(Icons.search, 'Unlimited search results'),
            _buildFeatureItem(Icons.category, 'Advanced category filtering'),
            _buildFeatureItem(Icons.location_on, 'City & location search'),
            _buildFeatureItem(Icons.auto_awesome, 'AI-powered recommendations'),
            _buildFeatureItem(Icons.notifications, 'Vendor notification system'),
            _buildFeatureItem(Icons.history, 'Search history & saved searches'),
            const SizedBox(height: 16),
            const UpgradeToPremiumButton(userType: 'shopper'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.store, color: Colors.blue.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['businessName'] ?? 'Unknown Business',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result['location'] ?? 'Location not specified',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (result['relevanceScore'] != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(result['relevanceScore'] as double).toStringAsFixed(1)}★',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (result['description'] != null && result['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                result['description'],
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (result['specificProducts'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Products: ${result['specificProducts']}',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (result['vendorId'] != null && result['vendorId'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  VendorFollowButton(
                    vendorId: result['vendorId'],
                    vendorName: result['businessName'] ?? 'Vendor',
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}