import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../organizer/models/approval_request.dart';
import '../../shared/services/user_profile_service.dart';
import '../models/post_type.dart';

/// Service for managing vendor monthly post tracking and limits
class VendorMonthlyTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _trackingCollection = 'vendor_monthly_tracking';
  static const int freeTierMonthlyLimit = 3;

  /// Get or create monthly tracking document for vendor
  static Future<VendorMonthlyTracking> getOrCreateMonthlyTracking(
    String vendorId, {
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(vendorId, targetDate);
    
    try {
      final doc = await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .get();
      
      if (doc.exists) {
        return VendorMonthlyTracking.fromFirestore(doc);
      }
      
      // Create new tracking document
      final userProfileService = UserProfileService();
      final vendor = await userProfileService.getUserProfile(vendorId);
      
      final newTracking = VendorMonthlyTracking(
        id: trackingId,
        vendorId: vendorId,
        yearMonth: '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}',
        posts: const {
          'total': 0,
          'independent': 0,
          'market': 0,
          'denied': 0,
        },
        postIds: const [],
        lastPostDate: targetDate,
        subscriptionTier: vendor?.subscriptionStatus ?? 'free',
      );
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .set(newTracking.toFirestore());
      
      debugPrint('✅ Created new monthly tracking: $trackingId');
      return newTracking;
    } catch (e) {
      debugPrint('❌ Error getting/creating monthly tracking: $e');
      rethrow;
    }
  }
  
  /// Increment post count for vendor
  static Future<void> incrementPostCount(
    String vendorId,
    PostType postType, {
    DateTime? date,
    String? postId,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(vendorId, targetDate);
    
    try {
      final updates = <String, dynamic>{
        'posts.total': FieldValue.increment(1),
        'posts.${postType.value}': FieldValue.increment(1),
        'lastPostDate': Timestamp.fromDate(targetDate),
      };
      
      if (postId != null) {
        updates['postIds'] = FieldValue.arrayUnion([postId]);
      }
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .set(updates, SetOptions(merge: true));
      
      debugPrint('✅ Incremented ${postType.value} post count for vendor: $vendorId');
    } catch (e) {
      debugPrint('❌ Error incrementing post count: $e');
      rethrow;
    }
  }
  
  /// Decrement post count for vendor (used when posts are deleted or denied)
  static Future<void> decrementPostCount(
    String vendorId,
    PostType postType, {
    DateTime? date,
    String? postId,
    bool wasDenied = false,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(vendorId, targetDate);
    
    try {
      final updates = <String, dynamic>{
        'posts.total': FieldValue.increment(-1),
        'posts.${postType.value}': FieldValue.increment(-1),
      };
      
      if (wasDenied) {
        updates['posts.denied'] = FieldValue.increment(1);
      }
      
      if (postId != null) {
        updates['postIds'] = FieldValue.arrayRemove([postId]);
      }
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .update(updates);
      
      debugPrint('✅ Decremented ${postType.value} post count for vendor: $vendorId${wasDenied ? ' (denied)' : ''}');
    } catch (e) {
      debugPrint('❌ Error decrementing post count: $e');
      rethrow;
    }
  }
  
  /// Check if vendor can create more posts this month
  static Future<bool> canCreatePost(String vendorId) async {
    try {
      // Check if user has premium subscription
      final userProfileService = UserProfileService();
      final hasPremium = await userProfileService.hasPremiumAccess(vendorId);
      if (hasPremium) return true;
      
      final tracking = await getOrCreateMonthlyTracking(vendorId);
      final currentCount = tracking.totalPosts;
      
      debugPrint('📊 Vendor $vendorId monthly usage: $currentCount/$freeTierMonthlyLimit');
      return currentCount < freeTierMonthlyLimit;
    } catch (e) {
      debugPrint('❌ Error checking post limit: $e');
      return true; // Default to allowing if check fails
    }
  }
  
  /// Get remaining posts for free tier vendor
  static Future<int> getRemainingPosts(String vendorId) async {
    try {
      final userProfileService = UserProfileService();
      final hasPremium = await userProfileService.hasPremiumAccess(vendorId);
      if (hasPremium) return -1; // Unlimited for premium
      
      final tracking = await getOrCreateMonthlyTracking(vendorId);
      final remaining = freeTierMonthlyLimit - tracking.totalPosts;
      
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('❌ Error getting remaining posts: $e');
      return 0;
    }
  }
  
  /// Get vendor's monthly tracking history
  static Future<List<VendorMonthlyTracking>> getTrackingHistory(
    String vendorId, {
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final trackingDocs = <VendorMonthlyTracking>[];
      
      for (int i = 0; i < monthsBack; i++) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final trackingId = _generateTrackingId(vendorId, targetDate);
        
        final doc = await _firestore
            .collection(_trackingCollection)
            .doc(trackingId)
            .get();
        
        if (doc.exists) {
          trackingDocs.add(VendorMonthlyTracking.fromFirestore(doc));
        }
      }
      
      // Sort by year-month descending (most recent first)
      trackingDocs.sort((a, b) => b.yearMonth.compareTo(a.yearMonth));
      
      return trackingDocs;
    } catch (e) {
      debugPrint('❌ Error getting tracking history: $e');
      return [];
    }
  }
  
  /// Get tracking stats for multiple vendors (admin function)
  static Future<List<VendorMonthlyTracking>> getTrackingForMonth(
    DateTime month, {
    String? subscriptionTier,
  }) async {
    try {
      final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      
      Query query = _firestore
          .collection(_trackingCollection)
          .where('yearMonth', isEqualTo: yearMonth);
      
      if (subscriptionTier != null) {
        query = query.where('subscriptionTier', isEqualTo: subscriptionTier);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => VendorMonthlyTracking.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting month tracking: $e');
      return [];
    }
  }
  
  /// Reset monthly tracking (admin function - use carefully)
  static Future<void> resetVendorTracking(String vendorId, DateTime month) async {
    try {
      final trackingId = _generateTrackingId(vendorId, month);
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .update({
            'posts': {
              'total': 0,
              'independent': 0,
              'market': 0,
              'denied': 0,
            },
            'postIds': [],
          });
      
      debugPrint('✅ Reset tracking for vendor $vendorId for month $trackingId');
    } catch (e) {
      debugPrint('❌ Error resetting vendor tracking: $e');
      rethrow;
    }
  }
  
  /// Update subscription tier for vendor tracking
  static Future<void> updateSubscriptionTier(
    String vendorId,
    String newTier, {
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(vendorId, targetDate);
    
    try {
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .update({'subscriptionTier': newTier});
      
      debugPrint('✅ Updated subscription tier for $vendorId to $newTier');
    } catch (e) {
      debugPrint('❌ Error updating subscription tier: $e');
      rethrow;
    }
  }
  
  /// Migrate existing posts to tracking system
  static Future<void> migrateExistingPosts(String vendorId) async {
    try {
      debugPrint('🔄 Migrating existing posts for vendor: $vendorId');
      
      // Get all posts for this vendor
      final postsSnapshot = await _firestore
          .collection('vendor_posts')
          .where('vendorId', isEqualTo: vendorId)
          .get();
      
      final postsByMonth = <String, List<Map<String, dynamic>>>{};
      
      // Group posts by month
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final createdAt = (postData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        
        postsByMonth.putIfAbsent(monthKey, () => []);
        postsByMonth[monthKey]!.add({
          'id': postDoc.id,
          'postType': postData['postType'] ?? 'independent',
          'createdAt': createdAt,
        });
      }
      
      // Create tracking documents for each month
      for (final entry in postsByMonth.entries) {
        final monthKey = entry.key;
        final posts = entry.value;
        
        final trackingId = '${vendorId}_$monthKey';
        final independentCount = posts.where((p) => p['postType'] == 'independent').length;
        final marketCount = posts.where((p) => p['postType'] == 'market').length;
        
        final trackingData = {
          'vendorId': vendorId,
          'yearMonth': monthKey,
          'posts': {
            'total': posts.length,
            'independent': independentCount,
            'market': marketCount,
            'denied': 0,
          },
          'postIds': posts.map((p) => p['id']).toList(),
          'lastPostDate': Timestamp.fromDate(posts.last['createdAt']),
          'subscriptionTier': 'free', // Default for migration
        };
        
        await _firestore
            .collection(_trackingCollection)
            .doc(trackingId)
            .set(trackingData, SetOptions(merge: true));
        
        debugPrint('✅ Created tracking for $monthKey: ${posts.length} posts');
      }
      
      debugPrint('🎉 Migration completed for vendor: $vendorId');
    } catch (e) {
      debugPrint('❌ Error migrating posts: $e');
      rethrow;
    }
  }
  
  /// Generate tracking document ID
  static String _generateTrackingId(String vendorId, DateTime date) {
    return '${vendorId}_${date.year}_${date.month.toString().padLeft(2, '0')}';
  }
  
  /// Get usage statistics for analytics
  static Future<Map<String, dynamic>> getUsageStats({DateTime? month}) async {
    try {
      final targetMonth = month ?? DateTime.now();
      final yearMonth = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';
      
      final snapshot = await _firestore
          .collection(_trackingCollection)
          .where('yearMonth', isEqualTo: yearMonth)
          .get();
      
      int totalVendors = 0;
      int totalPosts = 0;
      int freeVendors = 0;
      int premiumVendors = 0;
      int overLimitVendors = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalVendors++;
        
        final posts = data['posts'] as Map<String, dynamic>? ?? {};
        final postCount = posts['total'] as int? ?? 0;
        totalPosts += postCount;
        
        final tier = data['subscriptionTier'] as String? ?? 'free';
        if (tier == 'free') {
          freeVendors++;
          if (postCount > freeTierMonthlyLimit) {
            overLimitVendors++;
          }
        } else {
          premiumVendors++;
        }
      }
      
      return {
        'month': yearMonth,
        'totalVendors': totalVendors,
        'totalPosts': totalPosts,
        'freeVendors': freeVendors,
        'premiumVendors': premiumVendors,
        'overLimitVendors': overLimitVendors,
        'averagePostsPerVendor': totalVendors > 0 ? totalPosts / totalVendors : 0,
      };
    } catch (e) {
      debugPrint('❌ Error getting usage stats: $e');
      return {};
    }
  }
}

/// Exception class for tracking-related errors
class VendorTrackingException implements Exception {
  final String message;
  VendorTrackingException(this.message);
  @override
  String toString() => message;
}