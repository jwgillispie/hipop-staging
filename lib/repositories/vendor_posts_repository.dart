import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../features/vendor/models/vendor_post.dart';

// Helper class for proximity search
class _PostWithDistance {
  final VendorPost post;
  final double distance;
  
  _PostWithDistance({required this.post, required this.distance});
}

abstract class IVendorPostsRepository {
  Stream<List<VendorPost>> getVendorPosts(String vendorId);
  Stream<List<VendorPost>> getAllActivePosts();
  Stream<List<VendorPost>> getMarketPosts(String marketId);
  Stream<List<VendorPost>> getPendingMarketPosts(String marketId);
  Stream<List<VendorPost>> searchPostsByLocation(String location);
  Stream<List<VendorPost>> searchPostsByLocationAndProximity({
    required String location,
    required double latitude,
    required double longitude,
    required double radiusKm,
  });
  Future<String> createPost(VendorPost post);
  Future<void> updatePost(VendorPost post);
  Future<void> deletePost(String postId);
  Future<VendorPost?> getPost(String postId);
  Future<void> approvePost(String postId, String approvedBy);
  Future<void> denyPost(String postId, String deniedBy, String? reason);
}

class VendorPostsRepository implements IVendorPostsRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'vendor_posts';

  VendorPostsRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<VendorPost>> getVendorPosts(String vendorId) {
    return _firestore
        .collection(_collection)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('popUpStartDateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<VendorPost>> getAllActivePosts() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final posts = <VendorPost>[];
          
          for (final doc in snapshot.docs) {
            try {
              final post = VendorPost.fromFirestore(doc);
              // All active posts are included - market posts are auto-approved
              posts.add(post);
            } catch (e) {
              debugPrint('Failed to parse vendor post ${doc.id}: $e');
            }
          }
          
          // Sort in memory by start time (latest first)
          posts.sort((a, b) => b.popUpStartDateTime.compareTo(a.popUpStartDateTime));
          
          return posts;
        });
  }

  @override
  Stream<List<VendorPost>> getMarketPosts(String marketId) {
    return _firestore
        .collection(_collection)
        .where('associatedMarketId', isEqualTo: marketId) // Updated to use new field
        .where('isActive', isEqualTo: true) // Only show active posts
        .snapshots()
        .map((snapshot) {
          final posts = <VendorPost>[];
          
          for (final doc in snapshot.docs) {
            try {
              final post = VendorPost.fromFirestore(doc);
              posts.add(post);
            } catch (e) {
              debugPrint('Failed to parse post ${doc.id}: $e');
            }
          }
          
          // Sort in memory by start time (earliest first)
          posts.sort((a, b) => a.popUpStartDateTime.compareTo(b.popUpStartDateTime));
          
          return posts;
        });
  }

  @override
  Stream<List<VendorPost>> searchPostsByLocation(String location) {
    if (location.isEmpty) {
      return getAllActivePosts();
    }

    final searchKeyword = location.toLowerCase().trim();
    debugPrint('VendorPostsRepository: Searching for location: "$location" -> "$searchKeyword"');
    
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final allPosts = snapshot.docs
              .map((doc) => VendorPost.fromFirestore(doc))
              .toList();
          
          debugPrint('VendorPostsRepository: Total active posts: ${allPosts.length}');
          
          // Filter by location using optimized locationData fields for faster searches
          final filteredPosts = allPosts.where((post) {
            // First check optimized location data if available (new posts)
            if (post.locationData != null) {
              final locationData = post.locationData!;
              
              // Direct city match (fastest and most accurate)
              if (locationData.city != null) {
                final cityLower = locationData.city!.toLowerCase();
                if (cityLower == searchKeyword || 
                    cityLower.contains(searchKeyword) ||
                    searchKeyword.contains(cityLower)) {
                  return true;
                }
              }
              
              // Metro area match (broader geographic search)
              if (locationData.metroArea != null) {
                final metroLower = locationData.metroArea!.toLowerCase();
                if (metroLower.contains(searchKeyword) ||
                    searchKeyword.contains(metroLower)) {
                  return true;
                }
              }
              
              // Search keywords match (pre-computed for efficiency)
              if (locationData.searchKeywords.any((keyword) => 
                  keyword.toLowerCase().contains(searchKeyword) ||
                  searchKeyword.contains(keyword.toLowerCase()))) {
                return true;
              }
              
              // State match (for state-level searches)
              if (locationData.state != null) {
                final stateLower = locationData.state!.toLowerCase();
                if (stateLower == searchKeyword || 
                    (searchKeyword.length == 2 && stateLower.startsWith(searchKeyword))) {
                  return true;
                }
              }
              
              // Neighborhood match (for local area searches)
              if (locationData.neighborhood != null) {
                final neighborhoodLower = locationData.neighborhood!.toLowerCase();
                if (neighborhoodLower.contains(searchKeyword) ||
                    searchKeyword.contains(neighborhoodLower)) {
                  return true;
                }
              }
              
              return false;
            }
            
            // Fallback to legacy location search for older posts
            final locationMatch = post.location.toLowerCase().contains(searchKeyword);
            final keywordMatch = post.locationKeywords.any((keyword) => 
                keyword.toLowerCase().contains(searchKeyword));
            
            return locationMatch || keywordMatch;
          }).toList();
          
          debugPrint('VendorPostsRepository: Filtered to ${filteredPosts.length} posts');
          
          // Sort filtered posts by start time (latest first)
          filteredPosts.sort((a, b) => b.popUpStartDateTime.compareTo(a.popUpStartDateTime));
          
          return filteredPosts;
        });
  }

  @override
  Stream<List<VendorPost>> searchPostsByLocationAndProximity({
    required String location,
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final allPosts = snapshot.docs
              .map((doc) => VendorPost.fromFirestore(doc))
              .toList();
          
          // Use optimized geohash proximity search for new posts, fallback for older posts
          final postsWithDistance = allPosts
              .where((post) {
                // Check if we have coordinates (required for proximity)
                if (post.locationData?.coordinates != null) {
                  return true;
                } else if (post.latitude != null && post.longitude != null) {
                  return true;
                }
                return false;
              })
              .map((post) {
                double postLat, postLon;
                
                // Use optimized coordinates if available
                if (post.locationData?.coordinates != null) {
                  postLat = post.locationData!.coordinates!.latitude;
                  postLon = post.locationData!.coordinates!.longitude;
                } else {
                  postLat = post.latitude!;
                  postLon = post.longitude!;
                }
                
                final distance = _calculateDistance(
                  latitude, longitude,
                  postLat, postLon,
                );
                return _PostWithDistance(post: post, distance: distance);
              })
              .where((postWithDistance) => postWithDistance.distance <= radiusKm)
              .toList();
          
          // Sort by distance (closest first)
          postsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
          
          return postsWithDistance.map((pwd) => pwd.post).toList();
        });
  }
  
  /// Enhanced geohash-based proximity search for optimized location data
  Stream<List<VendorPost>> searchPostsByGeohash({
    required String geohash,
    required double radiusKm,
    required double centerLat,
    required double centerLon,
  }) {
    // Get geohash neighbors for broader search
    final searchHashes = _getGeohashNeighbors(geohash);
    
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final allPosts = snapshot.docs
              .map((doc) => VendorPost.fromFirestore(doc))
              .toList();
          
          // Filter by geohash for posts with optimized location data
          final nearbyPosts = allPosts.where((post) {
            if (post.locationData?.geohash != null) {
              // Use geohash for fast initial filtering
              return searchHashes.any((searchHash) => 
                post.locationData!.geohash!.startsWith(searchHash));
            }
            return false;
          }).toList();
          
          // Calculate exact distances and filter by radius
          final postsWithDistance = nearbyPosts
              .where((post) => post.locationData?.coordinates != null)
              .map((post) {
                final coords = post.locationData!.coordinates!;
                final distance = _calculateDistance(
                  centerLat, centerLon,
                  coords.latitude, coords.longitude,
                );
                return _PostWithDistance(post: post, distance: distance);
              })
              .where((pwd) => pwd.distance <= radiusKm)
              .toList();
          
          // Sort by distance
          postsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
          
          return postsWithDistance.map((pwd) => pwd.post).toList();
        });
  }
  
  /// Get geohash neighbors for proximity search
  List<String> _getGeohashNeighbors(String geohash) {
    if (geohash.isEmpty) return [];
    
    // Return progressively shorter geohashes for broader search
    final neighbors = <String>[geohash];
    
    // Add shorter geohashes for expanding search area
    for (int i = geohash.length - 1; i >= 4; i--) {
      neighbors.add(geohash.substring(0, i));
    }
    
    return neighbors;
  }

  // Helper method to calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  @override
  Future<String> createPost(VendorPost post) async {
    try {
      final postWithKeywords = post.copyWith(
        locationKeywords: VendorPost.generateLocationKeywords(post.location),
      );
      final docRef = await _firestore.collection(_collection).add(postWithKeywords.toFirestore());
      
      // Track monthly post count for ALL post types (free vendors limited to 3 total per month)
      await _updateVendorPostCount(post.vendorId);
      
      return docRef.id;
    } catch (e) {
      throw VendorPostException('Failed to create post: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePost(VendorPost post) async {
    try {
      final postWithKeywords = post.copyWith(
        locationKeywords: VendorPost.generateLocationKeywords(post.location),
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection(_collection)
          .doc(post.id)
          .update(postWithKeywords.toFirestore());
    } catch (e) {
      throw VendorPostException('Failed to update post: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).delete();
    } catch (e) {
      throw VendorPostException('Failed to delete post: ${e.toString()}');
    }
  }

  @override
  Future<VendorPost?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(postId).get();
      
      if (doc.exists) {
        return VendorPost.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw VendorPostException('Failed to get post: ${e.toString()}');
    }
  }

  Future<List<VendorPost>> searchPosts({
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('popUpStartDateTime', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('popUpEndDateTime', 
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('popUpStartDateTime');
      
      // Add pagination support
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      query = query.limit(limit);

      final snapshot = await query.get();
      List<VendorPost> posts = snapshot.docs
          .map((doc) => VendorPost.fromFirestore(doc))
          .toList();

      // Filter by location on client side since Firestore doesn't support
      // complex text search
      if (location != null && location.isNotEmpty) {
        posts = posts.where((post) => 
            post.location.toLowerCase().contains(location.toLowerCase())
        ).toList();
      }

      return posts;
    } catch (e) {
      throw VendorPostException('Failed to search posts: ${e.toString()}');
    }
  }
  
  /// Get paginated vendor posts
  Stream<List<VendorPost>> getVendorPostsPaginated(
    String vendorId, {
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('popUpStartDateTime', descending: false);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    return query.limit(pageSize).snapshots().map((snapshot) => 
        snapshot.docs.map((doc) => VendorPost.fromFirestore(doc)).toList());
  }

  Future<List<VendorPost>> getPostsNearLocation({
    required double latitude,
    required double longitude,
    required double radiusInKm,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Note: This is a simplified proximity search
      // For production, consider using GeoFlutterFire or similar
      Query query = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('latitude', isNotEqualTo: null)
          .where('longitude', isNotEqualTo: null);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final snapshot = await query.limit(limit * 2).get(); // Get more to filter

      final posts = snapshot.docs
          .map((doc) => VendorPost.fromFirestore(doc))
          .where((post) {
            if (post.latitude == null || post.longitude == null) return false;
            
            final distance = _calculateDistance(
              latitude, longitude, 
              post.latitude!, post.longitude!
            );
            
            return distance <= radiusInKm;
          })
          .take(limit)
          .toList();

      return posts;
    } catch (e) {
      throw VendorPostException('Failed to get nearby posts: ${e.toString()}');
    }
  }


  // Migration function to update existing posts with location keywords
  Future<void> migratePostsWithLocationKeywords() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .get();

      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Check if locationKeywords field is missing or empty
        if (!data.containsKey('locationKeywords') || 
            data['locationKeywords'] == null || 
            (data['locationKeywords'] is List && (data['locationKeywords'] as List).isEmpty)) {
          
          final location = data['location'] ?? '';
          if (location.isNotEmpty) {
            final keywords = VendorPost.generateLocationKeywords(location);
            batch.update(doc.reference, {'locationKeywords': keywords});
            updateCount++;
          }
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint('Migration completed: Updated $updateCount posts with location keywords');
      }
    } catch (e) {
      debugPrint('Migration failed: ${e.toString()}');
      throw VendorPostException('Failed to migrate posts: ${e.toString()}');
    }
  }

  // Helper method to check if migration is needed
  Future<bool> needsMigration() async {
    try {
      // Get a few posts and check if they need migration
      final snapshot = await _firestore
          .collection(_collection)
          .limit(5)
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('locationKeywords') || 
            data['locationKeywords'] == null ||
            (data['locationKeywords'] is List && (data['locationKeywords'] as List).isEmpty)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return true; // If we can't check, assume migration is needed
    }
  }

  @override
  Stream<List<VendorPost>> getPendingMarketPosts(String marketId) {
    // Market posts are auto-approved - no pending posts exist
    return Stream.value(<VendorPost>[]);
  }

  @override
  Future<void> approvePost(String postId, String approvedBy) async {
    try {
      final now = DateTime.now();
      
      // Verify post exists
      final postDoc = await _firestore.collection(_collection).doc(postId).get();
      if (!postDoc.exists) {
        throw VendorPostException('Post not found');
      }
      
      // Update the post status
      await _firestore.collection(_collection).doc(postId).update({
        'approvalStatus': 'approved',
        'approvalDecidedAt': Timestamp.fromDate(now),
        'approvedBy': approvedBy,
        'updatedAt': Timestamp.fromDate(now),
      });
      
      // Post count was already tracked during creation for market posts
      // No need to track again on approval
      
    } catch (e) {
      throw VendorPostException('Failed to approve post: ${e.toString()}');
    }
  }

  @override
  Future<void> denyPost(String postId, String deniedBy, String? reason) async {
    try {
      final now = DateTime.now();
      await _firestore.collection(_collection).doc(postId).update({
        'approvalStatus': 'denied',
        'approvalDecidedAt': Timestamp.fromDate(now),
        'approvedBy': deniedBy,
        'approvalNote': reason,
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      throw VendorPostException('Failed to deny post: ${e.toString()}');
    }
  }

  /// Update user's monthly post count (for free tier tracking - vendors and organizers)
  Future<void> _updateVendorPostCount(String userId) async {
    try {
      // Check if user is premium first (works for both vendors and organizers)
      final userDoc = await _firestore.collection('user_profiles').doc(userId).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final isPremium = userData['isPremium'] ?? false;
      
      // Skip counting for premium users
      if (isPremium) return;
      
      // Get or create user stats document (unified for vendors and organizers)
      final statsRef = _firestore.collection('user_stats').doc(userId);
      final statsDoc = await statsRef.get();
      
      final currentMonth = _getCurrentMonth();
      
      if (statsDoc.exists) {
        final data = statsDoc.data()!;
        final lastMonth = data['currentCountMonth'] as String?;
        
        if (lastMonth == currentMonth) {
          // Same month - increment count
          await statsRef.update({
            'monthlyPostCount': FieldValue.increment(1),
            'lastPostCreatedAt': Timestamp.fromDate(DateTime.now()),
          });
        } else {
          // New month - reset count to 1
          await statsRef.update({
            'monthlyPostCount': 1,
            'currentCountMonth': currentMonth,
            'lastPostCreatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      } else {
        // Create new stats document
        await statsRef.set({
          'userId': userId,
          'monthlyPostCount': 1,
          'currentCountMonth': currentMonth,
          'lastPostCreatedAt': Timestamp.fromDate(DateTime.now()),
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Error updating vendor post count: $e');
      // Don't throw - this shouldn't block the approval
    }
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

}

class VendorPostException implements Exception {
  final String message;
  
  VendorPostException(this.message);
  
  @override
  String toString() => message;
}