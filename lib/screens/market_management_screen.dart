import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/market.dart';
import '../services/market_service.dart';
import '../services/user_profile_service.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/auth/auth_event.dart';
import '../widgets/market_form_dialog.dart';

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
        
        setState(() {
          _markets = markets;
          _filteredMarkets = markets;
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
    // Check market limit
    if (_markets.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only manage up to 3 markets. Delete an existing market to create a new one.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
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
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMarketsList(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateMarketDialog,
            backgroundColor: _markets.length >= 3 ? Colors.grey : Colors.teal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(_markets.length >= 3 ? 'Limit Reached (3/3)' : 'Create Market (${_markets.length}/3)'),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search markets...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
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
            color: Colors.grey[400],
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
                : 'Create your first market to get started (up to 3 markets allowed)',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateMarketDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create First Market'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
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
                if (market.operatingDays.isNotEmpty) ...[
                  const Text(
                    'Operating Days:',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: market.operatingDays.entries.map((entry) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.key.toUpperCase()}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.teal[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
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