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
      
      final docRef = await _subscriptionsCollection.add(subscription.toFirestore());
      debugPrint('✅ Free subscription created for user: $userId');
      
      return subscription.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error creating free subscription: $e');
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Upgrade user to premium
  static Future<UserSubscription> upgradeToPremium(
    String userId, {
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
  }) async {
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No subscription found for user.');
      }

      final upgradedSubscription = currentSubscription.upgradeToPremium(
        stripeCustomerId: stripeCustomerId,
        stripeSubscriptionId: stripeSubscriptionId,
        paymentMethodId: paymentMethodId,
      );

      await _subscriptionsCollection
          .doc(currentSubscription.id)
          .update(upgradedSubscription.toFirestore());
      
      debugPrint('✅ User upgraded to premium: $userId');
      return upgradedSubscription;
    } catch (e) {
      debugPrint('❌ Error upgrading to premium: $e');
      throw Exception('Failed to upgrade subscription: $e');
    }
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
        // Create free subscription if none exists
        final userProfile = await _firestore.collection('users').doc(userId).get();
        final userType = userProfile.data()?['userType'] ?? 'shopper';
        final newSubscription = await createFreeSubscription(userId, userType);
        return newSubscription.isWithinLimit(limitName, currentUsage);
      }

      return subscription.isWithinLimit(limitName, currentUsage);
    } catch (e) {
      debugPrint('Error checking usage limit: $e');
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
        return {'monthly_markets': 5, 'photo_uploads': 3};
      case 'market_organizer':
        return {'markets_managed': 1, 'events_per_month': 10};
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
        'monthly_revenue': 0.0, // TODO: Calculate based on premium subscriptions
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
}