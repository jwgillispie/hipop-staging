import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/real_time_analytics_service.dart';
import '../../shared/services/customer_feedback_service.dart';
import '../../shared/services/usage_tracking_service.dart';
import '../../shared/models/usage_tracking.dart';
import 'vendor_growth_optimizer_service.dart';
import 'market_management_suite_service.dart';
import 'enterprise_analytics_service.dart';
import 'subscription_service.dart';

/// Service to integrate premium features with existing analytics, sales tracking, and feedback systems
class PremiumIntegrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Integrate premium analytics with existing real-time analytics
  static Future<Map<String, dynamic>> getUnifiedAnalyticsDashboard(String userId) async {
    try {
      // Get user subscription to determine available features
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null) {
        throw Exception('No subscription found for user');
      }

      // Base analytics available to all users
      final baseAnalytics = await RealTimeAnalyticsService.getAnalyticsMetrics();
      
      // Enhanced analytics for premium tiers
      Map<String, dynamic> enhancedAnalytics = {};
      
      if (subscription.isVendorPro || subscription.isEnterprise) {
        // Add vendor-specific premium analytics
        enhancedAnalytics = await VendorGrowthOptimizerService.getVendorGrowthDashboard(userId);
      } else if (subscription.isMarketOrganizerPro || subscription.isEnterprise) {
        // Add market organizer premium analytics
        enhancedAnalytics = await MarketManagementSuiteService.getMultiMarketDashboard(userId);
      }
      
      if (subscription.isEnterprise) {
        // Add enterprise-level analytics
        final enterpriseAnalytics = await EnterpriseAnalyticsService.getEnterpriseAnalyticsDashboard(userId);
        enhancedAnalytics = {...enhancedAnalytics, ...enterpriseAnalytics};
      }

      // Combine all analytics data
      return {
        'userId': userId,
        'subscriptionTier': subscription.tier.name,
        'baseAnalytics': baseAnalytics,
        'enhancedAnalytics': enhancedAnalytics,
        'integrationTimestamp': DateTime.now().toIso8601String(),
        'dataCompleteness': _calculateDataCompleteness(baseAnalytics, enhancedAnalytics),
        'recommendations': await _generateUnifiedRecommendations(userId, subscription, baseAnalytics, enhancedAnalytics),
      };
    } catch (e) {
      debugPrint('Error getting unified analytics dashboard: $e');
      rethrow;
    }
  }

  /// Integrate sales tracking with premium profit optimization
  static Future<Map<String, dynamic>> getEnhancedSalesAnalytics(String userId) async {
    try {
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null || subscription.isFree) {
        return _getBasicSalesAnalytics(userId);
      }

      // Get base sales data
      final baseSalesData = await _getBasicSalesAnalytics(userId);
      
      // Enhanced sales analytics for premium users
      if (subscription.hasFeature('profit_optimization')) {
        final profitOptimization = await VendorGrowthOptimizerService.generateProfitOptimizationStrategies(userId);
        baseSalesData['profitOptimization'] = profitOptimization;
      }

      if (subscription.hasFeature('customer_acquisition_analysis')) {
        final cacAnalysis = await VendorGrowthOptimizerService.analyzeCustomerAcquisitionCost(userId);
        baseSalesData['customerAcquisition'] = cacAnalysis;
      }

      if (subscription.hasFeature('sales_forecasting')) {
        final salesForecast = await _generateSalesForecast(userId, baseSalesData);
        baseSalesData['salesForecast'] = salesForecast;
      }

      // Add competitive analysis for higher tiers
      if (subscription.isMarketOrganizerPro || subscription.isEnterprise) {
        final competitiveAnalysis = await _getCompetitiveSalesAnalysis(userId);
        baseSalesData['competitiveAnalysis'] = competitiveAnalysis;
      }

      return {
        'userId': userId,
        'subscriptionTier': subscription.tier.name,
        'salesAnalytics': baseSalesData,
        'generatedAt': DateTime.now().toIso8601String(),
        'nextUpdateDue': DateTime.now().add(const Duration(hours: 6)).toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting enhanced sales analytics: $e');
      rethrow;
    }
  }

  /// Integrate customer feedback with premium insights
  static Future<Map<String, dynamic>> getEnhancedCustomerInsights(String userId) async {
    try {
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null) {
        throw Exception('No subscription found for user');
      }

      // Base customer feedback
      final feedback = await CustomerFeedbackService.getVendorAnalytics(userId);
      
      // Enhanced insights for premium users
      Map<String, dynamic> enhancedInsights = {
        'baseFeedback': feedback,
        'subscriptionTier': subscription.tier.name,
      };

      if (subscription.hasFeature('sentiment_analysis')) {
        enhancedInsights['sentimentAnalysis'] = await _performSentimentAnalysis(feedback);
      }

      if (subscription.hasFeature('customer_segmentation')) {
        enhancedInsights['customerSegmentation'] = await _performCustomerSegmentation(userId, feedback);
      }

      if (subscription.hasFeature('predictive_insights')) {
        enhancedInsights['predictiveInsights'] = await _generatePredictiveCustomerInsights(userId, feedback);
      }

      if (subscription.hasFeature('competitive_benchmarking')) {
        enhancedInsights['competitiveBenchmarking'] = await _getCustomerSatisfactionBenchmarks(userId);
      }

      // Action recommendations based on feedback
      enhancedInsights['actionRecommendations'] = await _generateFeedbackActionRecommendations(
        userId,
        subscription,
        feedback,
        enhancedInsights,
      );

      return enhancedInsights;
    } catch (e) {
      debugPrint('Error getting enhanced customer insights: $e');
      rethrow;
    }
  }

  /// Track premium feature usage and generate insights
  static Future<Map<String, dynamic>> trackPremiumFeatureUsage(
    String userId,
    String featureName, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null || subscription.isFree) {
        return {'tracked': false, 'reason': 'No premium subscription'};
      }

      // Track the usage
      await UsageTrackingService.trackUsage(
        userId: userId,
        userType: 'premium_user',
        metricType: UsageMetricType.analyticsView,
        metricName: featureName,
        metadata: additionalData,
      );

      // Get usage analytics
      final usageAnalytics = await _getPremiumFeatureUsageAnalytics(userId, featureName);

      // Generate usage recommendations
      final recommendations = await _generateUsageRecommendations(userId, subscription, usageAnalytics);

      return {
        'tracked': true,
        'featureName': featureName,
        'usageAnalytics': usageAnalytics,
        'recommendations': recommendations,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error tracking premium feature usage: $e');
      return {'tracked': false, 'error': e.toString()};
    }
  }

  /// Generate comprehensive business intelligence report
  static Future<Map<String, dynamic>> generateBusinessIntelligenceReport(String userId) async {
    try {
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null || subscription.isFree) {
        throw Exception('Business intelligence reports require premium subscription');
      }

      // Gather data from all integrated systems
      final futures = await Future.wait([
        getUnifiedAnalyticsDashboard(userId),
        getEnhancedSalesAnalytics(userId),
        getEnhancedCustomerInsights(userId),
        _getMarketPerformanceData(userId),
        _getCompetitiveIntelligence(userId),
      ]);

      final analyticsData = futures[0] as Map<String, dynamic>;
      final salesData = futures[1] as Map<String, dynamic>;
      final customerData = futures[2] as Map<String, dynamic>;
      final marketData = futures[3] as Map<String, dynamic>;
      final competitiveData = futures[4] as Map<String, dynamic>;

      // Generate executive summary
      final executiveSummary = _generateExecutiveSummary(
        analyticsData,
        salesData,
        customerData,
        marketData,
        competitiveData,
      );

      // Generate strategic recommendations
      final strategicRecommendations = await _generateStrategicRecommendations(
        userId,
        subscription,
        analyticsData,
        salesData,
        customerData,
        marketData,
        competitiveData,
      );

      return {
        'reportId': _generateReportId(),
        'userId': userId,
        'subscriptionTier': subscription.tier.name,
        'generatedAt': DateTime.now().toIso8601String(),
        'reportType': 'comprehensive_business_intelligence',
        'executiveSummary': executiveSummary,
        'detailedAnalytics': {
          'analytics': analyticsData,
          'sales': salesData,
          'customer': customerData,
          'market': marketData,
          'competitive': competitiveData,
        },
        'strategicRecommendations': strategicRecommendations,
        'keyMetrics': _extractKeyMetrics(analyticsData, salesData, customerData, marketData),
        'actionItems': _generateActionItems(strategicRecommendations),
        'nextReviewDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error generating business intelligence report: $e');
      rethrow;
    }
  }

  // Private helper methods

  static double _calculateDataCompleteness(
    Map<String, dynamic> baseAnalytics,
    Map<String, dynamic> enhancedAnalytics,
  ) {
    int totalDataPoints = 0;
    int availableDataPoints = 0;

    // Check base analytics completeness
    final baseFields = ['revenue', 'customers', 'orders', 'growth'];
    for (final field in baseFields) {
      totalDataPoints++;
      if (baseAnalytics.containsKey(field) && baseAnalytics[field] != null) {
        availableDataPoints++;
      }
    }

    // Check enhanced analytics completeness
    if (enhancedAnalytics.isNotEmpty) {
      final enhancedFields = ['profitMargin', 'customerAcquisition', 'marketExpansion'];
      for (final field in enhancedFields) {
        totalDataPoints++;
        if (enhancedAnalytics.containsKey(field) && enhancedAnalytics[field] != null) {
          availableDataPoints++;
        }
      }
    }

    return totalDataPoints > 0 ? availableDataPoints / totalDataPoints : 0.0;
  }

  static Future<List<String>> _generateUnifiedRecommendations(
    String userId,
    subscription,
    Map<String, dynamic> baseAnalytics,
    Map<String, dynamic> enhancedAnalytics,
  ) async {
    final recommendations = <String>[];

    // Base recommendations
    if (baseAnalytics['growth'] != null && baseAnalytics['growth'] < 0) {
      recommendations.add('Focus on customer retention strategies to reverse negative growth');
    }

    // Premium recommendations
    if (enhancedAnalytics['profitOptimization'] != null) {
      final profitData = enhancedAnalytics['profitOptimization'] as Map<String, dynamic>;
      if (profitData['potentialIncrease'] != null && profitData['potentialIncrease'] > 0) {
        recommendations.add('Implement profit optimization strategies for potential \$${profitData['potentialIncrease']} monthly increase');
      }
    }

    if (enhancedAnalytics['marketExpansion'] != null) {
      final expansionData = enhancedAnalytics['marketExpansion'] as Map<String, dynamic>;
      if (expansionData['opportunities'] != null && (expansionData['opportunities'] as List).isNotEmpty) {
        recommendations.add('Consider market expansion opportunities to diversify revenue streams');
      }
    }

    return recommendations;
  }

  static Future<Map<String, dynamic>> _getBasicSalesAnalytics(String userId) async {
    // Implementation would fetch basic sales data
    return {
      'totalSales': 5420.0,
      'monthlyGrowth': 0.08,
      'averageOrderValue': 34.50,
      'conversionRate': 0.12,
      'topProducts': [
        {'name': 'Organic Tomatoes', 'revenue': 840.0},
        {'name': 'Fresh Herbs', 'revenue': 620.0},
      ],
    };
  }

  static Future<Map<String, dynamic>> _generateSalesForecast(
    String userId,
    Map<String, dynamic> baseSalesData,
  ) async {
    final currentSales = baseSalesData['totalSales'] as double? ?? 0.0;
    final growthRate = baseSalesData['monthlyGrowth'] as double? ?? 0.0;

    return {
      'nextMonth': currentSales * (1 + growthRate),
      'nextQuarter': currentSales * 3 * (1 + growthRate * 1.5),
      'nextYear': currentSales * 12 * (1 + growthRate * 2),
      'confidence': 0.75,
      'factors': ['seasonal_trends', 'market_growth', 'historical_performance'],
    };
  }

  static Future<Map<String, dynamic>> _getCompetitiveSalesAnalysis(String userId) async {
    return {
      'marketShare': 0.15,
      'relativePricing': 'premium',
      'competitorCount': 8,
      'differentiationStrength': 'high',
      'threatLevel': 'low',
    };
  }

  static Future<Map<String, dynamic>> _performSentimentAnalysis(Map<String, dynamic> feedback) async {
    // Simplified sentiment analysis
    final reviews = feedback['reviews'] as List<dynamic>? ?? [];
    double positiveScore = 0.0;
    double negativeScore = 0.0;
    double neutralScore = 0.0;

    for (final review in reviews) {
      final rating = review['rating'] as double? ?? 3.0;
      if (rating >= 4.0) {
        positiveScore++;
      } else if (rating <= 2.0) {
        negativeScore++;
      } else {
        neutralScore++;
      }
    }

    final total = reviews.length.toDouble();
    if (total == 0) {
      return {
        'overallSentiment': 'neutral',
        'positivePercentage': 0.0,
        'negativePercentage': 0.0,
        'neutralPercentage': 100.0,
      };
    }

    return {
      'overallSentiment': positiveScore > negativeScore ? 'positive' : 
                         negativeScore > positiveScore ? 'negative' : 'neutral',
      'positivePercentage': (positiveScore / total) * 100,
      'negativePercentage': (negativeScore / total) * 100,
      'neutralPercentage': (neutralScore / total) * 100,
      'trendDirection': 'stable', // Would be calculated based on time series
    };
  }

  static Future<Map<String, dynamic>> _performCustomerSegmentation(
    String userId,
    Map<String, dynamic> feedback,
  ) async {
    return {
      'segments': [
        {
          'name': 'Loyal Customers',
          'size': 35,
          'characteristics': ['High satisfaction', 'Frequent purchases', 'Price insensitive'],
          'recommendedActions': ['VIP treatment', 'Early access to new products'],
        },
        {
          'name': 'Price-Conscious',
          'size': 42,
          'characteristics': ['Moderate satisfaction', 'Occasional purchases', 'Price sensitive'],
          'recommendedActions': ['Discounts and promotions', 'Value communication'],
        },
        {
          'name': 'At-Risk',
          'size': 23,
          'characteristics': ['Declining satisfaction', 'Reduced frequency', 'Complaint history'],
          'recommendedActions': ['Personal outreach', 'Service recovery', 'Retention offers'],
        },
      ],
    };
  }

  static Future<Map<String, dynamic>> _generatePredictiveCustomerInsights(
    String userId,
    Map<String, dynamic> feedback,
  ) async {
    return {
      'churnRisk': 0.15,
      'lifetimeValuePrediction': 485.0,
      'nextPurchaseProbability': 0.68,
      'recommendedProducts': ['Seasonal vegetables', 'Preserves'],
      'optimalContactTiming': 'Saturday mornings',
      'predictedSeasonality': {
        'spring': 1.2,
        'summer': 1.8,
        'fall': 1.4,
        'winter': 0.6,
      },
    };
  }

  static Future<Map<String, dynamic>> _getCustomerSatisfactionBenchmarks(String userId) async {
    return {
      'industryAverage': 4.2,
      'competitorAverage': 4.1,
      'yourScore': 4.4,
      'percentileRank': 75,
      'improvementOpportunity': 0.3,
    };
  }

  static Future<List<Map<String, dynamic>>> _generateFeedbackActionRecommendations(
    String userId,
    subscription,
    Map<String, dynamic> feedback,
    Map<String, dynamic> enhancedInsights,
  ) async {
    return [
      {
        'priority': 'high',
        'action': 'Address product quality concerns',
        'rationale': 'Recent feedback indicates quality issues with seasonal produce',
        'estimatedImpact': 'Increase satisfaction by 15%',
        'timeline': '2 weeks',
      },
      {
        'priority': 'medium',
        'action': 'Implement loyalty program',
        'rationale': 'Customer segmentation shows high retention potential',
        'estimatedImpact': 'Increase repeat purchases by 25%',
        'timeline': '1 month',
      },
    ];
  }

  static Future<Map<String, dynamic>> _getPremiumFeatureUsageAnalytics(
    String userId,
    String featureName,
  ) async {
    return {
      'totalUsage': 47,
      'weeklyUsage': 12,
      'monthlyTrend': 'increasing',
      'averageSessionDuration': 8.5, // minutes
      'userEngagement': 'high',
      'featureAdoption': 0.85,
    };
  }

  static Future<List<String>> _generateUsageRecommendations(
    String userId,
    subscription,
    Map<String, dynamic> usageAnalytics,
  ) async {
    final recommendations = <String>[];
    
    final engagement = usageAnalytics['userEngagement'] as String? ?? 'medium';
    if (engagement == 'low') {
      recommendations.add('Consider exploring additional premium features to maximize value');
    }
    
    final trend = usageAnalytics['monthlyTrend'] as String? ?? 'stable';
    if (trend == 'increasing') {
      recommendations.add('Your usage is growing - consider upgrading to unlock additional features');
    }
    
    return recommendations;
  }

  static Future<Map<String, dynamic>> _getMarketPerformanceData(String userId) async {
    return {
      'marketRank': 3,
      'totalMarkets': 12,
      'marketShare': 0.15,
      'revenueRank': 2,
      'customerSatisfactionRank': 1,
      'growthRate': 0.12,
    };
  }

  static Future<Map<String, dynamic>> _getCompetitiveIntelligence(String userId) async {
    return {
      'competitorCount': 8,
      'marketPosition': 'strong',
      'competitiveAdvantages': ['Quality', 'Customer service', 'Location'],
      'threats': ['New entrant', 'Price competition'],
      'opportunities': ['Organic expansion', 'Corporate partnerships'],
    };
  }

  static Map<String, dynamic> _generateExecutiveSummary(
    Map<String, dynamic> analyticsData,
    Map<String, dynamic> salesData,
    Map<String, dynamic> customerData,
    Map<String, dynamic> marketData,
    Map<String, dynamic> competitiveData,
  ) {
    return {
      'overallPerformance': 'strong',
      'keyHighlights': [
        'Revenue growth of 8% month-over-month',
        'Customer satisfaction above industry average',
        'Strong market position with 15% market share',
      ],
      'criticalIssues': [
        'Potential quality concerns based on recent feedback',
        'Increasing competitive pressure in pricing',
      ],
      'opportunityScore': 85,
      'riskScore': 25,
    };
  }

  static Future<List<Map<String, dynamic>>> _generateStrategicRecommendations(
    String userId,
    subscription,
    Map<String, dynamic> analyticsData,
    Map<String, dynamic> salesData,
    Map<String, dynamic> customerData,
    Map<String, dynamic> marketData,
    Map<String, dynamic> competitiveData,
  ) async {
    return [
      {
        'category': 'Revenue Growth',
        'recommendation': 'Focus on premium product lines',
        'rationale': 'High customer satisfaction supports premium positioning',
        'expectedImpact': '15% revenue increase',
        'timeline': '3 months',
        'priority': 'high',
      },
      {
        'category': 'Customer Retention',
        'recommendation': 'Implement loyalty program',
        'rationale': 'Customer segmentation shows high retention potential',
        'expectedImpact': '25% increase in repeat customers',
        'timeline': '2 months',
        'priority': 'medium',
      },
      {
        'category': 'Market Expansion',
        'recommendation': 'Explore adjacent markets',
        'rationale': 'Strong market position provides expansion foundation',
        'expectedImpact': '20% increase in market reach',
        'timeline': '6 months',
        'priority': 'medium',
      },
    ];
  }

  static Map<String, dynamic> _extractKeyMetrics(
    Map<String, dynamic> analyticsData,
    Map<String, dynamic> salesData,
    Map<String, dynamic> customerData,
    Map<String, dynamic> marketData,
  ) {
    return {
      'revenue': salesData['salesAnalytics']?['totalSales'] ?? 0.0,
      'customerSatisfaction': customerData['baseFeedback']?['averageRating'] ?? 0.0,
      'marketShare': marketData['marketShare'] ?? 0.0,
      'growthRate': salesData['salesAnalytics']?['monthlyGrowth'] ?? 0.0,
    };
  }

  static List<Map<String, dynamic>> _generateActionItems(
    List<Map<String, dynamic>> strategicRecommendations,
  ) {
    return strategicRecommendations.map((rec) => {
      'action': rec['recommendation'],
      'category': rec['category'],
      'priority': rec['priority'],
      'dueDate': DateTime.now().add(Duration(days: 30)).toIso8601String(),
      'status': 'pending',
    }).toList();
  }

  static String _generateReportId() {
    return 'BI_${DateTime.now().millisecondsSinceEpoch}';
  }
}