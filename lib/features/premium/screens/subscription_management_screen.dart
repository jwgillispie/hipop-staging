import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_subscription.dart';
import '../services/subscription_service.dart';
import '../services/stripe_service.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../core/widgets/hipop_app_bar.dart';
import '../../../core/theme/hipop_colors.dart';

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
  
  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }
  
  Future<void> _loadSubscriptionData() async {
    try {
      setState(() => _isLoading = true);
      
      final subscription = await SubscriptionService.getUserSubscription(widget.userId);
      
      if (mounted) {
        setState(() {
          _subscription = subscription;
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
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  /// Handle back navigation - either pop if possible, or navigate to appropriate dashboard
  void _handleBackNavigation() {
    // Check if we can pop (there's a screen underneath in the navigation stack)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // No screen underneath, navigate to appropriate dashboard based on user type
      final authBloc = context.read<AuthBloc>();
      final authState = authBloc.state;
      
      if (authState is Authenticated) {
        // Navigate to the appropriate dashboard based on user type
        switch (authState.userType) {
          case 'vendor':
            context.go('/vendor');
            break;
          case 'market_organizer':
            context.go('/organizer');
            break;
          case 'shopper':
            context.go('/shopper');
            break;
          default:
            // Fallback to shopper dashboard
            context.go('/shopper');
            break;
        }
      } else {
        // Not authenticated, go to auth screen
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HiPopAppBar(
        title: 'Manage Subscription',
        userRole: 'vendor',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBackNavigation(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _subscription?.isPremium == true
            ? _buildPremiumView()
            : _buildNonPremiumView(),
    );
  }
  
  Widget _buildPremiumView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPremiumStatusCard(),
          const SizedBox(height: 16),
          _buildPremiumFeaturesCard(),
          const SizedBox(height: 16),
          _buildBillingInfoCard(),
          const SizedBox(height: 16),
          _buildPremiumActionsCard(),
        ],
      ),
    );
  }

  Widget _buildNonPremiumView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUpgradePromptCard(),
          const SizedBox(height: 16),
          _buildPremiumBenefitsCard(),
          const SizedBox(height: 16),
          _buildCurrentLimitsCard(),
          const SizedBox(height: 16),
          _buildUpgradeActionCard(),
        ],
      ),
    );
  }

  Widget _buildUpgradePromptCard() {
    return Card(
      color: HiPopColors.surfaceSoftPink.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.workspace_premium,
              size: 64,
              color: HiPopColors.primaryDeepSage,
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock Premium Features',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Take your market management to the next level',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _navigateToUpgrade,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Upgrade to Premium'),
              style: FilledButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBenefitsCard() {
    final benefits = _getPremiumBenefitsForUserType();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars, color: HiPopColors.warningAmber),
                const SizedBox(width: 8),
                Text(
                  'Premium Benefits',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: HiPopColors.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      benefit,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLimitsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Free Tier Limits',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_subscription?.userType == 'market_organizer') ...[
              _buildLimitIndicator('Vendor Posts', _subscription?.effectiveMonthlyPostCount ?? 0, 1),
              const SizedBox(height: 12),
              _buildLimitIndicator('Markets Managed', 1, 2),
              const SizedBox(height: 12),
              _buildLimitIndicator('Events per Month', 5, 10),
            ] else if (_subscription?.userType == 'vendor') ...[
              _buildLimitIndicator('Products', 3, 3),
              const SizedBox(height: 12),
              _buildLimitIndicator('Product Lists', 1, 1),
              const SizedBox(height: 12),
              _buildLimitIndicator('Market Applications', _subscription?.effectiveMonthlyApplicationCount ?? 0, 5),
            ],
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: HiPopColors.warningAmber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upgrade to Premium for unlimited access',
                      style: TextStyle(
                        color: HiPopColors.warningAmberDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitIndicator(String label, int used, int limit) {
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
                color: isAtLimit ? HiPopColors.errorPlum : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            isAtLimit ? HiPopColors.errorPlum : HiPopColors.primaryDeepSage,
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeActionCard() {
    final pricing = StripeService.getPricingForUserType(_subscription?.userType ?? 'vendor');
    
    return Card(
      color: HiPopColors.primaryDeepSage.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pricing['name'] as String,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SAVE 20%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$${pricing['price']}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.primaryDeepSage,
                  ),
                ),
                Text(
                  ' /month',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _navigateToUpgrade,
                style: FilledButton.styleFrom(
                  backgroundColor: HiPopColors.primaryDeepSage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Premium Trial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '✓ Cancel anytime ✓ No hidden fees',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getPremiumBenefitsForUserType() {
    switch (_subscription?.userType) {
      case 'market_organizer':
        return [
          'Unlimited vendor recruitment posts',
          'Advanced vendor analytics & performance tracking',
          'Smart vendor matching with AI recommendations',
          'Bulk messaging & communication tools',
          'Financial reporting & revenue insights',
          'Priority vendor support & mediation',
          'Custom market branding options',
          'Export data & reports',
        ];
      case 'vendor':
        return [
          'Unlimited products & inventory tracking',
          'Advanced sales analytics dashboard',
          'Market discovery & auto-matching',
          'Revenue & profit tracking',
          'Customer demographics insights',
          'Multi-market management tools',
          'Priority application review',
          'Marketing tools & promotions',
        ];
      default:
        return [
          'Access to all premium features',
          'Unlimited usage',
          'Priority support',
          'Advanced analytics',
        ];
    }
  }

  Widget _buildPremiumStatusCard() {
    final subscription = _subscription!;
    
    return Card(
      color: HiPopColors.successGreen.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified,
                  color: HiPopColors.successGreen,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPlanName(subscription),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HiPopColors.successGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${subscription.getMonthlyPrice().toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.primaryDeepSage,
                      ),
                    ),
                    Text(
                      'per month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (subscription.nextPaymentDate != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Next billing date',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _formatDate(subscription.nextPaymentDate!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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

  Widget _buildPremiumFeaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.all_inclusive, color: HiPopColors.primaryDeepSage),
                const SizedBox(width: 8),
                Text(
                  'Your Premium Features',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                    HiPopColors.surfaceSoftPink.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: HiPopColors.primaryDeepSage,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlimited Everything',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No limits on posts, markets, or features',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Subscription',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Update Payment Method
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Update Payment Method'),
              subtitle: const Text('Change your billing information'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _updatePaymentMethod,
            ),
            
            if (_subscription?.status == SubscriptionStatus.active) ...[
              const Divider(),
              
              // Pause Subscription
              ListTile(
                leading: Icon(Icons.pause_circle_outline, color: HiPopColors.warningAmber),
                title: Text(
                  'Pause Subscription',
                  style: TextStyle(color: HiPopColors.warningAmber),
                ),
                subtitle: const Text('Temporarily pause billing'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showPauseSubscriptionDialog,
              ),
              
              const Divider(),
              
              // Cancel Subscription
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: HiPopColors.errorPlum),
                title: Text(
                  'Cancel Subscription',
                  style: TextStyle(color: HiPopColors.errorPlum),
                ),
                subtitle: const Text('End your premium access'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showCancellationDialog,
              ),
            ],
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
                  color: isActive ? HiPopColors.successGreen : HiPopColors.errorPlum,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (subscription?.tier != SubscriptionTier.free)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${(subscription?.getMonthlyPrice() ?? 0.0).toStringAsFixed(2)}',
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
                color: isActive ? HiPopColors.successGreen.withValues(alpha: 0.1) : HiPopColors.errorPlum.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? 'Active' : _getStatusText(subscription),
                style: TextStyle(
                  color: isActive ? HiPopColors.successGreenDark : HiPopColors.errorPlumDark,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  color: HiPopColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, color: HiPopColors.successGreen),
                    const SizedBox(width: 12),
                    Text(
                      'Unlimited Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HiPopColors.successGreen,
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
              onPressed: () => _navigateToUpgrade(),
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
                color: isAtLimit ? HiPopColors.errorPlum : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            isAtLimit ? HiPopColors.errorPlum : HiPopColors.primaryDeepSage,
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                leading: Icon(Icons.upgrade, color: HiPopColors.successGreen),
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
              
              // Pause Subscription
              if (_subscription?.status == SubscriptionStatus.active)
                ListTile(
                  leading: Icon(Icons.pause, color: HiPopColors.warningAmber),
                  title: Text(
                    'Pause Subscription',
                    style: TextStyle(color: HiPopColors.warningAmber),
                  ),
                  subtitle: const Text('Temporarily pause your subscription'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _showPauseSubscriptionDialog,
                ),
              
              if (_subscription?.status == SubscriptionStatus.active)
                const Divider(),
              
              // Cancel Subscription
              ListTile(
                leading: Icon(Icons.cancel, color: HiPopColors.errorPlum),
                title: Text(
                  'Cancel Subscription',
                  style: TextStyle(color: HiPopColors.errorPlum),
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
        return 'Vendor Premium';
      case SubscriptionTier.marketOrganizerPro:
        return 'Market Organizer Premium';
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
              _navigateToUpgrade();
            },
            child: const Text('Choose Plan'),
          ),
        ],
      ),
    );
  }
  
  void _navigateToUpgrade() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      // Navigate to premium upgrade flow with vendor tier (most common for subscription management)
      context.go('/premium/upgrade?tier=vendor&userId=${authState.user.uid}');
    }
  }
  
  Future<void> _updatePaymentMethod() async {
    try {
      final subscription = _subscription;
      if (subscription?.stripeCustomerId == null) {
        throw Exception('No payment method found');
      }
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Setting up payment method update...'),
            ],
          ),
        ),
      );
      
      // Get update URL from server
      final updateUrl = await StripeService.createPaymentMethodUpdateSession(
        subscription!.stripeCustomerId!,
      );
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (updateUrl != null) {
        // Launch payment method update
        await StripeService.launchPaymentMethodUpdate(updateUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method update completed'),
              backgroundColor: HiPopColors.successGreen,
            ),
          );
          
          // Reload subscription data
          await _loadSubscriptionData();
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment method: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  Future<void> _showCancellationDialog() async {
    debugPrint('Starting cancellation flow');
    
    // Show cancellation options directly (no fake retention offers)
    final cancellationChoice = await _showCancellationOptions();
    debugPrint('Cancellation choice: $cancellationChoice');
    if (cancellationChoice == null) return;
    
    // Get feedback
    final feedback = await _showFeedbackDialog();
    debugPrint('Feedback received: $feedback');
    
    // Execute cancellation
    await _executeCancellation(cancellationChoice, feedback);
  }
  // Removed fake retention offers per Google's advice and Stripe best practices
  // Keep cancellation simple and straightforward
  
  Future<String?> _showCancellationOptions() async {
    final subscription = _subscription;
    if (subscription == null) return null;
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellation Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How would you like to cancel your subscription?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Cancel at period end (recommended)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: HiPopColors.successGreen.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
                color: HiPopColors.successGreen.withValues(alpha: 0.1),
              ),
              child: ListTile(
                leading: Icon(Icons.schedule, color: HiPopColors.successGreen),
                title: const Text(
                  'Cancel at period end',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keep access until ${_formatDate(subscription.nextPaymentDate ?? DateTime.now())}'),
                    const Text('Recommended • No immediate loss of features'),
                  ],
                ),
                trailing: Icon(Icons.check_circle, color: HiPopColors.successGreen),
                onTap: () => Navigator.pop(context, 'end_of_period'),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Cancel immediately with prorated refund
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: HiPopColors.warningAmber.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
                color: HiPopColors.warningAmber.withValues(alpha: 0.1),
              ),
              child: ListTile(
                leading: Icon(Icons.money_off, color: HiPopColors.warningAmber),
                title: const Text(
                  'Cancel immediately',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Lose access now • Prorated refund for unused time',
                ),
                onTap: () => Navigator.pop(context, 'immediate'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'You will lose access to:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ..._getFeaturesList().take(3).map((feature) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  '• $feature',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              ),
            ),
            if (_getFeaturesList().length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  '• And ${_getFeaturesList().length - 3} more...',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
  
  Future<String?> _showFeedbackDialog() async {
    final feedbackController = TextEditingController();
    String? selectedReason;
    
    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Help us improve'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why are you cancelling? (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                
                // Reason selection
                ...[
                  'Too expensive',
                  'Not using enough features',
                  'Found a better alternative',
                  'Technical issues',
                  'Seasonal business',
                  'Other'
                ].map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() => selectedReason = value),
                  dense: true,
                )),
                
                const SizedBox(height: 16),
                
                // Additional feedback
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional feedback (optional)',
                    hintText: 'Tell us more about your experience...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                final feedback = {
                  'reason': selectedReason ?? '',
                  'details': feedbackController.text,
                }.entries
                .where((entry) => entry.value.isNotEmpty)
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n');
                Navigator.pop(context, feedback);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _executeCancellation(String cancellationType, String? feedback) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                cancellationType == 'immediate' 
                  ? 'Cancelling subscription and processing refund...'
                  : 'Scheduling cancellation for end of billing period...',
              ),
            ],
          ),
        ),
      );
      
      debugPrint('Executing cancellation: type=$cancellationType, feedback=$feedback');
      
      // Call enhanced cancellation service
      final success = await StripeService.cancelSubscriptionEnhanced(
        widget.userId,
        cancellationType: cancellationType,
        feedback: feedback,
      );
      
      debugPrint('Cancellation result: $success');
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cancellationType == 'immediate'
                  ? 'Subscription cancelled. Refund will be processed within 5-10 business days.'
                  : 'Subscription will be cancelled at the end of your billing period. You\'ll retain access until then.',
              ),
              backgroundColor: HiPopColors.successGreen,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Reload data
          await _loadSubscriptionData();
        }
      } else {
        throw Exception('Cancellation failed');
      }
    } catch (e) {
      debugPrint('Error in _executeCancellation: $e');
      
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling subscription: $e'),
            backgroundColor: HiPopColors.errorPlum,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _executeCancellation(cancellationType, feedback),
            ),
          ),
        );
      }
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
  
  Future<void> _showBillingHistory() async {
    try {
      final subscription = _subscription;
      if (subscription?.stripeCustomerId == null) {
        throw Exception('No billing history available');
      }
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading billing history...'),
            ],
          ),
        ),
      );
      
      final billingHistory = await StripeService.getBillingHistory(widget.userId);
      
      if (mounted) Navigator.of(context).pop();
      
      if (mounted && billingHistory != null) {
        _showBillingHistoryDialog(billingHistory);
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading billing history: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  void _showBillingHistoryDialog(List<Map<String, dynamic>> billingHistory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Billing History'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: billingHistory.length,
            itemBuilder: (context, index) {
              final invoice = billingHistory[index];
              return ListTile(
                leading: Icon(
                  invoice['status'] == 'paid' ? Icons.check_circle : Icons.pending,
                  color: invoice['status'] == 'paid' ? HiPopColors.successGreen : HiPopColors.warningAmber,
                ),
                title: Text('\$${(invoice['amount'] / 100).toStringAsFixed(2)}'),
                subtitle: Text(
                  '${_formatDate(DateTime.fromMillisecondsSinceEpoch(invoice['created'] * 1000))}\n'
                  'Status: ${invoice['status']}',
                ),
                trailing: invoice['invoice_pdf'] != null
                  ? IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => StripeService.downloadInvoice(invoice['invoice_pdf']),
                    )
                  : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _downloadLatestInvoice() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing invoice download...'),
            ],
          ),
        ),
      );
      
      final invoiceUrl = await StripeService.getLatestInvoicePdf(widget.userId);
      
      if (mounted) Navigator.of(context).pop();
      
      if (invoiceUrl != null) {
        await StripeService.downloadInvoice(invoiceUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice download started'),
              backgroundColor: HiPopColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading invoice: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  Future<void> _showPauseSubscriptionDialog() async {
    final pauseDuration = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How long would you like to pause your subscription?'),
            const SizedBox(height: 16),
            ...[
              {'duration': 30, 'label': '1 month'},
              {'duration': 60, 'label': '2 months'}, 
              {'duration': 90, 'label': '3 months'},
            ].map((option) => ListTile(
              title: Text(option['label'] as String),
              subtitle: const Text('No charges during pause'),
              onTap: () => Navigator.pop(context, option['duration'] as int),
            )),
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
    
    if (pauseDuration != null) {
      await _pauseSubscription(pauseDuration);
    }
  }
  
  Future<void> _pauseSubscription(int daysCount) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Pausing subscription...'),
            ],
          ),
        ),
      );
      
      final success = await StripeService.pauseSubscription(widget.userId, daysCount);
      
      if (mounted) Navigator.of(context).pop();
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription paused for $daysCount days'),
              backgroundColor: HiPopColors.successGreen,
            ),
          );
          
          await _loadSubscriptionData();
        }
      } else {
        throw Exception('Failed to pause subscription');
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pausing subscription: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
}