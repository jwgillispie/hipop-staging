import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/shared/services/search_history_service.dart';
import 'dart:math' as math;
import 'vendor_following_service.dart';

/// Shopping activity types
enum ActivityType {
  marketVisit,
  vendorInteraction,
  productPurchase,
  eventAttendance,
  popupVisit,
}

/// Personal shopping insights and analytics service for premium shoppers
/// Tracks spending patterns, vendor preferences, and shopping behavior
class VendorInsightsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _shoppingInsightsCollection = 
      _firestore.collection('shopping_insights');
  static final CollectionReference _spendingTrackingCollection = 
      _firestore.collection('spending_tracking');

  /// Spending categories for tracking
  static const List<String> spendingCategories = [
    'Fresh Produce',
    'Baked Goods',
    'Prepared Foods',
    'Beverages',
    'Crafts & Artwork',
    'Clothing & Accessories',
    'Health & Beauty',
    'Home & Garden',
    'Other',
  ];

  /// Record a shopping activity for insights
  static Future<void> recordShoppingActivity({
    required String shopperId,
    required ActivityType activityType,
    required Map<String, dynamic> activityData,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      // Only premium users get detailed tracking
      if (!hasFeature) return;

      await _shoppingInsightsCollection.add({
        'shopperId': shopperId,
        'activityType': activityType.name,
        'activityData': activityData,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().substring(0, 10), // YYYY-MM-DD
        'month': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        'year': DateTime.now().year,
      });

      debugPrint('✅ Shopping activity recorded: ${activityType.name}');
    } catch (e) {
      debugPrint('❌ Error recording shopping activity: $e');
    }
  }

  /// Record spending transaction
  static Future<void> recordSpending({
    required String shopperId,
    required String vendorId,
    required String vendorName,
    required double amount,
    required String category,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      if (!hasFeature) return;

      await _spendingTrackingCollection.add({
        'shopperId': shopperId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'amount': amount,
        'category': category,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'month': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        'year': DateTime.now().year,
      });

      debugPrint('✅ Spending recorded: \$${amount.toStringAsFixed(2)} at $vendorName');
    } catch (e) {
      debugPrint('❌ Error recording spending: $e');
    }
  }

  /// Get comprehensive shopping insights
  static Future<Map<String, dynamic>> getShoppingInsights({
    required String shopperId,
    int months = 6,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      if (!hasFeature) {
        throw Exception('Shopping insights is a premium feature');
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));
      
      // Get spending data
      final spendingSnapshot = await _spendingTrackingCollection
          .where('shopperId', isEqualTo: shopperId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('timestamp', descending: true)
          .get();

      // Get activity data
      final activitySnapshot = await _shoppingInsightsCollection
          .where('shopperId', isEqualTo: shopperId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('timestamp', descending: true)
          .get();

      // Get followed vendors for context
      final followedVendors = await VendorFollowingService.getFollowedVendors(shopperId);
      
      // Get search history for preferences
      final searchHistory = await SearchHistoryService.getSearchHistory(
        shopperId: shopperId, limit: 200);

      return _analyzeShoppingData(
        spendingSnapshot.docs,
        activitySnapshot.docs,
        followedVendors,
        searchHistory,
      );

    } catch (e) {
      debugPrint('❌ Error getting shopping insights: $e');
      rethrow;
    }
  }

  /// Analyze shopping data and generate insights
  static Map<String, dynamic> _analyzeShoppingData(
    List<QueryDocumentSnapshot> spendingDocs,
    List<QueryDocumentSnapshot> activityDocs,
    List<Map<String, dynamic>> followedVendors,
    List<Map<String, dynamic>> searchHistory,
  ) {
    // Initialize analysis containers
    final spendingByCategory = <String, double>{};
    final spendingByVendor = <String, double>{};
    final spendingByMonth = <String, double>{};
    final vendorFrequency = <String, int>{};
    final activityByType = <String, int>{};
    final favoriteCategories = <String, int>{};
    final timePatterns = <int, int>{}; // Hour of day patterns
    
    double totalSpent = 0.0;
    var transactions = <Map<String, dynamic>>[];

    // Analyze spending data
    for (final doc in spendingDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num).toDouble();
      final category = data['category'] as String;
      final vendorName = data['vendorName'] as String;
      final month = data['month'] as String;
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      totalSpent += amount;
      
      spendingByCategory[category] = (spendingByCategory[category] ?? 0.0) + amount;
      spendingByVendor[vendorName] = (spendingByVendor[vendorName] ?? 0.0) + amount;
      spendingByMonth[month] = (spendingByMonth[month] ?? 0.0) + amount;
      vendorFrequency[vendorName] = (vendorFrequency[vendorName] ?? 0) + 1;
      
      timePatterns[timestamp.hour] = (timePatterns[timestamp.hour] ?? 0) + 1;

      transactions.add({
        'id': doc.id,
        'amount': amount,
        'category': category,
        'vendorName': vendorName,
        'date': data['date'],
        'description': data['description'],
      });
    }

    // Analyze activity data
    for (final doc in activityDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final activityType = data['activityType'] as String;
      activityByType[activityType] = (activityByType[activityType] ?? 0) + 1;
    }

    // Analyze category preferences from searches and follows
    for (final search in searchHistory) {
      final categories = List<String>.from(search['categories'] ?? []);
      for (final category in categories) {
        favoriteCategories[category] = (favoriteCategories[category] ?? 0) + 1;
      }
    }

    for (final vendor in followedVendors) {
      final categories = List<String>.from(vendor['categories'] ?? []);
      for (final category in categories) {
        favoriteCategories[category] = (favoriteCategories[category] ?? 0) + 2;
      }
    }

    // Sort data for insights
    final topSpendingCategories = spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topVendors = spendingByVendor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final frequentVendors = vendorFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final preferredCategories = favoriteCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate insights metrics
    final averageTransactionAmount = transactions.isEmpty ? 0.0 : totalSpent / transactions.length;
    final averageMonthlySpending = _calculateAverageMonthlySpending(spendingByMonth);
    final shoppingFrequency = _calculateShoppingFrequency(transactions);
    final diversityScore = _calculateVendorDiversityScore(spendingByVendor);
    
    // Generate personalized insights
    final insights = _generatePersonalizedInsights(
      totalSpent: totalSpent,
      transactions: transactions,
      topCategories: topSpendingCategories,
      topVendors: topVendors,
      frequentVendors: frequentVendors,
      averageTransactionAmount: averageTransactionAmount,
      diversityScore: diversityScore,
    );

    return {
      'summary': {
        'totalSpent': totalSpent,
        'transactionCount': transactions.length,
        'averageTransactionAmount': averageTransactionAmount,
        'averageMonthlySpending': averageMonthlySpending,
        'uniqueVendors': spendingByVendor.length,
        'shoppingFrequency': shoppingFrequency,
        'diversityScore': diversityScore,
      },
      'spendingBreakdown': {
        'byCategory': Map.fromEntries(topSpendingCategories.take(10)),
        'byVendor': Map.fromEntries(topVendors.take(10)),
        'byMonth': spendingByMonth,
      },
      'vendorAnalytics': {
        'topVendorsBySpending': Map.fromEntries(topVendors.take(5)),
        'mostFrequentVendors': Map.fromEntries(frequentVendors.take(5)),
        'vendorDiversityScore': diversityScore,
      },
      'preferences': {
        'favoriteCategories': Map.fromEntries(preferredCategories.take(10)),
        'shoppingTimePreferences': timePatterns,
        'followedVendorCount': followedVendors.length,
      },
      'activityBreakdown': activityByType,
      'personalizedInsights': insights,
      'transactions': transactions.take(20).toList(), // Recent 20 transactions
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate average monthly spending
  static double _calculateAverageMonthlySpending(Map<String, double> spendingByMonth) {
    if (spendingByMonth.isEmpty) return 0.0;
    final totalSpending = spendingByMonth.values.reduce((a, b) => a + b);
    return totalSpending / spendingByMonth.length;
  }

  /// Calculate shopping frequency (visits per week)
  static double _calculateShoppingFrequency(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return 0.0;
    
    final dates = transactions.map((t) => t['date'] as String).toSet();
    final uniqueDays = dates.length;
    
    // Estimate based on unique shopping days
    return uniqueDays / 4.0; // Approximate weeks in a month
  }

  /// Calculate vendor diversity score (0-1)
  static double _calculateVendorDiversityScore(Map<String, double> spendingByVendor) {
    if (spendingByVendor.isEmpty) return 0.0;
    if (spendingByVendor.length == 1) return 0.0;
    
    final totalSpending = spendingByVendor.values.reduce((a, b) => a + b);
    final spendingDistribution = spendingByVendor.values.map((v) => v / totalSpending).toList();
    
    // Calculate Shannon diversity index
    double entropy = 0.0;
    for (final proportion in spendingDistribution) {
      if (proportion > 0) {
        entropy -= proportion * math.log(proportion) / math.ln2;
      }
    }
    
    // Normalize to 0-1 scale
    final maxEntropy = math.log(spendingByVendor.length) / math.ln2;
    return maxEntropy > 0 ? entropy / maxEntropy : 0.0;
  }

  /// Generate personalized insights and recommendations
  static List<Map<String, dynamic>> _generatePersonalizedInsights({
    required double totalSpent,
    required List<Map<String, dynamic>> transactions,
    required List<MapEntry<String, double>> topCategories,
    required List<MapEntry<String, double>> topVendors,
    required List<MapEntry<String, int>> frequentVendors,
    required double averageTransactionAmount,
    required double diversityScore,
  }) {
    final insights = <Map<String, dynamic>>[];

    // Spending insights
    if (totalSpent > 0) {
      insights.add({
        'type': 'spending_summary',
        'title': 'Your Local Shopping Impact',
        'description': 'You\'ve supported ${topVendors.length} local vendors with \$${totalSpent.toStringAsFixed(2)} in purchases',
        'icon': 'shopping_bag',
        'priority': 'high',
      });
    }

    // Category preferences
    if (topCategories.isNotEmpty) {
      final topCategory = topCategories.first;
      final percentage = (topCategory.value / totalSpent * 100).round();
      insights.add({
        'type': 'category_preference',
        'title': 'Your Favorite Category',
        'description': '${topCategory.key} makes up $percentage% of your spending - you love supporting ${topCategory.key.toLowerCase()} vendors!',
        'icon': 'category',
        'priority': 'medium',
        'data': {'category': topCategory.key, 'percentage': percentage},
      });
    }

    // Vendor loyalty
    if (frequentVendors.isNotEmpty) {
      final favoriteVendor = frequentVendors.first;
      insights.add({
        'type': 'vendor_loyalty',
        'title': 'Your Go-To Vendor',
        'description': 'You\'ve visited ${favoriteVendor.key} ${favoriteVendor.value} times - you\'re a loyal customer!',
        'icon': 'favorite',
        'priority': 'medium',
        'data': {'vendorName': favoriteVendor.key, 'visits': favoriteVendor.value},
      });
    }

    // Diversity insight
    if (diversityScore > 0.7) {
      insights.add({
        'type': 'diversity_high',
        'title': 'Market Explorer',
        'description': 'You explore a wide variety of vendors! Your diversity score is ${(diversityScore * 100).round()}%',
        'icon': 'explore',
        'priority': 'low',
        'data': {'diversityScore': diversityScore},
      });
    } else if (diversityScore < 0.3 && topVendors.length > 1) {
      insights.add({
        'type': 'diversity_low',
        'title': 'Branch Out Opportunity',
        'description': 'You tend to stick with your favorites. Try exploring some new vendors for variety!',
        'icon': 'trending_up',
        'priority': 'low',
        'data': {'diversityScore': diversityScore},
      });
    }

    // Transaction size insights
    if (averageTransactionAmount > 50) {
      insights.add({
        'type': 'big_spender',
        'title': 'Quality Shopper',
        'description': 'Your average purchase is \$${averageTransactionAmount.toStringAsFixed(2)} - you invest in quality local products!',
        'icon': 'star',
        'priority': 'low',
      });
    } else if (averageTransactionAmount < 15) {
      insights.add({
        'type': 'frequent_small',
        'title': 'Frequent Visitor',
        'description': 'You make frequent smaller purchases (\$${averageTransactionAmount.toStringAsFixed(2)} average) - great for trying new things!',
        'icon': 'refresh',
        'priority': 'low',
      });
    }

    // Seasonal insights (if we have date data)
    final recentTransactions = transactions.take(10).toList();
    if (recentTransactions.isNotEmpty) {
      final now = DateTime.now();
      final isWinter = now.month >= 12 || now.month <= 2;
      final isSpring = now.month >= 3 && now.month <= 5;
      final isSummer = now.month >= 6 && now.month <= 8;
      final isFall = now.month >= 9 && now.month <= 11;

      String seasonalTip = '';
      if (isWinter) {
        seasonalTip = 'Winter is perfect for warm baked goods and comfort foods from local vendors!';
      } else if (isSpring) {
        seasonalTip = 'Spring brings fresh produce and flowers - perfect time to explore new vendors!';
      } else if (isSummer) {
        seasonalTip = 'Summer markets are in full swing with fresh fruits and outdoor crafts!';
      } else if (isFall) {
        seasonalTip = 'Fall harvest season offers the best local produce and seasonal treats!';
      }

      insights.add({
        'type': 'seasonal_tip',
        'title': 'Seasonal Shopping Tip',
        'description': seasonalTip,
        'icon': 'eco',
        'priority': 'low',
      });
    }

    return insights;
  }

  /// Get spending comparison with similar users (anonymized)
  static Future<Map<String, dynamic>> getSpendingComparison(String shopperId) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      if (!hasFeature) {
        throw Exception('Spending comparison is a premium feature');
      }

      // Get user's spending data
      final userInsights = await getShoppingInsights(shopperId: shopperId);
      final userTotalSpent = userInsights['summary']['totalSpent'] as double;
      final userAvgTransaction = userInsights['summary']['averageTransactionAmount'] as double;

      // Generate anonymized benchmarks (in production, this would be calculated from aggregate data)
      final benchmarks = _generateSpendingBenchmarks();

      return {
        'userSpending': {
          'totalSpent': userTotalSpent,
          'averageTransaction': userAvgTransaction,
          'ranking': _calculateSpendingRanking(userTotalSpent, (benchmarks['totalSpent'] as double?) ?? 0.0),
        },
        'benchmarks': benchmarks,
        'comparison': {
          'vsAverage': ((userTotalSpent / ((benchmarks['totalSpent'] as double?) ?? 1.0)) * 100).round(),
          'message': _generateComparisonMessage(userTotalSpent, (benchmarks['totalSpent'] as double?) ?? 0.0),
        },
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting spending comparison: $e');
      rethrow;
    }
  }

  /// Generate spending benchmarks (mock data for demo)
  static Map<String, double> _generateSpendingBenchmarks() {
    return {
      'totalSpent': 250.0, // Average total spent per user
      'averageTransaction': 25.0, // Average transaction amount
      'topCategory': 75.0, // Average spending in top category
      'uniqueVendors': 8.0, // Average number of unique vendors
    };
  }

  /// Calculate spending ranking (percentile)
  static int _calculateSpendingRanking(double userSpending, double averageSpending) {
    if (userSpending >= averageSpending * 2) return 95;
    if (userSpending >= averageSpending * 1.5) return 85;
    if (userSpending >= averageSpending * 1.2) return 75;
    if (userSpending >= averageSpending) return 60;
    if (userSpending >= averageSpending * 0.8) return 45;
    if (userSpending >= averageSpending * 0.6) return 30;
    return 15;
  }

  /// Generate comparison message
  static String _generateComparisonMessage(double userSpending, double averageSpending) {
    final ratio = userSpending / averageSpending;
    
    if (ratio > 1.5) {
      return 'You\'re a strong supporter of local vendors, spending more than most users!';
    } else if (ratio > 1.2) {
      return 'You\'re an active local shopper, spending above average on local vendors.';
    } else if (ratio > 0.8) {
      return 'Your local spending is right around the average for similar users.';
    } else {
      return 'You have room to explore more local vendors and support the community even more!';
    }
  }

  /// Export shopping insights data
  static Future<Map<String, dynamic>> exportShoppingData(String shopperId) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      if (!hasFeature) {
        throw Exception('Data export is a premium feature');
      }

      final insights = await getShoppingInsights(shopperId: shopperId, months: 12);
      final comparison = await getSpendingComparison(shopperId);

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'shopperId': shopperId,
        'shoppingInsights': insights,
        'spendingComparison': comparison,
        'dataVersion': '1.0',
      };
    } catch (e) {
      debugPrint('❌ Error exporting shopping data: $e');
      rethrow;
    }
  }
}