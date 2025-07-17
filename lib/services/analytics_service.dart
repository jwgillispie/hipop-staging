import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/analytics.dart';
import '../models/vendor_application.dart';
import '../models/recipe.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _analyticsCollection =
      _firestore.collection('market_analytics');

  /// Generate and store daily analytics for a market
  static Future<void> generateDailyAnalytics(
    String marketId,
    String organizerId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Get vendor metrics
      final vendorMetrics = await _getVendorMetrics(marketId);
      
      // Get recipe metrics
      final recipeMetrics = await _getRecipeMetrics(marketId);
      
      // Get favorites metrics
      final favoritesMetrics = await _getFavoritesMetrics(marketId);
      
      // Create analytics record
      final analytics = MarketAnalytics(
        marketId: marketId,
        organizerId: organizerId,
        date: startOfDay,
        totalVendors: vendorMetrics['total'] ?? 0,
        activeVendors: vendorMetrics['active'] ?? 0,
        newVendorApplications: vendorMetrics['newApplications'] ?? 0,
        approvedApplications: vendorMetrics['approved'] ?? 0,
        rejectedApplications: vendorMetrics['rejected'] ?? 0,
        totalEvents: 0,
        publishedEvents: 0,
        completedEvents: 0,
        upcomingEvents: 0,
        averageEventOccupancy: 0.0,
        totalRecipes: recipeMetrics['total'] ?? 0,
        publicRecipes: recipeMetrics['public'] ?? 0,
        featuredRecipes: recipeMetrics['featured'] ?? 0,
        totalRecipeLikes: recipeMetrics['likes'] ?? 0,
        totalRecipeSaves: recipeMetrics['saves'] ?? 0,
        totalRecipeShares: recipeMetrics['shares'] ?? 0,
        totalMarketFavorites: favoritesMetrics['totalMarketFavorites'] ?? 0,
        totalVendorFavorites: favoritesMetrics['totalVendorFavorites'] ?? 0,
        newMarketFavoritesToday: favoritesMetrics['newMarketFavoritesToday'] ?? 0,
        newVendorFavoritesToday: favoritesMetrics['newVendorFavoritesToday'] ?? 0,
      );
      
      // Store or update analytics
      final docId = '${marketId}_${startOfDay.millisecondsSinceEpoch}';
      await _analyticsCollection.doc(docId).set(analytics.toFirestore());
      
      debugPrint('Daily analytics generated for market: $marketId');
    } catch (e) {
      debugPrint('Error generating daily analytics: $e');
      throw Exception('Failed to generate analytics: $e');
    }
  }

  /// Get analytics summary for a market over a time range
  static Future<AnalyticsSummary> getAnalyticsSummary(
    String marketId,
    AnalyticsTimeRange timeRange,
  ) async {
    try {
      debugPrint('Getting analytics summary for market: $marketId, timeRange: ${timeRange.displayName}');
      
      // Get real-time metrics instead of stored analytics for now
      final realTimeMetrics = await getRealTimeMetrics(marketId);
      
      final vendorMetrics = (realTimeMetrics['vendors'] as Map<String, dynamic>?) ?? {};
      final recipeMetrics = (realTimeMetrics['recipes'] as Map<String, dynamic>?) ?? {};
      final favoritesMetrics = (realTimeMetrics['favorites'] as Map<String, dynamic>?) ?? {};
      
      // Get current breakdowns
      final vendorApplicationsByStatus = await _getVendorApplicationBreakdown(marketId);
      final recipesByCategory = await _getRecipeCategoryBreakdown(marketId);
      
      return AnalyticsSummary(
        totalVendors: vendorMetrics['total'] ?? 0,
        totalEvents: 0,
        totalRecipes: recipeMetrics['total'] ?? 0,
        totalViews: 0, // No view tracking yet
        growthRate: 0.0, // Calculate when we have historical data
        vendorApplicationsByStatus: vendorApplicationsByStatus,
        eventsByStatus: <String, int>{},
        recipesByCategory: recipesByCategory,
        totalFavorites: (favoritesMetrics['totalMarketFavorites'] ?? 0) + (favoritesMetrics['totalVendorFavorites'] ?? 0),
        favoritesByType: {
          'market': favoritesMetrics['totalMarketFavorites'] ?? 0,
          'vendor': favoritesMetrics['totalVendorFavorites'] ?? 0,
        },
        dailyData: [], // No historical data yet
      );
    } catch (e) {
      debugPrint('Error getting analytics summary: $e');
      // Return empty summary instead of throwing
      return const AnalyticsSummary();
    }
  }

  /// Get real-time metrics for dashboard
  static Future<Map<String, dynamic>> getRealTimeMetrics(String marketId) async {
    try {
      debugPrint('Getting real-time metrics for market: $marketId');
      
      final vendorMetrics = await _getVendorMetrics(marketId);
      final recipeMetrics = await _getRecipeMetrics(marketId);
      final favoritesMetrics = await _getFavoritesMetrics(marketId);
      
      debugPrint('Vendor metrics: $vendorMetrics');
      debugPrint('Recipe metrics: $recipeMetrics');
      
      return {
        'vendors': vendorMetrics,
        'recipes': recipeMetrics,
        'favorites': favoritesMetrics,
        'events': {
          'total': 0,
          'upcoming': 0,
          'published': 0,
          'averageOccupancy': 0.0,
        },
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      debugPrint('Error getting real-time metrics: $e');
      // Return default metrics instead of throwing
      return {
        'vendors': {'total': 0, 'active': 0, 'pending': 0, 'approved': 0, 'rejected': 0},
        'recipes': {'total': 0, 'public': 0, 'featured': 0, 'likes': 0, 'saves': 0, 'shares': 0},
        'favorites': {'totalMarketFavorites': 0, 'totalVendorFavorites': 0, 'newMarketFavoritesToday': 0, 'newVendorFavoritesToday': 0},
        'events': {
          'total': 0,
          'upcoming': 0,
          'published': 0,
          'averageOccupancy': 0.0,
        },
        'lastUpdated': DateTime.now(),
      };
    }
  }

  /// Private helper methods
  static Future<Map<String, dynamic>> _getVendorMetrics(String marketId) async {
    try {
      debugPrint('Getting vendor metrics for market: $marketId');
      
      // Get vendor applications
      final applicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: marketId)
          .get();
      
      debugPrint('Found ${applicationsSnapshot.docs.length} vendor applications');
      
      final applications = applicationsSnapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
      
      final today = DateTime.now();
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      
      final metrics = {
        'total': applications.length,
        'active': applications.where((app) => app.status == ApplicationStatus.approved).length,
        'newApplications': applications.where((app) => 
            app.createdAt.isAfter(thirtyDaysAgo)).length,
        'approved': applications.where((app) => app.status == ApplicationStatus.approved).length,
        'rejected': applications.where((app) => app.status == ApplicationStatus.rejected).length,
        'pending': applications.where((app) => app.status == ApplicationStatus.pending).length,
      };
      
      debugPrint('Vendor metrics calculated: $metrics');
      return metrics;
    } catch (e) {
      debugPrint('Error getting vendor metrics: $e');
      return {'total': 0, 'active': 0, 'newApplications': 0, 'approved': 0, 'rejected': 0, 'pending': 0};
    }
  }


  static Future<Map<String, dynamic>> _getRecipeMetrics(String marketId) async {
    try {
      debugPrint('Getting recipe metrics for market: $marketId');
      
      final recipesSnapshot = await _firestore
          .collection('recipes')
          .where('marketId', isEqualTo: marketId)
          .get();
      
      debugPrint('Found ${recipesSnapshot.docs.length} recipes');
      
      final recipes = recipesSnapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
      
      final totalLikes = recipes.fold(0, (total, recipe) => total + recipe.likes);
      final totalSaves = recipes.fold(0, (total, recipe) => total + recipe.saves);
      final totalShares = recipes.fold(0, (total, recipe) => total + recipe.shares);
      
      final metrics = {
        'total': recipes.length,
        'public': recipes.where((r) => r.isPublic).length,
        'featured': recipes.where((r) => r.isFeatured).length,
        'likes': totalLikes,
        'saves': totalSaves,
        'shares': totalShares,
      };
      
      debugPrint('Recipe metrics calculated: $metrics');
      return metrics;
    } catch (e) {
      debugPrint('Error getting recipe metrics: $e');
      return {'total': 0, 'public': 0, 'featured': 0, 'likes': 0, 'saves': 0, 'shares': 0};
    }
  }

  static Future<Map<String, int>> _getVendorApplicationBreakdown(String marketId) async {
    try {
      final snapshot = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: marketId)
          .get();
      
      final applications = snapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
      
      return {
        'pending': applications.where((app) => app.status == ApplicationStatus.pending).length,
        'approved': applications.where((app) => app.status == ApplicationStatus.approved).length,
        'rejected': applications.where((app) => app.status == ApplicationStatus.rejected).length,
      };
    } catch (e) {
      debugPrint('Error getting vendor application breakdown: $e');
      return {};
    }
  }


  static Future<Map<String, int>> _getRecipeCategoryBreakdown(String marketId) async {
    try {
      final snapshot = await _firestore
          .collection('recipes')
          .where('marketId', isEqualTo: marketId)
          .get();
      
      final recipes = snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
      
      final breakdown = <String, int>{};
      for (final category in RecipeCategory.values) {
        breakdown[category.name] = recipes
            .where((r) => r.category == category)
            .length;
      }
      
      return breakdown;
    } catch (e) {
      debugPrint('Error getting recipe category breakdown: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getFavoritesMetrics(String marketId) async {
    try {
      debugPrint('Getting favorites metrics for market: $marketId');
      
      // Get all market favorites for this market
      final marketFavoritesSnapshot = await _firestore
          .collection('user_favorites')
          .where('itemId', isEqualTo: marketId)
          .where('type', isEqualTo: 'market')
          .get();
      
      final totalMarketFavorites = marketFavoritesSnapshot.docs.length;
      
      // Get vendor favorites for vendors in this market
      // First, get all vendors for this market from managed_vendors
      final managedVendorsSnapshot = await _firestore
          .collection('managed_vendors')
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final vendorIds = managedVendorsSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      int totalVendorFavorites = 0;
      if (vendorIds.isNotEmpty) {
        // Firestore "in" queries can only handle up to 10 items
        // If more than 10 vendors, we need to batch the queries
        for (int i = 0; i < vendorIds.length; i += 10) {
          final batch = vendorIds.skip(i).take(10).toList();
          final vendorFavoritesSnapshot = await _firestore
              .collection('user_favorites')
              .where('itemId', whereIn: batch)
              .where('type', isEqualTo: 'vendor')
              .get();
          totalVendorFavorites += vendorFavoritesSnapshot.docs.length;
        }
      }
      
      // Get new favorites today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final newMarketFavoritesToday = marketFavoritesSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(startOfDay);
          })
          .length;
      
      // Get new vendor favorites today (simplified - just count all vendor favorites created today)
      final newVendorFavoritesTodaySnapshot = await _firestore
          .collection('user_favorites')
          .where('type', isEqualTo: 'vendor')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      // Filter to only include vendors from this market
      final newVendorFavoritesToday = newVendorFavoritesTodaySnapshot.docs
          .where((doc) {
            final data = doc.data();
            final itemId = data['itemId'] as String?;
            return itemId != null && vendorIds.contains(itemId);
          })
          .length;
      
      final metrics = {
        'totalMarketFavorites': totalMarketFavorites,
        'totalVendorFavorites': totalVendorFavorites,
        'newMarketFavoritesToday': newMarketFavoritesToday,
        'newVendorFavoritesToday': newVendorFavoritesToday,
      };
      
      debugPrint('Favorites metrics calculated: $metrics');
      return metrics;
    } catch (e) {
      debugPrint('Error getting favorites metrics: $e');
      // For now, ignore permission errors and return empty metrics
      // This is common when market organizers don't have explicit permission
      // to read user favorites data
      return {
        'totalMarketFavorites': 0,
        'totalVendorFavorites': 0,
        'newMarketFavoritesToday': 0,
        'newVendorFavoritesToday': 0,
      };
    }
  }


  /// Export analytics data
  static Future<List<MarketAnalytics>> exportAnalyticsData(
    String marketId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _analyticsCollection
          .where('marketId', isEqualTo: marketId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();
      
      return snapshot.docs
          .map((doc) => MarketAnalytics.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error exporting analytics data: $e');
      throw Exception('Failed to export analytics data: $e');
    }
  }

  /// Get vendor registrations by month for chart data
  static Future<List<Map<String, dynamic>>> getVendorRegistrationsByMonth(
    String marketId, 
    int monthsBack
  ) async {
    try {
      debugPrint('Getting vendor registrations by month for market: $marketId');
      
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - monthsBack, 1);
      
      // Get all vendor applications for this market
      final applicationsSnapshot = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: marketId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('createdAt')
          .get();
      
      final applications = applicationsSnapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
      
      // Group applications by month
      final monthlyData = <String, Map<String, int>>{};
      
      // Initialize all months with zero values
      for (int i = 0; i < monthsBack; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        monthlyData[monthKey] = {
          'total': 0,
          'approved': 0,
          'pending': 0,
          'rejected': 0,
        };
      }
      
      // Count applications by month and status
      for (final application in applications) {
        final date = application.createdAt;
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        
        if (monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey]!['total'] = (monthlyData[monthKey]!['total'] ?? 0) + 1;
          
          switch (application.status) {
            case ApplicationStatus.approved:
              monthlyData[monthKey]!['approved'] = (monthlyData[monthKey]!['approved'] ?? 0) + 1;
              break;
            case ApplicationStatus.pending:
              monthlyData[monthKey]!['pending'] = (monthlyData[monthKey]!['pending'] ?? 0) + 1;
              break;
            case ApplicationStatus.rejected:
              monthlyData[monthKey]!['rejected'] = (monthlyData[monthKey]!['rejected'] ?? 0) + 1;
              break;
            case ApplicationStatus.waitlisted:
              monthlyData[monthKey]!['pending'] = (monthlyData[monthKey]!['pending'] ?? 0) + 1;
              break;
          }
        }
      }
      
      // Convert to list format for charts, sorted by date
      final result = monthlyData.entries
          .map((entry) => {
                'month': entry.key,
                'monthName': _getMonthName(entry.key),
                ...entry.value,
              })
          .toList();
      
      // Sort by month (chronological order)
      result.sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
      
      debugPrint('Vendor registrations by month: $result');
      return result;
    } catch (e) {
      debugPrint('Error getting vendor registrations by month: $e');
      return [];
    }
  }
  
  /// Helper method to get month name from YYYY-MM format
  static String _getMonthName(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    if (month < 1 || month > 12) return monthKey;
    
    return '${months[month - 1]} ${year.toString().substring(2)}'; // e.g., "Jan 24"
  }

  /// Get top performing metrics
  static Future<Map<String, dynamic>> getTopPerformingMetrics(String marketId) async {
    try {
      // Get top recipes by engagement
      final recipesSnapshot = await _firestore
          .collection('recipes')
          .where('marketId', isEqualTo: marketId)
          .orderBy('likes', descending: true)
          .limit(5)
          .get();
      
      final topRecipes = recipesSnapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
      
      return {
        'topRecipes': topRecipes,
      };
    } catch (e) {
      debugPrint('Error getting top performing metrics: $e');
      return {};
    }
  }
}