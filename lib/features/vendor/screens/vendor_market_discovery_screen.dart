import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../market/models/market.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../shared/widgets/common/error_widget.dart';
import '../../shared/widgets/common/hipop_text_field.dart';
import '../../premium/services/subscription_service.dart';
import '../../premium/models/user_subscription.dart';
import '../../shared/services/user_profile_service.dart';
import '../services/vendor_market_discovery_service.dart';
import '../services/vendor_application_service.dart';

class VendorMarketDiscoveryScreen extends StatefulWidget {
  const VendorMarketDiscoveryScreen({super.key});

  @override
  State<VendorMarketDiscoveryScreen> createState() => _VendorMarketDiscoveryScreenState();
}

class _VendorMarketDiscoveryScreenState extends State<VendorMarketDiscoveryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _hasPremiumAccess = false;
  bool _isLoadingMore = false;
  String? _error;
  
  List<MarketDiscoveryResult> _discoveryResults = [];
  List<String> _selectedCategories = [];
  String _selectedDistance = '25';
  bool _onlyActivelyRecruiting = false;
  
  final List<String> _distanceOptions = ['5', '10', '25', '50', '100'];
  final List<String> _availableCategories = [
    'produce', 'baked_goods', 'prepared_foods', 'crafts', 'beverages',
    'health_beauty', 'flowers', 'meat_seafood', 'dairy', 'other'
  ];

  @override
  void initState() {
    super.initState();
    _checkPremiumAccessAndLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreResults();
    }
  }

  Future<void> _checkPremiumAccessAndLoad() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please log in to access Market Discovery';
          _isLoading = false;
        });
        return;
      }

      // Check premium access
      final hasAccess = await SubscriptionService.hasFeature(user.uid, 'market_discovery');
      
      if (!hasAccess) {
        setState(() {
          _hasPremiumAccess = false;
          _isLoading = false;
        });
        return;
      }

      setState(() => _hasPremiumAccess = true);
      
      // Load initial results (without location for now)
      await _discoverMarkets();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Location functionality removed - could be added back with proper location package integration

  Future<void> _discoverMarkets() async {
    if (!_hasPremiumAccess) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final results = await VendorMarketDiscoveryService.discoverMarketsForVendor(
        user.uid,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
        // Location functionality removed - could be enabled with proper location package
        latitude: null,
        longitude: null,
        maxDistance: double.parse(_selectedDistance),
        searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        onlyActivelyRecruiting: _onlyActivelyRecruiting,
        limit: 20,
      );

      setState(() {
        _discoveryResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasPremiumAccess) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      // In a real implementation, you'd fetch more results with pagination
      // For now, just indicate loading completed
      setState(() => _isLoadingMore = false);
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _applyToMarket(Market market) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Navigate to market application with market pre-selected
      context.go('/vendor/market-permissions');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigate to Market Permissions to apply to ${market.name}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'GO',
              textColor: Colors.white,
              onPressed: () {
                context.go('/vendor/market-permissions');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.diamond,
                color: Colors.amber[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Market Discovery'),
          ],
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !_hasPremiumAccess
          ? _buildUpgradePrompt()
          : _isLoading
              ? const LoadingWidget(message: 'Discovering markets for you...')
              : _error != null
                  ? ErrorDisplayWidget(
                      title: 'Discovery Error',
                      message: _error!,
                      onRetry: _discoverMarkets,
                    )
                  : Column(
                      children: [
                        _buildFiltersSection(),
                        Expanded(
                          child: _discoveryResults.isEmpty
                              ? _buildEmptyState()
                              : _buildResultsList(),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildUpgradePrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Icon(
              Icons.diamond,
              size: 64,
              color: Colors.amber[700],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Upgrade to Vendor Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Market Discovery helps you find markets actively looking for vendors like you.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'With Vendor Pro, you get:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...[
                    'Smart market recommendations based on your products',
                    'Distance-based filtering and location matching',
                    'Market activity insights and vendor capacity',
                    'Application deadline tracking',
                    'Estimated fees and commission rates',
                    'Direct contact information for organizers',
                  ].map((feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to premium upgrade flow
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  context.go('/premium/upgrade?tier=vendor&userId=${user.uid}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.diamond),
                  const SizedBox(width: 8),
                  const Text(
                    'Upgrade to Vendor Pro - \$29/month',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          HiPopTextField(
            controller: _searchController,
            labelText: 'Search markets by name or location',
            hintText: 'e.g., "Downtown Farmers Market"',
            prefixIcon: const Icon(Icons.search),
            onChanged: (_) => _discoverMarkets(),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _discoverMarkets();
                    },
                  )
                : null,
          ),
          const SizedBox(height: 16),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Distance filter (disabled without location)
                _buildFilterChip(
                  'Search Distance: ${_selectedDistance}mi',
                  Icons.location_on,
                  onTap: () => _showDistanceDialog(),
                ),
                const SizedBox(width: 8),
                
                // Category filter
                _buildFilterChip(
                  _selectedCategories.isEmpty 
                      ? 'All Categories' 
                      : '${_selectedCategories.length} Categories',
                  Icons.category,
                  onTap: () => _showCategoryDialog(),
                ),
                const SizedBox(width: 8),
                
                // Actively recruiting filter
                _buildFilterChip(
                  _onlyActivelyRecruiting ? 'Actively Recruiting' : 'All Markets',
                  Icons.business_center,
                  isSelected: _onlyActivelyRecruiting,
                  onTap: () {
                    setState(() {
                      _onlyActivelyRecruiting = !_onlyActivelyRecruiting;
                    });
                    _discoverMarkets();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap() : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: Colors.orange.withValues(alpha: 0.2),
      checkmarkColor: Colors.orange[700],
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _discoveryResults.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _discoveryResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final result = _discoveryResults[index];
        return _buildMarketCard(result);
      },
    );
  }

  Widget _buildMarketCard(MarketDiscoveryResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with market name and recruiting status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.market.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              result.market.fullAddress,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (result.isActivelyRecruiting)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Recruiting',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Key metrics row
            Row(
              children: [
                if (result.distanceFromVendor != null) ...[
                  _buildMetricChip(
                    Icons.directions,
                    '${result.distanceFromVendor!.toStringAsFixed(1)} mi',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                ],
                _buildMetricChip(
                  Icons.people,
                  '${result.vendorCapacity} spots',
                  Colors.purple,
                ),
                const SizedBox(width: 8),
                if (result.estimatedFees != null)
                  _buildMetricChip(
                    Icons.attach_money,
                    '\$${result.estimatedFees!.dailyBoothFee.toStringAsFixed(0)}/day',
                    Colors.orange,
                  ),
              ],
            ),
            
            if (result.insights.isNotEmpty || result.opportunities.isNotEmpty) ...[
              const SizedBox(height: 16),
              
              // Insights and opportunities
              if (result.insights.isNotEmpty) ...[
                ...result.insights.take(2).map((insight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              
              if (result.opportunities.isNotEmpty) ...[
                ...result.opportunities.take(2).map((opportunity) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.trending_up, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opportunity,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showMarketDetails(result),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _applyToMarket(result.market),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Markets Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search filters or expanding your search area.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _selectedCategories.clear();
                _onlyActivelyRecruiting = false;
                _discoverMarkets();
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketDetails(MarketDiscoveryResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.market.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.market.fullAddress,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      if (result.market.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'About This Market',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(result.market.description!),
                      ],
                      
                      const SizedBox(height: 16),
                      Text(
                        'Operating Schedule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...result.market.operatingDays.entries.map((entry) => 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(entry.value),
                            ],
                          ),
                        ),
                      ),
                      
                      if (result.estimatedFees != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Estimated Costs',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Daily Booth Fee: \$${result.estimatedFees!.dailyBoothFee}'),
                        if (result.estimatedFees!.applicationFee != null)
                          Text('Application Fee: \$${result.estimatedFees!.applicationFee}'),
                        if (result.estimatedFees!.commissionRate != null)
                          Text('Commission: ${(result.estimatedFees!.commissionRate! * 100).toStringAsFixed(1)}%'),
                      ],
                      
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _applyToMarket(result.market);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Apply to This Market'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Distance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _distanceOptions.map((distance) => RadioListTile<String>(
            title: Text('$distance miles'),
            value: distance,
            groupValue: _selectedDistance,
            onChanged: (value) {
              setState(() => _selectedDistance = value!);
              Navigator.pop(context);
              _discoverMarkets();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showCategoryDialog() {
    final tempSelected = List<String>.from(_selectedCategories);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Categories'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _availableCategories.map((category) => CheckboxListTile(
                  title: Text(_formatCategoryName(category)),
                  value: tempSelected.contains(category),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        tempSelected.add(category);
                      } else {
                        tempSelected.remove(category);
                      }
                    });
                  },
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() => tempSelected.clear());
              },
              child: const Text('Clear All'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedCategories = tempSelected);
                Navigator.pop(context);
                _discoverMarkets();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}