import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/favorites/favorites_bloc.dart';
import '../models/market.dart';
import '../models/managed_vendor.dart';
import '../services/market_service.dart';
import '../services/managed_vendor_service.dart';
import '../widgets/common/loading_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ManagedVendor> _favoriteVendors = [];
  List<Market> _favoriteMarkets = [];
  bool _isLoadingVendors = false;
  bool _isLoadingMarkets = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Favorites are now automatically loaded when auth state changes in main.dart
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    await Future.wait([
      _loadFavoriteVendors(),
      _loadFavoriteMarkets(),
    ]);
  }

  Future<void> _loadFavoriteVendors() async {
    setState(() {
      _isLoadingVendors = true;
    });

    try {
      final favoritesState = context.read<FavoritesBloc>().state;
      final vendors = <ManagedVendor>[];
      
      for (final vendorId in favoritesState.favoriteVendorIds) {
        try {
          final vendor = await ManagedVendorService.getVendor(vendorId);
          if (vendor != null) {
            vendors.add(vendor);
          }
        } catch (e) {
          // Error fetching vendor
        }
      }

      if (mounted) {
        setState(() {
          _favoriteVendors = vendors;
          _isLoadingVendors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVendors = false;
        });
      }
    }
  }

  Future<void> _loadFavoriteMarkets() async {
    setState(() {
      _isLoadingMarkets = true;
    });

    try {
      final favoritesState = context.read<FavoritesBloc>().state;
      final markets = <Market>[];
      
      for (final marketId in favoritesState.favoriteMarketIds) {
        try {
          final market = await MarketService.getMarket(marketId);
          if (market != null) {
            markets.add(market);
          }
        } catch (e) {
          // Error fetching market
        }
      }

      if (mounted) {
        setState(() {
          _favoriteMarkets = markets;
          _isLoadingMarkets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMarkets = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FavoritesBloc, FavoritesState>(
      listener: (context, state) {
        // Reload favorites when state changes
        _loadFavorites();
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Scaffold(
              body: LoadingWidget(message: 'Loading...'),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('My Favorites'),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.store),
                    text: 'Vendors',
                  ),
                  Tab(
                    icon: Icon(Icons.location_on),
                    text: 'Markets',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildFavoriteVendorsList(),
                _buildFavoriteMarketsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteVendorsList() {
    if (_isLoadingVendors) {
      return const LoadingWidget(message: 'Loading favorite vendors...');
    }

    if (_favoriteVendors.isEmpty) {
      return _buildEmptyState(
        icon: Icons.store,
        title: 'No Favorite Vendors',
        subtitle: 'Vendors you favorite will appear here.\nStart exploring markets to find vendors you love!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteVendors.length,
      itemBuilder: (context, index) {
        final vendor = _favoriteVendors[index];
        return _buildVendorCard(vendor);
      },
    );
  }

  Widget _buildFavoriteMarketsList() {
    if (_isLoadingMarkets) {
      return const LoadingWidget(message: 'Loading favorite markets...');
    }

    if (_favoriteMarkets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.location_on,
        title: 'No Favorite Markets',
        subtitle: 'Markets you favorite will appear here.\nExplore nearby markets and save the ones you love!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteMarkets.length,
      itemBuilder: (context, index) {
        final market = _favoriteMarkets[index];
        return _buildMarketCard(market);
      },
    );
  }

  Widget _buildVendorCard(ManagedVendor vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // For now, just show a message since there's no vendor detail screen yet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${vendor.businessName} details'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                    child: const Icon(
                      Icons.store,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vendor.categoriesDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeFavoriteVendor(vendor.id),
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    tooltip: 'Remove from favorites',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                vendor.description,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (vendor.products.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Products: ${vendor.products.take(3).join(', ')}${vendor.products.length > 3 ? '...' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketCard(Market market) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.pushNamed('marketDetail', extra: market);
        },
        borderRadius: BorderRadius.circular(12),
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
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${market.city}, ${market.state}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeFavoriteMarket(market.id),
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    tooltip: 'Remove from favorites',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${market.operatingDays.length} days/week',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              if (market.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  market.description!,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate back to markets discovery
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Explore Markets'),
            ),
          ],
        ),
      ),
    );
  }


  void _removeFavoriteVendor(String vendorId) {
    context.read<FavoritesBloc>().add(ToggleVendorFavorite(vendorId: vendorId));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vendor removed from favorites'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeFavoriteMarket(String marketId) {
    context.read<FavoritesBloc>().add(ToggleMarketFavorite(marketId: marketId));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Market removed from favorites'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }
}