import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_post.dart';
import '../models/post_type.dart';
import '../../organizer/models/approval_request.dart';
import '../../shared/services/user_profile_service.dart';
import '../../shared/services/location_data_service.dart';
import '../../market/models/market.dart';
import '../models/managed_vendor.dart';
import '../services/managed_vendor_service.dart';
import '../../market/services/market_service.dart';
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
    
    // 4.1. Create optimized location data for new posts
    final locationData = LocationDataService.createLocationData(
      locationString: postData.location,
      latitude: postData.latitude,
      longitude: postData.longitude,
      placeId: postData.placeId,
      locationName: postData.locationName,
    );
    
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
      locationData: locationData,
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
  /// This bridges VendorPost and ManagedVendor systems
  static Future<void> _addVendorToMarketAutomatically(
    String vendorId, 
    String marketId, 
    dynamic vendorProfile,
  ) async {
    try {
      debugPrint('🔄 Starting auto-add vendor $vendorId to market $marketId');
      
      // Check if a ManagedVendor already exists for this vendor/market combination
      final existingVendors = await ManagedVendorService.getVendorsForMarketAsync(marketId);
      final existingVendor = existingVendors.where((v) => v.userProfileId == vendorId).firstOrNull;
      
      if (existingVendor != null) {
        debugPrint('✅ ManagedVendor already exists for vendor $vendorId in market $marketId');
        await _ensureVendorInMarketAssociatedIds(marketId, vendorId);
        return;
      }
      
      // Get market information for organizer context
      final market = await MarketService.getMarket(marketId);
      if (market == null) {
        debugPrint('❌ Market $marketId not found, cannot create ManagedVendor');
        return;
      }
      
      // Create a new ManagedVendor record
      final now = DateTime.now();
      final managedVendor = ManagedVendor(
        id: '', // Will be set by Firestore
        marketId: marketId,
        organizerId: 'system_auto_creation', // Mark as system-created
        userProfileId: vendorId, // Link to the vendor's UserProfile
        businessName: vendorProfile.businessName ?? vendorProfile.displayName ?? 'Vendor',
        vendorName: vendorProfile.displayName,
        contactName: vendorProfile.displayName ?? 'Vendor',
        description: vendorProfile.bio ?? 'Auto-created from vendor post',
        categories: _mapCategoriesToVendorCategories(vendorProfile.categories),
        email: vendorProfile.email,
        phoneNumber: vendorProfile.phoneNumber,
        website: vendorProfile.website,
        instagramHandle: vendorProfile.instagramHandle,
        products: vendorProfile.categories, // Use categories as initial products
        specificProducts: vendorProfile.specificProducts,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'autoCreated': true,
          'createdVia': 'vendor_post',
          'sourcePostType': 'market',
          'linkedUserProfileId': vendorId,
        },
      );
      
      // Create the ManagedVendor record
      final managedVendorId = await ManagedVendorService.createVendor(managedVendor);
      debugPrint('✅ Created ManagedVendor $managedVendorId for vendor $vendorId in market $marketId');
      
      // Update market's associatedVendorIds array
      await _ensureVendorInMarketAssociatedIds(marketId, vendorId);
      
      // Also create the legacy vendor-market relationship for backward compatibility
      await _createLegacyVendorMarketRelationship(vendorId, marketId, vendorProfile);
      
      debugPrint('✅ Successfully bridged VendorPost to ManagedVendor for vendor $vendorId in market $marketId');
    } catch (e) {
      debugPrint('❌ Error auto-adding vendor to market: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      // Don't rethrow - this shouldn't block post creation
    }
  }
  
  /// Map string categories to VendorCategory enum values
  static List<VendorCategory> _mapCategoriesToVendorCategories(List<String> stringCategories) {
    return stringCategories.map((categoryString) {
      final normalizedCategory = categoryString.toLowerCase().trim();
      
      // Map common category strings to VendorCategory enum values
      switch (normalizedCategory) {
        case 'produce':
        case 'fruits':
        case 'vegetables':
        case 'fresh produce':
          return VendorCategory.produce;
        case 'dairy':
        case 'milk':
        case 'cheese':
          return VendorCategory.dairy;
        case 'meat':
        case 'poultry':
        case 'beef':
        case 'chicken':
          return VendorCategory.meat;
        case 'bakery':
        case 'bread':
        case 'baked goods':
          return VendorCategory.bakery;
        case 'prepared foods':
        case 'ready to eat':
        case 'hot food':
          return VendorCategory.prepared_foods;
        case 'beverages':
        case 'drinks':
        case 'coffee':
        case 'tea':
          return VendorCategory.beverages;
        case 'flowers':
        case 'plants':
        case 'garden':
          return VendorCategory.flowers;
        case 'crafts':
        case 'handmade':
        case 'artisan':
          return VendorCategory.crafts;
        case 'skincare':
        case 'beauty':
        case 'cosmetics':
          return VendorCategory.skincare;
        case 'clothing':
        case 'apparel':
        case 'fashion':
          return VendorCategory.clothing;
        case 'jewelry':
        case 'accessories':
          return VendorCategory.jewelry;
        case 'art':
        case 'artwork':
        case 'paintings':
          return VendorCategory.art;
        case 'honey':
        case 'beekeeping':
          return VendorCategory.honey;
        case 'preserves':
        case 'jams':
        case 'jellies':
          return VendorCategory.preserves;
        case 'spices':
        case 'seasonings':
        case 'herbs':
          return VendorCategory.spices;
        default:
          return VendorCategory.other;
      }
    }).toList();
  }
  
  /// Ensure vendor is in market's associatedVendorIds array
  static Future<void> _ensureVendorInMarketAssociatedIds(String marketId, String vendorId) async {
    try {
      final marketDoc = await _firestore.collection('markets').doc(marketId).get();
      if (!marketDoc.exists) {
        debugPrint('❌ Market $marketId not found when updating associatedVendorIds');
        return;
      }
      
      final marketData = marketDoc.data() as Map<String, dynamic>;
      final currentVendorIds = List<String>.from(marketData['associatedVendorIds'] ?? []);
      
      if (!currentVendorIds.contains(vendorId)) {
        currentVendorIds.add(vendorId);
        await _firestore.collection('markets').doc(marketId).update({
          'associatedVendorIds': currentVendorIds,
        });
        debugPrint('✅ Added vendor $vendorId to market $marketId associatedVendorIds');
      } else {
        debugPrint('✅ Vendor $vendorId already in market $marketId associatedVendorIds');
      }
    } catch (e) {
      debugPrint('❌ Error updating market associatedVendorIds: $e');
    }
  }
  
  /// Create legacy vendor-market relationship for backward compatibility
  static Future<void> _createLegacyVendorMarketRelationship(
    String vendorId, 
    String marketId, 
    dynamic vendorProfile,
  ) async {
    try {
      // Check if relationship already exists
      final vendorListQuery = await _firestore
          .collection('vendor_market_relationships')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (vendorListQuery.docs.isNotEmpty) {
        debugPrint('✅ Legacy vendor-market relationship already exists');
        return;
      }
      
      // Create vendor-market relationship for backward compatibility
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
        'notes': 'Legacy relationship - auto-created when vendor created market post',
      });
      
      debugPrint('✅ Created legacy vendor-market relationship for backward compatibility');
    } catch (e) {
      debugPrint('❌ Error creating legacy vendor-market relationship: $e');
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