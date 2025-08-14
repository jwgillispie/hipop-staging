import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_subscription.dart';
import '../services/subscription_service.dart';
import '../../shared/widgets/common/loading_widget.dart';

/// Real Stripe Checkout Screen for production payments
class StripeCheckoutScreen extends StatefulWidget {
  final String userId;
  final String userType;
  final SubscriptionTier selectedTier;

  const StripeCheckoutScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.selectedTier,
  });

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  
  // Price IDs from environment
  late final Map<SubscriptionTier, String> _priceIds = {
    SubscriptionTier.vendorPro: dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '',
    SubscriptionTier.marketOrganizerPro: dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '',
    SubscriptionTier.enterprise: dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '',
  };

  @override
  void initState() {
    super.initState();
    // Automatically start checkout when screen loads
    _startStripeCheckout();
  }

  Future<void> _startStripeCheckout() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final priceId = _priceIds[widget.selectedTier];
      if (priceId == null || priceId.isEmpty) {
        throw Exception('Invalid price configuration for ${widget.selectedTier.name}');
      }

      debugPrint('🚀 Starting Stripe checkout for ${widget.selectedTier.name}');
      debugPrint('💰 Price ID: $priceId');

      // Call cloud function to create checkout session
      final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final result = await callable.call({
        'priceId': priceId,
        'customerEmail': user.email,
        'userId': user.uid,
        'userType': widget.userType,
        'successUrl': 'https://hipop-app.web.app/payment-success',
        'cancelUrl': 'https://hipop-app.web.app/payment-cancelled',
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      });

      final sessionUrl = result.data['url'] as String?;
      if (sessionUrl == null) {
        throw Exception('Failed to create checkout session');
      }

      debugPrint('✅ Checkout session created: $sessionUrl');

      // Launch Stripe Checkout in browser
      final uri = Uri.parse(sessionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // Show waiting screen
        setState(() {
          _isProcessing = false;
        });
        
        // Start polling for subscription status
        _pollSubscriptionStatus();
      } else {
        throw Exception('Could not launch Stripe checkout');
      }
    } catch (e) {
      debugPrint('❌ Error starting checkout: $e');
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  /// Poll for subscription status after user completes checkout
  Future<void> _pollSubscriptionStatus() async {
    int attempts = 0;
    const maxAttempts = 60; // Poll for up to 5 minutes
    const pollInterval = Duration(seconds: 5);

    while (attempts < maxAttempts) {
      await Future.delayed(pollInterval);
      
      try {
        // Check if subscription is now active
        final subscription = await SubscriptionService.getUserSubscription(widget.userId);
        
        if (subscription != null && 
            subscription.tier == widget.selectedTier &&
            subscription.status == SubscriptionStatus.active) {
          // Success! Navigate to success page
          if (mounted) {
            _navigateToSuccess();
          }
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Error checking subscription status: $e');
      }
      
      attempts++;
    }
    
    // Timeout - show message to user
    if (mounted) {
      setState(() {
        _errorMessage = 'Payment verification timed out. If you completed payment, please refresh the app.';
      });
    }
  }

  String _getTierName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.vendorPro:
        return 'Vendor Pro';
      case SubscriptionTier.marketOrganizerPro:
        return 'Market Organizer Pro';
      case SubscriptionTier.enterprise:
        return 'Enterprise';
      default:
        return 'Premium';
    }
  }

  void _navigateToSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to ${_getTierName(widget.selectedTier)}!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your premium features are now active.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to premium dashboard
              switch (widget.userType) {
                case 'vendor':
                  context.go('/vendor/premium-dashboard');
                  break;
                case 'market_organizer':
                  context.go('/organizer/premium-dashboard');
                  break;
                default:
                  context.go('/home');
              }
            },
            child: const Text('Go to Premium Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Purchase'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const LoadingWidget(
                  message: 'Setting up secure checkout...',
                ),
                const SizedBox(height: 24),
                const Text(
                  'You will be redirected to Stripe to complete payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Setup Failed',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _startStripeCheckout,
                  child: const Text('Try Again'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Waiting for payment confirmation...',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your purchase in the Stripe checkout window.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}