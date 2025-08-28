import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../blocs/vendor/vendor_products_bloc.dart';
import '../../../core/constants/constants.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../models/vendor_product.dart';
import '../models/vendor_market_product_assignment.dart';
import '../models/vendor_product_list.dart';
import '../services/vendor_product_service.dart';
import '../../market/models/market.dart';
import '../../../core/theme/hipop_colors.dart';
import '../../market/services/market_service.dart';
import '../../vendor/services/vendor_market_relationship_service.dart';
import '../../shared/models/user_feedback.dart';
import '../../shared/services/user_feedback_service.dart';

/// Unified screen for managing vendor's global product catalog and market assignments
/// Replaces both the old Market Items screen and Products tab in Sales Tracker
class VendorProductsManagementScreen extends StatefulWidget {
  const VendorProductsManagementScreen({super.key});

  @override
  State<VendorProductsManagementScreen> createState() => _VendorProductsManagementScreenState();
}

class _VendorProductsManagementScreenState extends State<VendorProductsManagementScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _productsScrollController = ScrollController();
  
  List<Market> _approvedMarkets = [];
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadApprovedMarkets();
    
    _productsScrollController.addListener(() {
      if (_productsScrollController.position.extentAfter < 500) {
        final bloc = context.read<VendorProductsBloc>();
        final state = bloc.state;
        if (state is ProductsLoaded && !state.hasReachedEnd && !state.isLoadingMore) {
          bloc.add(LoadMoreProducts(state.vendorId));
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovedMarkets() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    _currentUserId = authState.user.uid;

    try {
      // Load approved markets separately since we need to convert IDs to Market objects
      final approvedMarketIds = await VendorMarketRelationshipService.getApprovedMarketsForVendor(_currentUserId);
      final approvedMarkets = await _getMarketsByIds(approvedMarketIds);

      if (mounted) {
        setState(() {
          _approvedMarkets = approvedMarkets;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor approved markets: $e');
    }
  }
  
  void _refreshProducts() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<VendorProductsBloc>().add(RefreshProducts(authState.user.uid));
    }
  }

  /// Helper method to get Market objects from market IDs
  Future<List<Market>> _getMarketsByIds(List<String> marketIds) async {
    if (marketIds.isEmpty) return [];
    
    final markets = <Market>[];
    for (final marketId in marketIds) {
      try {
        final market = await MarketService.getMarket(marketId);
        if (market != null) {
          markets.add(market);
        }
      } catch (e) {
        debugPrint('Error loading market $marketId: $e');
      }
    }
    return markets;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to access this page'),
        ),
      );
    }

    return BlocProvider(
      create: (context) => VendorProductsBloc()..add(LoadProducts(authState.user.uid)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products & Market Items'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6F9686), // Soft Sage
                  Color(0xFF946C7E), // Mauve
                ],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.inventory), text: 'My Products'),
              Tab(icon: Icon(Icons.list_alt), text: 'Product Lists'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyProductsTab(),
            _buildProductListsTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyProductsTab() {
    return BlocBuilder<VendorProductsBloc, VendorProductsState>(
      builder: (context, state) {
        if (state is ProductsLoading) {
          return const LoadingWidget(message: 'Loading your products...');
        }
        
        if (state is ProductsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _refreshProducts(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (state is! ProductsLoaded) {
          return const SizedBox.shrink();
        }
        
        final products = state.products;
        
        return Column(
          children: [
            // Header with stats and add button
            Container(
              padding: const EdgeInsets.all(AppConstants.mediumSpacing),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6F9686),
                    Color(0xFF946C7E),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${products.length} Products',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your global product catalog',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProductDialog(context, state.vendorId),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Products list
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products yet',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first product to get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _productsScrollController,
                      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
                      itemCount: products.length + (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final product = products[index];
                        return _buildProductCard(product);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(VendorProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product image or placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: product.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.image, color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        )
                      : Icon(Icons.inventory, color: Colors.white.withValues(alpha: 0.3)),
                ),
                const SizedBox(width: AppConstants.mediumSpacing),
                
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.category,
                        style: const TextStyle(
                          color: HiPopColors.primaryDeepSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Price and actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.displayPrice,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.successGreenDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showEditProductDialog(context, product),
                          icon: const Icon(Icons.edit, size: 20),
                          color: HiPopColors.infoBlueGray,
                          tooltip: 'Edit Product',
                        ),
                        IconButton(
                          onPressed: () => _showDeleteProductDialog(context, product),
                          icon: const Icon(Icons.delete, size: 20),
                          color: HiPopColors.errorPlum,
                          tooltip: 'Delete Product',
                        ),
                      ],
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

  Widget _buildProductListsTab() {
    return BlocBuilder<VendorProductsBloc, VendorProductsState>(
      builder: (context, state) {
        if (state is! ProductsLoaded) {
          return const LoadingWidget(message: 'Loading product lists...');
        }
        
        final productLists = state.productLists;
        
        return Column(
          children: [
            // Header with add list button
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Lists',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Create custom product lists',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _createProductList(context, state.vendorId),
                    icon: const Icon(Icons.add),
                    label: const Text('Create List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Product lists grid
            Expanded(
              child: productLists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Product Lists Yet',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: productLists.length,
                      itemBuilder: (context, index) {
                        final list = productLists[index];
                        return _buildProductListCard(list);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductListCard(VendorProductList list) {
    final color = list.color != null 
        ? Color(int.parse(list.color!.substring(1), radix: 16) + 0xFF000000)
        : Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(list.name),
        subtitle: Text('${list.productCount} products'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // View product list details
        },
      ),
    );
  }

  Widget _buildSettingsTab() {
    return const Center(
      child: Text('Settings'),
    );
  }

  void _showAddProductDialog(BuildContext context, String vendorId) {
    // Show add product dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add product functionality')),
    );
  }

  void _showEditProductDialog(BuildContext context, VendorProduct product) {
    // Show edit product dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit product: ${product.name}')),
    );
  }

  void _showDeleteProductDialog(BuildContext context, VendorProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<VendorProductsBloc>().add(DeleteProduct(product.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _createProductList(BuildContext context, String vendorId) {
    // Show create product list dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create product list functionality')),
    );
  }
}