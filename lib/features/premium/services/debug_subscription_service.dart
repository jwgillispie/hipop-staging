import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'revenuecat_service.dart';

/// Debug service to help troubleshoot subscription sync issues
class DebugSubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check subscription status across all systems
  static Future<void> debugSubscriptionStatus([String? userId]) async {
    final targetUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUserId == null) {
      debugPrint('❌ No user ID provided and no current user');
      return;
    }
    
    debugPrint('\n🔍 === DEBUGGING SUBSCRIPTION STATUS ===');
    debugPrint('🆔 User ID: $targetUserId');
    
    try {
      // 1. Check RevenueCat status
      debugPrint('\n1️⃣ === REVENUECAT STATUS ===');
      final revenueCatService = RevenueCatService();
      final customerInfo = await revenueCatService.getCustomerInfo();
      
      if (customerInfo != null) {
        debugPrint('✅ RevenueCat customer info available');
        debugPrint('👤 RevenueCat user ID: ${customerInfo.originalAppUserId}');
        debugPrint('📋 Active entitlements: ${customerInfo.entitlements.active.keys}');
        debugPrint('📋 All entitlements: ${customerInfo.entitlements.all.keys}');
        debugPrint('🔐 Is premium: ${revenueCatService.isPremium}');
        debugPrint('🎫 Expected entitlement ID: ${revenueCatService.entitlementId}');
        
        final expectedEntitlement = customerInfo.entitlements.active[revenueCatService.entitlementId];
        if (expectedEntitlement != null) {
          debugPrint('✅ Target entitlement found: ${expectedEntitlement.productIdentifier}');
          debugPrint('📅 Expiration: ${expectedEntitlement.expirationDate}');
          debugPrint('🔒 Is active: ${expectedEntitlement.isActive}');
        } else {
          debugPrint('❌ Target entitlement not found in active entitlements');
        }
      } else {
        debugPrint('❌ No RevenueCat customer info available');
      }
      
      // 2. Check Firebase user profile
      debugPrint('\n2️⃣ === FIREBASE USER PROFILE ===');
      final userProfile = await _firestore.collection('userProfiles').doc(targetUserId).get();
      
      if (userProfile.exists) {
        final data = userProfile.data()!;
        debugPrint('✅ User profile found');
        debugPrint('🔐 isPremium: ${data['isPremium']}');
        debugPrint('📊 subscriptionStatus: ${data['subscriptionStatus']}');
        debugPrint('🏷️ subscriptionTier: ${data['subscriptionTier']}');
        debugPrint('💳 paymentProvider: ${data['paymentProvider']}');
        debugPrint('🆔 revenueCatUserId: ${data['revenueCatUserId']}');
        debugPrint('📦 revenueCatProductId: ${data['revenueCatProductId']}');
        debugPrint('📅 subscriptionStartDate: ${data['subscriptionStartDate']}');
        debugPrint('📅 subscriptionEndDate: ${data['subscriptionEndDate']}');
        debugPrint('🕒 updatedAt: ${data['updatedAt']}');
        debugPrint('👤 isVendor: ${data['isVendor']}');
        debugPrint('🏪 isMarketOrganizer: ${data['isMarketOrganizer']}');
      } else {
        debugPrint('❌ User profile not found');
      }
      
      // 3. Check user subscriptions collection
      debugPrint('\n3️⃣ === USER SUBSCRIPTIONS COLLECTION ===');
      final subscriptionsQuery = await _firestore
          .collection('user_subscriptions')
          .where('userId', isEqualTo: targetUserId)
          .get();
          
      if (subscriptionsQuery.docs.isNotEmpty) {
        debugPrint('✅ Found ${subscriptionsQuery.docs.length} subscription documents');
        for (final doc in subscriptionsQuery.docs) {
          final data = doc.data();
          debugPrint('📄 Document ID: ${doc.id}');
          debugPrint('  - tier: ${data['tier']}');
          debugPrint('  - status: ${data['status']}');
          debugPrint('  - isActive: ${data['isActive']}');
          debugPrint('  - productIdentifier: ${data['productIdentifier']}');
          debugPrint('  - revenuecatUserId: ${data['revenuecatUserId']}');
          debugPrint('  - updatedAt: ${data['updatedAt']}');
          debugPrint('  - createdAt: ${data['createdAt']}');
        }
      } else {
        debugPrint('❌ No subscription documents found');
      }
      
      // 4. Check recent subscription events
      debugPrint('\n4️⃣ === RECENT SUBSCRIPTION EVENTS ===');
      final eventsQuery = await _firestore
          .collection('subscription_events')
          .where('userId', isEqualTo: targetUserId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
          
      if (eventsQuery.docs.isNotEmpty) {
        debugPrint('✅ Found ${eventsQuery.docs.length} recent events');
        for (final doc in eventsQuery.docs) {
          final data = doc.data();
          debugPrint('📝 ${data['event']} - ${data['timestamp']} (${data['source']})');
        }
      } else {
        debugPrint('❌ No subscription events found');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error during debug: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
    
    debugPrint('🔍 === END DEBUGGING ===\n');
  }
  
  /// Force sync subscription from RevenueCat to Firebase
  static Future<void> forceSyncSubscription([String? userId]) async {
    final targetUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUserId == null) {
      debugPrint('❌ No user ID provided and no current user');
      return;
    }
    
    debugPrint('\n🔧 === FORCE SYNCING SUBSCRIPTION ===');
    debugPrint('🆔 Target user: $targetUserId');
    
    try {
      await RevenueCatService().forceSyncToFirebase();
      debugPrint('✅ Force sync completed');
      
      // Wait a moment and check status again
      await Future.delayed(const Duration(seconds: 1));
      await debugSubscriptionStatus(targetUserId);
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error during force sync: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
    
    debugPrint('🔧 === END FORCE SYNC ===\n');
  }
  
  /// Check if the entitlement ID matches what we expect
  static Future<void> checkEntitlementConfiguration() async {
    debugPrint('\n⚙️ === CHECKING ENTITLEMENT CONFIGURATION ===');
    
    final service = RevenueCatService();
    debugPrint('🎫 Expected entitlement ID: ${service.entitlementId}');
    debugPrint('🏪 Vendor offering ID: ${service.vendorOfferingId}');
    debugPrint('🏬 Organizer offering ID: ${service.organizerOfferingId}');
    
    try {
      final customerInfo = await service.getCustomerInfo();
      if (customerInfo != null) {
        debugPrint('📋 Available entitlements:');
        for (final entitlement in customerInfo.entitlements.all.entries) {
          debugPrint('  - ${entitlement.key}: ${entitlement.value.productIdentifier}');
        }
        
        debugPrint('🔍 Active entitlements:');
        for (final entitlement in customerInfo.entitlements.active.entries) {
          debugPrint('  - ${entitlement.key}: ${entitlement.value.productIdentifier} (expires: ${entitlement.value.expirationDate})');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking entitlements: $e');
    }
    
    debugPrint('⚙️ === END ENTITLEMENT CHECK ===\n');
  }
}