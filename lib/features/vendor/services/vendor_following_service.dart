import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../repositories/favorites_repository.dart';

/// Enhanced vendor following service that extends existing favorites system
/// Free users: Local favorites only (SharedPreferences)
/// Premium users: Local favorites + cloud sync for notifications & recommendations
class VendorFollowingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _followsCollection = 
      _firestore.collection('vendor_follows');

  /// Follow a vendor (uses existing favorites + premium cloud sync)
  static Future<void> followVendor({
    required String shopperId,
    required String vendorId,
    required String vendorName,
    required bool isPremium,
  }) async {
    try {
      // Always update local favorites (works for free & premium)
      final favoritesRepo = FavoritesRepository(); 
      await favoritesRepo.addFavoriteVendor(vendorId);

      // Premium users also get cloud sync for notifications & recommendations
      if (isPremium) {
        final followDoc = {
          'shopperId': shopperId,
          'vendorId': vendorId,
          'vendorName': vendorName,
          'followedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        };

        await _followsCollection
            .doc('${shopperId}_$vendorId')
            .set(followDoc, SetOptions(merge: true));

        debugPrint('✅ Vendor followed (premium): $vendorName');
      } else {
        debugPrint('✅ Vendor favorited (free): $vendorName');
      }
    } catch (e) {
      debugPrint('❌ Error following vendor: $e');
      throw Exception('Failed to follow vendor: $e');
    }
  }

  /// Unfollow a vendor (removes from local favorites + cloud)
  static Future<void> unfollowVendor({
    required String shopperId,
    required String vendorId,
    required bool isPremium,
  }) async {
    try {
      // Always remove from local favorites
      final favoritesRepo = FavoritesRepository();
      await favoritesRepo.removeFavoriteVendor(vendorId);

      // Premium users also remove from cloud
      if (isPremium) {
        await _followsCollection
            .doc('${shopperId}_$vendorId')
            .update({'isActive': false});
        debugPrint('✅ Vendor unfollowed (premium + local)');
      } else {
        debugPrint('✅ Vendor unfavorited (local only)');
      }
    } catch (e) {
      debugPrint('❌ Error unfollowing vendor: $e');
      throw Exception('Failed to unfollow vendor: $e');
    }
  }

  /// Check if shopper follows a vendor (checks local favorites)
  static Future<bool> isFollowing({
    required String shopperId,
    required String vendorId,
  }) async {
    try {
      // Check local favorites (works for both free & premium)
      final favoritesRepo = FavoritesRepository();
      return await favoritesRepo.isVendorFavorite(vendorId);
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return false;
    }
  }

  /// Get all vendors followed by a shopper (uses local favorites)
  static Future<List<Map<String, dynamic>>> getFollowedVendors(String shopperId) async {
    try {
      // Get from local favorites first
      final favoritesRepo = FavoritesRepository();
      final favoriteVendorIds = await favoritesRepo.getFavoriteVendorIds();
      
      if (favoriteVendorIds.isEmpty) {
        // Return demo data for testing when no favorites exist
        return [
          {
            'vendorId': 'demo_vendor_1',
            'vendorName': 'Local Honey Co',
            'followedAt': DateTime.now().subtract(const Duration(days: 5)),
            'businessName': 'Local Honey Co',
            'categories': ['Honey', 'Local Products'],
            'bio': 'Local raw honey and bee products from Atlanta beekeepers',
          },
          {
            'vendorId': 'demo_vendor_2',
            'vendorName': 'Fresh Garden Produce',
            'followedAt': DateTime.now().subtract(const Duration(days: 12)),
            'businessName': 'Fresh Garden Produce',
            'categories': ['Fresh Produce', 'Organic Vegetables'],
            'bio': 'Organic seasonal vegetables from local family farms',
          },
        ];
      }

      // Fetch actual vendor data from users collection
      final vendors = <Map<String, dynamic>>[];
      
      // Process vendors in batches to avoid Firestore "in" query limits
      const batchSize = 10;
      for (int i = 0; i < favoriteVendorIds.length; i += batchSize) {
        final batch = favoriteVendorIds.skip(i).take(batchSize).toList();
        
        final snapshot = await _firestore
            .collection('users')
            .where('uid', whereIn: batch)
            .where('userType', isEqualTo: 'vendor')
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          vendors.add({
            'vendorId': doc.id,
            'vendorName': data['businessName'] ?? data['displayName'] ?? 'Unknown Vendor',
            'businessName': data['businessName'] ?? data['displayName'] ?? 'Unknown Vendor',
            'followedAt': DateTime.now(), // Could be enhanced to store actual follow dates
            'categories': List<String>.from(data['categories'] ?? []),
            'bio': data['bio'] ?? '',
            'location': data['city'] ?? '',
            'profileImageUrl': data['profileImageUrl'],
          });
        }
      }
      
      return vendors;
    } catch (e) {
      debugPrint('❌ Error getting followed vendors: $e');
      // Return demo data on error for testing
      return [
        {
          'vendorId': 'demo_error_vendor',
          'vendorName': 'Demo Vendor',
          'followedAt': DateTime.now(),
          'businessName': 'Demo Vendor',
          'categories': ['Demo'],
          'bio': 'This is demo data shown when there is an error loading favorites',
        },
      ];
    }
  }

  /// Get followers count for a vendor
  static Future<int> getFollowerCount(String vendorId) async {
    try {
      final snapshot = await _followsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting follower count: $e');
      return 0;
    }
  }

  /// Stream of followed vendors for real-time updates
  static Stream<List<Map<String, dynamic>>> streamFollowedVendors(String shopperId) {
    return _followsCollection
        .where('shopperId', isEqualTo: shopperId)
        .where('isActive', isEqualTo: true)
        .orderBy('followedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'vendorId': data['vendorId'],
              'vendorName': data['vendorName'],
              'followedAt': data['followedAt'],
            };
          }).toList();
        });
  }

  /// Get vendor followers (for vendor analytics - future feature)
  static Future<List<Map<String, dynamic>>> getVendorFollowers(String vendorId) async {
    try {
      final snapshot = await _followsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .orderBy('followedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'shopperId': data['shopperId'],
          'followedAt': data['followedAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting vendor followers: $e');
      return [];
    }
  }

  /// Get recommendations based on followed vendors (basic algorithm)
  static Future<List<String>> getRecommendedVendorIds(String shopperId) async {
    try {
      // Get followed vendors
      final followedVendors = await getFollowedVendors(shopperId);
      if (followedVendors.isEmpty) return [];

      // Simple recommendation: vendors followed by users who follow similar vendors
      // This is a basic collaborative filtering approach
      final followedVendorIds = followedVendors.map((v) => v['vendorId'] as String).toList();
      
      // Find other shoppers who follow the same vendors
      final similarShoppersQuery = await _followsCollection
          .where('vendorId', whereIn: followedVendorIds.take(10).toList()) // Limit to avoid query constraints
          .where('isActive', isEqualTo: true)
          .get();

      final similarShopperIds = <String>{};
      for (final doc in similarShoppersQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final shopperId2 = data['shopperId'] as String;
        if (shopperId2 != shopperId) {
          similarShopperIds.add(shopperId2);
        }
      }

      if (similarShopperIds.isEmpty) return [];

      // Get vendors followed by similar shoppers
      final recommendedVendorsQuery = await _followsCollection
          .where('shopperId', whereIn: similarShopperIds.take(10).toList())
          .where('isActive', isEqualTo: true)
          .get();

      final recommendedVendorIds = <String>{};
      for (final doc in recommendedVendorsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vendorId = data['vendorId'] as String;
        if (!followedVendorIds.contains(vendorId)) {
          recommendedVendorIds.add(vendorId);
        }
      }

      return recommendedVendorIds.toList();
    } catch (e) {
      debugPrint('❌ Error getting recommendations: $e');
      return [];
    }
  }
}