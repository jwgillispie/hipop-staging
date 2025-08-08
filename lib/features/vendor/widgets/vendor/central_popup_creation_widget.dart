import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/market/services/market_service.dart';
import '../../services/vendor_market_relationship_service.dart';


class CentralPopupCreationWidget extends StatefulWidget {
  final bool isCompact;
  
  const CentralPopupCreationWidget({
    super.key,
    this.isCompact = false,
  });

  @override
  State<CentralPopupCreationWidget> createState() => _CentralPopupCreationWidgetState();
}

class _CentralPopupCreationWidgetState extends State<CentralPopupCreationWidget> {
  List<Market> _approvedMarkets = [];
  bool _isLoading = true;
  bool _canAccessMarkets = false;

  @override
  void initState() {
    super.initState();
    _loadApprovedMarkets();
  }

  Future<void> _loadApprovedMarkets() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get markets the vendor has permission for
        final approvedMarketIds = await VendorMarketRelationshipService.getApprovedMarketsForVendor(user.uid);
        
        // Get all markets and filter approved ones
        final allMarkets = await MarketService.getAllActiveMarkets();
        final approvedMarkets = allMarkets.where((market) => 
          approvedMarketIds.contains(market.id)
        ).toList();
        
        setState(() {
          _approvedMarkets = approvedMarkets;
          _canAccessMarkets = approvedMarkets.isNotEmpty;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(
                'Loading your market permissions...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_business,
                  size: 28,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Pop-Up Event',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Choose independent or market-associated',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.isCompact) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      title: 'Independent',
                      subtitle: 'Any location you choose',
                      icon: Icons.location_on,
                      color: Colors.deepOrange,
                      onTap: () => context.go('/vendor/create-popup?type=independent'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTypeOption(
                      title: 'Market-Associated',
                      subtitle: _canAccessMarkets 
                          ? '${_approvedMarkets.length} approved markets'
                          : 'Request permission first',
                      icon: Icons.storefront,
                      color: Colors.orange,
                      isEnabled: _canAccessMarkets,
                      onTap: _canAccessMarkets 
                          ? () => context.go('/vendor/create-popup?type=market')
                          : _showMarketPermissionDialog,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Compact version - single button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreatePopupMenu(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Pop-Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
            if (_canAccessMarkets && !widget.isCompact) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, 
                         size: 16, 
                         color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have permission for ${_approvedMarkets.length} market${_approvedMarkets.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/vendor/market-permissions'),
                      child: Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!_canAccessMarkets && !widget.isCompact) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                         size: 16, 
                         color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Request permission to create market-associated pop-ups',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/vendor/market-permissions'),
                      child: Text(
                        'Browse',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
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
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isEnabled ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.black87 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarketPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Market Permission'),
        content: const Text(
          'To create pop-ups associated with markets, you need permission from market organizers. '
          'Would you like to browse markets and request permission?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/vendor/market-permissions');
            },
            child: const Text('Browse Markets'),
          ),
        ],
      ),
    );
  }

  void _showCreatePopupMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create New Pop-up',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildPopupTypeCard(
                    context,
                    'Independent',
                    'Any location',
                    Icons.location_on,
                    Colors.deepOrange,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/vendor/create-popup?type=independent');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPopupTypeCard(
                    context,
                    'Market-Associated',
                    _canAccessMarkets ? 'Approved markets' : 'Need permission',
                    Icons.storefront,
                    Colors.orange,
                    isEnabled: _canAccessMarkets,
                    onTap: () {
                      Navigator.pop(context);
                      if (_canAccessMarkets) {
                        context.go('/vendor/create-popup?type=market');
                      } else {
                        context.go('/vendor/market-permissions');
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupTypeCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isEnabled ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? Colors.black87 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled ? Colors.grey[600] : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}