import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';

class StripeService {
  static const String _baseUrl = 'https://api.stripe.com/v1';
  
  /// Get the secret key from environment
  static String get _secretKey {
    final key = dotenv.env['STRIPE_SECRET_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('STRIPE_SECRET_KEY not found in environment');
    }
    return key;
  }

  /// Create a checkout session for a subscription
  static Future<String> createCheckoutSession({
    required String priceId,
    required String customerEmail,
    required Map<String, String> metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/sessions'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'mode': 'subscription',
          'line_items[0][price]': priceId,
          'line_items[0][quantity]': '1',
          'customer_email': customerEmail,
          'success_url': kIsWeb 
              ? '${Uri.base.origin}/#/subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=${metadata['user_id']}'
              : 'hipop://subscription/success?session_id={CHECKOUT_SESSION_ID}&user_id=${metadata['user_id']}',
          'cancel_url': kIsWeb 
              ? '${Uri.base.origin}/#/subscription/cancel'
              : 'hipop://subscription/cancel',
          'allow_promotion_codes': 'true',
          'billing_address_collection': 'required',
          'metadata[user_id]': metadata['user_id'] ?? '',
          'metadata[user_type]': metadata['user_type'] ?? '',
          'metadata[environment]': 'staging',
        },
      );

      debugPrint('Stripe API Response Status: ${response.statusCode}');
      debugPrint('Stripe API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Stripe API Error: ${error['error']['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error creating checkout session: $e');
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
        return dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '';
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
          'price': 15.00,
          'name': 'Vendor Premium',
          'description': 'Advanced analytics and multi-market management',
          'features': [
            'Advanced analytics dashboard',
            'Master product lists',
            'Multi-market management',
            'Push notifications',
          ],
        };
      case 'market_organizer':
        return {
          'price': 39.00,
          'name': 'Market Organizer Premium',
          'description': 'Complete market management and analytics suite',
          'features': [
            'Vendor performance analytics',
            'Smart recruitment tools',
            'Financial analytics',
            'Unlimited events',
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

  /// Verify webhook signature for secure webhook processing
  /// Implements HMAC-SHA256 signature verification as per Stripe documentation
  static bool verifyWebhookSignature(String payload, String signature) {
    final webhookSecret = dotenv.env['STRIPE_WEBHOOK_SECRET'];
    if (webhookSecret == null || webhookSecret.isEmpty) {
      debugPrint('⚠️ No webhook secret configured');
      return false;
    }
    
    try {
      // Parse signature header - format: "t=timestamp,v1=signature"
      final signatureParts = signature.split(',');
      String? timestamp;
      String? v1Signature;
      
      for (final part in signatureParts) {
        final keyValue = part.split('=');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          
          if (key == 't') {
            timestamp = value;
          } else if (key == 'v1') {
            v1Signature = value;
          }
        }
      }
      
      if (timestamp == null || v1Signature == null) {
        debugPrint('❌ Invalid signature format');
        return false;
      }
      
      // Check timestamp tolerance (5 minutes)
      final webhookTimestamp = int.tryParse(timestamp);
      if (webhookTimestamp == null) {
        debugPrint('❌ Invalid timestamp in signature');
        return false;
      }
      
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeDifference = (currentTimestamp - webhookTimestamp).abs();
      const toleranceInSeconds = 300; // 5 minutes
      
      if (timeDifference > toleranceInSeconds) {
        debugPrint('❌ Webhook timestamp too old: ${timeDifference}s > ${toleranceInSeconds}s');
        return false;
      }
      
      // Create signed payload: timestamp.payload
      final signedPayload = '$timestamp.$payload';
      
      // Generate expected signature using HMAC-SHA256
      final expectedSignature = _computeHmacSha256(webhookSecret, signedPayload);
      
      // Compare signatures using constant-time comparison
      final isValid = _constantTimeCompare(expectedSignature, v1Signature);
      
      if (!isValid) {
        debugPrint('❌ Webhook signature verification failed');
        debugPrint('Expected: $expectedSignature');
        debugPrint('Received: $v1Signature');
      } else {
        debugPrint('✅ Webhook signature verified successfully');
      }
      
      return isValid;
      
    } catch (e) {
      debugPrint('❌ Error verifying webhook signature: $e');
      return false;
    }
  }
  
  /// Compute HMAC-SHA256 signature
  static String _computeHmacSha256(String key, String message) {
    final keyBytes = utf8.encode(key);
    final messageBytes = utf8.encode(message);
    
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes);
    
    return digest.toString();
  }
  
  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    
    return result == 0;
  }
}