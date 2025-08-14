import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user_subscription.dart';
import '../services/subscription_service.dart';
import '../services/stripe_service.dart';

/// 🔒 SECURE: Subscription management screen for users
/// 
/// This screen allows users to:
/// - View current subscription status
/// - Manage billing information  
/// - Cancel subscriptions
/// - View usage statistics
/// - Update payment methods
class SubscriptionManagementScreen extends StatefulWidget {
  final String userId;
  
  const SubscriptionManagementScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  UserSubscription? _subscription;
  bool _isLoading = true;
  Map<String, dynamic>? _usageStats;
  
  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }
  
  Future<void> _loadSubscriptionData() async {
    try {
      setState(() => _isLoading = true);
      
      final subscription = await SubscriptionService.getUserSubscription(widget.userId);
      final usage = await SubscriptionService.getCurrentUsage(widget.userId);
      
      if (mounted) {
        setState(() {
          _subscription = subscription;
          _usageStats = usage;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading subscription data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subscription data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscription'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCurrentPlanCard(),
                const SizedBox(height: 16),
                _buildUsageStatsCard(),
                const SizedBox(height: 16),
                _buildBillingInfoCard(),
                const SizedBox(height: 16),
                _buildActionsCard(),
              ],
            ),
          ),
    );
  }
  
  Widget _buildCurrentPlanCard() {
    final subscription = _subscription;
    final isActive = subscription?.isActive == true;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  color: isActive ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Plan', 
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Plan name and price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPlanName(subscription),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPlanDescription(subscription),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (subscription?.tier != SubscriptionTier.free)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${subscription?.getMonthlyPrice()?.toStringAsFixed(2) ?? '0.00'}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Text('per month'),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? 'Active' : _getStatusText(subscription),
                style: TextStyle(
                  color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            if (subscription?.subscriptionStartDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Started: ${_formatDate(subscription!.subscriptionStartDate!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUsageStatsCard() {
    if (_subscription?.tier == SubscriptionTier.free) {
      return _buildFreeTierUsageCard();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Overview', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_subscription?.isPremium == true)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Unlimited Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text('Premium features unlock unlimited usage'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFreeTierUsageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free Tier Usage', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildUsageIndicator('Products', 3, 3),
            const SizedBox(height: 12),
            _buildUsageIndicator('Product Lists', 1, 1),
            const SizedBox(height: 12),
            _buildUsageIndicator('Monthly Markets', 5, 5),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: () => _showUpgradeDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.upgrade),
              label: const Text('Upgrade for Unlimited'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUsageIndicator(String label, int used, int limit) {
    final percentage = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final isAtLimit = used >= limit;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '$used / $limit',
              style: TextStyle(
                color: isAtLimit ? Colors.red : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            isAtLimit ? Colors.red : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBillingInfoCard() {
    final subscription = _subscription;
    if (subscription?.tier == SubscriptionTier.free) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Billing Information', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow('Customer ID', subscription?.stripeCustomerId ?? 'N/A'),
            _buildInfoRow('Subscription ID', subscription?.stripeSubscriptionId ?? 'N/A'),
            if (subscription?.nextPaymentDate != null)
              _buildInfoRow('Next Payment', _formatDate(subscription!.nextPaymentDate!)),
            if (subscription?.lastPaymentDate != null)
              _buildInfoRow('Last Payment', _formatDate(subscription!.lastPaymentDate!)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Actions', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_subscription?.tier == SubscriptionTier.free)
              ListTile(
                leading: const Icon(Icons.upgrade, color: Colors.green),
                title: const Text('Upgrade to Premium'),
                subtitle: const Text('Unlock unlimited features'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showUpgradeDialog(),
              )
            else ...[
              // Update Payment Method
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Update Payment Method'),
                subtitle: const Text('Change your billing information'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _updatePaymentMethod,
              ),
              
              const Divider(),
              
              // Cancel Subscription
              ListTile(
                leading: Icon(Icons.cancel, color: Colors.red.shade600),
                title: Text(
                  'Cancel Subscription',
                  style: TextStyle(color: Colors.red.shade600),
                ),
                subtitle: const Text('End your premium subscription'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showCancellationDialog,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _getPlanName(UserSubscription? subscription) {
    if (subscription == null) return 'Free Plan';
    
    switch (subscription.tier) {
      case SubscriptionTier.free:
        return 'Free Plan';
      case SubscriptionTier.shopperPro:
        return 'Shopper Pro';
      case SubscriptionTier.vendorPro:
        return 'Vendor Pro';
      case SubscriptionTier.marketOrganizerPro:
        return 'Market Organizer Pro';
      case SubscriptionTier.enterprise:
        return 'Enterprise';
    }
  }
  
  String _getPlanDescription(UserSubscription? subscription) {
    if (subscription == null) return 'Basic features included';
    
    switch (subscription.tier) {
      case SubscriptionTier.free:
        return 'Basic features included';
      case SubscriptionTier.shopperPro:
        return 'Enhanced shopping experience';
      case SubscriptionTier.vendorPro:
        return 'Advanced vendor tools';
      case SubscriptionTier.marketOrganizerPro:
        return 'Complete market management';
      case SubscriptionTier.enterprise:
        return 'Full enterprise solution';
    }
  }
  
  String _getStatusText(UserSubscription? subscription) {
    if (subscription == null) return 'No subscription';
    
    switch (subscription.status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.expired:
        return 'Expired';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _showUpgradeDialog() {
    // TODO: Implement upgrade dialog with different tiers
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text('Choose your premium plan to unlock unlimited features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to upgrade flow
            },
            child: const Text('Choose Plan'),
          ),
        ],
      ),
    );
  }
  
  void _updatePaymentMethod() {
    // TODO: Implement payment method update
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment method update coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  Future<void> _showCancellationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel your subscription?'),
            const SizedBox(height: 16),
            Text(
              'You will lose access to:', 
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._getFeaturesList().map((feature) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $feature'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your subscription will remain active until the end of your current billing period.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _cancelSubscription();
    }
  }
  
  List<String> _getFeaturesList() {
    final subscription = _subscription;
    if (subscription == null) return [];
    
    switch (subscription.tier) {
      case SubscriptionTier.shopperPro:
        return [
          'Enhanced search and filters',
          'Unlimited vendor following',
          'Personalized recommendations',
          'Priority customer support',
        ];
      case SubscriptionTier.vendorPro:
        return [
          'Advanced analytics dashboard',
          'Unlimited products and markets',
          'Revenue tracking',
          'Market discovery tools',
          'Priority customer support',
        ];
      case SubscriptionTier.marketOrganizerPro:
        return [
          'Advanced market analytics',
          'Vendor management tools',
          'Financial reporting',
          'Unlimited events',
          'Priority customer support',
        ];
      default:
        return [];
    }
  }
  
  Future<void> _cancelSubscription() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Cancelling subscription...'),
            ],
          ),
        ),
      );
      
      // Cancel via secure service
      final success = await StripeService.cancelSubscription(widget.userId);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data
        await _loadSubscriptionData();
      } else {
        throw Exception('Cancellation failed');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}