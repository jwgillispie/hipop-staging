import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_subscription.dart';
import 'subscription_service.dart';

/// 🧪 STAGING ONLY: Test service for subscription functionality
/// 
/// ⚠️  SECURITY WARNING: This service contains test functions that bypass
/// normal security checks. It is ONLY available in staging environments.
/// 
/// 🔒 PRODUCTION SAFETY: All methods check environment before execution
/// and throw exceptions if used outside of staging.
class StagingTestService {
  /// Check if we're in staging environment
  static bool get isStagingEnvironment => 
    dotenv.env['ENVIRONMENT'] == 'staging' || kDebugMode;

  /// Simulate premium upgrade for testing purposes
  /// 
  /// 🧪 TESTING ONLY: This bypasses normal payment validation
  /// ⚠️  SECURITY: Only works in staging environment
  static Future<void> simulatePremiumUpgrade({
    required String userId,
    required String userType,
    SubscriptionTier? specificTier,
  }) async {
    if (!isStagingEnvironment) {
      throw Exception('❌ Test functions only available in staging environment');
    }
    
    debugPrint('🧪 [STAGING TEST] Simulating premium upgrade');
    debugPrint('👤 User ID: $userId');
    debugPrint('🏷️  User Type: $userType');
    debugPrint('⚠️  WARNING: This is a test upgrade - not a real payment!');
    
    try {
      // Determine tier based on user type or use specific tier
      final tier = specificTier ?? _getTierForUserType(userType);
      
      // Create test subscription data
      final now = DateTime.now();
      final testSubscription = UserSubscription(
        id: 'test_sub_${userId}_${now.millisecondsSinceEpoch}',
        userId: userId,
        userType: userType,
        tier: tier,
        status: SubscriptionStatus.active,
        subscriptionStartDate: now,
        stripeCustomerId: 'cus_test_staging_$userId',
        stripeSubscriptionId: 'sub_test_staging_$userId',
        stripePriceId: 'price_test_staging_${tier.name}',
        monthlyPrice: _getPriceForTier(tier),
        features: _getDefaultFeaturesForTier(tier),
        limits: _getDefaultLimitsForTier(tier),
        metadata: {
          'test_subscription': true,
          'staging_environment': true,
          'created_by': 'StagingTestService',
          'test_timestamp': now.toIso8601String(),
        },
        createdAt: now,
        updatedAt: now,
      );
      
      // Save to user_subscriptions collection
      await FirebaseFirestore.instance
        .collection('user_subscriptions')
        .doc(testSubscription.id)
        .set(testSubscription.toFirestore());
      
      debugPrint('✅ [STAGING TEST] Premium upgrade simulation complete');
      debugPrint('🎯 Subscription ID: ${testSubscription.id}');
      debugPrint('💰 Monthly Price: \$${testSubscription.monthlyPrice}');
      debugPrint('🏆 Tier: ${testSubscription.tier.name}');
      
    } catch (e) {
      debugPrint('❌ [STAGING TEST] Error simulating premium upgrade: $e');
      rethrow;
    }
  }
  
  /// Clear test subscriptions for a user
  /// 
  /// 🧪 TESTING ONLY: Removes test subscriptions
  static Future<void> clearTestSubscriptions(String userId) async {
    if (!isStagingEnvironment) {
      throw Exception('❌ Test functions only available in staging environment');
    }
    
    debugPrint('🧹 [STAGING TEST] Clearing test subscriptions for user: $userId');
    
    try {
      // Find test subscriptions
      final query = await FirebaseFirestore.instance
        .collection('user_subscriptions')
        .where('userId', isEqualTo: userId)
        .where('metadata.test_subscription', isEqualTo: true)
        .get();
      
      // Delete test subscriptions
      for (final doc in query.docs) {
        await doc.reference.delete();
        debugPrint('🗑️  Deleted test subscription: ${doc.id}');
      }
      
      debugPrint('✅ [STAGING TEST] Cleared ${query.docs.length} test subscriptions');
      
    } catch (e) {
      debugPrint('❌ [STAGING TEST] Error clearing test subscriptions: $e');
      rethrow;
    }
  }
  
  /// Simulate webhook callback for testing
  /// 
  /// 🧪 TESTING ONLY: Simulates successful payment webhook
  static Future<void> simulateSuccessfulWebhook({
    required String userId,
    required String userType,
  }) async {
    if (!isStagingEnvironment) {
      throw Exception('❌ Test functions only available in staging environment');
    }
    
    debugPrint('🧪 [STAGING TEST] Simulating successful webhook');
    debugPrint('👤 User ID: $userId');
    debugPrint('🏷️  User Type: $userType');
    
    try {
      // Create test session data
      final sessionId = 'cs_test_staging_${DateTime.now().millisecondsSinceEpoch}';
      
      // Upgrade user through normal process but with test data
      await simulatePremiumUpgrade(
        userId: userId, 
        userType: userType,
      );
      
      debugPrint('✅ [STAGING TEST] Webhook simulation complete');
      debugPrint('🎫 Test Session ID: $sessionId');
      
    } catch (e) {
      debugPrint('❌ [STAGING TEST] Error simulating webhook: $e');
      rethrow;
    }
  }
  
  /// Get current test environment info
  static Map<String, dynamic> getTestEnvironmentInfo() {
    if (!isStagingEnvironment) {
      throw Exception('❌ Test functions only available in staging environment');
    }
    
    return {
      'environment': dotenv.env['ENVIRONMENT'] ?? 'unknown',
      'isDebugMode': kDebugMode,
      'isStagingEnvironment': isStagingEnvironment,
      'availableTestFunctions': [
        'simulatePremiumUpgrade',
        'clearTestSubscriptions', 
        'simulateSuccessfulWebhook',
        'getTestEnvironmentInfo',
      ],
      'safety_note': 'Test functions are disabled in production',
    };
  }
  
  // Helper methods
  static SubscriptionTier _getTierForUserType(String userType) {
    switch (userType) {
      case 'shopper':
        return SubscriptionTier.shopperPro;
      case 'vendor':
        return SubscriptionTier.vendorPro;
      case 'market_organizer':
        return SubscriptionTier.marketOrganizerPro;
      default:
        return SubscriptionTier.shopperPro;
    }
  }
  
  static double _getPriceForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 0.00;
      case SubscriptionTier.shopperPro:
        return 4.00;
      case SubscriptionTier.vendorPro:
        return 29.00;
      case SubscriptionTier.marketOrganizerPro:
        return 69.00;
      case SubscriptionTier.enterprise:
        return 199.99;
    }
  }
  
  static Map<String, dynamic> _getDefaultFeaturesForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return {};
      case SubscriptionTier.shopperPro:
        return {
          'enhanced_search': true,
          'unlimited_favorites': true,
          'vendor_following': true,
          'personalized_recommendations': true,
        };
      case SubscriptionTier.vendorPro:
        return {
          'market_discovery': true,
          'full_vendor_analytics': true,
          'revenue_tracking': true,
          'sales_tracking': true,
          'unlimited_markets': true,
        };
      case SubscriptionTier.marketOrganizerPro:
        return {
          'vendor_discovery': true,
          'multi_market_management': true,
          'vendor_analytics_dashboard': true,
          'financial_reporting': true,
        };
      case SubscriptionTier.enterprise:
        return {
          'white_label_analytics': true,
          'api_access': true,
          'custom_reporting': true,
          'dedicated_account_manager': true,
        };
    }
  }
  
  static Map<String, dynamic> _getDefaultLimitsForTier(SubscriptionTier tier) {
    if (tier == SubscriptionTier.free) {
      return {
        'monthly_markets': 5,
        'photo_uploads_per_post': 3,
        'global_products': 3,
        'product_lists': 1,
        'saved_favorites': 10,
      };
    }
    
    // Premium tiers get unlimited access (-1 = unlimited)
    return {
      'monthly_markets': -1,
      'photo_uploads_per_post': -1,
      'global_products': -1,
      'product_lists': -1,
      'saved_favorites': -1,
    };
  }
}

/// 🧪 STAGING ONLY: Widget for testing subscription functionality
/// 
/// This widget provides testing controls only in staging environments
class StagingSubscriptionTestWidget {
  /// Check if test widgets should be shown
  static bool get shouldShow => StagingTestService.isStagingEnvironment;
  
  /// Build staging test toolbar
  static Widget buildStagingToolbar() {
    if (!shouldShow) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Colors.yellow.shade200,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Text('🧪 STAGING', 
            style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(
            onPressed: () => _simulateUpgrade(),
            child: const Text('Test Premium'),
          ),
          TextButton(
            onPressed: () => _clearSubscriptions(),
            child: const Text('Clear Test'),
          ),
          TextButton(
            onPressed: () => _simulateWebhook(),
            child: const Text('Test Webhook'),
          ),
        ],
      ),
    );
  }
  
  static void _simulateUpgrade() {
    // This would need context and user ID
    debugPrint('🧪 Test upgrade button pressed');
  }
  
  static void _clearSubscriptions() {
    // This would need context and user ID
    debugPrint('🧪 Clear subscriptions button pressed');
  }
  
  static void _simulateWebhook() {
    // This would need context and user ID
    debugPrint('🧪 Simulate webhook button pressed');
  }
}