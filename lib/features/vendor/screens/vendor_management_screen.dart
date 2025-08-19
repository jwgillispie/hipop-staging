import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/vendor/models/managed_vendor.dart';
import 'package:hipop/features/vendor/services/managed_vendor_service.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_form_dialog.dart';
import 'package:hipop/core/theme/hipop_colors.dart';


class VendorManagementScreen extends StatefulWidget {
  const VendorManagementScreen({super.key});

  @override
  State<VendorManagementScreen> createState() => _VendorManagementScreenState();
}

class _VendorManagementScreenState extends State<VendorManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  VendorCategory? _selectedCategory;
  bool _showActiveOnly = false;
  String _searchQuery = '';
  String? _selectedMarketId;
  Map<String, String> _marketNames = {}; // marketId -> marketName
  List<String> _validMarketIds = []; // Only markets that actually exist
  bool _loadingMarketNames = true;

  @override
  void initState() {
    super.initState();
    _selectedMarketId = _getInitialMarketId();
    _loadMarketNames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getInitialMarketId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile?.isMarketOrganizer == true) {
      final managedMarketIds = authState.userProfile!.managedMarketIds;
      return managedMarketIds.isNotEmpty ? managedMarketIds.first : null;
    }
    return null;
  }

  List<String> _getManagedMarketIds() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile?.isMarketOrganizer == true) {
      return authState.userProfile!.managedMarketIds;
    }
    return [];
  }

  String? _getCurrentMarketId() {
    return _selectedMarketId;
  }

  Future<void> _loadMarketNames() async {
    try {
      final managedMarketIds = _getManagedMarketIds();
      final Map<String, String> marketNames = {};
      final List<String> validMarketIds = [];
      
      for (String marketId in managedMarketIds) {
        try {
          final market = await MarketService.getMarket(marketId);
          if (market != null && market.isActive) {
            marketNames[marketId] = market.name;
            validMarketIds.add(marketId);
          }
        } catch (e) {
        }
      }
      
      if (mounted) {
        setState(() {
          _marketNames = marketNames;
          _validMarketIds = validMarketIds;
          _loadingMarketNames = false;
          
          // If current selected market is not valid, switch to first valid one
          if (_selectedMarketId != null && !validMarketIds.contains(_selectedMarketId)) {
            _selectedMarketId = validMarketIds.isNotEmpty ? validMarketIds.first : null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMarketNames = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Management')),
            body: const Center(child: Text('Please sign in to access vendor management')),
          );
        }

        if (state.userProfile == null || !state.userProfile!.isMarketOrganizer) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Management')),
            body: const Center(child: Text('Only market organizers can access this feature')),
          );
        }

        if (state.userProfile!.managedMarketIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Management')),
            body: const Center(
              child: Text('No markets assigned to your organizer account. Please contact support.'),
            ),
          );
        }

        final organizerId = state.user.uid;
        final managedMarketIds = _loadingMarketNames ? _getManagedMarketIds() : _validMarketIds;
        
        // If no market is selected or no markets available, show message
        if (_selectedMarketId == null || managedMarketIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Management')),
            body: const Center(child: Text('No markets available')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vendor Management'),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HiPopColors.secondarySoftSage, // Soft Sage
                    HiPopColors.accentMauve, // Mauve
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: HiPopColors.darkTextPrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterDialog,
              ),
              if (kDebugMode)
                IconButton(
                  icon: const Icon(Icons.bug_report),
                  onPressed: _debugVendors,
                  tooltip: 'Debug Vendors',
                ),
            ],
          ),
          body: Column(
            children: [
              // Market selector dropdown (if multiple markets)
              if (managedMarketIds.length > 1)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    border: Border(bottom: BorderSide(color: HiPopColors.darkBorder)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Market: ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedMarketId,
                          isExpanded: true,
                          items: managedMarketIds.map((marketId) {
                            final marketName = _marketNames[marketId] ?? 
                                (_loadingMarketNames ? 'Loading...' : 'Market ${marketId.substring(0, 8)}...');
                            return DropdownMenuItem<String>(
                              value: marketId,
                              child: Text(
                                marketName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedMarketId = newValue;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              _buildSearchAndFilters(),
              Expanded(child: _buildVendorsList(_selectedMarketId!)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateVendorDialog(_selectedMarketId!, organizerId),
            backgroundColor: HiPopColors.accentMauve,
            foregroundColor: HiPopColors.darkTextPrimary,
            icon: const Icon(Icons.add),
            label: const Text('Add Vendor'),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkBackground, // Dark background
        border: Border(bottom: BorderSide(color: HiPopColors.darkBorder)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: HiPopColors.darkTextPrimary), // White text
            decoration: InputDecoration(
              hintText: 'Search vendors...',
              hintStyle: TextStyle(color: HiPopColors.darkTextTertiary), // Gray placeholder
              prefixIcon: Icon(Icons.search, color: HiPopColors.darkTextTertiary),
              filled: true,
              fillColor: HiPopColors.darkSurface, // Slightly lighter for input
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: HiPopColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: HiPopColors.accentMauve), // Mauve on focus
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<VendorCategory>(
                  value: _selectedCategory,
                  dropdownColor: HiPopColors.darkSurface, // Dark dropdown
                  style: const TextStyle(color: HiPopColors.darkTextPrimary), // White text
                  decoration: InputDecoration(
                    labelText: 'Filter by Category',
                    labelStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                    filled: true,
                    fillColor: HiPopColors.darkSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: HiPopColors.accentMauve),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<VendorCategory>(
                      value: null,
                      child: Text(
                        'All Categories',
                        style: TextStyle(color: HiPopColors.darkTextPrimary),
                      ),
                    ),
                    ...VendorCategory.values.map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            category.displayName,
                            style: const TextStyle(color: HiPopColors.darkTextPrimary),
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(
                  'Active Only',
                  style: TextStyle(
                    color: _showActiveOnly ? HiPopColors.darkTextPrimary : HiPopColors.darkTextTertiary,
                  ),
                ),
                selected: _showActiveOnly,
                selectedColor: HiPopColors.accentMauve, // Mauve when selected
                backgroundColor: HiPopColors.darkSurface,
                checkmarkColor: HiPopColors.darkTextPrimary,
                side: BorderSide(
                  color: _showActiveOnly ? HiPopColors.accentMauve : HiPopColors.darkBorder,
                ),
                onSelected: (selected) {
                  setState(() {
                    _showActiveOnly = selected;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorsList(String marketId) {
    debugPrint('🔍 Building vendors list for market: $marketId');
    
    return StreamBuilder<List<ManagedVendor>>(
      stream: ManagedVendorService.getVendorsForMarket(marketId),
      builder: (context, snapshot) {
        debugPrint('📡 StreamBuilder state: ${snapshot.connectionState}');
        debugPrint('📡 Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('📡 Error: ${snapshot.error}');
        }
        debugPrint('📡 Has data: ${snapshot.hasData}');
        if (snapshot.hasData) {
          debugPrint('📡 Data count: ${snapshot.data?.length}');
          for (var vendor in snapshot.data ?? []) {
            debugPrint('📡 Vendor: ${vendor.businessName} (marketId: ${vendor.marketId})');
          }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var vendors = snapshot.data ?? [];

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          vendors = vendors.where((vendor) =>
              vendor.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              vendor.contactName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              vendor.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }

        if (_selectedCategory != null) {
          vendors = vendors.where((vendor) =>
              vendor.categories.contains(_selectedCategory)).toList();
        }

        if (_showActiveOnly) {
          vendors = vendors.where((vendor) => vendor.isActive).toList();
        }

        if (vendors.isEmpty) {
          return _buildEmptyState(marketId);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            return _buildVendorCard(vendor);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String marketId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory,
            size: 64,
            color: HiPopColors.darkTextTertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Vendors Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null || _showActiveOnly
                ? 'Try adjusting your search or filters'
                : 'Create your first vendor to get started',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final state = context.read<AuthBloc>().state;
              if (state is Authenticated && state.userProfile != null) {
                final organizerId = state.user.uid;
                _showCreateVendorDialog(marketId, organizerId);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First Vendor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.accentMauve,
              foregroundColor: HiPopColors.darkTextPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(ManagedVendor vendor) {
    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor name and active status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.businessName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (vendor.metadata['isPermissionBased'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HiPopColors.accentMauve.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: HiPopColors.accentMauve.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  size: 14,
                                  color: HiPopColors.accentMauve,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Permission-Based',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: HiPopColors.accentMauve,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (vendor.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HiPopColors.warningAmber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: HiPopColors.warningAmber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: HiPopColors.warningAmber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Featured',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: HiPopColors.warningAmber,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: vendor.isActive 
                                ? HiPopColors.successGreen.withValues(alpha: 0.2) 
                                : HiPopColors.darkSurfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: vendor.isActive 
                                  ? HiPopColors.successGreen.withValues(alpha: 0.4)
                                  : HiPopColors.darkBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vendor.isActive ? Icons.check_circle : Icons.pause_circle,
                                size: 14,
                                color: vendor.isActive 
                                    ? HiPopColors.successGreen 
                                    : HiPopColors.darkTextTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vendor.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: vendor.isActive 
                                      ? HiPopColors.successGreen 
                                      : HiPopColors.darkTextTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Contact and description
                Text(
                  'Contact: ${vendor.contactName}',
                  style: TextStyle(
                    color: HiPopColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vendor.description,
                  style: TextStyle(
                    color: HiPopColors.darkTextTertiary,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (vendor.categories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: vendor.categories.take(3).map((category) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: HiPopColors.primaryDeepSage.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: HiPopColors.primaryDeepSage.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        category.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: HiPopColors.primaryDeepSage,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                if (vendor.products.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Products: ${vendor.products.take(3).join(', ')}${vendor.products.length > 3 ? '...' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.darkTextTertiary,
                    ),
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
                Flexible(
                  child: IconButton(
                    onPressed: () => _editVendor(vendor),
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Edit vendor',
                  ),
                ),
                Flexible(
                  child: IconButton(
                    onPressed: () => _toggleVendorStatus(vendor),
                    icon: Icon(
                      vendor.isActive ? Icons.pause_circle : Icons.play_circle,
                      size: 20,
                      color: vendor.isActive ? Colors.orange : Colors.green,
                    ),
                    tooltip: vendor.isActive ? 'Deactivate' : 'Activate',
                  ),
                ),
                Flexible(
                  child: IconButton(
                    onPressed: () => _toggleFeaturedStatus(vendor),
                    icon: Icon(
                      vendor.isFeatured ? Icons.star : Icons.star_border,
                      size: 20,
                      color: vendor.isFeatured ? Colors.amber : Colors.grey,
                    ),
                    tooltip: vendor.isFeatured ? 'Unfeature' : 'Feature',
                  ),
                ),
                const Spacer(),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: ListTile(
                        leading: Icon(Icons.copy),
                        title: Text('Duplicate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
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
                    switch (value) {
                      case 'duplicate':
                        _duplicateVendor(vendor);
                        break;
                      case 'delete':
                        _deleteVendor(vendor);
                        break;
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Show Active Only'),
              value: _showActiveOnly,
              onChanged: (value) {
                setState(() {
                  _showActiveOnly = value;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Clear All Filters'),
              leading: const Icon(Icons.clear),
              onTap: () {
                setState(() {
                  _selectedCategory = null;
                  _showActiveOnly = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
                Navigator.pop(context);
              },
            ),
          ],
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

  void _showCreateVendorDialog(String marketId, String organizerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VendorFormDialog(
        marketId: marketId,
        organizerId: organizerId,
      ),
    );
  }

  void _editVendor(ManagedVendor vendor) {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated && state.userProfile != null) {
      final marketId = state.userProfile!.managedMarketIds.first;
      final organizerId = state.user.uid;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VendorFormDialog(
          marketId: marketId,
          organizerId: organizerId,
          vendor: vendor,
        ),
      );
    }
  }

  void _toggleVendorStatus(ManagedVendor vendor) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await ManagedVendorService.toggleActiveStatus(vendor.id, !vendor.isActive);
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${vendor.businessName} ${vendor.isActive ? 'deactivated' : 'activated'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error updating vendor status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFeaturedStatus(ManagedVendor vendor) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await ManagedVendorService.toggleFeaturedStatus(vendor.id, !vendor.isFeatured);
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${vendor.businessName} ${vendor.isFeatured ? 'unfeatured' : 'featured'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error updating featured status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _duplicateVendor(ManagedVendor vendor) {
    // TODO: Implement vendor duplication
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicate ${vendor.businessName} - Coming soon!'),
      ),
    );
  }

  void _deleteVendor(ManagedVendor vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text(
          'Are you sure you want to delete "${vendor.businessName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await ManagedVendorService.deleteVendor(vendor.id);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('${vendor.businessName} deleted'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting vendor: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _debugVendors() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;
      
      final marketId = _selectedMarketId;
      
      // Get all managed vendors from Firestore directly
      final snapshot = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .get();
      
      
      int matchingMarketCount = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        if (data['marketId'] == marketId) {
          matchingMarketCount++;
        }
      }
      
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${snapshot.docs.length} total vendors, $matchingMarketCount for this market. Check console.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}