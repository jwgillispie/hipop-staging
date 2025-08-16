import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../../market/models/market.dart';
import '../../shared/services/user_profile_service.dart';
import 'vendor_application_service.dart';
import 'vendor_market_relationship_service.dart';

class VendorMarketDiscoveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get markets that are actively seeking vendors
  static Future<List<MarketDiscoveryResult>> discoverMarketsForVendor(
    String vendorId, {
    List<String>? categories,
    double? latitude,
    double? longitude,
    double maxDistance = 50.0, // miles
    List<String>? operatingDays,
    double? minFeeRange,
    double? maxFeeRange,
    String? searchQuery,
    bool onlyActivelyRecruiting = false,
    int limit = 20,
  }) async {
    try {
      // Get vendor profile to understand their categories and preferences
      final vendorProfile = await UserProfileService().getUserProfile(vendorId);
      if (vendorProfile == null) {
        throw Exception('Vendor profile not found');
      }

      // Get vendor's existing relationships to filter out already-applied markets
      final appliedMarketIds = await _getVendorAppliedMarkets(vendorId);
      final approvedMarketIds = await VendorMarketRelationshipService.getApprovedMarketsForVendor(vendorId);
      final excludeMarketIds = {...appliedMarketIds, ...approvedMarketIds};

      // Base query for active markets
      Query query = _firestore.collection('markets')
          .where('isActive', isEqualTo: true);

      // Execute the query
      final snapshot = await query.get();
      
      // Convert to Market objects and filter
      final markets = snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => !excludeMarketIds.contains(market.id))
          .toList();

      // Apply additional filters and scoring
      final results = <MarketDiscoveryResult>[];
      
      for (final market in markets) {
        final result = await _analyzeMarketForVendor(
          market, 
          vendorProfile.categories,
          latitude: latitude,
          longitude: longitude,
          searchQuery: searchQuery,
          operatingDays: operatingDays,
        );
        
        if (result != null && result.relevanceScore > 0) {
          results.add(result);
        }
      }

      // Sort by relevance score and distance
      results.sort((a, b) {
        // Primary sort by relevance score
        final scoreComparison = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreComparison != 0) return scoreComparison;
        
        // Secondary sort by distance (if available)
        if (a.distanceFromVendor != null && b.distanceFromVendor != null) {
          return a.distanceFromVendor!.compareTo(b.distanceFromVendor!);
        }
        
        // Tertiary sort by market name
        return a.market.name.compareTo(b.market.name);
      });

      return results.take(limit).toList();
    } catch (e) {
      debugPrint('Error discovering markets for vendor: $e');
      throw Exception('Failed to discover markets: $e');
    }
  }

  /// Analyze a market's suitability for a vendor
  static Future<MarketDiscoveryResult?> _analyzeMarketForVendor(
    Market market,
    List<String> vendorCategories, {
    double? latitude,
    double? longitude,
    String? searchQuery,
    List<String>? operatingDays,
  }) async {
    try {
      double relevanceScore = 0.0;
      final insights = <String>[];
      final opportunities = <String>[];
      double? distance;

      // Calculate distance if location provided
      if (latitude != null && longitude != null) {
        distance = _calculateDistance(
          latitude, longitude,
          market.latitude, market.longitude,
        );
        
        // Score based on distance (closer is better)
        if (distance <= 5) {
          relevanceScore += 30;
          insights.add('Very close location (${distance.toStringAsFixed(1)} miles)');
        } else if (distance <= 15) {
          relevanceScore += 20;
          insights.add('Convenient location (${distance.toStringAsFixed(1)} miles)');
        } else if (distance <= 30) {
          relevanceScore += 10;
          insights.add('Reasonable distance (${distance.toStringAsFixed(1)} miles)');
        } else if (distance <= 50) {
          relevanceScore += 5;
        }
      }

      // Text search matching
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final marketText = '${market.name} ${market.description ?? ''} ${market.city} ${market.state}'.toLowerCase();
        
        if (marketText.contains(query)) {
          relevanceScore += 25;
          insights.add('Matches search criteria');
        }
      }

      // Check for actively recruiting markets (markets with recent events or seeking vendors)
      final isActivelyRecruiting = await _isMarketActivelyRecruiting(market);
      if (isActivelyRecruiting) {
        relevanceScore += 15;
        opportunities.add('Currently seeking new vendors');
      }

      // Date compatibility (in the new system, markets have specific event dates)
      if (operatingDays != null && operatingDays.isNotEmpty) {
        // For now, we can't match against operating days since markets have specific dates
        // TODO: Update this to match against the day of week of the market's event date
        // relevanceScore += 10;
        // insights.add('Compatible operating schedule');
      }

      // Market activity and vendor count analysis
      final marketAnalysis = await _analyzeMarketActivity(market);
      relevanceScore += marketAnalysis['activityScore'] ?? 0.0;
      
      if (marketAnalysis['vendorCount'] != null) {
        final vendorCount = marketAnalysis['vendorCount'] as int;
        if (vendorCount < 10) {
          opportunities.add('Growing market with room for new vendors');
          relevanceScore += 5;
        } else if (vendorCount > 50) {
          insights.add('Established market with high vendor activity');
          relevanceScore += 3;
        }
      }

      // Base score for any active market
      relevanceScore += 5;

      // Minimum threshold for inclusion
      if (relevanceScore < 5) return null;

      return MarketDiscoveryResult(
        market: market,
        relevanceScore: relevanceScore,
        distanceFromVendor: distance,
        insights: insights,
        opportunities: opportunities,
        estimatedFees: await _estimateMarketFees(market),
        vendorCapacity: await _estimateVendorCapacity(market),
        nextApplicationDeadline: await _getNextApplicationDeadline(market),
        isActivelyRecruiting: isActivelyRecruiting,
      );
    } catch (e) {
      debugPrint('Error analyzing market ${market.id}: $e');
      return null;
    }
  }

  /// Get list of markets the vendor has already applied to
  static Future<List<String>> _getVendorAppliedMarkets(String vendorId) async {
    try {
      final applicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .get();

      return applicationsSnapshot.docs
          .map((doc) => doc.data()['marketId'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting vendor applied markets: $e');
      return [];
    }
  }

  /// Check if a market is actively recruiting vendors
  static Future<bool> _isMarketActivelyRecruiting(Market market) async {
    try {
      // Check if market has recent events or upcoming events
      final now = DateTime.now();
      final threeMonthsAgo = now.subtract(const Duration(days: 90));
      final threeMonthsFromNow = now.add(const Duration(days: 90));

      // Look for market events or scheduled dates
      final eventsSnapshot = await _firestore
          .collection('market_events')
          .where('marketId', isEqualTo: market.id)
          .where('eventDate', isGreaterThan: Timestamp.fromDate(threeMonthsAgo))
          .where('eventDate', isLessThan: Timestamp.fromDate(threeMonthsFromNow))
          .limit(1)
          .get();

      // Also check for recent vendor applications to gauge activity
      final applicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: market.id)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(threeMonthsAgo))
          .limit(5)
          .get();

      return eventsSnapshot.docs.isNotEmpty || applicationsSnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking market recruiting status: $e');
      return false;
    }
  }

  /// Analyze market activity and vendor engagement
  static Future<Map<String, dynamic>> _analyzeMarketActivity(Market market) async {
    try {
      double activityScore = 0.0;
      
      // Count associated vendors
      final vendorCount = market.associatedVendorIds.length;
      
      // Check for recent applications (indicates interest)
      final recentApplications = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: market.id)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30))
          ))
          .get();

      // Score based on recent activity
      if (recentApplications.docs.isNotEmpty) {
        activityScore += 10.0;
      }

      // Score based on vendor count (sweet spot around 15-25 vendors)
      if (vendorCount >= 10 && vendorCount <= 30) {
        activityScore += 8.0;
      } else if (vendorCount > 0) {
        activityScore += 5.0;
      }

      return {
        'activityScore': activityScore,
        'vendorCount': vendorCount,
        'recentApplications': recentApplications.docs.length,
      };
    } catch (e) {
      debugPrint('Error analyzing market activity: $e');
      return {'activityScore': 0.0};
    }
  }

  /// Estimate market fees (placeholder - would integrate with real fee data)
  static Future<MarketFeeEstimate?> _estimateMarketFees(Market market) async {
    // This would ideally pull from market-specific fee data
    // For now, return industry standard estimates based on market location/type
    return MarketFeeEstimate(
      dailyBoothFee: 75.0, // Estimated daily booth fee
      applicationFee: 25.0, // Estimated application fee
      commissionRate: 0.03, // 3% commission estimate
      currency: 'USD',
      notes: 'Estimated fees based on similar markets',
    );
  }

  /// Estimate vendor capacity for the market
  static Future<int> _estimateVendorCapacity(Market market) async {
    try {
      // Simple estimation based on associated vendors
      final currentVendors = market.associatedVendorIds.length;
      
      // Estimate capacity based on market size and type
      // This could be enhanced with actual market capacity data
      final estimatedCapacity = 50; // Default capacity
      final availableSpots = estimatedCapacity - currentVendors;
      
      return availableSpots > 0 ? availableSpots : 0;
    } catch (e) {
      debugPrint('Error estimating vendor capacity: $e');
      return 0;
    }
  }

  /// Get next application deadline for the market
  static Future<DateTime?> _getNextApplicationDeadline(Market market) async {
    try {
      // Look for upcoming events that might have application deadlines
      final upcomingEvents = await _firestore
          .collection('market_events')
          .where('marketId', isEqualTo: market.id)
          .where('eventDate', isGreaterThan: Timestamp.now())
          .orderBy('eventDate', descending: false)
          .limit(1)
          .get();

      if (upcomingEvents.docs.isNotEmpty) {
        final eventDate = (upcomingEvents.docs.first.data()['eventDate'] as Timestamp).toDate();
        // Assume application deadline is typically 1-2 weeks before event
        return eventDate.subtract(const Duration(days: 10));
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting application deadline: $e');
      return null;
    }
  }

  /// Get popular vendor categories for a market
  static Future<List<String>> getPopularCategoriesForMarket(String marketId) async {
    try {
      // Get vendors associated with this market and analyze their categories
      final managedVendorsSnapshot = await _firestore
          .collection('managed_vendors')
          .where('marketId', isEqualTo: marketId)
          .get();

      final categoryCount = <String, int>{};
      
      for (final doc in managedVendorsSnapshot.docs) {
        final vendorData = doc.data();
        final categories = List<String>.from(vendorData['categories'] ?? []);
        
        for (final category in categories) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Sort by count and return top categories
      final sortedCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories.take(5).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('Error getting popular categories for market: $e');
      return [];
    }
  }

  /// Search markets by text query
  static Future<List<Market>> searchMarketsByQuery(String query) async {
    try {
      // Simple text search - in production, you'd use a proper search service
      final snapshot = await _firestore
          .collection('markets')
          .where('isActive', isEqualTo: true)
          .get();

      final queryLower = query.toLowerCase();
      
      return snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) {
            final searchText = '${market.name} ${market.city} ${market.state} ${market.description ?? ''}'.toLowerCase();
            return searchText.contains(queryLower);
          })
          .toList();
    } catch (e) {
      debugPrint('Error searching markets by query: $e');
      return [];
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
}

/// Result of market discovery analysis
class MarketDiscoveryResult {
  final Market market;
  final double relevanceScore;
  final double? distanceFromVendor;
  final List<String> insights;
  final List<String> opportunities;
  final MarketFeeEstimate? estimatedFees;
  final int vendorCapacity;
  final DateTime? nextApplicationDeadline;
  final bool isActivelyRecruiting;

  const MarketDiscoveryResult({
    required this.market,
    required this.relevanceScore,
    this.distanceFromVendor,
    required this.insights,
    required this.opportunities,
    this.estimatedFees,
    required this.vendorCapacity,
    this.nextApplicationDeadline,
    required this.isActivelyRecruiting,
  });
}

/// Market fee estimate
class MarketFeeEstimate {
  final double dailyBoothFee;
  final double? applicationFee;
  final double? commissionRate;
  final String currency;
  final String? notes;

  const MarketFeeEstimate({
    required this.dailyBoothFee,
    this.applicationFee,
    this.commissionRate,
    required this.currency,
    this.notes,
  });
}