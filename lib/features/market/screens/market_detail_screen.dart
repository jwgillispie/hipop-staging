import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/favorites/favorites_bloc.dart';
import 'package:hipop/features/shared/services/url_launcher_service.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:hipop/features/shared/widgets/common/favorite_button.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/vendor_items_widget.dart';
import 'package:hipop/features/shared/widgets/share_button.dart';
import 'package:hipop/features/vendor/models/managed_vendor.dart';
import 'package:hipop/features/vendor/services/managed_vendor_service.dart';
import 'package:hipop/features/vendor/services/vendor_market_items_service.dart';
import '../../market/models/market.dart';


class MarketDetailScreen extends StatefulWidget {
  final Market market;

  const MarketDetailScreen({
    super.key,
    required this.market,
  });

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyAsVendor(BuildContext context) {
    // Navigate to vendor application form
    context.push('/apply/${widget.market.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.market.name),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<FavoritesBloc, FavoritesState>(
            builder: (context, favoritesState) {
              final totalFavorites = favoritesState.totalFavorites;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () => context.pushNamed('favorites'),
                    icon: const Icon(Icons.favorite_border),
                    tooltip: 'My Favorites',
                  ),
                  if (totalFavorites > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$totalFavorites',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          FavoriteButton(
            itemId: widget.market.id,
            type: FavoriteType.market,
            favoriteColor: Colors.white,
            unfavoriteColor: Colors.white70,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Vendors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildVendorsTab(),
        ],
      ),
      // TEMPORARILY HIDDEN: Apply as Vendor button (only showing permissions for now)
      // floatingActionButton: BlocBuilder<AuthBloc, AuthState>(
      //   builder: (context, state) {
      //     // Only show the Apply as Vendor button for authenticated vendors
      //     if (state is Authenticated && state.userType == 'vendor') {
      //       return FloatingActionButton.extended(
      //         onPressed: () => _applyAsVendor(context),
      //         backgroundColor: Colors.green,
      //         foregroundColor: Colors.white,
      //         icon: const Icon(Icons.store),
      //         label: const Text('Apply as Vendor'),
      //       );
      //     }
      //     return const SizedBox.shrink(); // Hide button for non-vendors
      //   },
      // ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Market Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.market.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _launchMaps(widget.market.address),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        widget.market.address,
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.market.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.market.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Stats Cards
          Text(
            'Market Stats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsCards(),
          
          const SizedBox(height: 24),
          
          // Event Schedule
          Text(
            'Event Schedule',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Event Date:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.market.eventDate.month}/${widget.market.eventDate.day}/${widget.market.eventDate.year}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.market.timeRange,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        widget.market.isHappeningToday ? Icons.check_circle : 
                        widget.market.isFutureEvent ? Icons.schedule : Icons.history,
                        size: 16,
                        color: widget.market.isHappeningToday ? Colors.green : 
                               widget.market.isFutureEvent ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.market.isHappeningToday ? 'Happening Today' : 
                        widget.market.isFutureEvent ? 'Upcoming' : 'Past Event',
                        style: TextStyle(
                          color: widget.market.isHappeningToday ? Colors.green : 
                                 widget.market.isFutureEvent ? Colors.orange : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<ManagedVendor>>(
            stream: ManagedVendorService.getVendorsForMarket(widget.market.id),
            builder: (context, snapshot) {
              final vendorCount = snapshot.hasData ? snapshot.data!.length : 0;
              return _buildStatCard(
                'Total Vendors',
                '$vendorCount',
                Icons.store,
                Colors.green,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<ManagedVendor>>(
            stream: ManagedVendorService.getActiveVendorsForMarket(widget.market.id),
            builder: (context, snapshot) {
              final activeCount = snapshot.hasData ? snapshot.data!.length : 0;
              return _buildStatCard(
                'Active Vendors',
                '$activeCount',
                Icons.check_circle,
                Colors.blue,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, MaterialColor color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color.shade600, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsTab() {
    return StreamBuilder<List<ManagedVendor>>(
      stream: ManagedVendorService.getVendorsForMarket(widget.market.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading vendors...');
        }

        if (snapshot.hasError) {
          return ErrorDisplayWidget.network(
            onRetry: () => setState(() {}),
          );
        }

        final vendors = snapshot.data ?? [];

        if (vendors.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_mall_directory,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No vendors yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This market hasn\'t added any vendors yet. Check back soon for vendors to discover!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<Map<String, List<String>>>(
          future: VendorMarketItemsService.getMarketVendorItems(widget.market.id),
          builder: (context, itemsSnapshot) {
            final vendorItemsMap = itemsSnapshot.data ?? <String, List<String>>{};
            
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: vendors.length,
              itemBuilder: (context, index) {
                final vendor = vendors[index];
                // Get market-specific items for this vendor
                final vendorItems = vendorItemsMap[vendor.id] ?? <String>[];
                return _buildVendorCard(vendor, vendorItems);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVendorCard(ManagedVendor vendor, List<String> marketItems) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    size: 20,
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
                Row(
                  children: [
                    ShareButton(
                      onGetShareContent: () async {
                        return _buildVendorShareContent(vendor);
                      },
                      style: ShareButtonStyle.icon,
                      size: ShareButtonSize.small,
                    ),
                    const SizedBox(width: 8),
                    FavoriteButton(
                      itemId: vendor.id,
                      type: FavoriteType.vendor,
                      size: 20,
                    ),
                  ],
                ),
                if (vendor.isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.amber[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'FEATURED',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            if (vendor.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                vendor.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            // Show market-specific items if available, otherwise show general products
            if (marketItems.isNotEmpty || vendor.products.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (marketItems.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.local_grocery_store,
                          size: 14,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Available at this market:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    VendorItemsWidget.full(items: marketItems),
                  ] else if (vendor.products.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'General products:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    VendorItemsWidget.full(items: vendor.products),
                  ],
                ],
              ),
            ],
            
            if (vendor.phoneNumber != null || vendor.email != null || vendor.instagramHandle != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (vendor.phoneNumber != null) ...[
                    Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _launchPhone(vendor.phoneNumber!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          vendor.phoneNumber!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (vendor.phoneNumber != null && vendor.email != null)
                    const SizedBox(width: 16),
                  if (vendor.email != null) ...[
                    Icon(Icons.email, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchEmail(vendor.email!),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            vendor.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            
            if (vendor.instagramHandle != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.camera_alt, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _launchInstagram(vendor.instagramHandle!),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '@${vendor.instagramHandle!}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _launchMaps(String address) async {
    try {
      await UrlLauncherService.launchMaps(address);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _launchPhone(String phoneNumber) async {
    try {
      await UrlLauncherService.launchPhone(phoneNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not make call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _launchEmail(String email) async {
    try {
      await UrlLauncherService.launchEmail(email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _launchInstagram(String handle) async {
    try {
      await UrlLauncherService.launchInstagram(handle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Instagram: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  String _buildVendorShareContent(ManagedVendor vendor) {
    final buffer = StringBuffer();
    
    buffer.writeln('🛒 Check out ${vendor.businessName}!');
    buffer.writeln();
    
    if (vendor.description.isNotEmpty) {
      buffer.writeln('${vendor.description}');
      buffer.writeln();
    }
    
    buffer.writeln('📋 Categories: ${vendor.categoriesDisplay}');
    
    if (vendor.products.isNotEmpty) {
      buffer.writeln('🥬 Products: ${vendor.products.take(5).join(", ")}${vendor.products.length > 5 ? "..." : ""}');
    }
    
    if (vendor.phoneNumber != null) {
      buffer.writeln('📞 Phone: ${vendor.phoneNumber}');
    }
    
    if (vendor.email != null) {
      buffer.writeln('📧 Email: ${vendor.email}');
    }
    
    if (vendor.instagramHandle != null) {
      buffer.writeln('📱 Instagram: @${vendor.instagramHandle}');
    }
    
    buffer.writeln();
    buffer.writeln('Find them at ${widget.market.name}!');
    buffer.writeln('Shared via HiPop 🍎');
    
    return buffer.toString();
  }

}