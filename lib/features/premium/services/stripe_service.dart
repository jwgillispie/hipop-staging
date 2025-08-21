import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/remote_config_service.dart';
import 'browser_detection_service.dart';

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
    String? couponCode,
  }) async {
    try {
      debugPrint('🔒 Creating secure checkout session via Cloud Function');
      debugPrint('📧 Customer email: $customerEmail');
      debugPrint('💰 Price ID: $priceId');
      debugPrint('📋 Metadata: $metadata');
      
      // Call secure Cloud Function instead of direct Stripe API
      final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final requestData = {
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
      };
      
      // Add coupon code if provided
      if (couponCode != null && couponCode.isNotEmpty) {
        requestData['couponCode'] = couponCode;
        debugPrint('🎟️ Including coupon code: $couponCode');
      }
      
      final result = await callable.call(requestData);

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
    String? couponCode,
    BuildContext? context,
  }) async {
    try {
      debugPrint('');
      debugPrint('💳 ========= STRIPE CHECKOUT LAUNCH =========');
      debugPrint('🚀 Starting checkout for $userType subscription');
      debugPrint('👤 User ID: $userId');
      debugPrint('📧 User email: $userEmail');
      debugPrint('⏰ Timestamp: ${DateTime.now()}');
      
      // Get the price ID for this user type - try Remote Config first, then fallback
      debugPrint('🔍 Getting price ID for user type: $userType');
      debugPrint('🔍 Environment check:');
      debugPrint('   ENVIRONMENT: ${dotenv.env['ENVIRONMENT']}');
      debugPrint('   STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM: ${dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM']}');
      debugPrint('   STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST: ${dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST']}');
      
      String priceId = await RemoteConfigService.getStripePriceId(userType);
      
      // If Remote Config fails, use local method
      if (priceId.isEmpty) {
        debugPrint('⚠️ Remote Config price ID empty, trying local .env');
        priceId = _getPriceIdForUserType(userType);
        debugPrint('🔍 Local .env price ID result: $priceId');
      }
      
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
      if (couponCode != null && couponCode.isNotEmpty) {
        debugPrint('🎟️ With coupon code: $couponCode');
      }
      final checkoutUrl = await createCheckoutSession(
        priceId: priceId,
        customerEmail: userEmail,
        metadata: {
          'user_id': userId,
          'user_type': userType,
        },
        couponCode: couponCode,
      );

      debugPrint('✅ Checkout URL created: $checkoutUrl');
      final successUrl = kIsWeb 
          ? '${Uri.base.origin}/#/subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=$userId'
          : 'hipop://subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=$userId';
      debugPrint('🔗 Success URL will be: $successUrl');

      // Launch the checkout URL
      debugPrint('🌐 Launching checkout...');
      if (kIsWeb) {
        // On web, check browser type
        BrowserDetectionService.initialize();
        if (BrowserDetectionService.isSafari) {
          debugPrint('🦁 Safari detected - using same-tab navigation');
          await _launchUrlSafari(checkoutUrl);
        } else {
          debugPrint('🌐 Chrome/Firefox detected - using popup');
          await _launchUrlPopup(checkoutUrl);
        }
      } else {
        // On mobile, use InAppWebView
        debugPrint('📱 Platform: Mobile - using InAppWebView');
        if (context != null) {
          await _launchInAppWebView(context, checkoutUrl, userId);
        } else {
          debugPrint('⚠️ No context provided, falling back to external browser');
          await _launchUrl(checkoutUrl);
        }
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
    // Determine environment to choose the right price ID
    final environment = dotenv.env['ENVIRONMENT'] ?? 'staging';
    final isProduction = environment == 'production';
    
    debugPrint('🔧 _getPriceIdForUserType: Environment=$environment, userType=$userType');
    
    switch (userType) {
      // case 'shopper':
      //   return isProduction 
      //     ? (dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '')
      //     : (dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM_TEST'] ?? '');
      case 'vendor':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '')
          : (dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM_TEST'] ?? '');
        debugPrint('🏷️ StripeService price ID for vendor: $priceId (${isProduction ? 'LIVE' : 'TEST'})');
        return priceId;
      case 'market_organizer':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '')
          : (dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST'] ?? '');
        debugPrint('🏷️ StripeService price ID for market_organizer: $priceId (${isProduction ? 'LIVE' : 'TEST'})');
        return priceId;
      default:
        debugPrint('❌ Unknown user type in StripeService fallback: $userType');
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
          'name': 'Vendor Premium',
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

  /// Launch URL in Safari using same-tab navigation
  static Future<void> _launchUrlSafari(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView, // Use in-app for Safari
      );
    } else {
      throw Exception('Could not launch checkout URL in Safari: $url');
    }
  }

  /// Launch URL in popup for Chrome/Firefox
  static Future<void> _launchUrlPopup(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // External popup
      );
    } else {
      throw Exception('Could not launch checkout URL in popup: $url');
    }
  }

  /// Launch URL in InAppWebView for mobile platforms
  static Future<void> _launchInAppWebView(BuildContext context, String url, String userId) async {
    if (!context.mounted) {
      debugPrint('⚠️ Context not mounted, falling back to external browser');
      await _launchUrl(url);
      return;
    }

    try {
      debugPrint('📱 Opening InAppWebView for: $url');
      
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext context) => _InAppWebViewPayment(
            url: url,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening InAppWebView: $e');
      // Fallback to external browser
      await _launchUrl(url);
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
  
  /// Enhanced subscription cancellation with options
  /// 🔒 SECURITY: All cancellation options handled server-side
  static Future<bool> cancelSubscriptionEnhanced(
    String userId, {
    required String cancellationType, // 'immediate' or 'end_of_period'
    String? feedback,
  }) async {
    try {
      debugPrint('🔒 Enhanced subscription cancellation via Cloud Function');
      debugPrint('👤 User ID: $userId');
      debugPrint('🔄 Cancellation type: $cancellationType');
      debugPrint('📝 Feedback provided: ${feedback?.isNotEmpty == true ? 'Yes' : 'No'}');
      
      final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscriptionEnhanced');
      final result = await callable.call({
        'userId': userId,
        'cancellationType': cancellationType,
        'feedback': feedback ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      final success = result.data['success'] as bool? ?? false;
      final message = result.data['message'] as String? ?? '';
      
      debugPrint(success 
        ? '✅ Enhanced subscription cancellation successful: $message' 
        : '❌ Enhanced subscription cancellation failed: $message');
      
      return success;
    } catch (e) {
      debugPrint('❌ Error in enhanced subscription cancellation: $e');
      return false;
    }
  }
  
  /// Create payment method update session
  /// 🔒 SECURITY: Payment method updates handled server-side
  static Future<String?> createPaymentMethodUpdateSession(String stripeCustomerId) async {
    try {
      debugPrint('🔒 Creating payment method update session via Cloud Function');
      debugPrint('🏢 Customer ID: $stripeCustomerId');
      
      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentMethodUpdateSession');
      final result = await callable.call({
        'customerId': stripeCustomerId,
        'returnUrl': kIsWeb 
            ? '${Uri.base.origin}/#/subscription/payment-updated'
            : 'hipop://subscription/payment-updated',
      });
      
      final updateUrl = result.data['url'] as String?;
      debugPrint(updateUrl != null 
        ? '✅ Payment method update session created: $updateUrl' 
        : '❌ Failed to create payment method update session');
      
      return updateUrl;
    } catch (e) {
      debugPrint('❌ Error creating payment method update session: $e');
      return null;
    }
  }
  
  /// Launch payment method update URL
  static Future<void> launchPaymentMethodUpdate(String updateUrl) async {
    try {
      debugPrint('🌐 Launching payment method update URL: $updateUrl');
      await _launchUrl(updateUrl);
    } catch (e) {
      debugPrint('❌ Error launching payment method update: $e');
      rethrow;
    }
  }
  
  /// Get billing history for user
  /// 🔒 SECURITY: Billing data accessed server-side only
  static Future<List<Map<String, dynamic>>?> getBillingHistory(String userId) async {
    try {
      debugPrint('🔒 Fetching billing history via Cloud Function');
      debugPrint('👤 User ID: $userId');
      
      final callable = FirebaseFunctions.instance.httpsCallable('getBillingHistory');
      final result = await callable.call({
        'userId': userId,
      });
      
      final invoices = result.data['invoices'] as List<dynamic>?;
      if (invoices != null) {
        final billingHistory = invoices
          .map((invoice) => Map<String, dynamic>.from(invoice as Map))
          .toList();
        
        debugPrint('✅ Retrieved ${billingHistory.length} billing records');
        return billingHistory;
      }
      
      debugPrint('❌ No billing history found');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching billing history: $e');
      return null;
    }
  }
  
  /// Get latest invoice PDF URL
  /// 🔒 SECURITY: Invoice access controlled server-side
  static Future<String?> getLatestInvoicePdf(String userId) async {
    try {
      debugPrint('🔒 Getting latest invoice PDF via Cloud Function');
      debugPrint('👤 User ID: $userId');
      
      final callable = FirebaseFunctions.instance.httpsCallable('getLatestInvoicePdf');
      final result = await callable.call({
        'userId': userId,
      });
      
      final pdfUrl = result.data['invoicePdfUrl'] as String?;
      debugPrint(pdfUrl != null 
        ? '✅ Latest invoice PDF URL retrieved' 
        : '❌ No invoice PDF available');
      
      return pdfUrl;
    } catch (e) {
      debugPrint('❌ Error getting latest invoice PDF: $e');
      return null;
    }
  }
  
  /// Download invoice by opening URL
  static Future<void> downloadInvoice(String invoiceUrl) async {
    try {
      debugPrint('📥 Downloading invoice: $invoiceUrl');
      await _launchUrl(invoiceUrl);
    } catch (e) {
      debugPrint('❌ Error downloading invoice: $e');
      rethrow;
    }
  }
  
  /// Pause subscription for specified duration
  /// 🔒 SECURITY: Subscription pausing handled server-side
  static Future<bool> pauseSubscription(String userId, int daysCount) async {
    try {
      debugPrint('🔒 Pausing subscription via Cloud Function');
      debugPrint('👤 User ID: $userId');
      debugPrint('⏸️ Pause duration: $daysCount days');
      
      final callable = FirebaseFunctions.instance.httpsCallable('pauseSubscription');
      final result = await callable.call({
        'userId': userId,
        'pauseDurationDays': daysCount,
      });
      
      final success = result.data['success'] as bool? ?? false;
      final message = result.data['message'] as String? ?? '';
      
      debugPrint(success 
        ? '✅ Subscription paused successfully: $message' 
        : '❌ Failed to pause subscription: $message');
      
      return success;
    } catch (e) {
      debugPrint('❌ Error pausing subscription: $e');
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

/// InAppWebView widget for mobile payment handling
class _InAppWebViewPayment extends StatefulWidget {
  final String url;
  final String userId;

  const _InAppWebViewPayment({
    required this.url,
    required this.userId,
  });

  @override
  State<_InAppWebViewPayment> createState() => _InAppWebViewPaymentState();
}

class _InAppWebViewPaymentState extends State<_InAppWebViewPayment> {
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4.0),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        onLoadStart: (controller, url) {
          debugPrint('📱 InAppWebView started loading: $url');
          setState(() {
            _isLoading = true;
          });
        },
        onProgressChanged: (controller, progress) {
          setState(() {
            _progress = progress / 100;
          });
        },
        onLoadStop: (controller, url) async {
          debugPrint('📱 InAppWebView finished loading: $url');
          setState(() {
            _isLoading = false;
          });

          if (url != null) {
            await _handleUrlChange(url.toString());
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('❌ InAppWebView error: ${error.description}');
          setState(() {
            _isLoading = false;
          });
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url;
          if (url != null) {
            await _handleUrlChange(url.toString());
          }
          return NavigationActionPolicy.ALLOW;
        },
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
          supportZoom: true,
          useOnLoadResource: true,
        ),
      ),
    );
  }

  Future<void> _handleUrlChange(String url) async {
    debugPrint('📱 URL changed to: $url');

    // Check for success URL
    if (url.contains('/subscription/success') && url.contains('session_id=')) {
      debugPrint('✅ Payment success detected, closing WebView');
      final sessionId = _extractSessionId(url);
      if (sessionId != null) {
        // Navigate to success screen and close WebView
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
          context.go('/subscription/success?session_id=$sessionId&user_id=${widget.userId}');
        }
      }
      return;
    }

    // Check for cancel URL
    if (url.contains('/subscription/cancel')) {
      debugPrint('❌ Payment cancelled, closing WebView');
      if (mounted && context.mounted) {
        Navigator.of(context).pop();
        context.go('/subscription/cancel');
      }
      return;
    }

    // Check for custom scheme redirects (mobile deep links)
    if (url.startsWith('hipop://')) {
      debugPrint('🔗 Deep link detected: $url');
      if (url.contains('subscription/success') && url.contains('session_id=')) {
        final sessionId = _extractSessionId(url);
        if (sessionId != null && mounted && context.mounted) {
          Navigator.of(context).pop();
          context.go('/subscription/success?session_id=$sessionId&user_id=${widget.userId}');
        }
      } else if (url.contains('subscription/cancel')) {
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
          context.go('/subscription/cancel');
        }
      }
      return;
    }
  }

  String? _extractSessionId(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      return uri.queryParameters['session_id'];
    }
    
    // Fallback regex extraction
    final match = RegExp(r'session_id=([^&]+)').firstMatch(url);
    return match?.group(1);
  }

  @override
  void dispose() {
    super.dispose();
  }
}