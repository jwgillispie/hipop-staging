import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../models/market.dart';
import '../models/vendor_application.dart';
import '../services/market_service.dart';
import '../services/vendor_market_relationship_service.dart';
import '../services/vendor_application_service.dart';
import '../widgets/common/hipop_text_field.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

class VendorMarketPermissionsScreen extends StatefulWidget {
  const VendorMarketPermissionsScreen({super.key});

  @override
  State<VendorMarketPermissionsScreen> createState() => _VendorMarketPermissionsScreenState();
}

class _VendorMarketPermissionsScreenState extends State<VendorMarketPermissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Market> _allMarkets = [];
  List<Market> _approvedMarkets = [];
  List<VendorApplication> _pendingApplications = [];
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Load all markets
      final allMarkets = await MarketService.getAllActiveMarkets();
      
      // Load approved market IDs
      final approvedMarketIds = await VendorMarketRelationshipService.getApprovedMarketsForVendor(user.uid);
      
      // Filter approved markets
      final approvedMarkets = allMarkets.where((market) => 
        approvedMarketIds.contains(market.id)
      ).toList();

      // Load pending applications
      final applications = await VendorApplicationService.getApplicationsForVendor(user.uid).first;
      final pendingPermissionApps = applications.where((app) => 
        app.isMarketPermission && app.isPending
      ).toList();

      setState(() {
        _allMarkets = allMarkets;
        _approvedMarkets = approvedMarkets;
        _pendingApplications = pendingPermissionApps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Permissions'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Browse Markets', icon: Icon(Icons.search)),
            Tab(text: 'My Markets', icon: Icon(Icons.verified)),
            Tab(text: 'Pending', icon: Icon(Icons.pending)),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading market data...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Error Loading Markets',
                  message: _error!,
                  onRetry: _loadData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBrowseMarketsTab(),
                    _buildMyMarketsTab(),
                    _buildPendingTab(),
                  ],
                ),
    );
  }

  Widget _buildBrowseMarketsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to continue'));
    }

    // Filter out markets where vendor already has permission or pending request
    final approvedMarketIds = _approvedMarkets.map((m) => m.id).toSet();
    final pendingMarketIds = _pendingApplications.map((app) => app.marketId).toSet();
    
    final availableMarkets = _allMarkets.where((market) => 
      !approvedMarketIds.contains(market.id) && !pendingMarketIds.contains(market.id)
    ).toList();

    if (availableMarkets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green[400],
              ),
              const SizedBox(height: 16),
              Text(
                'All Set!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.green[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have permissions or pending requests for all available markets.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: availableMarkets.length,
      itemBuilder: (context, index) {
        final market = availableMarkets[index];
        return _buildMarketCard(market, canRequest: true);
      },
    );
  }

  Widget _buildMyMarketsTab() {
    if (_approvedMarkets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Market Permissions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Request permission from market organizers to create pop-ups at their markets.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                child: const Text('Browse Markets'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _approvedMarkets.length,
      itemBuilder: (context, index) {
        final market = _approvedMarkets[index];
        return _buildMarketCard(market, isApproved: true);
      },
    );
  }

  Widget _buildPendingTab() {
    if (_pendingApplications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pending,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Pending Requests',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You don\'t have any pending permission requests.',
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingApplications.length,
      itemBuilder: (context, index) {
        final application = _pendingApplications[index];
        final market = _allMarkets.firstWhere(
          (m) => m.id == application.marketId,
          orElse: () => Market(
            id: application.marketId,
            name: 'Unknown Market',
            address: '',
            city: '',
            state: '',
            latitude: 0,
            longitude: 0,
            createdAt: DateTime.now(),
          ),
        );
        return _buildPendingApplicationCard(market, application);
      },
    );
  }

  Widget _buildMarketCard(Market market, {bool canRequest = false, bool isApproved = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        market.fullAddress,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isApproved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Approved',
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
            if (market.operatingDays.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Operating Days:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: market.operatingDays.entries.map((entry) {
                  return Chip(
                    label: Text(
                      '${_formatOperatingDayKey(entry.key)}: ${entry.value}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
            if (canRequest) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _showRequestPermissionDialog(market),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Request Permission'),
                ),
              ),
            ],
            if (isApproved) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/vendor/create-popup?type=market&marketId=${market.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Pop-Up'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApplicationCard(Market market, VendorApplication application) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        market.fullAddress,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Submitted: ${_formatDate(application.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (application.specialMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Message: "${application.specialMessage}"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRequestPermissionDialog(Market market) {
    final messageController = TextEditingController();
    final howDidYouHearController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Permission: ${market.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Send a permission request to the market organizer. Once approved, you can create pop-ups for this market.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              HiPopTextField(
                controller: messageController,
                labelText: 'Message to Organizer (Optional)',
                hintText: 'Tell them about your business...',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              HiPopTextField(
                controller: howDidYouHearController,
                labelText: 'How did you hear about this market? (Optional)',
                hintText: 'Social media, referral, etc.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _submitPermissionRequest(
                market,
                messageController.text.trim(),
                howDidYouHearController.text.trim(),
              );
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPermissionRequest(Market market, String message, String howDidYouHear) async {
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await VendorApplicationService.submitMarketPermissionRequest(
        vendorId: user.uid,
        marketId: market.id,
        specialMessage: message.isEmpty ? null : message,
        howDidYouHear: howDidYouHear.isEmpty ? null : howDidYouHear,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission request sent to ${market.name}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh data and switch to pending tab
        await _loadData();
        _tabController.animateTo(2);
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatOperatingDayKey(String key) {
    // Check if this is a specific date format (contains underscores and numbers)
    if (key.contains('_') && RegExp(r'_\d{4}_\d{1,2}_\d{1,2}$').hasMatch(key)) {
      // Parse specific date format: "sunday_2025_7_27"
      final parts = key.split('_');
      if (parts.length == 4) {
        final year = int.tryParse(parts[1]);
        final month = int.tryParse(parts[2]);
        final day = int.tryParse(parts[3]);
        
        if (year != null && month != null && day != null) {
          final monthName = _getMonthName(month);
          return '$monthName $day';
        }
      }
    }
    
    // Regular recurring day format
    return key.toUpperCase();
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return 'Month';
    }
  }
}