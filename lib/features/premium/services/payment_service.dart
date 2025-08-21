import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_subscription.dart';
import '../../shared/services/remote_config_service.dart';

// Web-safe platform detection using kIsWeb and defaultTargetPlatform
bool get isWebPlatform => kIsWeb;

// Safe mobile platform detection using defaultTargetPlatform
bool get isIOSPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool get isAndroidPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Enhanced payment service that handles in-app Stripe payments with CardField
class PaymentService {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static bool _isInitialized = false;

  /// Initialize Stripe with publishable key
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Stripe is already initialized from main.dart
      if (Stripe.publishableKey.isNotEmpty) {
        _isInitialized = true;
        debugPrint('✅ PaymentService found existing Stripe initialization');
        return;
      }

      // Use platform-specific initialization
      if (isWebPlatform) {
        await _initializeForWeb();
      } else {
        await _initializeForMobile();
      }

      _isInitialized = true;
      debugPrint('✅ PaymentService initialized with Stripe');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize PaymentService: $e');
      debugPrint('📍 Error type: ${e.runtimeType}');
      debugPrint('📍 Stack trace: $stackTrace');
      
      // Try web fallback initialization if primary method fails
      if (!isWebPlatform && !_isInitialized) {
        try {
          debugPrint('🔄 Attempting web fallback initialization...');
          await _initializeForWeb();
          _isInitialized = true;
          debugPrint('✅ PaymentService initialized with web fallback');
          return;
        } catch (fallbackError, fallbackStack) {
          debugPrint('❌ Web fallback initialization also failed: $fallbackError');
          debugPrint('📍 Fallback stack: $fallbackStack');
        }
      }
      
      rethrow;
    }
  }

  /// Initialize Stripe for web platform
  static Future<void> _initializeForWeb() async {
    debugPrint('🔍 Initializing Stripe for web...');
    
    // Try Remote Config first (following the pattern of other working functions)
    String publishableKey = await RemoteConfigService.getStripePublishableKey();
    
    // If Remote Config fails, use hardcoded fallback
    if (publishableKey.isEmpty) {
      // Fallback - This is your live publishable key - safe to expose
      publishableKey = 'pk_live_51RsQNrC8FCSHt0iKEEfaV2Kd98wwFHAw0d6rcvLR7kxGzvfWuOxhaOvYOD2GRvODOR5eAQnFC7p622ech7BDGddy00IP3xtXun';
      debugPrint('⚠️ Using hardcoded fallback key for web (Remote Config failed)');
    } else {
      debugPrint('✅ Using Stripe key from Remote Config');
    }
    
    if (publishableKey.isEmpty) {
      throw Exception('Stripe publishable key not found');
    }

    Stripe.publishableKey = publishableKey;
    debugPrint('🌐 Web platform initialization complete');
  }

  /// Initialize Stripe for mobile platforms (iOS/Android)
  static Future<void> _initializeForMobile() async {
    final publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    if (publishableKey == null || publishableKey.isEmpty) {
      throw Exception('Stripe publishable key not found in environment');
    }

    Stripe.publishableKey = publishableKey;
    
    // Set merchant identifier for Apple Pay (iOS only)
    if (isIOSPlatform) {
      try {
        Stripe.merchantIdentifier = dotenv.env['STRIPE_MERCHANT_IDENTIFIER'] ?? 'merchant.com.hipop';
        debugPrint('🍎 Set merchant identifier for iOS');
      } catch (e) {
        debugPrint('⚠️ Could not set merchant identifier: $e');
        // Continue without merchant identifier - not critical
      }
    } else if (isAndroidPlatform) {
      debugPrint('🤖 Android platform initialization complete');
    } else {
      debugPrint('📱 Mobile platform initialization complete');
    }
  }

  /// Create payment intent for subscription
  static Future<String> createPaymentIntent({
    required String priceId,
    required String customerEmail,
    required String userId,
    required String userType,
    String? promoCode,
  }) async {
    try {
      debugPrint('💳 Creating payment intent');
      debugPrint('📧 Customer: $customerEmail');
      debugPrint('💰 Price ID: $priceId');
      debugPrint('🎟️ Promo code: ${promoCode ?? 'none'}');

      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final result = await callable.call({
        'priceId': priceId,
        'customerEmail': customerEmail,
        'userId': userId,
        'userType': userType,
        'promoCode': promoCode,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;
      
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Invalid payment intent response from server');
      }

      debugPrint('✅ Payment intent created with client secret');
      return clientSecret;
    } catch (e) {
      debugPrint('❌ Error creating payment intent: $e');
      
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            throw PaymentException('Invalid payment information provided');
          case 'permission-denied':
            throw PaymentException('Not authorized to create payment');
          case 'unavailable':
            throw PaymentException('Payment service temporarily unavailable');
          case 'failed-precondition':
            throw PaymentException('Invalid promo code or payment configuration');
          default:
            throw PaymentException('Unable to process payment request');
        }
      }
      
      throw PaymentException('Payment processing failed: ${e.toString()}');
    }
  }

  /// Initialize Payment Sheet for mobile platforms
  static Future<void> initPaymentSheet({
    required String clientSecret,
    required String customerEmail,
    String? merchantDisplayName,
  }) async {
    if (isWebPlatform) {
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      debugPrint('📱 Initializing Payment Sheet for mobile...');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName ?? 'HiPop',
          customerEphemeralKeySecret: null, // Not needed for payment intents
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: customerEmail,
          ),
          appearance: PaymentSheetAppearance(
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF6366F1), // Indigo color
                  text: const Color(0xFFFFFFFF),
                  border: const Color(0xFF6366F1),
                ),
                dark: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF6366F1),
                  text: const Color(0xFFFFFFFF),
                  border: const Color(0xFF6366F1),
                ),
              ),
            ),
          ),
        ),
      );

      debugPrint('✅ Payment Sheet initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Payment Sheet: $e');
      
      if (e is StripeException) {
        final errorMessage = e.error.localizedMessage ?? e.error.message ?? 'Failed to initialize payment';
        throw PaymentException(errorMessage);
      }
      
      throw PaymentException('Failed to initialize payment: ${e.toString()}');
    }
  }

  /// Present Payment Sheet for mobile payment
  static Future<void> presentPaymentSheet() async {
    if (isWebPlatform) {
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      debugPrint('💳 Presenting Payment Sheet...');

      await Stripe.instance.presentPaymentSheet();
      
      debugPrint('✅ Payment Sheet completed successfully');
    } catch (e) {
      debugPrint('❌ Payment Sheet error: $e');
      
      if (e is StripeException) {
        final errorCode = e.error.code.name;
        final errorMessage = e.error.localizedMessage ?? e.error.message ?? 'Payment failed';
        
        // Handle user cancellation
        if (errorCode.contains('canceled') || errorCode.contains('cancelled')) {
          throw PaymentException('Payment was cancelled');
        }
        
        // Handle common error types
        if (errorCode.contains('card_declined') || errorCode.contains('generic_decline')) {
          throw PaymentException('Your card was declined. Please try a different card.');
        } else if (errorCode.contains('expired_card')) {
          throw PaymentException('Your card has expired. Please use a different card.');
        } else if (errorCode.contains('incorrect_cvc')) {
          throw PaymentException('Your card\'s security code is incorrect.');
        } else if (errorCode.contains('incorrect_number') || errorCode.contains('invalid_number')) {
          throw PaymentException('Your card number is incorrect.');
        } else {
          throw PaymentException(errorMessage);
        }
      }
      
      throw PaymentException('Payment failed: ${e.toString()}');
    }
  }

  /// Complete payment flow using Payment Sheet (mobile only)
  static Future<void> processPaymentWithSheet({
    required String priceId,
    required String customerEmail,
    required String userId,
    required String userType,
    String? promoCode,
    String? merchantDisplayName,
  }) async {
    if (isWebPlatform) {
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      debugPrint('🚀 Starting Payment Sheet flow...');

      // Step 1: Create payment intent
      final clientSecret = await createPaymentIntent(
        priceId: priceId,
        customerEmail: customerEmail,
        userId: userId,
        userType: userType,
        promoCode: promoCode,
      );

      // Step 2: Initialize Payment Sheet
      await initPaymentSheet(
        clientSecret: clientSecret,
        customerEmail: customerEmail,
        merchantDisplayName: merchantDisplayName,
      );

      // Step 3: Present Payment Sheet
      await presentPaymentSheet();

      debugPrint('✅ Payment Sheet flow completed successfully');
    } catch (e) {
      debugPrint('❌ Payment Sheet flow failed: $e');
      rethrow;
    }
  }

  /// Confirm payment with card details (legacy method for CardField)
  /// @deprecated Use Payment Sheet instead for better UX
  static Future<PaymentIntent> confirmPayment({
    required String clientSecret,
    required PaymentMethodData paymentMethodData,
  }) async {
    try {
      debugPrint('🔄 Confirming payment with CardField (legacy)...');

      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(paymentMethodData: paymentMethodData),
      );

      if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
        debugPrint('✅ Payment confirmed successfully');
        return paymentIntent;
      } else if (paymentIntent.status == PaymentIntentsStatus.RequiresAction) {
        // Handle 3D Secure or other authentication
        debugPrint('🔐 Payment requires additional authentication');
        throw PaymentException('Payment requires additional authentication');
      } else {
        debugPrint('❌ Payment failed with status: ${paymentIntent.status}');
        throw PaymentException('Payment failed. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Error confirming payment: $e');
      
      if (e is StripeException) {
        final errorCode = e.error.code.name;
        final errorMessage = e.error.localizedMessage ?? e.error.message ?? 'Payment failed. Please try again.';
        
        // Handle common error types
        if (errorCode.contains('card_declined') || errorCode.contains('generic_decline')) {
          throw PaymentException('Your card was declined. Please try a different card.');
        } else if (errorCode.contains('expired_card')) {
          throw PaymentException('Your card has expired. Please use a different card.');
        } else if (errorCode.contains('incorrect_cvc')) {
          throw PaymentException('Your card\'s security code is incorrect.');
        } else if (errorCode.contains('incorrect_number') || errorCode.contains('invalid_number')) {
          throw PaymentException('Your card number is incorrect.');
        } else {
          throw PaymentException(errorMessage);
        }
      }
      
      if (e is PaymentException) {
        rethrow;
      }
      
      throw PaymentException('Payment processing failed: ${e.toString()}');
    }
  }

  /// Validate promo code
  static Future<PromoCodeValidation> validatePromoCode(String promoCode) async {
    try {
      debugPrint('🎟️ Validating promo code: $promoCode');

      final callable = FirebaseFunctions.instance.httpsCallable('validatePromoCode');
      final result = await callable.call({
        'promoCode': promoCode,
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      
      return PromoCodeValidation(
        isValid: data['valid'] as bool? ?? false,
        discountPercent: (data['discount_percent'] as num?)?.toDouble(),
        discountAmount: (data['discount_amount'] as num?)?.toDouble(),
        description: data['description'] as String?,
        errorMessage: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Error validating promo code: $e');
      return PromoCodeValidation(
        isValid: false,
        errorMessage: 'Unable to validate promo code. Please try again.',
      );
    }
  }

  /// Check if Apple Pay is available (disabled for now)
  static Future<bool> isApplePaySupported() async {
    // Apple Pay not available on web
    if (kIsWeb) return false;
    // Apple Pay integration disabled temporarily due to API changes
    return false;
  }

  /// Check if Google Pay is available (disabled for now)
  static Future<bool> isGooglePaySupported() async {
    // Google Pay not available on web
    if (kIsWeb) return false;
    // Google Pay integration disabled temporarily due to API changes
    return false;
  }

  /// Create payment method with Apple Pay (temporarily disabled)
  static Future<PaymentMethod> createApplePayPaymentMethod({
    required double amount,
    required String currency,
    required String countryCode,
  }) async {
    throw PaymentException('Apple Pay is temporarily unavailable. Please use a card instead.');
  }

  /// Create payment method with Google Pay (temporarily disabled)
  static Future<PaymentMethod> createGooglePayPaymentMethod({
    required double amount,
    required String currency,
    required String countryCode,
  }) async {
    throw PaymentException('Google Pay is temporarily unavailable. Please use a card instead.');
  }

  /// Get subscription pricing for user type
  static SubscriptionPricing getPricingForUserType(String userType) {
    switch (userType) {
      case 'vendor':
        return SubscriptionPricing(
          priceId: dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '',
          amount: 29.00,
          currency: 'USD',
          interval: 'month',
          name: 'Vendor Pro',
          description: 'Advanced analytics and market management tools',
          features: [
            'Unlimited market applications',
            'Advanced analytics dashboard',
            'Multi-market management',
            'Priority customer support',
          ],
        );
      case 'market_organizer':
        return SubscriptionPricing(
          priceId: dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '',
          amount: 69.00,
          currency: 'USD',
          interval: 'month',
          name: 'Market Organizer Premium',
          description: 'Complete market management and vendor recruitment suite',
          features: [
            'Unlimited vendor posts',
            'Advanced vendor recruitment',
            'Market performance analytics',
            'Priority customer support',
          ],
        );
      case 'shopper':
        return SubscriptionPricing(
          priceId: dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '',
          amount: 4.00,
          currency: 'USD',
          interval: 'month',
          name: 'Shopper Premium',
          description: 'Enhanced discovery and personalized recommendations',
          features: [
            'Follow unlimited vendors',
            'Advanced search filters',
            'Personalized recommendations',
            'Vendor appearance predictions',
          ],
        );
      default:
        throw ArgumentError('Unsupported user type: $userType');
    }
  }

  /// Get subscription tier from user type
  static SubscriptionTier getSubscriptionTierForUserType(String userType) {
    switch (userType) {
      case 'vendor':
        return SubscriptionTier.vendorPro;
      case 'market_organizer':
        return SubscriptionTier.marketOrganizerPro;
      case 'shopper':
        return SubscriptionTier.shopperPro;
      default:
        throw ArgumentError('Unsupported user type: $userType');
    }
  }

  /// Calculate final amount after applying promo code
  static double calculateFinalAmount(double originalAmount, PromoCodeValidation? promoValidation) {
    if (promoValidation == null || !promoValidation.isValid) {
      return originalAmount;
    }

    if (promoValidation.discountAmount != null) {
      return (originalAmount - promoValidation.discountAmount!).clamp(0.0, originalAmount);
    }

    if (promoValidation.discountPercent != null) {
      final discount = originalAmount * (promoValidation.discountPercent! / 100);
      return (originalAmount - discount).clamp(0.0, originalAmount);
    }

    return originalAmount;
  }
}

/// Custom exception for payment errors
class PaymentException implements Exception {
  final String message;
  
  const PaymentException(this.message);
  
  @override
  String toString() => 'PaymentException: $message';
}

/// Promo code validation result
class PromoCodeValidation {
  final bool isValid;
  final double? discountPercent;
  final double? discountAmount;
  final String? description;
  final String? errorMessage;

  const PromoCodeValidation({
    required this.isValid,
    this.discountPercent,
    this.discountAmount,
    this.description,
    this.errorMessage,
  });
}

/// Subscription pricing information
class SubscriptionPricing {
  final String priceId;
  final double amount;
  final String currency;
  final String interval;
  final String name;
  final String description;
  final List<String> features;

  const SubscriptionPricing({
    required this.priceId,
    required this.amount,
    required this.currency,
    required this.interval,
    required this.name,
    required this.description,
    required this.features,
  });

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
  String get displayName => '$name - $formattedAmount/$interval';
}