import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../shared/services/user_profile_service.dart';

/// Service to handle Stripe subscription success callbacks
class SubscriptionSuccessService {
  static final UserProfileService _userProfileService = UserProfileService();

  /// Handle successful subscription from Stripe checkout
  /// This should be called when the app receives the success URL
  static Future<bool> handleSubscriptionSuccess({
    required String userId,
    required String sessionId,
  }) async {
    try {
      debugPrint('');
      debugPrint('🎯 ========= SUBSCRIPTION SUCCESS CALLBACK =========');
      debugPrint('🎯 Processing subscription success for user: $userId');
      debugPrint('🔍 Verifying Stripe session: $sessionId');
      debugPrint('⏰ Timestamp: ${DateTime.now()}');

      String stripeCustomerId;
      String stripeSubscriptionId;
      String stripePriceId;

      // Handle test sessions differently
      if (sessionId.startsWith('cs_test_fake_session')) {
        debugPrint('🧪 Processing test session - bypassing Stripe verification');
        stripeCustomerId = 'cus_test_fake_customer_$userId';
        stripeSubscriptionId = 'sub_test_fake_subscription_$userId';
        stripePriceId = 'price_1RsQYQFvX8Cx8YoHyGnGie4p'; // Use shopper premium price for testing
        debugPrint('🧪 Test data assigned:');
        debugPrint('   Customer ID: $stripeCustomerId');
        debugPrint('   Subscription ID: $stripeSubscriptionId');
        debugPrint('   Price ID: $stripePriceId');
      } else {
        debugPrint('🔐 Processing REAL Stripe session - verifying with Stripe API');
        debugPrint('🌐 Making API call to Stripe...');
        
        // Verify the session with Stripe for real sessions
        final sessionData = await _verifyStripeSession(sessionId);
        
        if (sessionData == null) {
          debugPrint('❌ Invalid Stripe session - API returned null');
          return false;
        }

        debugPrint('✅ Stripe session data received');
        debugPrint('📊 Session data keys: ${sessionData.keys.toList()}');
        debugPrint('💳 Payment status: ${sessionData['payment_status']}');

        // Check if the session was actually paid
        if (sessionData['payment_status'] != 'paid') {
          debugPrint('❌ Session not paid: ${sessionData['payment_status']}');
          debugPrint('📋 Full session data: $sessionData');
          return false;
        }

        debugPrint('✅ Payment confirmed as PAID');

        // Extract Stripe data with proper type handling
        final customerId = _extractCustomerId(sessionData);
        final subscriptionId = _extractSubscriptionId(sessionData);
        final priceId = _extractPriceId(sessionData);

        debugPrint('🔍 Extracted Stripe data:');
        debugPrint('   Customer ID: $customerId');
        debugPrint('   Subscription ID: $subscriptionId');
        debugPrint('   Price ID: $priceId');

        if (customerId == null || subscriptionId == null || priceId == null) {
          debugPrint('❌ Missing required Stripe data - cannot proceed');
          debugPrint('❌ Customer ID null: ${customerId == null}');
          debugPrint('❌ Subscription ID null: ${subscriptionId == null}');
          debugPrint('❌ Price ID null: ${priceId == null}');
          return false;
        }

        stripeCustomerId = customerId;
        stripeSubscriptionId = subscriptionId;
        stripePriceId = priceId;
        debugPrint('✅ All required Stripe data extracted successfully');
      }

      // Upgrade user to premium in user profile
      debugPrint('');
      debugPrint('🔄 Upgrading user profile to premium...');
      debugPrint('👤 User ID: $userId');
      debugPrint('🏪 Customer ID: $stripeCustomerId');
      debugPrint('📋 Subscription ID: $stripeSubscriptionId');
      debugPrint('💰 Price ID: $stripePriceId');
      
      await _userProfileService.upgradeToPremium(
        userId: userId,
        stripeCustomerId: stripeCustomerId,
        stripeSubscriptionId: stripeSubscriptionId,
        stripePriceId: stripePriceId,
      );

      debugPrint('✅ User $userId successfully upgraded to premium!');
      debugPrint('🎉 ========= SUCCESS CALLBACK COMPLETE =========');
      debugPrint('');
      return true;
    } catch (e) {
      debugPrint('');
      debugPrint('💥 ========= SUBSCRIPTION CALLBACK ERROR =========');
      debugPrint('❌ Error handling subscription success: $e');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      debugPrint('🎯 Failed for user: $userId, session: $sessionId');
      debugPrint('💥 ============================================');
      debugPrint('');
      return false;
    }
  }

  /// Verify Stripe checkout session
  static Future<Map<String, dynamic>?> _verifyStripeSession(String sessionId) async {
    try {
      debugPrint('🔐 Starting Stripe session verification...');
      
      final secretKey = dotenv.env['STRIPE_SECRET_KEY'];
      if (secretKey == null) {
        debugPrint('❌ STRIPE_SECRET_KEY not found in environment');
        throw Exception('Stripe secret key not found');
      }
      
      debugPrint('✅ Stripe secret key found (length: ${secretKey.length})');
      
      // Expand subscription and line_items to get price information
      final url = 'https://api.stripe.com/v1/checkout/sessions/$sessionId?expand[]=subscription&expand[]=line_items';
      debugPrint('🌐 Making request to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      debugPrint('📡 Stripe API Response Status: ${response.statusCode}');
      debugPrint('📦 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Successfully parsed Stripe response');
        return data;
      } else {
        debugPrint('❌ Stripe API Error: ${response.statusCode}');
        debugPrint('❌ Error body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception verifying Stripe session: $e');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Extract customer ID from session data (handles both string and object formats)
  static String? _extractCustomerId(Map<String, dynamic> sessionData) {
    try {
      final customer = sessionData['customer'];
      if (customer is String) {
        debugPrint('✅ Customer ID found as string: $customer');
        return customer;
      } else if (customer is Map<String, dynamic>) {
        final customerId = customer['id'] as String?;
        debugPrint('✅ Customer ID found in object: $customerId');
        return customerId;
      } else {
        debugPrint('❌ Customer field is neither string nor object: $customer');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception extracting customer ID: $e');
      return null;
    }
  }

  /// Extract subscription ID from session data (handles both string and object formats)
  static String? _extractSubscriptionId(Map<String, dynamic> sessionData) {
    try {
      final subscription = sessionData['subscription'];
      if (subscription is String) {
        debugPrint('✅ Subscription ID found as string: $subscription');
        return subscription;
      } else if (subscription is Map<String, dynamic>) {
        final subscriptionId = subscription['id'] as String?;
        debugPrint('✅ Subscription ID found in object: $subscriptionId');
        return subscriptionId;
      } else {
        debugPrint('❌ Subscription field is neither string nor object: $subscription');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception extracting subscription ID: $e');
      return null;
    }
  }

  /// Extract price ID from session data
  static String? _extractPriceId(Map<String, dynamic> sessionData) {
    try {
      debugPrint('🔍 Attempting to extract price ID from session data...');
      
      // Method 1: Try to get price ID from expanded subscription object
      final subscription = sessionData['subscription'] as Map<String, dynamic>?;
      if (subscription != null) {
        debugPrint('📋 Found subscription object, checking for price ID...');
        final items = subscription['items'] as Map<String, dynamic>?;
        final itemsData = items?['data'] as List<dynamic>?;
        if (itemsData != null && itemsData.isNotEmpty) {
          final firstItem = itemsData[0] as Map<String, dynamic>?;
          final price = firstItem?['price'] as Map<String, dynamic>?;
          final priceId = price?['id'] as String?;
          if (priceId != null) {
            debugPrint('✅ Found price ID from subscription: $priceId');
            return priceId;
          }
        }
        debugPrint('⚠️ No price ID found in subscription items');
      } else {
        debugPrint('⚠️ No subscription object found in session data');
      }

      // Method 2: Try to get price ID from expanded line_items
      final lineItems = sessionData['line_items'] as Map<String, dynamic>?;
      if (lineItems != null) {
        debugPrint('📋 Found line_items object, checking for price ID...');
        final data = lineItems['data'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          final firstItem = data[0] as Map<String, dynamic>?;
          final price = firstItem?['price'] as Map<String, dynamic>?;
          final priceId = price?['id'] as String?;
          if (priceId != null) {
            debugPrint('✅ Found price ID from line_items: $priceId');
            return priceId;
          }
        }
        debugPrint('⚠️ No price ID found in line_items');
      } else {
        debugPrint('⚠️ No line_items object found in session data');
      }

      debugPrint('❌ Could not extract price ID from session data');
      debugPrint('📋 Available session keys: ${sessionData.keys.toList()}');
      
      // Debug: Show what's in subscription if it exists
      if (subscription != null) {
        debugPrint('📋 Subscription keys: ${subscription.keys.toList()}');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Exception extracting price ID: $e');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Parse user ID from success URL
  /// Expected format: hipop://subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id={USER_ID}
  static String? parseUserIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['user_id'];
    } catch (e) {
      debugPrint('❌ Error parsing user ID from URL: $e');
      return null;
    }
  }

  /// Parse session ID from success URL
  static String? parseSessionIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['session_id'];
    } catch (e) {
      debugPrint('❌ Error parsing session ID from URL: $e');
      return null;
    }
  }

  /// Check if user has premium access (convenience method)
  static Future<bool> checkPremiumAccess(String userId) async {
    try {
      return await _userProfileService.hasPremiumAccess(userId);
    } catch (e) {
      debugPrint('❌ Error checking premium access: $e');
      return false;
    }
  }

  /// Process successful subscription (used by success screen)
  static Future<Map<String, dynamic>> processSuccessfulSubscription({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final success = await handleSubscriptionSuccess(
        userId: userId,
        sessionId: sessionId,
      );

      if (success) {
        // Return success without subscription info since getUserSubscription doesn't exist
        // The subscription info would be loaded separately by the UI
        return {
          'success': true,
          'subscription': null,
          'message': 'Subscription processed successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to process subscription',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception during subscription processing: $e',
      };
    }
  }
}