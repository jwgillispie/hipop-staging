import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/services/user_profile_service.dart';
import '../models/user_subscription.dart';
import 'subscription_service.dart';

/// 🔒 SECURE: Service to handle subscription success callbacks
/// 
/// This service has been completely rewritten to remove test code vulnerabilities
/// and use secure server-side validation through Cloud Functions.
/// 
/// ⚠️  SECURITY: All test code and fake sessions have been REMOVED
/// ✅ SECURE: All validation now happens server-side via Cloud Functions
class SubscriptionSuccessService {
  static final UserProfileService _userProfileService = UserProfileService();

  /// Handle successful subscription from Stripe checkout with secure validation
  /// 
  /// 🔒 SECURITY: All session validation moved to server-side Cloud Functions
  /// No test code or fake sessions allowed in production.
  static Future<bool> handleSubscriptionSuccess({
    required String userId,
    required String sessionId,
  }) async {
    try {
      debugPrint('🔒 Processing secure subscription success');
      debugPrint('👤 User ID: $userId');
      debugPrint('🎫 Session ID: $sessionId');
      debugPrint('⏰ Timestamp: ${DateTime.now()}');

      // 🔒 SECURE: Verify session server-side only
      debugPrint('🔒 Verifying session via secure Cloud Function...');
      
      final callable = FirebaseFunctions.instance.httpsCallable('verifySubscriptionSession');
      final result = await callable.call({
        'sessionId': sessionId,
        'userId': userId,
      });
      
      final isValid = result.data['valid'] as bool? ?? false;
      if (!isValid) {
        debugPrint('❌ Server-side session verification failed');
        return false;
      }
      
      debugPrint('✅ Server-side session verification successful');
      
      // Extract validated data from server response
      final customerEmail = result.data['customerEmail'] as String?;
      final stripeSubscriptionId = result.data['subscriptionId'] as String?;
      
      if (stripeSubscriptionId == null) {
        debugPrint('❌ No subscription ID returned from server');
        return false;
      }
      
      // 🔒 SECURE: Upgrade handled through existing secure service
      debugPrint('🔄 Upgrading user subscription via SubscriptionService...');
      
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null) {
        debugPrint('❌ No subscription found for user during upgrade');
        return false;
      }
      
      // Update subscription to active status
      // Determine the tier based on the user type
      SubscriptionTier targetTier;
      
      // Get user profile to determine the correct tier
      final userProfile = await UserProfileService().getUserProfile(userId);
      if (userProfile != null) {
        switch (userProfile.userType) {
          case 'vendor':
            targetTier = SubscriptionTier.vendorPro;
            break;
          case 'market_organizer':
            targetTier = SubscriptionTier.marketOrganizerPro;
            break;
          case 'shopper':
            targetTier = SubscriptionTier.shopperPro;
            break;
          default:
            targetTier = SubscriptionTier.vendorPro; // Default fallback
        }
      } else {
        // If we can't get user profile, use the subscription's current tier if it's not free
        targetTier = subscription.tier == SubscriptionTier.free 
            ? SubscriptionTier.vendorPro  // Default to vendor pro
            : subscription.tier;
      }
      
      debugPrint('🎯 Upgrading to tier: ${targetTier.name} for user type: ${userProfile?.userType}');
      
      // Upgrade the subscription using the proper method
      await SubscriptionService.upgradeToTier(
        userId,
        targetTier,
        stripeSubscriptionId: stripeSubscriptionId,
      );
      
      // Also update the user profile with premium status
      debugPrint('📝 Updating user profile with premium status...');
      await UserProfileService().updateUserProfileFields(
        userId,
        {
          'isPremium': true,
          'subscriptionStatus': targetTier.name,
          'stripeSubscriptionId': stripeSubscriptionId,
          'subscriptionStartDate': Timestamp.fromDate(DateTime.now()),
        },
      );
      
      debugPrint('✅ User subscription activated successfully');
      debugPrint('🎉 Secure subscription success process complete');
      
      return true;
    } catch (e) {
      debugPrint('❌ Error in secure subscription success handler: $e');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Process successful subscription with secure validation
  /// 
  /// This replaces the old method that had test vulnerabilities
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
        // Get the updated subscription
        final subscription = await SubscriptionService.getUserSubscription(userId);
        
        return {
          'success': true,
          'subscription': subscription,
          'message': 'Subscription processed successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to process subscription - invalid session',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception during secure subscription processing: $e');
      return {
        'success': false,
        'error': 'Subscription processing failed',
      };
    }
  }

  /// Parse user ID from success URL (utility method)
  static String? parseUserIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['user_id'];
    } catch (e) {
      debugPrint('❌ Error parsing user ID from URL: $e');
      return null;
    }
  }

  /// Parse session ID from success URL (utility method)
  static String? parseSessionIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['session_id'];
    } catch (e) {
      debugPrint('❌ Error parsing session ID from URL: $e');
      return null;
    }
  }

  /// Check if user has premium access (secure convenience method)
  static Future<bool> checkPremiumAccess(String userId) async {
    try {
      final subscription = await SubscriptionService.getUserSubscription(userId);
      return subscription?.isPremium == true && subscription?.isActive == true;
    } catch (e) {
      debugPrint('❌ Error checking premium access: $e');
      return false;
    }
  }

  /// Validate subscription session before processing
  /// 
  /// 🔒 SECURITY: Always use server-side validation
  static Future<bool> validateSessionBeforeProcessing({
    required String sessionId,
    required String userId,
  }) async {
    try {
      // Basic format validation
      if (!sessionId.startsWith('cs_')) {
        debugPrint('❌ Invalid session ID format');
        return false;
      }
      
      if (userId.isEmpty) {
        debugPrint('❌ Empty user ID provided');
        return false;
      }
      
      // Server-side validation
      final callable = FirebaseFunctions.instance.httpsCallable('verifySubscriptionSession');
      final result = await callable.call({
        'sessionId': sessionId,
        'userId': userId,
      });
      
      return result.data['valid'] as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Error validating session: $e');
      return false;
    }
  }
}