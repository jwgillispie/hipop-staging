import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_subscription.dart';
import 'subscription_service.dart';
import 'premium_error_handler.dart';

/// 🔒 SECURE: Server-side subscription validation service
/// 
/// This service provides secure feature access validation with optional
/// server-side verification for critical operations. It uses caching to
/// minimize database calls while ensuring security.
class SecureSubscriptionService {
  static final Map<String, CachedSubscription> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  static const Duration _shortCacheTimeout = Duration(seconds: 30);

  /// Validates feature access with optional server-side check for sensitive operations
  /// 
  /// For high-security operations like payment processing or data export,
  /// use `serverValidation: true` to verify with the server.
  static Future<bool> validateFeatureAccess(
    String userId, 
    String featureName, {
    bool serverValidation = false,
  }) async {
    try {
      debugPrint('🔒 Validating feature access: $featureName for user: $userId');
      debugPrint('🌐 Server validation: ${serverValidation ? 'ENABLED' : 'CLIENT-SIDE'}');

      // Check cache first (unless server validation is required)
      if (!serverValidation) {
        final cached = _cache[userId];
        if (cached != null && cached.isValid) {
          final hasAccess = cached.subscription?.hasFeature(featureName) ?? false;
          debugPrint('💾 Cache hit - Feature access: $hasAccess');
          return hasAccess;
        }
      }

      if (serverValidation) {
        // Call Cloud Function for sensitive features
        debugPrint('🔒 Performing server-side validation via Cloud Function');
        
        final callable = FirebaseFunctions.instance.httpsCallable('validateFeatureAccess');
        final result = await callable.call({
          'userId': userId,
          'featureName': featureName,
        });
        
        final hasAccess = result.data['hasAccess'] as bool? ?? false;
        debugPrint('✅ Server validation result: $hasAccess');
        
        // Update cache with server result
        if (result.data['subscription'] != null) {
          final subscriptionData = result.data['subscription'] as Map<String, dynamic>;
          // Note: In a full implementation, you'd reconstruct the UserSubscription object here
          _cache[userId] = CachedSubscription(null, DateTime.now(), _cacheTimeout);
        }
        
        return hasAccess;
      }

      // Regular client-side check with caching
      debugPrint('📱 Performing client-side validation');
      final subscription = await SubscriptionService.getUserSubscription(userId);
      
      // Cache the subscription
      final cacheTimeout = subscription?.isPremium == true ? _cacheTimeout : _shortCacheTimeout;
      _cache[userId] = CachedSubscription(subscription, DateTime.now(), cacheTimeout);
      
      final hasAccess = subscription?.hasFeature(featureName) ?? false;
      debugPrint('✅ Client validation result: $hasAccess');
      
      return hasAccess;
      
    } catch (e) {
      debugPrint('❌ Error validating feature access: $e');
      
      // For security, deny access on error
      return false;
    }
  }

  /// Validates usage limits with server-side enforcement for critical limits
  /// 
  /// For operations that could be expensive or abused, use server-side validation
  /// to ensure accurate limit tracking.
  static Future<bool> validateUsageLimit(
    String userId,
    String limitName,
    int requestedUsage, {
    bool serverValidation = false,
  }) async {
    try {
      debugPrint('🔒 Validating usage limit: $limitName for user: $userId');
      debugPrint('📊 Requested usage: $requestedUsage');
      debugPrint('🌐 Server validation: ${serverValidation ? 'ENABLED' : 'CLIENT-SIDE'}');

      if (serverValidation) {
        // Server-side limit validation
        final callable = FirebaseFunctions.instance.httpsCallable('validateUsageLimit');
        final result = await callable.call({
          'userId': userId,
          'limitName': limitName,
          'requestedUsage': requestedUsage,
        });
        
        final allowed = result.data['allowed'] as bool? ?? false;
        final currentUsage = result.data['currentUsage'] as int? ?? 0;
        final limit = result.data['limit'] as int? ?? 0;
        
        debugPrint('✅ Server limit validation:');
        debugPrint('   Allowed: $allowed');
        debugPrint('   Current usage: $currentUsage');
        debugPrint('   Limit: $limit');
        
        return allowed;
      }

      // Client-side validation
      final subscription = await _getCachedSubscription(userId);
      final limit = subscription?.getLimit(limitName) ?? 0;
      
      // -1 means unlimited
      if (limit == -1) {
        debugPrint('✅ Unlimited access for $limitName');
        return true;
      }
      
      // For client-side validation, we can't track usage accurately
      // so we just check if the user has premium access for the limit
      final hasAccess = subscription?.isPremium == true || requestedUsage <= limit;
      debugPrint('✅ Client limit validation result: $hasAccess (limit: $limit)');
      
      return hasAccess;
      
    } catch (e) {
      debugPrint('❌ Error validating usage limit: $e');
      return false;
    }
  }

  /// Get cached subscription or fetch fresh data
  static Future<UserSubscription?> _getCachedSubscription(String userId) async {
    final cached = _cache[userId];
    
    // Check if cache is valid
    if (cached != null && cached.isValid) {
      return cached.subscription;
    }
    
    // Fetch fresh data
    final subscription = await SubscriptionService.getUserSubscription(userId);
    
    // Cache the result
    final cacheTimeout = subscription?.isPremium == true ? _cacheTimeout : _shortCacheTimeout;
    _cache[userId] = CachedSubscription(subscription, DateTime.now(), cacheTimeout);
    
    return subscription;
  }

  /// Invalidate cache for a specific user
  /// Call this when subscription status changes
  static void invalidateCache(String userId) {
    debugPrint('🧹 Invalidating subscription cache for user: $userId');
    _cache.remove(userId);
  }

  /// Invalidate all cached subscriptions
  /// Call this during app lifecycle events
  static void invalidateAllCaches() {
    debugPrint('🧹 Invalidating all subscription caches');
    _cache.clear();
  }

  /// Check if user has premium access (cached)
  static Future<bool> isPremiumUser(String userId) async {
    final subscription = await _getCachedSubscription(userId);
    return subscription?.isPremium == true;
  }

  /// Get user's subscription tier (cached)
  static Future<SubscriptionTier> getUserTier(String userId) async {
    final subscription = await _getCachedSubscription(userId);
    return subscription?.tier ?? SubscriptionTier.free;
  }

  /// Batch validate multiple features for efficiency
  static Future<Map<String, bool>> validateMultipleFeatures(
    String userId,
    List<String> featureNames, {
    bool serverValidation = false,
  }) async {
    final results = <String, bool>{};
    
    if (serverValidation) {
      // Server-side batch validation
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('validateMultipleFeatures');
        final result = await callable.call({
          'userId': userId,
          'featureNames': featureNames,
        });
        
        final serverResults = result.data['results'] as Map<String, dynamic>? ?? {};
        for (final feature in featureNames) {
          results[feature] = serverResults[feature] as bool? ?? false;
        }
      } catch (e) {
        debugPrint('❌ Error in batch server validation: $e');
        // Fill with false for security
        for (final feature in featureNames) {
          results[feature] = false;
        }
      }
    } else {
      // Client-side batch validation
      final subscription = await _getCachedSubscription(userId);
      for (final feature in featureNames) {
        results[feature] = subscription?.hasFeature(feature) ?? false;
      }
    }
    
    debugPrint('✅ Batch feature validation results: $results');
    return results;
  }

  /// Preload subscription data for better UX
  static Future<void> preloadSubscription(String userId) async {
    debugPrint('📦 Preloading subscription for user: $userId');
    await _getCachedSubscription(userId);
  }
}

/// Cached subscription entry with expiration
class CachedSubscription {
  final UserSubscription? subscription;
  final DateTime timestamp;
  final Duration timeout;

  CachedSubscription(this.subscription, this.timestamp, this.timeout);

  bool get isValid => 
    DateTime.now().difference(timestamp) < timeout;
}

/// Security levels for feature validation
// SecurityLevel moved to premium_error_handler.dart to avoid conflicts
// enum SecurityLevel {
//   /// Client-side validation only (fast, less secure)
//   client,
//   
//   /// Server-side validation (slower, more secure)
//   server,
//   
//   /// Hybrid - client for quick checks, server for sensitive operations
//   hybrid,
// }

/// Helper class for managing different security levels
class SecureFeatureGuard {
  /// Features that require server-side validation for security
  static const Set<String> _criticalFeatures = {
    'revenue_tracking',
    'sales_tracking',
    'financial_reporting',
    'data_export',
    'api_access',
    'white_label_analytics',
    'custom_reporting',
    'advanced_data_export',
  };

  /// Check if a feature requires server-side validation
  static bool requiresServerValidation(String featureName) {
    return _criticalFeatures.contains(featureName);
  }

  /// Validate feature with appropriate security level
  static Future<bool> validateFeature(String userId, String featureName) async {
    final requiresServer = requiresServerValidation(featureName);
    
    return SecureSubscriptionService.validateFeatureAccess(
      userId,
      featureName,
      serverValidation: requiresServer,
    );
  }

  /// Batch validate features with appropriate security levels
  static Future<Map<String, bool>> validateFeatures(
    String userId, 
    List<String> featureNames
  ) async {
    // Separate features by security requirements
    final clientFeatures = <String>[];
    final serverFeatures = <String>[];
    
    for (final feature in featureNames) {
      if (requiresServerValidation(feature)) {
        serverFeatures.add(feature);
      } else {
        clientFeatures.add(feature);
      }
    }
    
    final results = <String, bool>{};
    
    // Validate client features in batch
    if (clientFeatures.isNotEmpty) {
      final clientResults = await SecureSubscriptionService.validateMultipleFeatures(
        userId,
        clientFeatures,
        serverValidation: false,
      );
      results.addAll(clientResults);
    }
    
    // Validate server features individually or in batch
    if (serverFeatures.isNotEmpty) {
      final serverResults = await SecureSubscriptionService.validateMultipleFeatures(
        userId,
        serverFeatures,
        serverValidation: true,
      );
      results.addAll(serverResults);
    }
    
    return results;
  }
}