import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
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
  
  List<VendorProduct> _products = [];
  List<VendorProductList> _productLists = [];
  List<Market> _approvedMarkets = [];
  bool _isLoading = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() {
      _currentUserId = authState.user.uid;
      _isLoading = true;
    });

    try {
      // Load products and product lists
      final futures = await Future.wait([
        VendorProductService.getVendorProducts(_currentUserId),
        VendorProductService.getProductLists(_currentUserId),
      ]);

      // Load approved markets separately since we need to convert IDs to Market objects
      final approvedMarketIds = await VendorMarketRelationshipService.getApprovedMarketsForVendor(_currentUserId);
      final approvedMarkets = await _getMarketsByIds(approvedMarketIds);

      if (mounted) {
        setState(() {
          _products = futures[0] as List<VendorProduct>;
          _productLists = futures[1] as List<VendorProductList>;
          _approvedMarkets = approvedMarkets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor products data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: _isLoading
          ? const LoadingWidget(message: 'Loading your products...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyProductsTab(),
                _buildProductListsTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildMyProductsTab() {
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
                Color(0xFF6F9686), // Soft Sage (same as AppBar)
                Color(0xFF946C7E), // Mauve (same as AppBar)
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
                      '${_products.length} Products',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // White text to match AppBar
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your global product catalog',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9), // Slightly transparent white
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2), // Semi-transparent white
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
          child: _products.isEmpty
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
                        'Create your first product to get started. Products can be used across multiple markets.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.mediumSpacing),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _buildProductCard(product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(VendorProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Clean dark background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08), // Subtle border
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
                    color: const Color(0xFF2A2A2A), // Darker background for image container
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
                      if (product.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                          onPressed: () => _showEditProductDialog(product),
                          icon: const Icon(Icons.edit, size: 20),
                          color: HiPopColors.infoBlueGray,
                          tooltip: 'Edit Product',
                        ),
                        IconButton(
                          onPressed: () => _showDeleteProductDialog(product),
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
            
            // Tags
            if (product.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: product.tags.map((tag) => Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
                  side: BorderSide(color: HiPopColors.infoBlueGray.withValues(alpha: 0.3)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            
            // Market assignments info
            FutureBuilder<List<VendorMarketProductAssignment>>(
              future: VendorProductService.getProductAssignments(product.id),
              builder: (context, snapshot) {
                final assignments = snapshot.data ?? [];
                if (assignments.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: HiPopColors.warningAmber.withValues(alpha: 0.3)),
                    )
                  );
                }
                
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreenLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: HiPopColors.successGreenLight.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.store, size: 16, color: HiPopColors.successGreenDark),
                      const SizedBox(width: 8),
                      Text(
                        'Available in ${assignments.length} market${assignments.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: HiPopColors.successGreenDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListsTab() {
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
                onPressed: () => _createProductList(),
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
          child: _productLists.isEmpty
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
                      const SizedBox(height: 8),
                      Text(
                        'Create your first product list to organize products\nfor specific markets or events.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _createProductList(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Product List'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Swipe to see all lists',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200, // Fixed height for horizontal scrolling
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _productLists.length,
                          itemBuilder: (context, index) {
                            final list = _productLists[index];
                            return Container(
                              width: 280, // Fixed width for each card
                              margin: EdgeInsets.only(
                                right: index < _productLists.length - 1 ? 16 : 0,
                              ),
                              child: _buildProductListCard(list),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProductListCard(VendorProductList list) {
    final color = list.color != null 
        ? Color(int.parse(list.color!.substring(1), radix: 16) + 0xFF000000)
        : Theme.of(context).primaryColor;

    return Container(
      height: 200, // Fixed height for horizontal cards
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Clean dark background matching products
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08), // Subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewProductList(list),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with color indicator and menu
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        list.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editProductList(list);
                            break;
                          case 'assign':
                            _assignListToMarket(list);
                            break;
                          case 'delete':
                            _deleteProductList(list);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit List'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign',
                          child: ListTile(
                            leading: Icon(Icons.store),
                            title: Text('Assign to Market'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('Delete List'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Description
                if (list.description?.isNotEmpty == true) ...[
                  Text(
                    list.description!,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
                
                const Spacer(),
                
                // Footer with product count and action buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${list.productCount} products',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                'View Details',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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
          ),
        ),
      ),
    );
  }


  // =============================================================================
  // PRODUCT LIST MANAGEMENT METHODS
  // =============================================================================

  void _createProductList() {
    _showProductListDialog(null);
  }

  void _editProductList(VendorProductList list) {
    _showProductListDialog(list);
  }

  void _viewProductList(VendorProductList list) {
    showDialog(
      context: context,
      builder: (context) => _buildProductListViewDialog(list),
    );
  }

  Widget _buildProductListViewDialog(VendorProductList list) {
    // Get products in this list
    final listProducts = _products.where((product) => 
      list.productIds.contains(product.id)
    ).toList();
    
    // Get products NOT in this list
    final availableProducts = _products.where((product) => 
      !list.productIds.contains(product.id)
    ).toList();

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: list.color != null 
                    ? Color(int.parse(list.color!.substring(1), radix: 16) + 0xFF000000)
                    : Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (list.description != null)
                          Text(
                            list.description!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _editProductList(list);
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.inventory), text: 'Products in List'),
                        Tab(icon: Icon(Icons.add_circle_outline), text: 'Add Products'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Products in list tab
                          _buildProductsInListTab(list, listProducts),
                          // Add products tab
                          _buildAddProductsTab(list, availableProducts),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsInListTab(VendorProductList list, List<VendorProduct> listProducts) {
    if (listProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Products in List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to "Add Products" tab to add products to this list.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listProducts.length,
      itemBuilder: (context, index) {
        final product = listProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: HiPopColors.infoBlueGray.withValues(alpha: 0.2),
              child: Text(
                product.name[0].toUpperCase(),
                style: TextStyle(
                  color: HiPopColors.infoBlueGrayDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.category),
                if (product.basePrice != null)
                  Text('\$${product.basePrice!.toStringAsFixed(2)}'),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _removeProductFromList(list, product),
              icon: const Icon(Icons.remove_circle, color: HiPopColors.errorPlum),
              tooltip: 'Remove from list',
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddProductsTab(VendorProductList list, List<VendorProduct> availableProducts) {
    if (availableProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: HiPopColors.successGreenLight),
            const SizedBox(height: 16),
            Text(
              'All Products Added',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HiPopColors.successGreenDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All your products are already in this list!',
              style: TextStyle(color: HiPopColors.backgroundWarmGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: availableProducts.length,
      itemBuilder: (context, index) {
        final product = availableProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: HiPopColors.successGreenLight.withValues(alpha: 0.2),
              child: Text(
                product.name[0].toUpperCase(),
                style: TextStyle(
                  color: HiPopColors.successGreenDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.category),
                if (product.basePrice != null)
                  Text('\$${product.basePrice!.toStringAsFixed(2)}'),
              ],
            ),
            trailing: ElevatedButton.icon(
              onPressed: () => _addProductToList(list, product),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.successGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  void _assignListToMarket(VendorProductList list) {
    if (_approvedMarkets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be approved for markets first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign "${list.name}" to Market'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a market to assign all ${list.productCount} products from "${list.name}":'),
            const SizedBox(height: 16),
            DropdownButton<Market>(
              value: null,
              hint: const Text('Select Market'),
              isExpanded: true,
              items: _approvedMarkets.map((market) {
                return DropdownMenuItem(
                  value: market,
                  child: Text(market.name),
                );
              }).toList(),
              onChanged: (market) {
                if (market != null) {
                  Navigator.pop(context);
                  _performListAssignment(list, market);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performListAssignment(VendorProductList list, Market market) async {
    try {
      final assignments = await VendorProductService.assignProductListToMarket(
        vendorId: _currentUserId,
        marketId: market.id,
        listId: list.id,
        isAvailable: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully assigned ${assignments.length}/${list.productCount} products from "${list.name}" to ${market.name}'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        _loadInitialData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning list to market: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  void _deleteProductList(VendorProductList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product List'),
        content: Text('Are you sure you want to delete "${list.name}"?\n\nThis will not delete the products themselves, only the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performListDeletion(list);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performListDeletion(VendorProductList list) async {
    try {
      await VendorProductService.deleteProductList(list.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${list.name}"'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        _loadInitialData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting list: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  void _showProductListDialog(VendorProductList? existingList) {
    final nameController = TextEditingController(text: existingList?.name ?? '');
    final descriptionController = TextEditingController(text: existingList?.description ?? '');
    String? selectedColor = existingList?.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingList != null ? 'Edit Product List' : 'Create Product List'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  hintText: 'e.g., Grant Park List, Summer Items',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What products are in this list?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Color (Optional):'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: VendorProductList.suggestedColors.map((colorHex) {
                  final color = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
                  return GestureDetector(
                    onTap: () {
                      selectedColor = selectedColor == colorHex ? null : colorHex;
                      (context as Element).markNeedsBuild();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == colorHex
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a list name')),
                );
                return;
              }
              Navigator.pop(context);
              _saveProductList(existingList, name, descriptionController.text.trim(), selectedColor);
            },
            child: Text(existingList != null ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProductList(VendorProductList? existingList, String name, String description, String? color) async {
    try {
      if (existingList != null) {
        // Update existing list
        final updatedList = existingList.copyWith(
          name: name,
          description: description.isEmpty ? null : description,
          color: color,
        );
        await VendorProductService.updateProductList(updatedList);
      } else {
        // Create new list
        await VendorProductService.createProductList(
          vendorId: _currentUserId,
          name: name,
          description: description.isEmpty ? null : description,
          color: color,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingList != null ? 'List updated!' : 'List created!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        _loadInitialData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        // Check if this is a limit error and show upgrade dialog
        if (e.toString().contains('Product list limit reached')) {
          _showProductListLimitReachedDialog();
        } else {
          // Show regular error dialog
          _showErrorDialog(context, 'Error saving list', e.toString());
        }
      }
    }
  }

  void _showProductListLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.upgrade,
                color: HiPopColors.warningAmber,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Product List Limit Reached',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You\'ve reached your limit of 1 product list on the free plan.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.premiumGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HiPopColors.premiumGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upgrade to Vendor Premium (\$29/month) to unlock:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.warningAmber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('✅ Unlimited product lists'),
                  const Text('✅ Unlimited products'),
                  const Text('✅ Advanced analytics'),
                  const Text('✅ Revenue tracking'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to premium upgrade flow
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Premium upgrade flow would open here'),
                  backgroundColor: HiPopColors.infoBlueGray,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // FEEDBACK METHODS
  // =============================================================================

  void _showFeedbackDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    FeedbackCategory selectedCategory = FeedbackCategory.general;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help us improve HiPOP! Your feedback goes directly to our team.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                
                // Category selection
                const Text('Category:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<FeedbackCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: FeedbackCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryDisplayName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Brief summary of your feedback',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Please provide details about your feedback',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 2000,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              
              if (title.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              Navigator.pop(context);
              _submitFeedback(selectedCategory, title, description);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.infoBlueGray,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.feature:
        return 'Feature Request';
      case FeedbackCategory.improvement:
        return 'Improvement Suggestion';
      case FeedbackCategory.general:
        return 'General Feedback';
      case FeedbackCategory.tutorial:
        return 'Tutorial Feedback';
      case FeedbackCategory.support:
        return 'Support Request';
    }
  }

  Future<void> _submitFeedback(FeedbackCategory category, String title, String description) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      await UserFeedbackService.submitFeedback(
        userId: authState.user.uid,
        userType: 'vendor',
        userEmail: authState.user.email ?? '',
        userName: authState.user.displayName,
        category: category,
        title: title,
        description: description,
        metadata: {
          'screen': 'vendor_products_management',
          'timestamp': DateTime.now().toIso8601String(),
          'appSection': 'products_settings',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! We\'ll review it soon.'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  // =============================================================================
  // PRODUCT LIST ITEM MANAGEMENT METHODS
  // =============================================================================

  Future<void> _addProductToList(VendorProductList list, VendorProduct product) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adding "${product.name}" to "${list.name}"...'),
          duration: const Duration(seconds: 1),
        ),
      );

      // Add the product to the list using the service
      await VendorProductService.addProductToList(list.id, product.id);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${product.name}" to "${list.name}"'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );

        // Refresh the data to update the UI
        await _loadInitialData();
        
        // Close and reopen the dialog to show updated data
        if (mounted) {
          Navigator.pop(context);
          _viewProductList(_productLists.firstWhere((l) => l.id == list.id));
        }
      }
    } catch (e) {
      debugPrint('Error adding product to list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product to list: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _removeProductFromList(VendorProductList list, VendorProduct product) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removing "${product.name}" from "${list.name}"...'),
          duration: const Duration(seconds: 1),
        ),
      );

      // Remove the product from the list using the service
      await VendorProductService.removeProductFromList(list.id, product.id);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${product.name}" from "${list.name}"'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );

        // Refresh the data to update the UI
        await _loadInitialData();
        
        // Close and reopen the dialog to show updated data
        if (mounted) {
          Navigator.pop(context);
          _viewProductList(_productLists.firstWhere((l) => l.id == list.id));
        }
      }
    } catch (e) {
      debugPrint('Error removing product from list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing product from list: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
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

  /// Build the Settings tab
  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.mediumSpacing),
          
          // Feedback section
          Card(
            child: ListTile(
              leading: const Icon(Icons.feedback, color: HiPopColors.infoBlueGray),
              title: const Text('Send Feedback'),
              subtitle: const Text('Help us improve the product management experience'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showFeedbackDialog,
            ),
          ),
          
          const SizedBox(height: AppConstants.mediumSpacing),
          
          // Product limits info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.mediumSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: HiPopColors.infoBlueGray),
                      const SizedBox(width: 8),
                      Text(
                        'Product Limits',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Free Plan: Unlimited products, 1 product list\n'
                    'Vendor Premium: Unlimited products & lists',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog to add a new product
  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final basePriceController = TextEditingController();
    final tagsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g., Handmade Soap',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  hintText: 'e.g., Bath & Body, Food, Art',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of your product',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: basePriceController,
                decoration: const InputDecoration(
                  labelText: 'Base Price',
                  hintText: '0.00',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (optional)',
                  hintText: 'organic, handmade, local (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final category = categoryController.text.trim();
              
              if (name.isEmpty || category.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in required fields')),
                );
                return;
              }
              
              Navigator.pop(context);
              _createProduct(
                name: name,
                category: category,
                description: descriptionController.text.trim(),
                basePrice: double.tryParse(basePriceController.text.trim()),
                tags: tagsController.text.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Product'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to edit an existing product
  void _showEditProductDialog(VendorProduct product) {
    final nameController = TextEditingController(text: product.name);
    final categoryController = TextEditingController(text: product.category);
    final descriptionController = TextEditingController(text: product.description ?? '');
    final basePriceController = TextEditingController(text: product.basePrice?.toString() ?? '');
    final tagsController = TextEditingController(text: product.tags.join(', '));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: basePriceController,
                decoration: const InputDecoration(
                  labelText: 'Base Price',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final category = categoryController.text.trim();
              
              if (name.isEmpty || category.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in required fields')),
                );
                return;
              }
              
              Navigator.pop(context);
              _updateProduct(
                product: product,
                name: name,
                category: category,
                description: descriptionController.text.trim(),
                basePrice: double.tryParse(basePriceController.text.trim()),
                tags: tagsController.text.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Product'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to confirm product deletion
  void _showDeleteProductDialog(VendorProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?\n\nThis will remove it from all product lists and market assignments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            style: TextButton.styleFrom(foregroundColor: HiPopColors.errorPlum),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Create a new product
  Future<void> _createProduct({
    required String name,
    required String category,
    String? description,
    double? basePrice,
    List<String>? tags,
  }) async {
    try {
      await VendorProductService.createProduct(
        vendorId: _currentUserId,
        name: name,
        category: category,
        description: description,
        basePrice: basePrice,
        tags: tags ?? [],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "$name"'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        _loadInitialData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating product: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  /// Update an existing product
  Future<void> _updateProduct({
    required VendorProduct product,
    required String name,
    required String category,
    String? description,
    double? basePrice,
    List<String>? tags,
  }) async {
    try {
      await VendorProductService.updateProduct(
        productId: product.id,
        name: name,
        category: category,
        description: description,
        basePrice: basePrice,
        tags: tags,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "$name"'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        _loadInitialData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating product: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  /// Delete a product
  Future<void> _deleteProduct(VendorProduct product) async {
    try {
      await VendorProductService.deleteProduct(product.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${product.name}"'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        _loadInitialData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
}