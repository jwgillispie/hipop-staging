import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static const String _googleMapsApiKey = 'GOOGLE_MAPS_API_KEY';
  static const String _fallbackApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: 'AIzaSyDp17RxIsSydQqKZGBRsYtJkmGdwqnHZ84');
  static bool _initialized = false;

  static Future<FirebaseRemoteConfig?> get instance async {
    try {
      _remoteConfig ??= FirebaseRemoteConfig.instance;
      
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode 
          ? const Duration(minutes: 5)  // Fetch frequently in debug
          : const Duration(hours: 1),   // Cache for 1 hour in production
      ));

      // Set default values including Stripe configuration
      await _remoteConfig!.setDefaults({
        _googleMapsApiKey: _fallbackApiKey,
        // Stripe Price IDs - fallback to .env values
        // 'stripe_price_shopper_premium': dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '',
        'stripe_price_vendor_premium': dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '',
        'stripe_price_market_organizer_premium': dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '',
        'stripe_price_enterprise': dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '',
        // Stripe Keys
        'stripe_publishable_key': dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '',
        // Environment
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      });

      await _remoteConfig!.fetchAndActivate();
      _initialized = true;
      
      // Log loaded values for debugging
      debugPrint('✅ Remote Config initialized');
      debugPrint('📋 Stripe Price IDs loaded:');
      debugPrint('  Vendor: ${_remoteConfig!.getString('stripe_price_vendor_premium')}');
      debugPrint('  Market Organizer: ${_remoteConfig!.getString('stripe_price_market_organizer_premium')}');
      // debugPrint('  Shopper: ${_remoteConfig!.getString('stripe_price_shopper_premium')}');
      
      return _remoteConfig!;
    } catch (e) {
      debugPrint('❌ Remote Config initialization failed: $e');
      debugPrint('⚠️ Using fallback .env values');
      return null;
    }
  }

  static Future<String> getGoogleMapsApiKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString(_googleMapsApiKey);
        return key.isNotEmpty ? key : _fallbackApiKey;
      }
      return _fallbackApiKey;
    } catch (e) {
      return _fallbackApiKey;
    }
  }

  /// Get Stripe price ID for user type
  static Future<String> getStripePriceId(String userType) async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        String key;
        switch (userType) {
          // case 'shopper':
          //   key = 'stripe_price_shopper_premium';
          //   break;
          case 'vendor':
            key = 'stripe_price_vendor_premium';
            break;
          case 'market_organizer':
            key = 'stripe_price_market_organizer_premium';
            break;
          case 'enterprise':
            key = 'stripe_price_enterprise';
            break;
          default:
            debugPrint('❌ Unknown user type for price lookup: $userType');
            return '';
        }
        
        final priceId = remoteConfig.getString(key);
        debugPrint('🏷️ Price ID for $userType: $priceId');
        return priceId;
      }
      
      // Fallback to .env if Remote Config fails
      return _getPriceIdFromEnv(userType);
    } catch (e) {
      debugPrint('❌ Error getting price ID from Remote Config: $e');
      return _getPriceIdFromEnv(userType);
    }
  }

  /// Fallback to get price ID from environment variables
  static String _getPriceIdFromEnv(String userType) {
    switch (userType) {
      // case 'shopper':
      //   return dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '';
      case 'vendor':
        return dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '';
      case 'market_organizer':
        return dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '';
      case 'enterprise':
        return dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '';
      default:
        return '';
    }
  }

  /// Get Stripe publishable key
  static Future<String> getStripePublishableKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('stripe_publishable_key');
        if (key.isNotEmpty) return key;
      }
      // Fallback to .env
      return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    } catch (e) {
      return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    }
  }

  /// Force refresh Remote Config values
  static Future<void> refresh() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final activated = await remoteConfig.fetchAndActivate();
        if (activated) {
          debugPrint('✅ Remote Config refreshed with new values');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh Remote Config: $e');
    }
  }
}