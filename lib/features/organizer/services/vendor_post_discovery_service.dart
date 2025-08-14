import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../models/organizer_vendor_post.dart';
import '../models/organizer_vendor_post_result.dart';
import '../models/vendor_post_response.dart';
import '../../market/models/market.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/services/user_profile_service.dart';
import 'organizer_vendor_post_service.dart';

class VendorPostDiscoveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Discover organizer vendor posts relevant to a specific vendor
  static Future<List<OrganizerVendorPostResult>> discoverVendorPosts({
    String? vendorId,
    List<String>? categories,
    double? latitude,
    double? longitude,
    double maxDistance = 50.0,
    String? searchQuery,
    bool onlyActivelyRecruiting = false,
    int limit = 20,
  }) async {
    try {
      debugPrint('🔍 Starting vendor post discovery for vendor: $vendorId');

      // Get vendor profile if vendorId provided
      UserProfile? vendorProfile;
      if (vendorId != null) {
        vendorProfile = await UserProfileService().getUserProfile(vendorId);
        if (vendorProfile == null) {
          debugPrint('⚠️ Vendor profile not found for: $vendorId');
          return [];
        }
        
        // Use vendor's categories if not provided
        categories ??= vendorProfile.categories;
      }

      // Get vendor's existing responses to avoid duplicates
      final respondedPostIds = await _getVendorRespondedPosts(vendorId);

      // Search for relevant vendor posts
      final posts = await OrganizerVendorPostService.searchVendorPosts(
        categories: categories,
        searchQuery: searchQuery,
        maxDistance: maxDistance,
        latitude: latitude,
        longitude: longitude,
        onlyActive: true,
        limit: limit * 2, // Get more to filter later
      );

      // Filter out posts vendor has already responded to
      final availablePosts = posts
          .where((post) => !respondedPostIds.contains(post.id))
          .toList();

      debugPrint('📋 Found ${availablePosts.length} available posts after filtering');

      // Analyze and score posts for this vendor
      final results = <OrganizerVendorPostResult>[];
      
      for (final post in availablePosts) {
        final result = await _analyzePostForVendor(
          post,
          vendorProfile,
          latitude: latitude,
          longitude: longitude,
          searchQuery: searchQuery,
        );
        
        if (result != null && result.relevanceScore > 0) {
          results.add(result);
        }
      }

      // Sort by relevance score and other factors
      results.sort((a, b) {
        // Primary sort by relevance score
        final scoreComparison = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreComparison != 0) return scoreComparison;
        
        // Secondary sort by urgency
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        
        // Tertiary sort by distance (if available)
        if (a.distanceFromVendor != null && b.distanceFromVendor != null) {
          return a.distanceFromVendor!.compareTo(b.distanceFromVendor!);
        }
        
        // Final sort by creation date (newest first)
        return b.post.createdAt.compareTo(a.post.createdAt);
      });

      final finalResults = results.take(limit).toList();
      debugPrint('✅ Returning ${finalResults.length} vendor post discovery results');
      
      return finalResults;
    } catch (e) {
      debugPrint('❌ Error discovering vendor posts: $e');
      throw Exception('Failed to discover vendor posts: $e');
    }
  }

  /// Analyze a post's relevance for a specific vendor
  static Future<OrganizerVendorPostResult?> _analyzePostForVendor(
    OrganizerVendorPost post,
    UserProfile? vendorProfile, {
    double? latitude,
    double? longitude,
    String? searchQuery,
  }) async {
    try {
      double relevanceScore = 0.0;
      final matchReasons = <String>[];
      final opportunities = <String>[];
      double? distance;

      // Get market information
      final market = await _getMarketById(post.marketId);
      if (market == null) return null;

      // Base score for any active post
      relevanceScore += 10.0;

      // Category matching
      if (vendorProfile != null) {
        final vendorCategories = vendorProfile.categories;
        final categoryMatches = post.categories.where((cat) => vendorCategories.contains(cat)).toList();
        
        if (categoryMatches.isNotEmpty) {
          relevanceScore += categoryMatches.length * 25.0; // High weight for category match
          matchReasons.add('Categories: ${categoryMatches.join(', ')}');
        }
      }

      // Calculate distance if location provided
      if (latitude != null && longitude != null) {
        distance = _calculateDistance(
          latitude, longitude,
          market.latitude, market.longitude,
        );
        
        // Score based on distance (closer is better)
        if (distance <= 5) {
          relevanceScore += 30;
          matchReasons.add('Very close location (${distance.toStringAsFixed(1)} miles)');
        } else if (distance <= 15) {
          relevanceScore += 20;
          matchReasons.add('Convenient location (${distance.toStringAsFixed(1)} miles)');
        } else if (distance <= 30) {
          relevanceScore += 10;
          matchReasons.add('Reasonable distance (${distance.toStringAsFixed(1)} miles)');
        } else if (distance <= 50) {
          relevanceScore += 5;
        }
      }

      // Text search matching
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final postText = '${post.title} ${post.description}'.toLowerCase();
        
        if (postText.contains(query)) {
          relevanceScore += 25;
          matchReasons.add('Matches search criteria');
        }
      }

      // Experience level matching
      if (vendorProfile != null) {
        // For now, use a default experience level until we add this field to UserProfile
        final vendorExperience = 'intermediate'; // Default assumption
        final requiredLevel = post.requirements.experienceLevel;
        
        if (_isExperienceMatch(vendorExperience, requiredLevel)) {
          relevanceScore += 15;
          matchReasons.add('Experience level matches requirements');
        }
      }

      // Urgency and deadline factors
      if (post.requirements.applicationDeadline != null) {
        final deadline = post.requirements.applicationDeadline!;
        final daysUntilDeadline = deadline.difference(DateTime.now()).inDays;
        
        if (daysUntilDeadline <= 7 && daysUntilDeadline > 0) {
          relevanceScore += 20;
          opportunities.add('Application deadline approaching (${daysUntilDeadline} days)');
        } else if (daysUntilDeadline <= 0) {
          relevanceScore -= 50; // Heavily penalize expired posts
        }
      }

      // Market activity analysis
      final responseCount = await _getPostResponseCount(post.id);
      if (responseCount < 3) {
        relevanceScore += 10;
        opportunities.add('Low competition - few responses so far');
      } else if (responseCount > 10) {
        relevanceScore -= 5;
        matchReasons.add('High interest - many vendors responding');
      }

      // Fee analysis (if vendor has fee preferences)
      if (post.requirements.boothFee != null) {
        final fee = post.requirements.boothFee!;
        if (fee == 0) {
          opportunities.add('No booth fees required');
          relevanceScore += 10;
        } else if (fee < 100) {
          opportunities.add('Affordable booth fee: \$${fee.toStringAsFixed(0)}');
          relevanceScore += 5;
        }
      }

      // Post freshness
      final daysSincePosted = DateTime.now().difference(post.createdAt).inDays;
      if (daysSincePosted <= 3) {
        relevanceScore += 10;
        opportunities.add('Recently posted opportunity');
      }

      // Minimum threshold for inclusion
      if (relevanceScore < 10) return null;

      // Determine if urgent
      final isUrgent = post.metadata.urgency == 'high' || 
                      (post.requirements.applicationDeadline != null &&
                       post.requirements.applicationDeadline!.difference(DateTime.now()).inDays <= 7);

      return OrganizerVendorPostResult(
        post: post,
        market: market,
        relevanceScore: relevanceScore,
        distanceFromVendor: distance,
        matchReasons: matchReasons,
        opportunities: opportunities,
        isPremiumOnly: post.isPremiumOnly,
        applicationDeadline: post.requirements.applicationDeadline,
        isUrgent: isUrgent,
        responseCount: responseCount,
      );
    } catch (e) {
      debugPrint('Error analyzing post ${post.id}: $e');
      return null;
    }
  }

  /// Create a vendor response to an organizer post
  static Future<String> respondToPost(
    String postId,
    String vendorId,
    VendorPostResponse response,
  ) async {
    try {
      // Track the post view first
      await OrganizerVendorPostService.trackPostView(postId, vendorId);

      // Create the response
      final docRef = await _firestore
          .collection('organizer_vendor_post_responses')
          .add(response.toFirestore());

      // Update post analytics
      await _updatePostResponseCount(postId);

      debugPrint('Created vendor response: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error responding to post: $e');
      throw Exception('Failed to respond to post: $e');
    }
  }

  /// Get vendor's responses to organizer posts
  static Future<List<VendorPostResponse>> getVendorResponses(
    String vendorId, {
    ResponseStatus? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('organizer_vendor_post_responses')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => VendorPostResponse.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting vendor responses: $e');
      throw Exception('Failed to get vendor responses: $e');
    }
  }

  /// Get list of post IDs that vendor has already responded to
  static Future<List<String>> _getVendorRespondedPosts(String? vendorId) async {
    if (vendorId == null) return [];
    
    try {
      final responseQuery = await _firestore
          .collection('organizer_vendor_post_responses')
          .where('vendorId', isEqualTo: vendorId)
          .get();

      return responseQuery.docs
          .map((doc) => doc.data()['postId'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting vendor responded posts: $e');
      return [];
    }
  }

  /// Get market by ID
  static Future<Market?> _getMarketById(String marketId) async {
    try {
      final doc = await _firestore.collection('markets').doc(marketId).get();
      if (!doc.exists) return null;
      return Market.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting market: $e');
      return null;
    }
  }

  /// Get response count for a post
  static Future<int> _getPostResponseCount(String postId) async {
    try {
      final responseQuery = await _firestore
          .collection('organizer_vendor_post_responses')
          .where('postId', isEqualTo: postId)
          .get();
      
      return responseQuery.docs.length;
    } catch (e) {
      debugPrint('Error getting post response count: $e');
      return 0;
    }
  }

  /// Update post analytics when a response is created
  static Future<void> _updatePostResponseCount(String postId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore
            .collection('organizer_vendor_posts')
            .doc(postId);
        
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final currentAnalytics = PostAnalytics.fromMap(
          postDoc.data()?['analytics'] ?? {}
        );
        
        final updatedAnalytics = currentAnalytics.copyWith(
          responses: currentAnalytics.responses + 1,
        );

        transaction.update(postRef, {
          'analytics': updatedAnalytics.toMap(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      debugPrint('Error updating post response count: $e');
    }
  }

  /// Check if vendor experience matches requirements
  static bool _isExperienceMatch(String vendorExperience, ExperienceLevel required) {
    // Simple matching logic - can be enhanced
    final vendorLevel = vendorExperience.toLowerCase();
    
    switch (required) {
      case ExperienceLevel.beginner:
        return true; // Accept all levels for beginner requirements
      case ExperienceLevel.intermediate:
        return vendorLevel.contains('intermediate') || 
               vendorLevel.contains('experienced') || 
               vendorLevel.contains('expert');
      case ExperienceLevel.experienced:
        return vendorLevel.contains('experienced') || 
               vendorLevel.contains('expert');
      case ExperienceLevel.expert:
        return vendorLevel.contains('expert');
    }
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 3959.0; // Earth's radius in miles
    
    final double lat1Rad = lat1 * (math.pi / 180);
    final double lat2Rad = lat2 * (math.pi / 180);
    final double deltaLat = (lat2 - lat1) * (math.pi / 180);
    final double deltaLon = (lon2 - lon1) * (math.pi / 180);
    
    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Get trending categories from recent posts
  static Future<List<String>> getTrendingCategories() async {
    try {
      final recentPosts = await _firestore
          .collection('organizer_vendor_posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30))
          ))
          .where('status', isEqualTo: PostStatus.active.name)
          .get();

      final categoryCount = <String, int>{};
      
      for (final doc in recentPosts.docs) {
        final categories = List<String>.from(doc.data()['categories'] ?? []);
        for (final category in categories) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Sort by count and return top categories
      final sortedCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories.take(10).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('Error getting trending categories: $e');
      return [];
    }
  }

  /// Get posts with urgent deadlines
  static Future<List<OrganizerVendorPost>> getUrgentPosts({
    List<String>? categories,
    int limit = 10,
  }) async {
    try {
      final urgentDeadline = DateTime.now().add(const Duration(days: 7));
      
      Query query = _firestore
          .collection('organizer_vendor_posts')
          .where('status', isEqualTo: PostStatus.active.name)
          .where('requirements.applicationDeadline', isLessThan: Timestamp.fromDate(urgentDeadline))
          .where('requirements.applicationDeadline', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('requirements.applicationDeadline')
          .limit(limit);

      if (categories != null && categories.isNotEmpty) {
        query = query.where('categories', arrayContainsAny: categories);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => OrganizerVendorPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting urgent posts: $e');
      return [];
    }
  }
}