import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

class StripeService {
  // 🔒 SECURITY: All Stripe secret key operations moved to server-side Cloud Functions
  
  // Rate limiting and debug tracking
  static final Map<String, DateTime> _lastOperationTime = {};
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  
  // Debug logger - would need to import if actually used
  // static final _debugLogger = DebugLoggerService.instance;
  
  /// Create a checkout session for a subscription using secure Cloud Function
  static Future<String> createCheckoutSession({
    required String priceId,
    required String customerEmail,
    required Map<String, String> metadata,
  }) async {
    try {
      debugPrint('🔒 Creating secure checkout session via Cloud Function');
      debugPrint('📧 Customer email: $customerEmail');
      debugPrint('💰 Price ID: $priceId');
      debugPrint('📋 Metadata: $metadata');
      
      // Call secure Cloud Function instead of direct Stripe API
      final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final result = await callable.call({
        'priceId': priceId,
        'customerEmail': customerEmail,
        'userId': metadata['user_id'],
        'userType': metadata['user_type'],
        'successUrl': kIsWeb 
            ? '${Uri.base.origin}/#/subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=${metadata['user_id']}'
            : 'hipop://subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=${metadata['user_id']}',
        'cancelUrl': kIsWeb 
            ? '${Uri.base.origin}/#/subscription/cancel'
            : 'hipop://subscription/cancel',
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      });

      final checkoutUrl = result.data['url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned from server');
      }

      debugPrint('✅ Secure checkout session created: $checkoutUrl');
      return checkoutUrl;
    } catch (e) {
      debugPrint('❌ Error creating secure checkout session: $e');
      
      // Provide user-friendly error messages
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            throw Exception('Invalid subscription information provided');
          case 'permission-denied':
            throw Exception('Not authorized to create subscription');
          case 'unavailable':
            throw Exception('Subscription service temporarily unavailable');
          default:
            throw Exception('Unable to process subscription request');
        }
      }
      
      rethrow;
    }
  }

  /// Launch checkout for a user subscription
  static Future<void> launchSubscriptionCheckout({
    required String userType,
    required String userId,
    required String userEmail,
  }) async {
    try {
      debugPrint('');
      debugPrint('💳 ========= STRIPE CHECKOUT LAUNCH =========');
      debugPrint('🚀 Starting checkout for $userType subscription');
      debugPrint('👤 User ID: $userId');
      debugPrint('📧 User email: $userEmail');
      debugPrint('⏰ Timestamp: ${DateTime.now()}');
      
      // Get the price ID for this user type
      final priceId = _getPriceIdForUserType(userType);
      if (priceId.isEmpty) {
        debugPrint('❌ No price configured for user type: $userType');
        throw Exception('No price configured for user type: $userType');
      }

      debugPrint('💰 Price ID: $priceId');
      debugPrint('🔍 Environment check:');
      debugPrint('   STRIPE_SECRET_KEY present: ${dotenv.env['STRIPE_SECRET_KEY'] != null}');
      debugPrint('   STRIPE_PUBLISHABLE_KEY present: ${dotenv.env['STRIPE_PUBLISHABLE_KEY'] != null}');

      // Create checkout session
      debugPrint('🔄 Creating Stripe checkout session...');
      final checkoutUrl = await createCheckoutSession(
        priceId: priceId,
        customerEmail: userEmail,
        metadata: {
          'user_id': userId,
          'user_type': userType,
        },
      );

      debugPrint('✅ Checkout URL created: $checkoutUrl');
      final successUrl = kIsWeb 
          ? '${Uri.base.origin}/#/subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=$userId'
          : 'hipop://subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=$userId';
      debugPrint('🔗 Success URL will be: $successUrl');

      // Launch the checkout URL in browser
      debugPrint('🌐 Launching checkout in browser...');
      if (kIsWeb) {
        // On web, open in new tab
        debugPrint('🌐 Platform: Web - opening in new tab');
        await _launchUrl(checkoutUrl);
      } else {
        // On mobile, open in system browser
        debugPrint('📱 Platform: Mobile - opening in system browser');
        await _launchUrl(checkoutUrl);
      }
      
      debugPrint('✅ Checkout launched successfully!');
      debugPrint('💳 ======================================');
      debugPrint('');
    } catch (e) {
      debugPrint('');
      debugPrint('💥 ========= STRIPE CHECKOUT ERROR =========');
      debugPrint('❌ Error launching checkout: $e');
      debugPrint('👤 User: $userId ($userType)');
      debugPrint('📧 Email: $userEmail');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      debugPrint('💥 =====================================');
      debugPrint('');
      rethrow;
    }
  }

  /// Get price ID from environment for user type
  static String _getPriceIdForUserType(String userType) {
    switch (userType) {
      case 'shopper':
        return dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '';
      case 'vendor':
        return dotenv.env['STRIPE_PRICE_VENDOR_PRO'] ?? '';
      case 'market_organizer':
        return dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '';
      default:
        return '';
    }
  }

  /// Get pricing info for display
  static Map<String, dynamic> getPricingForUserType(String userType) {
    switch (userType) {
      case 'shopper':
        return {
          'price': 4.00,
          'name': 'Shopper Premium',
          'description': 'Advanced search, vendor following, and personalized recommendations',
          'features': [
            'Follow unlimited vendors',
            'Advanced search filters',
            'Personalized recommendations',
            'Vendor appearance predictions',
          ],
        };
      case 'vendor':
        return {
          'price': 29.00,
          'name': 'Vendor Pro',
          'description': 'Advanced analytics, market discovery, and multi-market management',
          'features': [
            'Unlimited market applications',
            'Access to organizer vendor posts',
            'Advanced analytics dashboard',
            'Master product lists & inventory tracking',
            'Multi-market management tools',
            'Market discovery & vendor matching',
            'Revenue tracking & financial insights',
            'Customer demographics & behavior analysis',
            'Location performance comparison',
            'Priority customer support',
          ],
        };
      case 'market_organizer':
        return {
          'price': 69.00,  // Updated pricing
          'name': 'Market Organizer Premium',
          'description': 'Complete market management, vendor recruitment and analytics suite',
          'features': [
            'Unlimited vendor posts',
            'Vendor performance analytics',
            'Smart recruitment tools',
            'Financial analytics',
            'Unlimited events',
            'Response management',
            'Advanced reporting',
          ],
        };
      default:
        return {
          'price': 0.00,
          'name': 'Unknown',
          'description': '',
          'features': <String>[],
        };
    }
  }

  /// Launch URL helper
  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
    } else {
      throw Exception('Could not launch checkout URL: $url');
    }
  }

  /// Verify subscription session using secure server-side validation
  /// 🔒 SECURITY: Session verification moved to Cloud Function for security
  static Future<bool> verifySubscriptionSession(String sessionId) async {
    try {
      debugPrint('🔒 Verifying subscription session via Cloud Function');
      debugPrint('🎫 Session ID: $sessionId');
      
      final callable = FirebaseFunctions.instance.httpsCallable('verifySubscriptionSession');
      final result = await callable.call({
        'sessionId': sessionId,
      });
      
      final isValid = result.data['valid'] as bool? ?? false;
      debugPrint(isValid ? '✅ Session verified successfully' : '❌ Session verification failed');
      
      return isValid;
    } catch (e) {
      debugPrint('❌ Error verifying subscription session: $e');
      return false;
    }
  }
  
  /// Cancel subscription using secure server-side operation
  /// 🔒 SECURITY: Cancellation handled server-side for security
  static Future<bool> cancelSubscription(String userId) async {
    try {
      debugPrint('🔒 Cancelling subscription via Cloud Function');
      debugPrint('👤 User ID: $userId');
      
      final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
      final result = await callable.call({
        'userId': userId,
      });
      
      final success = result.data['success'] as bool? ?? false;
      debugPrint(success ? '✅ Subscription cancelled successfully' : '❌ Subscription cancellation failed');
      
      return success;
    } catch (e) {
      debugPrint('❌ Error cancelling subscription: $e');
      return false;
    }
  }
  
  /// Get comprehensive error information for debugging
  static Map<String, dynamic> getDebugInfo() {
    return {
      'service_name': 'StripeService',
      'rate_limit_entries': _lastOperationTime.length,
      'environment_variables': {
        'stripe_secret_key_present': dotenv.env['STRIPE_SECRET_KEY'] != null,
        'stripe_publishable_key_present': dotenv.env['STRIPE_PUBLISHABLE_KEY'] != null,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'unknown',
      },
      'configuration': {
        'default_timeout_seconds': _defaultTimeout.inSeconds,
        'rate_limit_window_seconds': _rateLimitWindow.inSeconds,
      },
      'platform_info': {
        'is_web': kIsWeb,
        'debug_mode': kDebugMode,
      },
    };
  }
  
  /// Clear rate limiting cache (useful for testing)
  static void clearRateLimitCache() {
    _lastOperationTime.clear();
    // Debug logging would go here
    debugPrint('Rate limit cache cleared');
  }
}