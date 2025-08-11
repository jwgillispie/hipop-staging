import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_profile.dart';

class OrganizerVendorDiscoveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Discover qualified vendors for organizer's markets
  static Future<List<VendorDiscoveryResult>> discoverVendorsForOrganizer(
    String organizerId, {
    List<String>? categories,
    String? location,
    List<String>? experienceLevels,
    double? minRating,
    List<String>? availableMarketIds,
    String? searchQuery,
    bool onlyVerified = true,
    bool onlyAvailable = false,
    int limit = 20,
  }) async {
    try {
      debugPrint('🔍 Starting vendor discovery for organizer: $organizerId');

      // Get organizer's markets to understand their categories and requirements
      final organizerMarkets = await getOrganizerMarkets(organizerId);
      debugPrint('🏪 Found ${organizerMarkets.length} markets for organizer');

      // Get vendors that might be a good fit
      Query vendorQuery = _firestore.collection('user_profiles')
          .where('userType', isEqualTo: 'vendor');
      
      if (onlyVerified) {
        vendorQuery = vendorQuery.where('isVerified', isEqualTo: true);
      }

      final snapshot = await vendorQuery.limit(200).get(); // Get larger pool for filtering
      debugPrint('📋 Retrieved ${snapshot.docs.length} vendor profiles');

      final results = <VendorDiscoveryResult>[];
      
      for (final doc in snapshot.docs) {
        try {
          final vendorProfile = UserProfile.fromFirestore(doc);
          
          // Skip if vendor has already been invited recently
          if (await _hasRecentInvitation(organizerId, vendorProfile.userId)) {
            continue;
          }

          final result = await _analyzeVendorForOrganizer(
            vendorProfile,
            organizerMarkets,
            organizerId: organizerId,
            categories: categories,
            location: location,
            experienceLevels: experienceLevels,
            minRating: minRating,
            searchQuery: searchQuery,
            onlyAvailable: onlyAvailable,
          );

          if (result != null && result.matchScore > 0) {
            results.add(result);
          }
        } catch (e) {
          debugPrint('❌ Error analyzing vendor ${doc.id}: $e');
        }
      }

      // Sort by match score and return top results
      results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      final topResults = results.take(limit).toList();
      
      debugPrint('✅ Returning ${topResults.length} vendor discovery results');
      return topResults;

    } catch (e) {
      debugPrint('❌ Error discovering vendors for organizer: $e');
      throw Exception('Failed to discover vendors: $e');
    }
  }

  /// Get organizer's markets and their requirements
  static Future<List<Map<String, dynamic>>> getOrganizerMarkets(String organizerId) async {
    try {
      final marketsSnapshot = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: organizerId)
          .where('isActive', isEqualTo: true)
          .get();

      return marketsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'categories': List<String>.from(data['vendorCategories'] ?? []),
          'location': data['city'] ?? '',
          'state': data['state'] ?? '',
          'associatedVendorIds': List<String>.from(data['associatedVendorIds'] ?? []),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting organizer markets: $e');
      return [];
    }
  }

  /// Analyze vendor suitability for organizer's markets
  static Future<VendorDiscoveryResult?> _analyzeVendorForOrganizer(
    UserProfile vendorProfile,
    List<Map<String, dynamic>> organizerMarkets, {
    required String organizerId,
    List<String>? categories,
    String? location,
    List<String>? experienceLevels,
    double? minRating,
    String? searchQuery,
    bool onlyAvailable = false,
  }) async {
    try {
      double matchScore = 0.0;
      final insights = <String>[];
      final marketFit = <String>[];
      
      // Base score for verified vendors
      if (vendorProfile.isVerified) {
        matchScore += 10.0;
        insights.add('Verified vendor profile');
      }

      // Category matching
      final vendorCategories = vendorProfile.categories;
      if (vendorCategories.isNotEmpty && categories != null && categories.isNotEmpty) {
        final matchingCategories = vendorCategories.where(
          (cat) => categories.contains(cat)
        ).toList();
        
        if (matchingCategories.isNotEmpty) {
          matchScore += matchingCategories.length * 15.0;
          insights.add('Matches ${matchingCategories.length} requested categories');
        }
      }

      // Market-specific category matching
      for (final market in organizerMarkets) {
        final marketCategories = List<String>.from(market['categories']);
        final matchingCategories = vendorCategories.where(
          (cat) => marketCategories.contains(cat)
        ).toList();
        
        if (matchingCategories.isNotEmpty) {
          matchScore += matchingCategories.length * 10.0;
          marketFit.add('Perfect fit for ${market['name']} (${matchingCategories.join(', ')})');
        }
      }

      // Location matching (UserProfile doesn't have city/state fields - using preferences or bio)
      if (location != null && location.isNotEmpty) {
        final vendorBio = vendorProfile.bio?.toLowerCase() ?? '';
        if (vendorBio.contains(location.toLowerCase())) {
          matchScore += 20.0;
          insights.add('Located in target area');
        }
      }

      // Search query matching
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchText = '${vendorProfile.displayName} ${vendorProfile.businessName} ${vendorProfile.bio}'.toLowerCase();
        if (searchText.contains(searchQuery.toLowerCase())) {
          matchScore += 25.0;
          insights.add('Matches search criteria');
        }
      }

      // Get vendor's market experience and performance metrics
      final vendorMetrics = await _getVendorMetrics(vendorProfile.userId);
      
      // Experience scoring
      final marketCount = vendorMetrics['totalMarkets'] ?? 0;
      if (marketCount > 0) {
        if (marketCount >= 5) {
          matchScore += 15.0;
          insights.add('Experienced vendor ($marketCount markets)');
        } else {
          matchScore += 8.0;
          insights.add('Some market experience ($marketCount markets)');
        }
      }

      // Rating scoring
      final avgRating = vendorMetrics['averageRating'] ?? 0.0;
      if (avgRating >= 4.5) {
        matchScore += 20.0;
        insights.add('Excellent ratings (${avgRating.toStringAsFixed(1)}/5.0)');
      } else if (avgRating >= 4.0) {
        matchScore += 15.0;
        insights.add('Great ratings (${avgRating.toStringAsFixed(1)}/5.0)');
      } else if (avgRating >= 3.5) {
        matchScore += 10.0;
        insights.add('Good ratings (${avgRating.toStringAsFixed(1)}/5.0)');
      }

      // Apply minimum rating filter
      if (minRating != null && avgRating < minRating) {
        return null; // Doesn't meet minimum rating requirement
      }

      // Availability check
      if (onlyAvailable) {
        final isAvailable = await _checkVendorAvailability(vendorProfile.userId);
        if (!isAvailable) {
          return null; // Vendor not available
        }
        insights.add('Currently available for new markets');
      }

      // Activity and engagement scoring
      final recentActivity = vendorMetrics['recentActivityScore'] ?? 0.0;
      matchScore += recentActivity;
      
      if (recentActivity > 10) {
        insights.add('Highly active vendor');
      }

      // Check if vendor has been rejected from organizer's markets
      final hasRejections = await _hasRecentRejections(vendorProfile.userId, organizerId);
      if (hasRejections) {
        matchScore -= 20.0; // Reduce score for recent rejections
      }

      // Minimum threshold for inclusion
      if (matchScore < 10.0) return null;

      return VendorDiscoveryResult(
        vendor: vendorProfile,
        matchScore: matchScore,
        insights: insights,
        marketFit: marketFit,
        experienceLevel: _determineExperienceLevel(vendorMetrics),
        averageRating: avgRating,
        totalMarkets: marketCount,
        categories: vendorCategories,
        lastActive: vendorMetrics['lastActiveDate'],
        portfolioItems: vendorMetrics['portfolioItemCount'] ?? 0,
      );

    } catch (e) {
      debugPrint('❌ Error analyzing vendor ${vendorProfile.userId}: $e');
      return null;
    }
  }

  /// Get vendor performance metrics
  static Future<Map<String, dynamic>> _getVendorMetrics(String vendorId) async {
    try {
      final metrics = <String, dynamic>{};
      
      // Count approved applications (markets participated in)
      final applicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'approved')
          .get();
      
      metrics['totalMarkets'] = applicationsSnapshot.docs.length;

      // Get average rating from vendor feedback
      final feedbackSnapshot = await _firestore
          .collection('vendor_feedback')
          .where('vendorId', isEqualTo: vendorId)
          .get();
      
      if (feedbackSnapshot.docs.isNotEmpty) {
        final ratings = feedbackSnapshot.docs
            .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0.0)
            .where((rating) => rating > 0)
            .toList();
        
        if (ratings.isNotEmpty) {
          metrics['averageRating'] = ratings.reduce((a, b) => a + b) / ratings.length;
        }
      }

      // Check recent activity (vendor posts, applications)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final recentPostsSnapshot = await _firestore
          .collection('vendor_posts')
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      final recentApplicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      double activityScore = 0.0;
      activityScore += recentPostsSnapshot.docs.length * 2.0; // 2 points per recent post
      activityScore += recentApplicationsSnapshot.docs.length * 5.0; // 5 points per recent application
      
      metrics['recentActivityScore'] = activityScore;

      // Get last active date
      if (recentPostsSnapshot.docs.isNotEmpty || recentApplicationsSnapshot.docs.isNotEmpty) {
        final allRecentDocs = [...recentPostsSnapshot.docs, ...recentApplicationsSnapshot.docs];
        final latestTimestamp = allRecentDocs
            .map((doc) => (doc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970))
            .reduce((a, b) => a.isAfter(b) ? a : b);
        
        metrics['lastActiveDate'] = latestTimestamp;
      }

      // Count portfolio items (vendor posts with images)
      final portfolioSnapshot = await _firestore
          .collection('vendor_posts')
          .where('vendorId', isEqualTo: vendorId)
          .where('imageUrls', isNotEqualTo: [])
          .get();
      
      metrics['portfolioItemCount'] = portfolioSnapshot.docs.length;

      return metrics;

    } catch (e) {
      debugPrint('❌ Error getting vendor metrics: $e');
      return {};
    }
  }

  /// Determine vendor experience level
  static String _determineExperienceLevel(Map<String, dynamic> metrics) {
    final totalMarkets = metrics['totalMarkets'] ?? 0;
    final avgRating = metrics['averageRating'] ?? 0.0;
    
    if (totalMarkets >= 10 && avgRating >= 4.5) {
      return 'Expert';
    } else if (totalMarkets >= 5 && avgRating >= 4.0) {
      return 'Experienced';
    } else if (totalMarkets >= 2) {
      return 'Intermediate';
    } else {
      return 'Beginner';
    }
  }

  /// Check if vendor is currently available for new markets
  static Future<bool> _checkVendorAvailability(String vendorId) async {
    try {
      // Check if vendor has capacity for more markets
      // For now, assume vendors are available unless they're in too many active markets
      final activeApplicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'approved')
          .get();
      
      // Assume vendors can handle up to 10 active markets
      return activeApplicationsSnapshot.docs.length < 10;

    } catch (e) {
      debugPrint('❌ Error checking vendor availability: $e');
      return true; // Default to available
    }
  }

  /// Check if organizer has recent invitations to this vendor
  static Future<bool> _hasRecentInvitation(String organizerId, String vendorId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final recentInvitationSnapshot = await _firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId)
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .limit(1)
          .get();
      
      return recentInvitationSnapshot.docs.isNotEmpty;

    } catch (e) {
      debugPrint('❌ Error checking recent invitations: $e');
      return false;
    }
  }

  /// Check if vendor has recent rejections from organizer's markets
  static Future<bool> _hasRecentRejections(String vendorId, String organizerId) async {
    try {
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
      
      // Get organizer's market IDs
      final marketsSnapshot = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: organizerId)
          .get();
      
      final marketIds = marketsSnapshot.docs.map((doc) => doc.id).toList();
      
      if (marketIds.isEmpty) return false;

      // Check for recent rejections
      final rejectionSnapshot = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', whereIn: marketIds)
          .where('status', isEqualTo: 'rejected')
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(sixtyDaysAgo))
          .limit(1)
          .get();
      
      return rejectionSnapshot.docs.isNotEmpty;

    } catch (e) {
      debugPrint('❌ Error checking recent rejections: $e');
      return false;
    }
  }

  /// Get vendor categories that are popular in organizer's markets
  static Future<List<String>> getSuggestedCategoriesForOrganizer(String organizerId) async {
    try {
      final organizerMarkets = await getOrganizerMarkets(organizerId);
      final categoryCount = <String, int>{};
      
      // Count categories across all organizer markets
      for (final market in organizerMarkets) {
        final categories = List<String>.from(market['categories']);
        for (final category in categories) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Sort by frequency and return top categories
      final sortedCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories.take(10).map((e) => e.key).toList();

    } catch (e) {
      debugPrint('❌ Error getting suggested categories: $e');
      return [];
    }
  }

  /// Get vendor discovery analytics for organizer
  static Future<Map<String, dynamic>> getVendorDiscoveryAnalytics(String organizerId) async {
    try {
      final analytics = <String, dynamic>{};
      
      // Count total vendors discovered in last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final invitationsSent = await _firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      analytics['invitationsSent'] = invitationsSent.docs.length;
      
      // Count responses
      final responses = invitationsSent.docs
          .where((doc) => doc.data()['status'] != 'pending')
          .length;
      
      analytics['responseRate'] = invitationsSent.docs.isEmpty 
          ? 0.0 
          : responses / invitationsSent.docs.length;
      
      // Count acceptances
      final acceptances = invitationsSent.docs
          .where((doc) => doc.data()['status'] == 'accepted')
          .length;
      
      analytics['acceptanceRate'] = invitationsSent.docs.isEmpty 
          ? 0.0 
          : acceptances / invitationsSent.docs.length;

      return analytics;

    } catch (e) {
      debugPrint('❌ Error getting vendor discovery analytics: $e');
      return {};
    }
  }
}

/// Result of vendor discovery analysis
class VendorDiscoveryResult {
  final UserProfile vendor;
  final double matchScore;
  final List<String> insights;
  final List<String> marketFit;
  final String experienceLevel;
  final double averageRating;
  final int totalMarkets;
  final List<String> categories;
  final DateTime? lastActive;
  final int portfolioItems;

  const VendorDiscoveryResult({
    required this.vendor,
    required this.matchScore,
    required this.insights,
    required this.marketFit,
    required this.experienceLevel,
    required this.averageRating,
    required this.totalMarkets,
    required this.categories,
    this.lastActive,
    required this.portfolioItems,
  });
}