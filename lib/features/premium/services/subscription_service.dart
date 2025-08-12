import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_subscription.dart';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _subscriptionsCollection = 
      _firestore.collection('user_subscriptions');

  /// Get user's current subscription
  static Future<UserSubscription?> getUserSubscription(String userId) async {
    try {
      final snapshot = await _subscriptionsCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return UserSubscription.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user subscription: $e');
      return null;
    }
  }

  /// Create free subscription for new user
  static Future<UserSubscription> createFreeSubscription(
    String userId, 
    String userType,
  ) async {
    try {
      final subscription = UserSubscription.createFree(userId, userType);
      debugPrint('🔍 DEBUG: Created free subscription object - tier: ${subscription.tier.name}, userType: ${subscription.userType}, isFree: ${subscription.isFree}');
      
      final docRef = await _subscriptionsCollection.add(subscription.toFirestore());
      debugPrint('✅ Free subscription created for user: $userId with ID: ${docRef.id}');
      
      return subscription.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error creating free subscription: $e');
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Upgrade user to specific tier
  static Future<UserSubscription> upgradeToTier(
    String userId,
    SubscriptionTier tier, {
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
    String? stripePriceId,
  }) async {
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No subscription found for user.');
      }

      final upgradedSubscription = currentSubscription.upgradeToTier(
        tier,
        stripeCustomerId: stripeCustomerId,
        stripeSubscriptionId: stripeSubscriptionId,
        paymentMethodId: paymentMethodId,
        stripePriceId: stripePriceId,
      );

      await _subscriptionsCollection
          .doc(currentSubscription.id)
          .update(upgradedSubscription.toFirestore());
      
      debugPrint('✅ User upgraded to ${tier.name}: $userId');
      return upgradedSubscription;
    } catch (e) {
      debugPrint('❌ Error upgrading to ${tier.name}: $e');
      throw Exception('Failed to upgrade subscription: $e');
    }
  }

  /// Upgrade user to premium (backward compatibility)
  static Future<UserSubscription> upgradeToPremium(
    String userId, {
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
    String? stripePriceId,
  }) async {
    // Default to appropriate tier based on user type
    final userProfile = await _firestore.collection('users').doc(userId).get();
    final userType = userProfile.data()?['userType'] ?? 'shopper';
    
    final targetTier = userType == 'vendor' 
        ? SubscriptionTier.vendorPro
        : userType == 'market_organizer'
        ? SubscriptionTier.marketOrganizerPro
        : SubscriptionTier.vendorPro;
    
    return upgradeToTier(
      userId,
      targetTier,
      stripeCustomerId: stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId,
      paymentMethodId: paymentMethodId,
      stripePriceId: stripePriceId,
    );
  }

  /// Cancel user subscription
  static Future<UserSubscription> cancelSubscription(String userId) async {
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No subscription found for user.');
      }

      final cancelledSubscription = currentSubscription.cancel();

      await _subscriptionsCollection
          .doc(currentSubscription.id)
          .update(cancelledSubscription.toFirestore());
      
      debugPrint('✅ Subscription cancelled for user: $userId');
      return cancelledSubscription;
    } catch (e) {
      debugPrint('❌ Error cancelling subscription: $e');
      throw Exception('Failed to cancel subscription: $e');
    }
  }

  /// Check if user has a specific feature
  static Future<bool> hasFeature(String userId, String featureName) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        // Create free subscription if none exists
        final userProfile = await _firestore.collection('users').doc(userId).get();
        final userType = userProfile.data()?['userType'] ?? 'shopper';
        await createFreeSubscription(userId, userType);
        return false; // Free tier doesn't have premium features
      }

      return subscription.hasFeature(featureName);
    } catch (e) {
      debugPrint('Error checking feature access: $e');
      return false;
    }
  }

  /// Check if user is within usage limit
  static Future<bool> isWithinLimit(
    String userId, 
    String limitName, 
    int currentUsage,
  ) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        debugPrint('🔍 DEBUG: No subscription found for user: $userId, creating free subscription');
        // Create free subscription if none exists
        final userProfile = await _firestore.collection('users').doc(userId).get();
        debugPrint('🔍 DEBUG: User profile exists: ${userProfile.exists}');
        if (userProfile.exists) {
          debugPrint('🔍 DEBUG: User profile data: ${userProfile.data()}');
        }
        final userType = userProfile.data()?['userType'] ?? 'shopper';
        debugPrint('🔍 DEBUG: User type from profile: $userType (default: shopper)');
        
        // Critical fix: If we're checking vendor-specific limits but userType is wrong, override it
        String actualUserType = userType;
        if (limitName == 'global_products' && userType != 'vendor') {
          debugPrint('🔧 FIX: Checking global_products limit suggests this is a vendor. Overriding userType from $userType to vendor');
          actualUserType = 'vendor';
        }
        final newSubscription = await createFreeSubscription(userId, actualUserType);
        debugPrint('🔍 DEBUG: Created subscription - tier: ${newSubscription.tier.name}, userType: ${newSubscription.userType}');
        final limit = newSubscription.getLimit(limitName);
        debugPrint('🔍 DEBUG: Limit for $limitName: $limit');
        final withinLimit = newSubscription.isWithinLimit(limitName, currentUsage);
        debugPrint('🔍 DEBUG: isWithinLimit($limitName, $currentUsage) = $withinLimit (limit: $limit)');
        return withinLimit;
      }

      debugPrint('🔍 DEBUG: Found existing subscription - tier: ${subscription.tier.name}, userType: ${subscription.userType}');
      
      // Critical check: If subscription has wrong userType, fix it
      if (limitName == 'global_products' && subscription.userType != 'vendor') {
        debugPrint('🔧 FIX: Found subscription with wrong userType for vendor operation. Updating subscription.');
        final updatedSubscription = subscription.copyWith(userType: 'vendor', updatedAt: DateTime.now());
        await _subscriptionsCollection
            .doc(subscription.id)
            .update(updatedSubscription.toFirestore());
        
        final limit = updatedSubscription.getLimit(limitName);
        debugPrint('🔍 DEBUG: Limit for $limitName after fix: $limit');
        final withinLimit = updatedSubscription.isWithinLimit(limitName, currentUsage);
        debugPrint('🔍 DEBUG: isWithinLimit($limitName, $currentUsage) = $withinLimit (limit: $limit) after fix');
        return withinLimit;
      }
      
      final limit = subscription.getLimit(limitName);
      debugPrint('🔍 DEBUG: Limit for $limitName: $limit');
      final withinLimit = subscription.isWithinLimit(limitName, currentUsage);
      debugPrint('🔍 DEBUG: isWithinLimit($limitName, $currentUsage) = $withinLimit (limit: $limit)');
      return withinLimit;
    } catch (e) {
      debugPrint('❌ Error checking usage limit: $e');
      return false;
    }
  }

  /// Get user's usage limit for a specific metric
  static Future<int> getUserLimit(String userId, String limitName) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        // Return free tier limits
        final limits = _getFreeLimits('shopper'); // Default to shopper
        return limits[limitName] ?? 0;
      }

      return subscription.getLimit(limitName);
    } catch (e) {
      debugPrint('Error getting user limit: $e');
      return 0;
    }
  }

  /// Get free tier limits by user type
  static Map<String, int> _getFreeLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return {
          'monthly_markets': 5, 
          'photo_uploads_per_post': 3, 
          'global_products': 3,
          'product_lists': 1,
        };
      case 'market_organizer':
        return {'markets_managed': -1, 'events_per_month': 10};
      case 'shopper':
        return {'saved_favorites': 10};
      default:
        return {};
    }
  }

  /// Update subscription payment information
  static Future<UserSubscription> updatePaymentInfo(
    String userId, {
    String? paymentMethodId,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    DateTime? nextPaymentDate,
  }) async {
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No subscription found for user.');
      }

      final updatedSubscription = currentSubscription.copyWith(
        paymentMethodId: paymentMethodId,
        stripeCustomerId: stripeCustomerId,
        stripeSubscriptionId: stripeSubscriptionId,
        nextPaymentDate: nextPaymentDate,
        updatedAt: DateTime.now(),
      );

      await _subscriptionsCollection
          .doc(currentSubscription.id)
          .update(updatedSubscription.toFirestore());
      
      debugPrint('✅ Payment info updated for user: $userId');
      return updatedSubscription;
    } catch (e) {
      debugPrint('❌ Error updating payment info: $e');
      throw Exception('Failed to update payment information: $e');
    }
  }

  /// Get subscription statistics (for admin dashboard)
  static Future<Map<String, dynamic>> getSubscriptionStats() async {
    try {
      final snapshot = await _subscriptionsCollection.get();
      final subscriptions = snapshot.docs
          .map((doc) => UserSubscription.fromFirestore(doc))
          .toList();
      
      final stats = <String, dynamic>{
        'total': subscriptions.length,
        'free': 0,
        'premium': 0,
        'active': 0,
        'cancelled': 0,
        'by_user_type': <String, int>{},
        'monthly_revenue': 0.0,
      };
      
      for (final subscription in subscriptions) {
        // Count by tier
        if (subscription.isFree) {
          stats['free'] = stats['free'] + 1;
        } else {
          stats['premium'] = stats['premium'] + 1;
        }
        
        // Count by status
        if (subscription.isActive) {
          stats['active'] = stats['active'] + 1;
        } else if (subscription.isCancelled) {
          stats['cancelled'] = stats['cancelled'] + 1;
        }
        
        // Count by user type
        final userTypeStats = stats['by_user_type'] as Map<String, int>;
        userTypeStats[subscription.userType] = 
            (userTypeStats[subscription.userType] ?? 0) + 1;
        
        // Calculate monthly revenue from active premium subscriptions
        if (subscription.isActive && subscription.isPremium) {
          stats['monthly_revenue'] = 
              (stats['monthly_revenue'] as double) + subscription.getMonthlyPrice();
        }
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting subscription stats: $e');
      throw Exception('Failed to get subscription statistics: $e');
    }
  }

  /// Check if user needs to upgrade for a feature
  static Future<bool> needsUpgradeForFeature(String userId, String featureName) async {
    final hasAccess = await hasFeature(userId, featureName);
    return !hasAccess;
  }

  /// Check if user needs to upgrade for usage limit
  static Future<bool> needsUpgradeForLimit(
    String userId, 
    String limitName, 
    int currentUsage,
  ) async {
    final withinLimit = await isWithinLimit(userId, limitName, currentUsage);
    return !withinLimit;
  }

  /// Stream user subscription changes
  static Stream<UserSubscription?> streamUserSubscription(String userId) {
    return _subscriptionsCollection
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return UserSubscription.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  /// Get pricing information for a user type
  static Map<String, dynamic> getPricingInfo(String userType) {
    switch (userType) {
      case 'market_organizer':
        return {
          'price': 39.00,
          'currency': 'USD',
          'interval': 'month',
          'features': [
            'Analytics Dashboard',
            'Push Notifications',
            'Smart Recruitment',
            'Unlimited Events',
          ],
        };
      case 'vendor':
        return {
          'price': 29.00,
          'currency': 'USD',
          'interval': 'month',
          'features': [
            'Advanced Analytics',
            'Master Product Lists',
            'Push Notifications',
            'Multi-Market Management',
          ],
        };
      case 'shopper':
        return {
          'price': 4.00,
          'currency': 'USD',
          'interval': 'month',
          'features': [
            'Advanced Search & Discovery',
            'Smart Recommendations',
            'Vendor Following',
            'Predictive Features',
          ],
        };
      default:
        return {
          'price': 0.00,
          'currency': 'USD',
          'interval': 'month',
          'features': <String>[],
        };
    }
  }

  /// Get all pricing tiers for a user type
  static List<Map<String, dynamic>> getAllPricingTiers(String userType) {
    switch (userType) {
      case 'shopper':
        return [
          {
            'userType': 'shopper',
            'name': 'Shopper Basic',
            'description': 'Enhanced market discovery',
            'price': 4.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Advanced Search & Discovery',
              'Smart Recommendations',
              'Unlimited Favorites',
            ],
          },
          {
            'userType': 'shopper',
            'name': 'Shopper Pro',
            'description': 'Complete shopping experience',
            'price': 19.99,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Everything in Basic',
              'Vendor Following & Notifications',
              'Predictive Features',
              'Premium Support',
            ],
          },
        ];
      case 'vendor':
        return [
          {
            'userType': 'vendor',
            'name': 'Vendor Pro',
            'description': 'Essential business tools',
            'price': 29.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Advanced Analytics',
              'Master Product Lists',
              'Push Notifications',
              'Multi-Market Management',
            ],
          },
          {
            'userType': 'vendor',
            'name': 'Vendor Pro',
            'description': 'Advanced business intelligence',
            'price': 39.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Everything in Basic',
              'Price Optimization',
              'Customer Demographics',
              'Revenue Analytics',
              'Advanced Reporting',
            ],
          },
          {
            'userType': 'vendor',
            'name': 'Vendor Enterprise',
            'description': 'Complete business solution',
            'price': 99.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Everything in Pro',
              'White-label Solutions',
              'API Access',
              'Dedicated Support',
              'Custom Integrations',
            ],
          },
        ];
      case 'market_organizer':
        return [
          {
            'userType': 'market_organizer',
            'name': 'Organizer Basic',
            'description': 'Essential market management',
            'price': 39.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Analytics Dashboard',
              'Push Notifications',
              'Smart Recruitment',
              'Unlimited Events',
            ],
          },
          {
            'userType': 'market_organizer',
            'name': 'Organizer Pro',
            'description': 'Advanced market operations',
            'price': 79.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Everything in Basic',
              'Market Intelligence',
              'Advanced Reporting',
              'Revenue Optimization',
              'Multi-market Management',
            ],
          },
          {
            'userType': 'market_organizer',
            'name': 'Organizer Enterprise',
            'description': 'Multi-market enterprise solution',
            'price': 199.00,
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Everything in Pro',
              'Custom Branding',
              'API Access',
              'Dedicated Account Manager',
              'Enterprise Integrations',
            ],
          },
        ];
      default:
        return [];
    }
  }

  /// Get current usage analytics for a user
  static Future<Map<String, dynamic>> getCurrentUsage(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return {};
      
      // Calculate usage percentages for various limits
      final utilizationData = <String, double>{};
      
      // This would normally query actual usage data from the database
      // For now, return sample usage data
      switch (subscription.userType) {
        case 'vendor':
          utilizationData['monthly_markets'] = 60.0; // 3 out of 5 markets used
          utilizationData['photo_uploads'] = 66.7; // 2 out of 3 uploads used
          break;
        case 'market_organizer':
          utilizationData['events_per_month'] = 70.0; // 7 out of 10 events used
          break;
        case 'shopper':
          utilizationData['saved_favorites'] = 40.0; // 4 out of 10 favorites used
          break;
      }
      
      return {
        'utilizationPercentage': utilizationData,
        'currentPeriodStart': DateTime.now().subtract(const Duration(days: 30)),
        'currentPeriodEnd': DateTime.now(),
        'totalUsage': utilizationData.values.isNotEmpty 
            ? utilizationData.values.reduce((a, b) => a + b) / utilizationData.length
            : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting current usage: $e');
      return {};
    }
  }

  /// Get upgrade recommendations based on usage patterns
  static Future<Map<String, dynamic>> getUpgradeRecommendations(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return {};
      
      final usage = await getCurrentUsage(userId);
      final recommendations = <String>[];
      String? suggestedTier;
      
      // Analyze usage patterns and suggest upgrades
      final utilizationData = usage['utilizationPercentage'] as Map<String, double>? ?? {};
      
      bool highUsage = false;
      for (final utilization in utilizationData.values) {
        if (utilization > 80) {
          highUsage = true;
          break;
        }
      }
      
      if (highUsage) {
        recommendations.add('You\'re approaching your usage limits');
        suggestedTier = _getNextTier(subscription.userType, subscription.tier.name);
        if (suggestedTier != null) {
          recommendations.add('Consider upgrading to $suggestedTier for unlimited access');
        }
      }
      
      // Feature-based recommendations
      final missingFeatures = await _identifyMissingFeatures(userId, subscription);
      if (missingFeatures.isNotEmpty) {
        recommendations.add('Unlock premium features: ${missingFeatures.take(3).join(', ')}');
      }
      
      return {
        'userId': userId,
        'currentTier': subscription.tier.name,
        'suggestedTier': suggestedTier,
        'recommendations': recommendations,
        'potentialSavings': _calculatePotentialSavings(subscription.userType, suggestedTier),
        'upgradeIncentives': _getUpgradeIncentives(subscription.userType, suggestedTier),
      };
    } catch (e) {
      debugPrint('Error getting upgrade recommendations: $e');
      return {};
    }
  }
  
  static String? _getNextTier(String userType, String currentTier) {
    // For now, the app uses a simple free/premium model
    // This could be expanded to support multiple tiers in the future
    if (currentTier == 'free') {
      return 'premium';
    }
    return null; // Already at highest tier
  }
  
  static Future<List<String>> _identifyMissingFeatures(
    String userId, 
    UserSubscription subscription,
  ) async {
    // Identify features the user might benefit from but doesn't have access to
    final missingFeatures = <String>[];
    
    // This would analyze user behavior and suggest relevant features
    // For now, return common premium features
    switch (subscription.userType) {
      case 'vendor':
        if (!subscription.hasFeature('advanced_analytics')) {
          missingFeatures.add('Advanced Analytics');
        }
        if (!subscription.hasFeature('price_optimization')) {
          missingFeatures.add('Price Optimization');
        }
        break;
      case 'market_organizer':
        if (!subscription.hasFeature('market_intelligence')) {
          missingFeatures.add('Market Intelligence');
        }
        break;
    }
    
    return missingFeatures;
  }
  
  static double _calculatePotentialSavings(String userType, String? suggestedTier) {
    if (suggestedTier == null) return 0.0;
    
    // Calculate potential ROI or savings from upgrade
    switch (userType) {
      case 'vendor':
        if (suggestedTier == 'premium') {
          return 150.0; // Estimated monthly savings from optimization features
        }
        return 0.0;
      default:
        return 0.0;
    }
  }
  
  static List<String> _getUpgradeIncentives(String userType, String? suggestedTier) {
    if (suggestedTier == null) return [];
    
    switch (userType) {
      case 'vendor':
        if (suggestedTier == 'premium') {
          return [
            '30-day free trial',
            'Price optimization tools can increase revenue by 15%',
            'Advanced analytics help identify growth opportunities',
          ];
        }
        break;
      case 'market_organizer':
        if (suggestedTier == 'premium') {
          return [
            '14-day free trial',
            'Market intelligence tools improve vendor selection',
            'Advanced reporting saves 10+ hours monthly',
          ];
        }
        break;
    }
    
    return [];
  }
}