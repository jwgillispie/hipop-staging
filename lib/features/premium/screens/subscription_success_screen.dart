import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/subscription_success_service.dart';
import '../models/user_subscription.dart';
import '../../shared/services/user_profile_service.dart';

class SubscriptionSuccessScreen extends StatefulWidget {
  final String sessionId;
  final String userId;

  const SubscriptionSuccessScreen({
    super.key,
    required this.sessionId,
    required this.userId,
  });

  @override
  State<SubscriptionSuccessScreen> createState() => _SubscriptionSuccessScreenState();
}

class _SubscriptionSuccessScreenState extends State<SubscriptionSuccessScreen> {
  bool _isProcessing = true;
  String? _errorMessage;
  UserSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _processSuccessfulSubscription();
  }

  Future<void> _processSuccessfulSubscription() async {
    try {
      debugPrint('🎉 Processing successful subscription...');
      debugPrint('Session ID: ${widget.sessionId}');
      debugPrint('User ID: ${widget.userId}');

      // Process the successful subscription
      final result = await SubscriptionSuccessService.processSuccessfulSubscription(
        sessionId: widget.sessionId,
        userId: widget.userId,
      );

      if (result['success'] == true) {
        setState(() {
          _subscription = result['subscription'] as UserSubscription?;
          _isProcessing = false;
        });
        
        debugPrint('✅ Subscription processed successfully');
        debugPrint('Tier: ${_subscription?.tier.name}');
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Unknown error occurred';
          _isProcessing = false;
        });
        debugPrint('❌ Subscription processing failed: ${_errorMessage}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process subscription: $e';
        _isProcessing = false;
      });
      debugPrint('❌ Exception during subscription processing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Subscription Complete'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(), // Remove back button
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return _buildProcessingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return _buildSuccessView();
  }

  Widget _buildProcessingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 24),
          Text(
            'Processing your subscription...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Subscription Error',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processSuccessfulSubscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Home',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final tierName = _getTierDisplayName(_subscription?.tier) ?? 'Premium';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '🎉 Welcome to $tierName!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your subscription has been activated successfully. You now have access to all premium features.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildFeaturesList(),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToPremiumFeatures(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Explore Premium Features',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _navigateToUserDashboard(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue to App',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'What\'s Next?',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Your subscription will auto-renew monthly\n• You can cancel anytime from your account settings\n• Need help? Contact us at hipopmarkets@gmail.com',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = _getActivatedFeatures();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activated Features',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => 
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.green.shade600,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPremiumFeatures(BuildContext context) async {
    try {
      // Get user profile to determine user type and navigate appropriately
      final userProfileService = UserProfileService();
      final userProfile = await userProfileService.getUserProfile(widget.userId);
      
      if (!mounted) return;
      
      if (userProfile == null) {
        // Fallback to generic premium dashboard
        context.go('/premium/dashboard?userId=${widget.userId}');
        return;
      }
      
      // Navigate based on user type and subscription tier
      final userType = userProfile.userType;
      if (_subscription != null && _subscription!.isPremium) {
        context.go('/premium/dashboard?userId=${widget.userId}');
      } else {
        // If no premium subscription, redirect to appropriate dashboard
        _navigateToUserDashboard(context, userType: userType);
      }
    } catch (e) {
      debugPrint('Error navigating to premium features: $e');
      if (!mounted) return;
      // Fallback navigation
      context.go('/premium/dashboard?userId=${widget.userId}');
    }
  }
  
  Future<void> _navigateToUserDashboard(BuildContext context, {String? userType}) async {
    try {
      if (userType == null) {
        // Get user profile to determine user type
        final userProfileService = UserProfileService();
        final userProfile = await userProfileService.getUserProfile(widget.userId);
        if (!mounted) return;
        userType = userProfile?.userType ?? 'shopper'; // Default to shopper
      }
      
      if (!mounted) return;
      
      // Navigate to appropriate user dashboard
      switch (userType) {
        case 'vendor':
          context.go('/vendor');
          break;
        case 'market_organizer':
          context.go('/organizer');
          break;
        case 'shopper':
        default:
          context.go('/shopper');
          break;
      }
    } catch (e) {
      debugPrint('Error navigating to user dashboard: $e');
      if (!mounted) return;
      // Fallback to shopper dashboard
      context.go('/shopper');
    }
  }

  String? _getTierDisplayName(SubscriptionTier? tier) {
    switch (tier) {
      case SubscriptionTier.shopperPro:
        return 'Shopper Pro';
      case SubscriptionTier.vendorPro:
        return 'Vendor Pro';
      case SubscriptionTier.marketOrganizerPro:
        return 'Market Organizer Pro';
      case SubscriptionTier.enterprise:
        return 'Enterprise';
      case SubscriptionTier.free:
        return 'Free';
      case null:
        return null;
    }
  }

  List<String> _getActivatedFeatures() {
    switch (_subscription?.tier) {
      case SubscriptionTier.shopperPro:
        return [
          'Enhanced search & filtering',
          'Unlimited favorites',
          'Vendor following',
          'Personalized recommendations',
          'Exclusive deals access',
        ];
      case SubscriptionTier.vendorPro:
        return [
          'Full vendor analytics dashboard',
          'Unlimited market participation',
          'Customer acquisition analysis',
          'Profit optimization insights',
          'Priority customer support',
        ];
      case SubscriptionTier.marketOrganizerPro:
        return [
          'Multi-market management dashboard',
          'Vendor performance analytics',
          'Financial forecasting tools',
          'Automated vendor recruitment',
          'Market intelligence reports',
        ];
      case SubscriptionTier.enterprise:
        return [
          'White-label analytics platform',
          'Custom API access',
          'Advanced data integrations',
          'Dedicated account manager',
          'Custom reporting and branding',
        ];
      default:
        return [
          'Premium features activated',
          'Enhanced analytics',
          'Priority support',
        ];
    }
  }
}