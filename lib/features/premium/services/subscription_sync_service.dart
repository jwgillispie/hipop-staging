import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'revenuecat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Service to handle subscription status synchronization between RevenueCat and Firebase
class SubscriptionSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Listen to subscription changes and update user profile accordingly
  static void startListeningToSubscriptionChanges() {
    // Listen to RevenueCat subscription status changes
    RevenueCatService().onSubscriptionStatusChanged.listen((isPremium) {
      debugPrint('📱 Subscription status changed: Premium = $isPremium');
      _updateUserPremiumStatus(isPremium);
    });
    
    // Also check on app resume (handles external changes like App Store cancellation)
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }
  
  /// Update user's premium status in Firebase
  static Future<void> _updateUserPremiumStatus(bool isPremium) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      // Update userProfiles collection
      await _firestore.collection('userProfiles').doc(userId).update({
        'isPremium': isPremium,
        'subscriptionStatus': isPremium ? 'active' : 'cancelled',
        'subscriptionTier': isPremium ? 'premium' : 'free',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Updated user profile - isPremium: $isPremium');
      
      // If cancelling, clear premium-only data
      if (!isPremium) {
        await _handleSubscriptionCancellation(userId);
      } else {
        await _handleSubscriptionActivation(userId);
      }
    } catch (e) {
      debugPrint('❌ Error updating premium status: $e');
    }
  }
  
  /// Handle subscription activation
  static Future<void> _handleSubscriptionActivation(String userId) async {
    try {
      // Log activation event
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'event': 'subscription_activated',
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'revenuecat',
      });
      
      // Grant premium features
      final userProfile = await _firestore.collection('userProfiles').doc(userId).get();
      final userData = userProfile.data();
      
      if (userData != null) {
        final isVendor = userData['isVendor'] ?? false;
        final isOrganizer = userData['isMarketOrganizer'] ?? false;
        
        // Update limits based on user type
        if (isVendor) {
          // Remove vendor limits
          await _firestore.collection('userProfiles').doc(userId).update({
            'maxMarkets': 999, // Unlimited
            'maxVendorPosts': 999, // Unlimited
            'canAccessAnalytics': true,
            'canExportData': true,
          });
        }
        
        if (isOrganizer) {
          // Remove organizer limits
          await _firestore.collection('userProfiles').doc(userId).update({
            'maxMarkets': 999, // Unlimited
            'maxEvents': 999, // Unlimited
            'maxVendors': 999, // Unlimited
            'canAccessAnalytics': true,
            'canBulkMessage': true,
            'canExportVendorData': true,
          });
        }
      }
      
      debugPrint('✅ Premium features activated for user: $userId');
    } catch (e) {
      debugPrint('❌ Error activating premium features: $e');
    }
  }
  
  /// Handle subscription cancellation
  static Future<void> _handleSubscriptionCancellation(String userId) async {
    try {
      // Log cancellation event
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'event': 'subscription_cancelled',
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'revenuecat',
      });
      
      // Revert to free tier limits
      final userProfile = await _firestore.collection('userProfiles').doc(userId).get();
      final userData = userProfile.data();
      
      if (userData != null) {
        final isVendor = userData['isVendor'] ?? false;
        final isOrganizer = userData['isMarketOrganizer'] ?? false;
        
        // Apply free tier limits
        if (isVendor) {
          await _firestore.collection('userProfiles').doc(userId).update({
            'maxMarkets': 1, // Free tier: 1 market
            'maxVendorPosts': 2, // Free tier: 2 posts/month
            'canAccessAnalytics': false,
            'canExportData': false,
          });
        }
        
        if (isOrganizer) {
          await _firestore.collection('userProfiles').doc(userId).update({
            'maxMarkets': 1, // Free tier: 1 market
            'maxEvents': 1, // Free tier: 1 event/month
            'maxVendors': 10, // Free tier: 10 vendors
            'canAccessAnalytics': false,
            'canBulkMessage': false,
            'canExportVendorData': false,
          });
        }
      }
      
      debugPrint('✅ User reverted to free tier: $userId');
      
      // Note: We don't delete their premium content, just restrict creating new
    } catch (e) {
      debugPrint('❌ Error handling cancellation: $e');
    }
  }
  
  /// Check and sync subscription status (call this on app launch)
  static Future<void> checkAndSyncSubscriptionStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      // Get latest status from RevenueCat
      final customerInfo = await RevenueCatService().getCustomerInfo();
      if (customerInfo == null) return;
      
      final isPremium = RevenueCatService().isPremium;
      
      // Get current status from Firebase
      final userProfile = await _firestore.collection('userProfiles').doc(userId).get();
      final currentIsPremium = userProfile.data()?['isPremium'] ?? false;
      
      // Sync if different
      if (currentIsPremium != isPremium) {
        debugPrint('🔄 Syncing subscription status: $currentIsPremium → $isPremium');
        await _updateUserPremiumStatus(isPremium);
      }
      
      // Also check for expired subscriptions
      if (isPremium) {
        final entitlementId = RevenueCatService().entitlementId;
        final entitlement = customerInfo.entitlements.active[entitlementId];
        
        if (entitlement != null && entitlement.expirationDate != null) {
          final expirationDate = DateTime.parse(entitlement.expirationDate!);
          final daysUntilExpiration = expirationDate.difference(DateTime.now()).inDays;
          
          if (daysUntilExpiration <= 3) {
            // Show renewal reminder
            debugPrint('⚠️ Subscription expiring in $daysUntilExpiration days');
            await _showRenewalReminder(userId, daysUntilExpiration);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking subscription status: $e');
    }
  }
  
  /// Show renewal reminder notification
  static Future<void> _showRenewalReminder(String userId, int daysRemaining) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'type': 'subscription_expiring',
      'title': 'Subscription Expiring Soon',
      'message': 'Your premium subscription will expire in $daysRemaining days. Renew to keep your premium features.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Handle subscription restoration
  static Future<bool> restoreSubscription() async {
    try {
      final customerInfo = await RevenueCatService().restorePurchases();
      
      if (customerInfo != null && customerInfo.entitlements.active.isNotEmpty) {
        // Subscription restored - sync status
        await checkAndSyncSubscriptionStatus();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error restoring subscription: $e');
      return false;
    }
  }
}

/// App lifecycle observer to check subscription on resume
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check subscription status when app resumes
      // This catches external changes like App Store cancellations
      SubscriptionSyncService.checkAndSyncSubscriptionStatus();
    }
  }
}