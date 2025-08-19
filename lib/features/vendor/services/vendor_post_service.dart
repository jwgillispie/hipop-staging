import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_post.dart';
import '../models/post_type.dart';
import '../../organizer/models/approval_request.dart';
import '../../shared/services/user_profile_service.dart';
import '../../market/models/market.dart';
import 'vendor_monthly_tracking_service.dart';

/// Service for creating and managing vendor posts with unified post-approval workflow
class VendorPostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _postsCollection = 'vendor_posts';
  static const String _queueCollection = 'market_approval_queue';

  /// Create a new vendor post with unified workflow
  static Future<VendorPost> createVendorPost({
    required VendorPostData postData,
    required PostType postType,
    Market? selectedMarket,
  }) async {
    final vendorId = FirebaseAuth.instance.currentUser!.uid;
    
    // 1. Check monthly limits for free tier
    final canCreate = await VendorMonthlyTrackingService.canCreatePost(vendorId);
    if (!canCreate) {
      throw PostLimitException('Monthly limit reached. Upgrade to Premium for unlimited posts.');
    }
    
    // 2. Get vendor profile for embedded data
    final userProfileService = UserProfileService();
    final vendor = await userProfileService.getUserProfile(vendorId);
    if (vendor == null) {
      throw VendorProfileException('Vendor profile not found');
    }
    
    // 3. Validate market selection
    if (postType == PostType.market && selectedMarket == null) {
      throw ValidationException('Market must be selected for market posts');
    }
    
    // 4. Prepare post document
    final postId = _firestore.collection(_postsCollection).doc().id;
    final now = DateTime.now();
    final tracking = await VendorMonthlyTrackingService.getOrCreateMonthlyTracking(vendorId);
    final monthlyPostNumber = tracking.totalPosts + 1;
    
    final post = VendorPost(
      id: postId,
      vendorId: vendorId,
      vendorName: vendor.businessName ?? vendor.displayName ?? 'Vendor',
      description: postData.description,
      location: postData.location,
      locationKeywords: VendorPost.generateLocationKeywords(postData.location),
      latitude: postData.latitude,
      longitude: postData.longitude,
      placeId: postData.placeId,
      locationName: postData.locationName,
      productListIds: postData.productListIds,
      popUpStartDateTime: postData.popUpStartDateTime,
      popUpEndDateTime: postData.popUpEndDateTime,
      photoUrls: postData.photoUrls,
      createdAt: now,
      updatedAt: now,
      isActive: true, // Changed: All posts are active immediately
      // NEW FIELDS
      postType: postType,
      associatedMarketId: selectedMarket?.id,
      associatedMarketName: selectedMarket?.name,
      associatedMarketLogo: selectedMarket?.imageUrl,
      approvalStatus: postType == PostType.market ? ApprovalStatus.approved : null, // Changed: Market posts are approved immediately
      approvalRequestedAt: postType == PostType.market ? now : null,
      approvalDecidedAt: postType == PostType.market ? now : null, // Changed: Set approval decision time immediately
      approvedBy: postType == PostType.market ? 'system_auto_approval' : null, // Changed: Mark as system auto-approved
      approvalExpiresAt: null, // Changed: No expiration since auto-approved
      vendorNotes: postData.vendorNotes,
      monthlyPostNumber: monthlyPostNumber,
      countsTowardLimit: true,
      version: 2,
    );
    
    // 5. Execute in transaction
    await _firestore.runTransaction((transaction) async {
      // Create the post
      transaction.set(
        _firestore.collection(_postsCollection).doc(postId), 
        post.toFirestore(),
      );
      
      // Market posts no longer need approval queue - they're auto-approved
      // Automatically add vendor to market's vendor list for management visibility
      if (postType == PostType.market && selectedMarket != null) {
        await _addVendorToMarketAutomatically(vendorId, selectedMarket.id, vendor);
      }
      
      // Monthly tracking will be handled after transaction completes
    });
    
    // 6. Update monthly tracking after successful transaction
    await VendorMonthlyTrackingService.incrementPostCount(
      vendorId,
      postType,
      date: now,
      postId: postId,
    );
    
    // 7. Market posts are auto-approved - no notification needed for approval requests
    if (postType == PostType.market && selectedMarket != null) {
      debugPrint('✅ Market post auto-approved for market: ${selectedMarket.name}');
    }
    
    debugPrint('✅ Created ${postType.value} post: $postId');
    return post;
  }

  /// Automatically add vendor to market's vendor list when they create a market post
  static Future<void> _addVendorToMarketAutomatically(
    String vendorId, 
    String marketId, 
    dynamic vendorProfile,
  ) async {
    try {
      // Check if vendor is already in the market's vendor list
      final vendorListQuery = await _firestore
          .collection('vendor_market_relationships')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (vendorListQuery.docs.isNotEmpty) {
        debugPrint('Vendor $vendorId already in market $marketId vendor list');
        return;
      }
      
      // Create vendor-market relationship for management purposes
      await _firestore.collection('vendor_market_relationships').add({
        'vendorId': vendorId,
        'marketId': marketId,
        'vendorName': vendorProfile.businessName ?? vendorProfile.displayName ?? 'Vendor',
        'vendorEmail': vendorProfile.email,
        'relationshipType': 'auto_added_via_post',
        'isActive': true,
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'system_auto_approval',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': 'Automatically added when vendor created market post',
      });
      
      debugPrint('✅ Automatically added vendor $vendorId to market $marketId');
    } catch (e) {
      debugPrint('❌ Error auto-adding vendor to market: $e');
      // Don't rethrow - this shouldn't block post creation
    }
  }
  
  /// Get approved vendors for a market on a specific date
  static Stream<List<VendorPost>> getApprovedMarketVendors(String marketId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _firestore
        .collection(_postsCollection)
        .where('associatedMarketId', isEqualTo: marketId)
        .where('approvalStatus', isEqualTo: 'approved')
        .where('popUpStartDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('popUpStartDateTime', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList());
  }
  
  /// Get vendor's posts with approval status
  static Stream<List<VendorPost>> getVendorPostsWithStatus(String vendorId) {
    return _firestore
        .collection(_postsCollection)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList());
  }
  
  /// Get vendor's remaining posts for current month
  static Future<int> getRemainingPosts(String vendorId) async {
    return await VendorMonthlyTrackingService.getRemainingPosts(vendorId);
  }
  
  /// Get vendor's monthly tracking info
  static Future<VendorMonthlyTracking?> getMonthlyTracking(String vendorId, {DateTime? date}) async {
    return await VendorMonthlyTrackingService.getOrCreateMonthlyTracking(vendorId, date: date);
  }
  
  /// Update an existing vendor post
  static Future<void> updateVendorPost(VendorPost post) async {
    try {
      final updatedPost = post.copyWith(
        updatedAt: DateTime.now(),
        locationKeywords: VendorPost.generateLocationKeywords(post.location),
      );
      
      await _firestore
          .collection(_postsCollection)
          .doc(post.id)
          .update(updatedPost.toFirestore());
          
      debugPrint('✅ Updated vendor post: ${post.id}');
    } catch (e) {
      debugPrint('❌ Error updating vendor post: $e');
      rethrow;
    }
  }
  
  /// Delete a vendor post and update tracking
  static Future<void> deleteVendorPost(String postId) async {
    try {
      // Get post data before deletion for tracking purposes
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!postDoc.exists) {
        throw PostNotFoundException('Post not found: $postId');
      }
      
      final postData = postDoc.data()!;
      final vendorId = postData['vendorId'] as String;
      final createdAt = (postData['createdAt'] as Timestamp).toDate();
      final postTypeStr = postData['postType'] as String? ?? 'independent';
      final postType = PostType.fromString(postTypeStr);
      
      // Execute deletion in transaction
      await _firestore.runTransaction((transaction) async {
        // Delete the post
        transaction.delete(postDoc.reference);
        
        // Delete from approval queue if exists
        final queueQuery = await _firestore
            .collection(_queueCollection)
            .where('vendorPostId', isEqualTo: postId)
            .get();
        
        for (final queueDoc in queueQuery.docs) {
          transaction.delete(queueDoc.reference);
        }
      });
      
      // Update tracking after successful deletion
      if (createdAt.year == DateTime.now().year && createdAt.month == DateTime.now().month) {
        await VendorMonthlyTrackingService.decrementPostCount(
          vendorId,
          postType,
          date: createdAt,
          postId: postId,
        );
      }
      
      debugPrint('✅ Deleted vendor post: $postId');
    } catch (e) {
      debugPrint('❌ Error deleting vendor post: $e');
      rethrow;
    }
  }
}

/// Data class for vendor post creation
class VendorPostData {
  final String description;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? locationName;
  final List<String> productListIds;
  final DateTime popUpStartDateTime;
  final DateTime popUpEndDateTime;
  final List<String> photoUrls;
  final String? vendorNotes;

  const VendorPostData({
    required this.description,
    required this.location,
    this.latitude,
    this.longitude,
    this.placeId,
    this.locationName,
    this.productListIds = const [],
    required this.popUpStartDateTime,
    required this.popUpEndDateTime,
    this.photoUrls = const [],
    this.vendorNotes,
  });
}

/// Custom exceptions
class PostLimitException implements Exception {
  final String message;
  PostLimitException(this.message);
  @override
  String toString() => message;
}

class VendorProfileException implements Exception {
  final String message;
  VendorProfileException(this.message);
  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

class PostNotFoundException implements Exception {
  final String message;
  PostNotFoundException(this.message);
  @override
  String toString() => message;
}