import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import '../../market/models/market.dart';
import '../../market/services/market_service.dart';
import '../../premium/services/subscription_service.dart';
import '../../shared/services/real_time_analytics_service.dart';
import '../widgets/market_form_dialog.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class MarketManagementScreen extends StatefulWidget {
  const MarketManagementScreen({super.key});

  @override
  State<MarketManagementScreen> createState() => _MarketManagementScreenState();
}

class _MarketManagementScreenState extends State<MarketManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Market> _markets = [];
  List<Market> _filteredMarkets = [];
  bool _isLoading = true;
  Map<String, dynamic> _usageSummary = {};
  bool _canCreateMarkets = true;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets() async {
    setState(() => _isLoading = true);
    
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated && authState.userProfile?.isMarketOrganizer == true) {
        final managedMarketIds = authState.userProfile!.managedMarketIds;
        
        final markets = <Market>[];
        for (final marketId in managedMarketIds) {
          final market = await MarketService.getMarket(marketId);
          if (market != null) {
            markets.add(market);
          }
        }
        
        // Load usage summary
        final currentMarketCount = markets.length;
        final usageSummary = await SubscriptionService.getMarketUsageSummary(
          authState.userProfile!.userId, 
          currentMarketCount,
        );
        final canCreate = await SubscriptionService.canCreateMarket(
          authState.userProfile!.userId,
        );
        
        setState(() {
          _markets = markets;
          _filteredMarkets = markets;
          _usageSummary = usageSummary;
          _canCreateMarkets = canCreate;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading markets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterMarkets() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredMarkets = _markets;
      } else {
        _filteredMarkets = _markets.where((market) =>
          market.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          market.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          market.address.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
      }
    });
  }

  Future<void> _showCreateMarketDialog() async {
    // Check if user can create markets before showing dialog
    if (!_canCreateMarkets) {
      _showMarketLimitReachedDialog();
      return;
    }

    final result = await showDialog<Market>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MarketFormDialog(),
    );

    if (result != null) {
      await _associateMarketWithUser(result.id);
      // Wait a bit for the AuthBloc to update, then reload markets
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _loadMarkets();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.name} created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _associateMarketWithUser(String marketId) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated && authState.userProfile != null) {
        final userProfileService = UserProfileService();
        final updatedProfile = authState.userProfile!.addManagedMarket(marketId);
        await userProfileService.updateUserProfile(updatedProfile);
        
        // Refresh the AuthBloc to get updated user profile
        if (mounted) {
          context.read<AuthBloc>().add(ReloadUserEvent());
        }
      }
    } catch (e) {
      // Error associating market with user
    }
  }

  Future<void> _editMarket(Market market) async {
    final result = await showDialog<Market>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MarketFormDialog(market: market),
    );

    if (result != null) {
      _loadMarkets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.name} updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _toggleMarketStatus(Market market) async {
    try {
      final updatedMarket = market.copyWith(isActive: !market.isActive);
      await MarketService.updateMarket(updatedMarket.id, updatedMarket.toFirestore());
      _loadMarkets();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${market.name} ${market.isActive ? 'deactivated' : 'activated'}',
            ),
            backgroundColor: market.isActive ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating market status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMarket(Market market) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Market'),
        content: Text(
          'Are you sure you want to delete "${market.name}"?\n\n'
          'This will also remove all associated vendors. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MarketService.deleteMarket(market.id);
        
        // Remove from user profile
        if (mounted) {
          final authState = context.read<AuthBloc>().state;
          if (authState is Authenticated && authState.userProfile != null) {
            final userProfileService = UserProfileService();
            final updatedProfile = authState.userProfile!.removeManagedMarket(market.id);
            await userProfileService.updateUserProfile(updatedProfile);
          }
        }
        
        _loadMarkets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${market.name} deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting market: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMarketLimitReachedDialog() {
    // Track analytics for limit dialog shown
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile != null) {
      RealTimeAnalyticsService.trackEvent(
        'market_limit_dialog_shown',
        {
          'user_type': 'market_organizer',
          'current_market_count': _usageSummary['markets_used'] ?? 0,
          'limit': _usageSummary['markets_limit'] ?? 2,
          'is_premium': _usageSummary['is_premium'] ?? false,
          'source': 'market_management_screen',
        },
        userId: authState.userProfile!.userId,
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Market Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached your free tier limit of ${_usageSummary['markets_limit']} markets.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Usage: ${_usageSummary['markets_used']} of ${_usageSummary['markets_limit']} markets',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upgrade to Market Organizer Pro for unlimited markets!',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pro Benefits:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Unlimited markets'),
                Text('• Advanced analytics'),
                Text('• Vendor recruitment tools'),
                Text('• Priority support'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to upgrade screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: HiPopColors.darkTextPrimary,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSummaryCard() {
    if (_usageSummary.isEmpty) return const SizedBox.shrink();
    
    final isAtLimit = !_canCreateMarkets;
    final isPremium = _usageSummary['is_premium'] == true;
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: isAtLimit ? Colors.orange[50] : Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPremium ? Icons.star : Icons.storage,
                    color: isAtLimit ? Colors.orange[600] : Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPremium ? 'Premium Account' : 'Market Usage',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAtLimit ? Colors.orange[800] : Colors.blue[800],
                    ),
                  ),
                  const Spacer(),
                  if (!isPremium && isAtLimit)
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to upgrade screen
                      },
                      child: const Text('Upgrade'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (isPremium)
                Text(
                  'Unlimited markets available',
                  style: TextStyle(color: Colors.blue[700]),
                )
              else ...[
                FutureBuilder<int>(
                  future: () async {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is Authenticated && authState.userProfile != null) {
                      return SubscriptionService.getRemainingMonthlyMarkets(authState.userProfile!.userId);
                    }
                    return 0;
                  }(),
                  builder: (context, snapshot) {
                    final remaining = snapshot.data ?? 0;
                    final monthlyUsed = 2 - remaining; // Since free tier limit is 2
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$monthlyUsed of 2 markets used this month',
                          style: TextStyle(
                            color: remaining == 0 ? Colors.orange[700] : Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: monthlyUsed / 2,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            remaining == 0 ? Colors.orange : Colors.blue,
                          ),
                        ),
                        if (remaining == 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Monthly limit reached. Resets on the 1st',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            '$remaining market${remaining == 1 ? '' : 's'} remaining this month',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Market Management')),
            body: const Center(child: Text('Please sign in to access market management')),
          );
        }

        if (state.userProfile == null || !state.userProfile!.isMarketOrganizer) {
          return Scaffold(
            appBar: AppBar(title: const Text('Market Management')),
            body: const Center(child: Text('Only market organizers can access this feature')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Market Management'),
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
            foregroundColor: HiPopColors.darkTextPrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMarkets,
                tooltip: 'Refresh markets',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildUsageSummaryCard(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMarketsList(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _canCreateMarkets ? _showCreateMarketDialog : _showMarketLimitReachedDialog,
            backgroundColor: _canCreateMarkets ? HiPopColors.accentMauve : Colors.grey,
            foregroundColor: HiPopColors.darkTextPrimary,
            icon: Icon(_canCreateMarkets ? Icons.add : Icons.lock),
            label: Text(_canCreateMarkets ? 'Create Market' : 'Limit Reached'),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkBackground,
        border: Border(bottom: BorderSide(color: HiPopColors.darkBorder)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: HiPopColors.darkTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search markets...',
          hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
          prefixIcon: Icon(Icons.search, color: HiPopColors.darkTextTertiary),
          filled: true,
          fillColor: HiPopColors.darkBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: HiPopColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: HiPopColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: HiPopColors.accentMauve),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _filterMarkets();
        },
      ),
    );
  }

  Widget _buildMarketsList() {
    if (_filteredMarkets.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMarkets.length,
      itemBuilder: (context, index) {
        final market = _filteredMarkets[index];
        return _buildMarketCard(market);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront,
            size: 64,
            color: HiPopColors.darkTextTertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Markets Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Create your first market to get started',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _canCreateMarkets ? _showCreateMarketDialog : _showMarketLimitReachedDialog,
            icon: Icon(_canCreateMarkets ? Icons.add : Icons.lock),
            label: Text(_canCreateMarkets ? 'Create First Market' : 'Limit Reached'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _canCreateMarkets ? HiPopColors.accentMauve : Colors.grey,
              foregroundColor: HiPopColors.darkTextPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCard(Market market) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            market.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${market.address}, ${market.city}, ${market.state}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (market.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              market.description!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: market.isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            market.isActive ? Icons.check_circle : Icons.pause_circle,
                            size: 16,
                            color: market.isActive ? Colors.green[800] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            market.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              color: market.isActive ? Colors.green[800] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Event Schedule:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    market.eventDisplayInfo,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.teal[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _editMarket(market),
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit market',
                ),
                IconButton(
                  onPressed: () => _toggleMarketStatus(market),
                  icon: Icon(
                    market.isActive ? Icons.pause_circle : Icons.play_circle,
                    size: 20,
                    color: market.isActive ? Colors.orange : Colors.green,
                  ),
                  tooltip: market.isActive ? 'Deactivate' : 'Activate',
                ),
                const Spacer(),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteMarket(market);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}