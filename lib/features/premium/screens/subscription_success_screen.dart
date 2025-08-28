import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/subscription_success_service.dart';
import '../models/user_subscription.dart';
import '../../shared/services/user_profile_service.dart';
import '../services/payment_state_storage_service.dart';
import '../../../core/theme/hipop_colors.dart';

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
  Timer? _timeoutTimer;
  bool _isTimeout = false;
  
  static const int _processingTimeoutSeconds = 30;

  @override
  void initState() {
    super.initState();
    _handleInitialState();
    _startTimeoutTimer();
  }
  
  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(Duration(seconds: _processingTimeoutSeconds), () {
      if (mounted && _isProcessing) {
        setState(() {
          _isTimeout = true;
          _errorMessage = 'Processing is taking longer than expected. Your payment was successful, but we\'re still setting up your account.';
          _isProcessing = false;
        });
        debugPrint('⏰ Subscription processing timed out after $_processingTimeoutSeconds seconds');
      }
    });
  }

  Future<void> _handleInitialState() async {
    // Clear any stored payment state since we're now in success screen
    if (kIsWeb) {
      await PaymentStateStorageService.clearStoredPaymentState();
    }
    
    // Process the successful subscription
    await _processSuccessfulSubscription();
  }

  Future<void> _processSuccessfulSubscription() async {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _isTimeout = false;
    });
    
    try {
      debugPrint('🎉 Processing successful subscription...');
      debugPrint('Session ID: ${widget.sessionId}');
      debugPrint('User ID: ${widget.userId}');

      // Process the successful subscription with timeout
      final result = await SubscriptionSuccessService.processSuccessfulSubscription(
        sessionId: widget.sessionId,
        userId: widget.userId,
      ).timeout(Duration(seconds: _processingTimeoutSeconds), onTimeout: () {
        return {'success': false, 'error': 'Processing timeout'};
      });

      if (!mounted) return;

      if (result['success'] == true) {
        _timeoutTimer?.cancel(); // Cancel timeout since we succeeded
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
        debugPrint('❌ Subscription processing failed: $_errorMessage');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to process subscription: $e';
        _isProcessing = false;
      });
      debugPrint('❌ Exception during subscription processing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? HiPopColors.darkBackground : HiPopColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Subscription Complete',
          style: TextStyle(
            color: isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
          ),
        ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.primaryDeepSage),
          ),
          const SizedBox(height: 24),
          Text(
            'Processing your subscription...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? HiPopColors.darkTextPrimary 
                  : HiPopColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? HiPopColors.darkTextSecondary 
                  : HiPopColors.lightTextSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue to App',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
              color: HiPopColors.errorPlumLight.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 80,
              color: HiPopColors.errorPlum,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Subscription Error',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.errorPlum,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? HiPopColors.darkTextSecondary 
                  : HiPopColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isTimeout) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: HiPopColors.warningAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: HiPopColors.warningAmber,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your payment was processed successfully. The premium features will be available shortly.',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? HiPopColors.darkTextPrimary 
                          : HiPopColors.lightTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processSuccessfulSubscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.warningAmber,
                foregroundColor: HiPopColors.darkTextPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isTimeout ? 'Check Again' : 'Try Again',
                style: const TextStyle(
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
              color: HiPopColors.successGreenLight.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: HiPopColors.successGreen,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '🎉 Welcome to $tierName!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? HiPopColors.darkTextPrimary 
                  : HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your subscription has been activated successfully. You now have access to all premium features.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? HiPopColors.darkTextSecondary 
                  : HiPopColors.lightTextSecondary,
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
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: HiPopColors.darkTextPrimary,
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? HiPopColors.darkSurfaceVariant
                  : HiPopColors.infoBlueGrayLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? HiPopColors.darkBorder
                    : HiPopColors.infoBlueGray.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: HiPopColors.infoBlueGray,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'What\'s Next?',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? HiPopColors.darkTextPrimary 
                              : HiPopColors.lightTextPrimary,
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
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? HiPopColors.darkTextSecondary 
                        : HiPopColors.lightTextSecondary,
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
        color: Theme.of(context).brightness == Brightness.dark
            ? HiPopColors.darkSurface
            : HiPopColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? HiPopColors.darkBorder
              : HiPopColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : HiPopColors.lightShadow,
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? HiPopColors.darkTextPrimary 
                  : HiPopColors.lightTextPrimary,
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
                      color: HiPopColors.successGreenLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.check,
                      color: HiPopColors.successGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? HiPopColors.darkTextPrimary 
                            : HiPopColors.lightTextPrimary,
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
      final localContext = this.context;
      
      if (userProfile == null) {
        // Fallback to shopper dashboard (most common case)
        localContext.go('/shopper');
        return;
      }
      
      // Navigate based on user type to their specific premium experience
      final userType = userProfile.userType;
      if (_subscription != null && _subscription!.isPremium) {
        switch (userType) {
          case 'vendor':
            localContext.go('/vendor'); // Vendor dashboard shows premium features when user has subscription
            break;
          case 'market_organizer':
          case 'organizer':
            localContext.go('/organizer'); // Organizer dashboard shows premium features when user has subscription
            break;
          case 'shopper':
          default:
            localContext.go('/shopper'); // Shopper dashboard shows premium features when user has subscription
            break;
        }
      } else {
        // If no premium subscription, redirect to appropriate dashboard
        await _navigateToUserDashboard(localContext, userType: userType);
      }
    } catch (e) {
      debugPrint('Error navigating to premium features: $e');
      if (!mounted) return;
      // Fallback navigation to shopper dashboard (safest default)
      this.context.go('/shopper');
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
      final localContext = this.context;
      
      // Navigate to appropriate user dashboard
      switch (userType) {
        case 'vendor':
          localContext.go('/vendor');
          break;
        case 'market_organizer':
          localContext.go('/organizer');
          break;
        case 'shopper':
        default:
          localContext.go('/shopper');
          break;
      }
    } catch (e) {
      debugPrint('Error navigating to user dashboard: $e');
      if (!mounted) return;
      // Fallback to shopper dashboard
      this.context.go('/shopper');
    }
  }

  String? _getTierDisplayName(SubscriptionTier? tier) {
    switch (tier) {
      case SubscriptionTier.shopperPremium:
        return 'Shopper Pro';
      case SubscriptionTier.vendorPremium:
        return 'Vendor Premium';
      case SubscriptionTier.marketOrganizerPremium:
        return 'Market Organizer Premium';
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
      case SubscriptionTier.shopperPremium:
        return [
          'Enhanced search & filtering',
          'Unlimited favorites',
          'Vendor following',
          'Personalized recommendations',
          'Exclusive deals access',
        ];
      case SubscriptionTier.vendorPremium:
        return [
          'Full vendor analytics dashboard',
          'Unlimited market participation',
          'Customer acquisition analysis',
          'Profit optimization insights',
          'Priority customer support',
        ];
      case SubscriptionTier.marketOrganizerPremium:
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