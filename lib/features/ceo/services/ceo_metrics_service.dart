import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive metrics aggregation service for CEO dashboard
class CEOMetricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive platform metrics
  static Future<Map<String, dynamic>> getPlatformMetrics() async {
    try {
      final results = await Future.wait([
        _getUserMetrics(),
        _getVendorMetrics(),
        _getMarketMetrics(),
        _getEngagementMetrics(),
        _getRevenueMetrics(),
        _getActivityMetrics(),
        _getErrorMetrics(),
        _getContentMetrics(),
      ]);

      return {
        'users': results[0],
        'vendors': results[1],
        'markets': results[2],
        'engagement': results[3],
        'revenue': results[4],
        'activity': results[5],
        'errors': results[6],
        'content': results[7],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error fetching platform metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// User metrics - total users, by type, new users, active users
  static Future<Map<String, dynamic>> _getUserMetrics() async {
    try {
      // Get all user profiles
      final userProfilesSnapshot = await _firestore.collection('user_profiles').get();
      
      int totalUsers = userProfilesSnapshot.docs.length;
      int vendorUsers = 0;
      int organizerUsers = 0;
      int shopperUsers = 0;
      int verifiedUsers = 0;
      int premiumUsers = 0;
      
      // Today's metrics
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));
      
      int todayNewUsers = 0;
      int weekNewUsers = 0;
      int monthNewUsers = 0;
      int activeToday = 0;
      int activeWeek = 0;
      int activeMonth = 0;
      
      for (final doc in userProfilesSnapshot.docs) {
        final data = doc.data();
        final userType = data['userType'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
        final isVerified = data['isVerified'] as bool? ?? false;
        final isPremium = data['isPremium'] as bool? ?? false;
        
        // Count by user type
        if (userType == 'vendor') vendorUsers++;
        else if (userType == 'organizer') organizerUsers++;
        else if (userType == 'shopper') shopperUsers++;
        
        if (isVerified) verifiedUsers++;
        if (isPremium) premiumUsers++;
        
        // New user counts
        if (createdAt != null) {
          if (createdAt.isAfter(todayStart)) todayNewUsers++;
          if (createdAt.isAfter(weekAgo)) weekNewUsers++;
          if (createdAt.isAfter(monthAgo)) monthNewUsers++;
        }
        
        // Active user counts
        if (lastActive != null) {
          if (lastActive.isAfter(todayStart)) activeToday++;
          if (lastActive.isAfter(weekAgo)) activeWeek++;
          if (lastActive.isAfter(monthAgo)) activeMonth++;
        }
      }
      
      // Get subscription breakdown
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions')
          .where('status', isEqualTo: 'active')
          .get();
      
      int vendorBasic = 0;
      int vendorGrowth = 0;
      int vendorPremium = 0;
      int organizerBasic = 0;
      int organizerPro = 0;
      int shopperPremium = 0;
      
      for (final doc in subscriptionsSnapshot.docs) {
        final tier = doc.data()['tier'] as String?;
        switch (tier) {
          case 'vendor_basic':
            vendorBasic++;
            break;
          case 'vendor_growth':
            vendorGrowth++;
            break;
          case 'vendor_pro':
            vendorPremium++;
            break;
          case 'organizer_basic':
            organizerBasic++;
            break;
          case 'organizer_pro':
            organizerPro++;
            break;
          case 'shopper_premium':
            shopperPremium++;
            break;
        }
      }
      
      return {
        'total': totalUsers,
        'byType': {
          'vendors': vendorUsers,
          'organizers': organizerUsers,
          'shoppers': shopperUsers,
        },
        'verified': verifiedUsers,
        'premium': premiumUsers,
        'newUsers': {
          'today': todayNewUsers,
          'week': weekNewUsers,
          'month': monthNewUsers,
        },
        'activeUsers': {
          'today': activeToday,
          'week': activeWeek,
          'month': activeMonth,
        },
        'subscriptions': {
          'vendorBasic': vendorBasic,
          'vendorGrowth': vendorGrowth,
          'vendorPremium': vendorPremium,
          'organizerBasic': organizerBasic,
          'organizerPro': organizerPro,
          'shopperPremium': shopperPremium,
          'totalActive': subscriptionsSnapshot.docs.length,
        },
      };
    } catch (e) {
      debugPrint('Error fetching user metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Vendor-specific metrics
  static Future<Map<String, dynamic>> _getVendorMetrics() async {
    try {
      final vendorsSnapshot = await _firestore.collection('managed_vendors').get();
      final vendorAppsSnapshot = await _firestore.collection('vendor_applications').get();
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();
      
      // Count by status
      int activeVendors = 0;
      int featuredVendors = 0;
      int organicVendors = 0;
      
      for (final doc in vendorsSnapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == true) activeVendors++;
        if (data['isFeatured'] == true) featuredVendors++;
        if (data['isOrganic'] == true) organicVendors++;
      }
      
      // Application metrics
      int pendingApps = 0;
      int approvedApps = 0;
      int rejectedApps = 0;
      
      for (final doc in vendorAppsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending') pendingApps++;
        else if (status == 'approved') approvedApps++;
        else if (status == 'rejected') rejectedApps++;
      }
      
      return {
        'total': vendorsSnapshot.docs.length,
        'active': activeVendors,
        'featured': featuredVendors,
        'organic': organicVendors,
        'applications': {
          'total': vendorAppsSnapshot.docs.length,
          'pending': pendingApps,
          'approved': approvedApps,
          'rejected': rejectedApps,
        },
        'posts': vendorPostsSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error fetching vendor metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Market metrics
  static Future<Map<String, dynamic>> _getMarketMetrics() async {
    try {
      final marketsSnapshot = await _firestore.collection('markets').get();
      final eventsSnapshot = await _firestore.collection('events').get();
      
      int activeMarkets = 0;
      int upcomingMarkets = 0;
      int pastMarkets = 0;
      int recruitingMarkets = 0;
      
      final now = DateTime.now();
      
      for (final doc in marketsSnapshot.docs) {
        final data = doc.data();
        final eventDate = (data['eventDate'] as Timestamp?)?.toDate();
        final isActive = data['isActive'] as bool? ?? false;
        final isLookingForVendors = data['isLookingForVendors'] as bool? ?? false;
        
        if (isActive) activeMarkets++;
        if (isLookingForVendors) recruitingMarkets++;
        
        if (eventDate != null) {
          if (eventDate.isAfter(now)) {
            upcomingMarkets++;
          } else {
            pastMarkets++;
          }
        }
      }
      
      return {
        'total': marketsSnapshot.docs.length,
        'active': activeMarkets,
        'upcoming': upcomingMarkets,
        'past': pastMarkets,
        'recruiting': recruitingMarkets,
        'events': eventsSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error fetching market metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Engagement metrics - favorites, shares, views
  static Future<Map<String, dynamic>> _getEngagementMetrics() async {
    try {
      // Favorites
      final favoritesSnapshot = await _firestore.collection('user_favorites').get();
      
      int vendorFavorites = 0;
      int marketFavorites = 0;
      int eventFavorites = 0;
      
      for (final doc in favoritesSnapshot.docs) {
        final type = doc.data()['type'] as String?;
        if (type == 'vendor') vendorFavorites++;
        else if (type == 'market') marketFavorites++;
        else if (type == 'event') eventFavorites++;
      }
      
      // Analytics events
      final analyticsSnapshot = await _firestore.collection('analytics').get();
      
      int totalViews = 0;
      int totalShares = 0;
      int profileViews = 0;
      int marketViews = 0;
      int vendorInteractions = 0;
      
      for (final doc in analyticsSnapshot.docs) {
        final data = doc.data();
        final eventType = data['eventType'] as String?;
        final count = data['count'] as int? ?? 1;
        
        if (eventType?.contains('view') == true) {
          totalViews += count;
          if (eventType?.contains('profile') == true) profileViews += count;
          if (eventType?.contains('market') == true) marketViews += count;
        }
        if (eventType?.contains('share') == true) totalShares += count;
        if (eventType?.contains('vendor') == true) vendorInteractions += count;
      }
      
      // User sessions
      final sessionsSnapshot = await _firestore.collection('user_sessions').get();
      
      return {
        'favorites': {
          'total': favoritesSnapshot.docs.length,
          'vendors': vendorFavorites,
          'markets': marketFavorites,
          'events': eventFavorites,
        },
        'views': {
          'total': totalViews,
          'profiles': profileViews,
          'markets': marketViews,
        },
        'shares': totalShares,
        'interactions': vendorInteractions,
        'sessions': sessionsSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error fetching engagement metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Revenue metrics
  static Future<Map<String, dynamic>> _getRevenueMetrics() async {
    try {
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions')
          .where('status', isEqualTo: 'active')
          .get();
      
      double monthlyRecurring = 0;
      double annualRecurring = 0;
      
      // Calculate MRR and ARR
      for (final doc in subscriptionsSnapshot.docs) {
        final data = doc.data();
        final tier = data['tier'] as String?;
        final interval = data['interval'] as String?;
        
        // Define pricing (you should adjust these to match your actual pricing)
        double monthlyPrice = 0;
        switch (tier) {
          case 'vendor_basic':
            monthlyPrice = 19.99;
            break;
          case 'vendor_growth':
            monthlyPrice = 49.99;
            break;
          case 'vendor_pro':
            monthlyPrice = 99.99;
            break;
          case 'organizer_basic':
            monthlyPrice = 29.99;
            break;
          case 'organizer_pro':
            monthlyPrice = 79.99;
            break;
          case 'shopper_premium':
            monthlyPrice = 9.99;
            break;
        }
        
        if (interval == 'month') {
          monthlyRecurring += monthlyPrice;
        } else if (interval == 'year') {
          monthlyRecurring += (monthlyPrice * 12) / 12; // Convert annual to monthly
        }
      }
      
      annualRecurring = monthlyRecurring * 12;
      
      // Get transaction history
      final transactionsSnapshot = await _firestore.collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      double totalRevenue = 0;
      double todayRevenue = 0;
      double weekRevenue = 0;
      double monthRevenue = 0;
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));
      
      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        totalRevenue += amount;
        
        if (createdAt != null) {
          if (createdAt.isAfter(todayStart)) todayRevenue += amount;
          if (createdAt.isAfter(weekAgo)) weekRevenue += amount;
          if (createdAt.isAfter(monthAgo)) monthRevenue += amount;
        }
      }
      
      return {
        'mrr': monthlyRecurring,
        'arr': annualRecurring,
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'weekRevenue': weekRevenue,
        'monthRevenue': monthRevenue,
        'activeSubscriptions': subscriptionsSnapshot.docs.length,
        'averageRevenue': subscriptionsSnapshot.docs.isNotEmpty 
            ? monthlyRecurring / subscriptionsSnapshot.docs.length 
            : 0,
      };
    } catch (e) {
      debugPrint('Error fetching revenue metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// User activity metrics
  static Future<Map<String, dynamic>> _getActivityMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final hourAgo = now.subtract(const Duration(hours: 1));
      
      // Get recent user events
      final userEventsSnapshot = await _firestore.collection('user_events')
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();
      
      int todayEvents = 0;
      int hourEvents = 0;
      Map<String, int> eventTypes = {};
      
      for (final doc in userEventsSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final eventType = data['eventType'] as String? ?? 'unknown';
        
        eventTypes[eventType] = (eventTypes[eventType] ?? 0) + 1;
        
        if (timestamp != null) {
          if (timestamp.isAfter(todayStart)) todayEvents++;
          if (timestamp.isAfter(hourAgo)) hourEvents++;
        }
      }
      
      // Get user feedback
      final feedbackSnapshot = await _firestore.collection('user_feedback').get();
      
      int positiveFeedback = 0;
      int negativeFeedback = 0;
      int neutralFeedback = 0;
      
      for (final doc in feedbackSnapshot.docs) {
        final rating = doc.data()['rating'] as int?;
        if (rating != null) {
          if (rating >= 4) positiveFeedback++;
          else if (rating <= 2) negativeFeedback++;
          else neutralFeedback++;
        }
      }
      
      return {
        'todayEvents': todayEvents,
        'lastHourEvents': hourEvents,
        'totalEvents': userEventsSnapshot.docs.length,
        'eventTypes': eventTypes,
        'feedback': {
          'total': feedbackSnapshot.docs.length,
          'positive': positiveFeedback,
          'negative': negativeFeedback,
          'neutral': neutralFeedback,
        },
      };
    } catch (e) {
      debugPrint('Error fetching activity metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Error and system health metrics
  static Future<Map<String, dynamic>> _getErrorMetrics() async {
    try {
      // System alerts
      final alertsSnapshot = await _firestore.collection('system_alerts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      int criticalErrors = 0;
      int warnings = 0;
      int info = 0;
      List<Map<String, dynamic>> recentErrors = [];
      
      for (final doc in alertsSnapshot.docs) {
        final data = doc.data();
        final severity = data['severity'] as String?;
        
        if (severity == 'critical') criticalErrors++;
        else if (severity == 'warning') warnings++;
        else info++;
        
        if (recentErrors.length < 10) {
          recentErrors.add({
            'message': data['message'],
            'severity': severity,
            'timestamp': (data['timestamp'] as Timestamp?)?.toDate()?.toIso8601String(),
          });
        }
      }
      
      // Debug logs
      final debugLogsSnapshot = await _firestore.collection('debug_logs').get();
      
      // Performance metrics
      final performanceSnapshot = await _firestore.collection('performance_metrics')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      Map<String, dynamic> latestPerformance = {};
      if (performanceSnapshot.docs.isNotEmpty) {
        latestPerformance = performanceSnapshot.docs.first.data();
      }
      
      return {
        'alerts': {
          'total': alertsSnapshot.docs.length,
          'critical': criticalErrors,
          'warnings': warnings,
          'info': info,
        },
        'debugLogs': debugLogsSnapshot.docs.length,
        'recentErrors': recentErrors,
        'performance': latestPerformance,
      };
    } catch (e) {
      debugPrint('Error fetching error metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Content metrics - posts, products, etc.
  static Future<Map<String, dynamic>> _getContentMetrics() async {
    try {
      // Vendor posts
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();
      
      int activePosts = 0;
      int expiredPosts = 0;
      final now = DateTime.now();
      
      for (final doc in vendorPostsSnapshot.docs) {
        final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
        if (expiresAt != null) {
          if (expiresAt.isAfter(now)) {
            activePosts++;
          } else {
            expiredPosts++;
          }
        }
      }
      
      // Vendor products
      final vendorProductsSnapshot = await _firestore.collection('vendor_product_lists').get();
      
      // Market items
      final marketItemsSnapshot = await _firestore.collection('vendor_market_items').get();
      
      return {
        'vendorPosts': {
          'total': vendorPostsSnapshot.docs.length,
          'active': activePosts,
          'expired': expiredPosts,
        },
        'products': vendorProductsSnapshot.docs.length,
        'marketItems': marketItemsSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error fetching content metrics: $e');
      return {'error': e.toString()};
    }
  }

  /// Get real-time activity stream
  static Stream<List<Map<String, dynamic>>> getActivityStream() {
    return _firestore
        .collection('user_events')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'userEmail': data['userEmail'],
          'eventType': data['eventType'],
          'details': data['details'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate()?.toIso8601String(),
        };
      }).toList();
    });
  }

  /// Get growth trends over time
  static Future<Map<String, dynamic>> getGrowthTrends() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      // Daily user growth
      Map<String, int> dailyNewUsers = {};
      Map<String, double> dailyRevenue = {};
      
      // Get users created in last 30 days
      final usersSnapshot = await _firestore
          .collection('user_profiles')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      for (final doc in usersSnapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyNewUsers[dateKey] = (dailyNewUsers[dateKey] ?? 0) + 1;
        }
      }
      
      // Get revenue trends
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        
        if (createdAt != null) {
          final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + amount;
        }
      }
      
      return {
        'dailyNewUsers': dailyNewUsers,
        'dailyRevenue': dailyRevenue,
      };
    } catch (e) {
      debugPrint('Error fetching growth trends: $e');
      return {'error': e.toString()};
    }
  }
}