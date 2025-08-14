import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_subscription.dart';
import 'premium_error_handler.dart';
import 'premium_validation_service.dart';
import 'premium_network_service.dart';
import 'debug_logger_service.dart';
import 'dart:async';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _subscriptionsCollection = 
      _firestore.collection('user_subscriptions');
  static final _debugLogger = DebugLoggerService.instance;
  static final _networkService = PremiumNetworkService.instance;
  
  // Initialize the service
  static Future<void> initialize() async {
    try {
      await _networkService.initialize();
      _debugLogger.logInfo(
        operation: 'service_init',
        message: 'SubscriptionService initialized successfully',
      );
    } catch (e) {
      _debugLogger.logError(
        operation: 'service_init',
        message: 'Failed to initialize SubscriptionService: $e',
      );
      rethrow;
    }
  }

  /// Get user's current subscription with comprehensive error handling
  static Future<UserSubscription?> getUserSubscription(String userId) async {
    // Validate input
    final userIdValidation = PremiumValidationService.validateUserId(userId);
    if (!userIdValidation.isValid) {
      debugPrint('⚠️ Invalid userId in getUserSubscription: $userId');
      return null; // Return null instead of throwing for invalid user IDs
    }
    
    try {
      final snapshot = await _subscriptionsCollection
          .where('userId', isEqualTo: userIdValidation.value)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return UserSubscription.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      // Log the error but don't throw - return null to gracefully handle missing subscriptions
      debugPrint('⚠️ Error getting subscription for user $userId: $e');
      _debugLogger.logError(
        operation: 'getUserSubscription',
        message: 'Failed to fetch subscription, user will default to free tier',
        context: {
          'user_id': userId,
          'error': e.toString(),
        },
      );
      return null;
    }
  }

  /// Create free subscription for new user with comprehensive validation
  static Future<UserSubscription> createFreeSubscription(
    String userId, 
    String userType,
  ) async {
    // Validate inputs
    final validationResult = await PremiumValidationService.validateSubscriptionCreation(
      userId: userId,
      userType: userType,
    );
    if (!validationResult.isValid) {
      throw validationResult.toError();
    }
    
    try {
        final subscription = UserSubscription.createFree(
          validationResult.value['userId'],
          validationResult.value['userType'],
        );
        
        final docRef = await _subscriptionsCollection.add(subscription.toFirestore());
        
        _debugLogger.logInfo(
          operation: 'createFreeSubscription',
          message: 'Free subscription created successfully',
          context: {
            'user_id': userId,
            'user_type': userType,
            'subscription_id': docRef.id,
            'tier': subscription.tier.name,
          },
        );
        
        return subscription.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error creating free subscription: $e');
      rethrow;
    }
  }

  /// Upgrade user to specific tier with comprehensive error handling
  static Future<UserSubscription> upgradeToTier(
    String userId,
    SubscriptionTier tier, {
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
    String? stripePriceId,
  }) async {
    // Start flow tracking
    final flowTracker = _debugLogger.startFlow(
      'subscription_upgrade',
      userId,
      {
        'target_tier': tier.name,
        'has_stripe_customer_id': stripeCustomerId != null,
        'has_stripe_subscription_id': stripeSubscriptionId != null,
        'has_payment_method_id': paymentMethodId != null,
        'has_stripe_price_id': stripePriceId != null,
      },
    );
    
    // Validate inputs
    final userIdValidation = PremiumValidationService.validateUserId(userId);
    if (!userIdValidation.isValid) {
      _debugLogger.failFlow(flowTracker.flowId, 'Invalid user ID: ${userIdValidation.errorMessage}');
      throw userIdValidation.toError();
    }
    
    if (stripeCustomerId != null) {
      final customerIdValidation = PremiumValidationService.validateStripeCustomerId(stripeCustomerId);
      if (!customerIdValidation.isValid) {
        _debugLogger.failFlow(flowTracker.flowId, 'Invalid Stripe customer ID: ${customerIdValidation.errorMessage}');
        throw customerIdValidation.toError();
      }
    }
    
    if (stripeSubscriptionId != null) {
      final subscriptionIdValidation = PremiumValidationService.validateStripeSubscriptionId(stripeSubscriptionId);
      if (!subscriptionIdValidation.isValid) {
        _debugLogger.failFlow(flowTracker.flowId, 'Invalid Stripe subscription ID: ${subscriptionIdValidation.errorMessage}');
        throw subscriptionIdValidation.toError();
      }
    }
    
    return await PremiumErrorHandler.executeWithErrorHandling(
      operationName: 'upgradeToTier',
      operation: () async {
        _debugLogger.updateFlow(flowTracker.flowId, 'fetching_current_subscription');
        
        final currentSubscription = await getUserSubscription(userId);
        if (currentSubscription == null) {
          throw PremiumError.notFound('No subscription found for user');
        }
        
        _debugLogger.updateFlow(flowTracker.flowId, 'creating_upgraded_subscription', {
          'current_tier': currentSubscription.tier.name,
          'target_tier': tier.name,
        });
        
        final upgradedSubscription = currentSubscription.upgradeToTier(
          tier,
          stripeCustomerId: stripeCustomerId,
          stripeSubscriptionId: stripeSubscriptionId,
          paymentMethodId: paymentMethodId,
          stripePriceId: stripePriceId,
        );
        
        _debugLogger.updateFlow(flowTracker.flowId, 'updating_firestore');
        
        await _subscriptionsCollection
            .doc(currentSubscription.id)
            .update(upgradedSubscription.toFirestore());
        
        _debugLogger.logSubscriptionEvent(
          event: 'subscription_upgraded',
          userId: userId,
          subscriptionId: currentSubscription.id,
          additionalContext: {
            'from_tier': currentSubscription.tier.name,
            'to_tier': tier.name,
            'stripe_customer_id': stripeCustomerId,
            'stripe_subscription_id': stripeSubscriptionId,
          },
        );
        
        _debugLogger.completeFlow(flowTracker.flowId, {
          'upgraded_tier': tier.name,
          'subscription_id': currentSubscription.id,
        });
        
        return upgradedSubscription;
      },
      context: {
        'user_id': userId,
        'target_tier': tier.name,
        'operation_type': 'upgrade',
        'flow_id': flowTracker.flowId,
      },
      requiresNetwork: true,
    );
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

  /// Cancel user subscription with comprehensive error handling
  static Future<UserSubscription> cancelSubscription(String userId) async {
    // Start flow tracking
    final flowTracker = _debugLogger.startFlow(
      'subscription_cancellation',
      userId,
    );
    
    // Validate input
    final userIdValidation = PremiumValidationService.validateUserId(userId);
    if (!userIdValidation.isValid) {
      _debugLogger.failFlow(flowTracker.flowId, 'Invalid user ID: ${userIdValidation.errorMessage}');
      throw userIdValidation.toError();
    }
    
    return await PremiumErrorHandler.executeWithErrorHandling(
      operationName: 'cancelSubscription',
      operation: () async {
        _debugLogger.updateFlow(flowTracker.flowId, 'fetching_current_subscription');
        
        final currentSubscription = await getUserSubscription(userIdValidation.value);
        if (currentSubscription == null) {
          throw PremiumError.notFound('No subscription found for user');
        }
        
        _debugLogger.updateFlow(flowTracker.flowId, 'creating_cancelled_subscription', {
          'current_tier': currentSubscription.tier.name,
          'current_status': currentSubscription.status.name,
        });
        
        final cancelledSubscription = currentSubscription.cancel();
        
        _debugLogger.updateFlow(flowTracker.flowId, 'updating_firestore');
        
        await _subscriptionsCollection
            .doc(currentSubscription.id)
            .update(cancelledSubscription.toFirestore());
        
        _debugLogger.logSubscriptionEvent(
          event: 'subscription_cancelled',
          userId: userId,
          subscriptionId: currentSubscription.id,
          additionalContext: {
            'cancelled_tier': currentSubscription.tier.name,
            'was_active': currentSubscription.isActive,
          },
        );
        
        _debugLogger.completeFlow(flowTracker.flowId, {
          'cancelled_subscription_id': currentSubscription.id,
          'final_status': cancelledSubscription.status.name,
        });
        
        return cancelledSubscription;
      },
      context: {
        'user_id': userId,
        'operation_type': 'cancel',
        'flow_id': flowTracker.flowId,
      },
      requiresNetwork: true,
    );
  }

  /// Check if user has a specific feature with enhanced error handling
  static Future<bool> hasFeature(String userId, String featureName) async {
    // Validate inputs
    final userIdValidation = PremiumValidationService.validateUserId(userId);
    if (!userIdValidation.isValid) {
      _debugLogger.logError(
        operation: 'hasFeature',
        message: 'Invalid user ID provided',
        context: {'provided_user_id': userId, 'feature_name': featureName},
      );
      return false;
    }
    
    final featureValidation = PremiumValidationService.validateFeatureName(featureName);
    if (!featureValidation.isValid) {
      _debugLogger.logError(
        operation: 'hasFeature',
        message: 'Invalid feature name provided',
        context: {'user_id': userId, 'provided_feature_name': featureName},
      );
      return false;
    }
    
    try {
      // Call getUserSubscription without additional error wrapping to avoid double-wrapping
      final subscription = await getUserSubscription(userIdValidation.value);
      if (subscription == null) {
        _debugLogger.logDebug(
          operation: 'hasFeature',
          message: 'No subscription found, defaulting to free tier',
          context: {'user_id': userId, 'feature_name': featureName},
        );
        return false; // Free tier doesn't have premium features by default
      }
      
      final hasAccess = subscription.hasFeature(featureValidation.value);
        
      _debugLogger.logDebug(
        operation: 'hasFeature',
        message: 'Feature access check completed',
        context: {
          'user_id': userId,
          'feature_name': featureName,
          'has_access': hasAccess,
          'user_tier': subscription.tier.name,
        },
      );
      
      return hasAccess;
    } catch (e) {
      // Log error but don't throw - gracefully degrade to free tier
      _debugLogger.logError(
        operation: 'hasFeature',
        message: 'Error checking feature access, defaulting to free tier',
        context: {
          'user_id': userId,
          'feature_name': featureName,
          'error': e.toString(),
        },
      );
      debugPrint('⚠️ Error in hasFeature for $userId/$featureName: $e');
      return false; // Default to no access on error
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
          'price': 69.00,  // Updated pricing
          'currency': 'USD',
          'interval': 'month',
          'features': [
            'Unlimited vendor posts',
            'Analytics Dashboard',
            'Push Notifications',
            'Smart Recruitment',
            'Unlimited Events',
            'Response Management',
          ],
        };
      case 'vendor':
        return {
          'price': 29.00,
          'currency': 'USD',
          'interval': 'month',
          'features': [
            'Unlimited market applications',
            'Advanced Analytics',
            'Master Product Lists',
            'Push Notifications',
            'Multi-Market Management',
            'Organizer Post Access',
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
            'name': 'Organizer Pro',
            'description': 'Complete market management and vendor recruitment',
            'price': 69.00,  // Updated pricing
            'currency': 'USD',
            'interval': 'month',
            'features': [
              'Unlimited vendor posts',
              'Analytics Dashboard',
              'Push Notifications',
              'Smart Recruitment',
              'Unlimited Events',
              'Response Management',
              'Market Intelligence',
              'Advanced Reporting',
              'Revenue Optimization',
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

  /// Check if user can create a vendor post (new method for post limits)
  static Future<bool> canCreateVendorPost(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        // Create free subscription if none exists
        final userProfile = await _firestore.collection('users').doc(userId).get();
        final userType = userProfile.data()?['userType'] ?? 'shopper';
        final newSubscription = await createFreeSubscription(userId, userType);
        return newSubscription.canCreateVendorPost();
      }

      return subscription.canCreateVendorPost();
    } catch (e) {
      debugPrint('Error checking vendor post creation ability: $e');
      return false;
    }
  }

  /// Check if user can create a market application
  static Future<bool> canCreateMarketApplication(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        // Create free subscription if none exists
        final userProfile = await _firestore.collection('users').doc(userId).get();
        final userType = userProfile.data()?['userType'] ?? 'shopper';
        final newSubscription = await createFreeSubscription(userId, userType);
        return newSubscription.canCreateMarketApplication();
      }

      return subscription.canCreateMarketApplication();
    } catch (e) {
      debugPrint('Error checking market application creation ability: $e');
      return false;
    }
  }

  /// Get remaining market applications for this month
  static Future<int> getRemainingMarketApplications(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        // Return free tier limit
        return 5; // Free tier has 5 applications for vendors
      }

      return subscription.getRemainingMarketApplications();
    } catch (e) {
      debugPrint('Error getting remaining market applications: $e');
      return 0;
    }
  }

  /// Get remaining vendor posts for this month
  static Future<int> getRemainingVendorPosts(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        // Return free tier limit
        return 0; // Free tier has 0 vendor posts for vendors, 1 for organizers
      }

      return subscription.getRemainingVendorPosts();
    } catch (e) {
      debugPrint('Error getting remaining vendor posts: $e');
      return 0;
    }
  }

  /// Increment user's monthly post count (call when a vendor post is created)
  static Future<UserSubscription> incrementPostCount(String userId) async {
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No subscription found for user.');
      }

      final updatedSubscription = currentSubscription.incrementPostCount();

      await _subscriptionsCollection
          .doc(currentSubscription.id)
          .update(updatedSubscription.toFirestore());
      
      debugPrint('✅ Post count incremented for user: $userId (new count: ${updatedSubscription.effectiveMonthlyPostCount})');
      return updatedSubscription;
    } catch (e) {
      debugPrint('❌ Error incrementing post count: $e');
      throw Exception('Failed to increment post count: $e');
    }
  }

  /// Increment user's monthly application count (call when a market application is created)
  static Future<UserSubscription> incrementApplicationCount(String userId) async {
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No subscription found for user.');
      }

      final updatedSubscription = currentSubscription.incrementApplicationCount();

      await _subscriptionsCollection
          .doc(currentSubscription.id)
          .update(updatedSubscription.toFirestore());
      
      debugPrint('✅ Application count incremented for user: $userId (new count: ${updatedSubscription.effectiveMonthlyApplicationCount})');
      return updatedSubscription;
    } catch (e) {
      debugPrint('❌ Error incrementing application count: $e');
      throw Exception('Failed to increment application count: $e');
    }
  }

  /// Reset monthly counters for all users (background job)
  static Future<void> resetAllMonthlyCounters() async {
    try {
      final snapshot = await _subscriptionsCollection.get();
      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in snapshot.docs) {
        try {
          final subscription = UserSubscription.fromFirestore(doc);
          if (subscription.needsMonthlyReset) {
            final resetSubscription = subscription.resetMonthlyCounters();
            batch.update(doc.reference, resetSubscription.toFirestore());
            updateCount++;
          }
        } catch (e) {
          debugPrint('Error processing subscription ${doc.id}: $e');
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint('✅ Reset monthly counters for $updateCount subscriptions');
      } else {
        debugPrint('ℹ️ No subscriptions needed monthly reset');
      }
    } catch (e) {
      debugPrint('❌ Error resetting monthly counters: $e');
      throw Exception('Failed to reset monthly counters: $e');
    }
  }

  /// Get post usage summary for a user
  static Future<Map<String, dynamic>> getPostUsageSummary(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        return {
          'monthly_posts_used': 0,
          'monthly_posts_limit': 0,
          'remaining_posts': 0,
          'is_premium': false,
          'reset_date': null,
        };
      }

      final limit = subscription.getLimit('vendor_posts_per_month');
      final used = subscription.effectiveMonthlyPostCount;
      final remaining = subscription.getRemainingVendorPosts();

      return {
        'monthly_posts_used': used,
        'monthly_posts_limit': limit == -1 ? 'unlimited' : limit,
        'remaining_posts': remaining == -1 ? 'unlimited' : remaining,
        'is_premium': subscription.isPremium,
        'reset_date': subscription.lastResetDate,
        'needs_reset': subscription.needsMonthlyReset,
      };
    } catch (e) {
      debugPrint('Error getting post usage summary: $e');
      return {};
    }
  }
}