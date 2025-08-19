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

      // Determine environment from .env
      final environment = dotenv.env['ENVIRONMENT'] ?? 'staging';
      final isProduction = environment == 'production';
      
      debugPrint('🔧 Remote Config Environment: $environment (isProduction: $isProduction)');
      
      // Set default values with environment-specific price IDs
      final defaults = <String, dynamic>{
        _googleMapsApiKey: _fallbackApiKey,
        'environment': environment,
        'stripe_publishable_key': dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '',
      };
      
      // Add environment-specific price IDs
      if (isProduction) {
        // Use live price IDs for production
        defaults['stripe_price_vendor_premium'] = dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '';
        defaults['stripe_price_market_organizer_premium'] = dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '';
        defaults['stripe_price_enterprise'] = dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '';
        debugPrint('🔧 Using LIVE price IDs as defaults');
      } else {
        // Use test price IDs for staging/test
        defaults['stripe_price_vendor_premium'] = dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM_TEST'] ?? '';
        defaults['stripe_price_market_organizer_premium'] = dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST'] ?? '';
        defaults['stripe_price_enterprise'] = dotenv.env['STRIPE_PRICE_ENTERPRISE_TEST'] ?? '';
        debugPrint('🔧 Using TEST price IDs as defaults');
      }

      await _remoteConfig!.setDefaults(defaults);

      // Fetch and activate with timeout protection
      try {
        final activated = await _remoteConfig!.fetchAndActivate();
        debugPrint('🔄 Remote Config fetch and activate result: $activated');
      } catch (fetchError) {
        debugPrint('⚠️ Remote Config fetch failed, using defaults: $fetchError');
        // Continue with defaults instead of failing
      }
      
      _initialized = true;
      
      // Log loaded values for debugging
      debugPrint('✅ Remote Config initialized');
      debugPrint('📋 Stripe Price IDs loaded from Remote Config:');
      debugPrint('  Environment: ${_remoteConfig!.getString('ENVIRONMENT')}');
      debugPrint('  Vendor: ${_remoteConfig!.getString('STRIPE_PRICE_VENDOR_PREMIUM')}');
      debugPrint('  Market Organizer: ${_remoteConfig!.getString('STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM')}');
      debugPrint('  Enterprise: ${_remoteConfig!.getString('STRIPE_PRICE_ENTERPRISE')}');
      
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
      debugPrint('🔍 Getting price ID for user type: $userType');
      
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        String key;
        switch (userType) {
          // case 'shopper':
          //   key = 'STRIPE_PRICE_SHOPPER_PREMIUM';
          //   break;
          case 'vendor':
            key = 'STRIPE_PRICE_VENDOR_PREMIUM';
            break;
          case 'market_organizer':
            key = 'STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM';
            break;
          case 'enterprise':
            key = 'STRIPE_PRICE_ENTERPRISE';
            break;
          default:
            debugPrint('❌ Unknown user type for price lookup: $userType');
            return '';
        }
        
        final priceId = remoteConfig.getString(key);
        debugPrint('🏷️ Remote Config price ID for $userType: $priceId');
        
        // If Remote Config returns empty, try direct .env fallback
        if (priceId.isEmpty) {
          debugPrint('⚠️ Remote Config returned empty price ID, trying .env fallback');
          return _getPriceIdFromEnv(userType);
        }
        
        return priceId;
      }
      
      // Fallback to .env if Remote Config fails
      debugPrint('⚠️ Remote Config not available, using .env fallback');
      return _getPriceIdFromEnv(userType);
    } catch (e) {
      debugPrint('❌ Error getting price ID from Remote Config: $e');
      return _getPriceIdFromEnv(userType);
    }
  }

  /// Fallback to get price ID from environment variables
  static String _getPriceIdFromEnv(String userType) {
    // Determine environment to choose the right price ID
    final environment = dotenv.env['ENVIRONMENT'] ?? 'staging';
    final isProduction = environment == 'production';
    
    debugPrint('🔧 _getPriceIdFromEnv: Environment=$environment, userType=$userType');
    
    switch (userType) {
      // case 'shopper':
      //   return isProduction 
      //     ? (dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '')
      //     : (dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM_TEST'] ?? '');
      case 'vendor':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '')
          : (dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM_TEST'] ?? '');
        debugPrint('🏷️ Env price ID for vendor: $priceId (${isProduction ? 'LIVE' : 'TEST'})');
        return priceId;
      case 'market_organizer':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '')
          : (dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST'] ?? '');
        debugPrint('🏷️ Env price ID for market_organizer: $priceId (${isProduction ? 'LIVE' : 'TEST'})');
        return priceId;
      case 'enterprise':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '')
          : (dotenv.env['STRIPE_PRICE_ENTERPRISE_TEST'] ?? '');
        debugPrint('🏷️ Env price ID for enterprise: $priceId (${isProduction ? 'LIVE' : 'TEST'})');
        return priceId;
      default:
        debugPrint('❌ Unknown user type in env fallback: $userType');
        return '';
    }
  }

  /// Get Stripe publishable key
  static Future<String> getStripePublishableKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('STRIPE_PUBLISHABLE_KEY');
        if (key.isNotEmpty) return key;
      }
      // Fallback to .env
      return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    } catch (e) {
      return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    }
  }

  /// Debug method to print all Remote Config values
  static Future<void> debugConfiguration() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        debugPrint('');
        debugPrint('🔍 ===== REMOTE CONFIG DEBUG =====');
        debugPrint('📋 All Remote Config Values:');
        
        // Check Stripe price IDs
        final vendorPrice = remoteConfig.getString('STRIPE_PRICE_VENDOR_PREMIUM');
        final marketOrgPrice = remoteConfig.getString('STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM');
        final enterprisePrice = remoteConfig.getString('STRIPE_PRICE_ENTERPRISE');
        final publishableKey = remoteConfig.getString('STRIPE_PUBLISHABLE_KEY');
        
        debugPrint('  STRIPE_PRICE_VENDOR_PREMIUM: ${vendorPrice.isNotEmpty ? vendorPrice : "❌ EMPTY"}');
        debugPrint('  STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM: ${marketOrgPrice.isNotEmpty ? marketOrgPrice : "❌ EMPTY"}');
        debugPrint('  STRIPE_PRICE_ENTERPRISE: ${enterprisePrice.isNotEmpty ? enterprisePrice : "❌ EMPTY"}');
        debugPrint('  STRIPE_PUBLISHABLE_KEY: ${publishableKey.isNotEmpty ? "✅ Present (${publishableKey.substring(0, 10)}...)" : "❌ EMPTY"}');
        
        debugPrint('');
        debugPrint('📱 Test Price Lookup:');
        final testVendor = await getStripePriceId('vendor');
        final testMarketOrg = await getStripePriceId('market_organizer');
        debugPrint('  vendor price: ${testVendor.isNotEmpty ? testVendor : "❌ FAILED"}');
        debugPrint('  market_organizer price: ${testMarketOrg.isNotEmpty ? testMarketOrg : "❌ FAILED"}');
        debugPrint('===========================');
        debugPrint('');
      } else {
        debugPrint('❌ Remote Config not initialized');
      }
    } catch (e) {
      debugPrint('❌ Error debugging Remote Config: $e');
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