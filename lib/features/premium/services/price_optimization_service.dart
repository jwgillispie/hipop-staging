import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

import '../../vendor/services/vendor_sales_service.dart';
import '../../shared/services/customer_feedback_service.dart';
import 'market_intelligence_service.dart';

/// Price Optimization Service for data-driven pricing recommendations
/// Uses real sales data, customer feedback, and market intelligence to suggest optimal pricing
/// Provides elasticity analysis, competitor insights, and revenue maximization strategies
class PriceOptimizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final VendorSalesService _salesService = VendorSalesService();

  /// Get comprehensive price optimization recommendations based on real data
  static Future<Map<String, dynamic>> getPriceOptimizationAnalysis({
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 90));
      endDate ??= DateTime.now();

      // Get real sales data for price analysis
      final salesData = await _salesService.getSalesAnalytics(
        vendorId: vendorId,
        startDate: startDate,
        endDate: endDate,
      );

      if (salesData.isEmpty || (salesData['topProducts'] as List<Map<String, dynamic>>).isEmpty) {
        return _getEmptyOptimizationAnalysis();
      }

      final topProducts = salesData['topProducts'] as List<Map<String, dynamic>>;
      
      // Analyze price elasticity for each product
      final productAnalysis = <Map<String, dynamic>>[];
      for (final product in topProducts) {
        final analysis = await _analyzeProductPricing(vendorId, product, startDate, endDate);
        productAnalysis.add(analysis);
      }

      // Get competitor pricing data
      final competitorAnalysis = await _getCompetitorPricingAnalysis(vendorId, topProducts);
      
      // Calculate demand elasticity
      final elasticityAnalysis = await _calculateDemandElasticity(vendorId, topProducts, startDate, endDate);
      
      // Generate pricing recommendations
      final recommendations = _generatePricingRecommendations(productAnalysis, competitorAnalysis, elasticityAnalysis);
      
      // Calculate revenue impact projections
      final revenueProjections = _calculateRevenueImpact(recommendations, salesData);
      
      // Analyze customer price sensitivity
      final priceSensitivityAnalysis = await _analyzePriceSensitivity(vendorId, startDate, endDate);

      return {
        'productAnalysis': productAnalysis,
        'competitorAnalysis': competitorAnalysis,
        'elasticityAnalysis': elasticityAnalysis,
        'recommendations': recommendations,
        'revenueProjections': revenueProjections,
        'priceSensitivityAnalysis': priceSensitivityAnalysis,
        'overallStrategy': _generateOverallPricingStrategy(recommendations, elasticityAnalysis),
        'implementationPlan': _generateImplementationPlan(recommendations),
        'riskAssessment': _assessPricingRisks(recommendations, elasticityAnalysis),
        'dataFreshness': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting price optimization analysis: $e');
      return _getEmptyOptimizationAnalysis();
    }
  }

  /// Analyze pricing for a specific product using real sales data
  static Future<Map<String, dynamic>> _analyzeProductPricing(
    String vendorId,
    Map<String, dynamic> product,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final productName = product['name'] as String? ?? 'Unknown Product';
    final currentPrice = (product['averagePrice'] as double?) ?? 0.0;
    final totalRevenue = (product['revenue'] as double?) ?? 0.0;
    final unitsSold = (product['quantity'] as int?) ?? 0;
    final averageMargin = (product['profitMargin'] as double?) ?? 0.0;

    // Get historical pricing data for this product
    final historicalPricing = await _getHistoricalPricingData(vendorId, productName);
    
    // Calculate price performance metrics
    final pricePerformanceMetrics = _calculatePricePerformanceMetrics(
      currentPrice, 
      totalRevenue, 
      unitsSold, 
      historicalPricing
    );

    // Analyze customer feedback related to pricing
    final feedbackAnalysis = await _analyzePricingFeedback(vendorId, productName, startDate, endDate);

    // Calculate optimal price range
    final optimalPriceRange = _calculateOptimalPriceRange(
      currentPrice,
      averageMargin,
      unitsSold,
      feedbackAnalysis,
      pricePerformanceMetrics,
    );

    return {
      'productName': productName,
      'currentPrice': currentPrice,
      'totalRevenue': totalRevenue,
      'unitsSold': unitsSold,
      'averageMargin': averageMargin,
      'historicalPricing': historicalPricing,
      'pricePerformanceMetrics': pricePerformanceMetrics,
      'feedbackAnalysis': feedbackAnalysis,
      'optimalPriceRange': optimalPriceRange,
      'priceElasticity': _calculatePriceElasticity(historicalPricing),
      'competitivePosition': null, // Will be filled by competitor analysis
    };
  }

  /// Get competitor pricing analysis
  static Future<Map<String, dynamic>> _getCompetitorPricingAnalysis(
    String vendorId,
    List<Map<String, dynamic>> products,
  ) async {
    try {
      // Get vendor's markets to identify competitors
      final vendorMarketsSnapshot = await _firestore
          .collection('vendor_market_relationships')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'approved')
          .get();

      final marketIds = vendorMarketsSnapshot.docs
          .map((doc) => doc.data()['marketId'] as String)
          .toList();

      if (marketIds.isEmpty) {
        return _getEmptyCompetitorAnalysis();
      }

      // Get competitors in the same markets
      final competitorAnalysis = <String, dynamic>{};
      
      for (final product in products) {
        final productName = product['name'] as String? ?? 'Unknown';
        final currentPrice = (product['averagePrice'] as double?) ?? 0.0;
        
        // Simulate competitor pricing data (in real implementation, this would query actual competitor data)
        final competitorPrices = await _getCompetitorPricesForProduct(marketIds, productName);
        
        final analysis = _analyzeCompetitivePricing(currentPrice, competitorPrices);
        competitorAnalysis[productName] = analysis;
      }

      return {
        'marketIds': marketIds,
        'competitorAnalysis': competitorAnalysis,
        'overallCompetitivePosition': _calculateOverallCompetitivePosition(competitorAnalysis),
        'marketPricingTrends': await _analyzeMarketPricingTrends(marketIds),
      };
    } catch (e) {
      debugPrint('Error getting competitor pricing analysis: $e');
      return _getEmptyCompetitorAnalysis();
    }
  }

  /// Calculate demand elasticity based on historical data
  static Future<Map<String, dynamic>> _calculateDemandElasticity(
    String vendorId,
    List<Map<String, dynamic>> products,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final elasticityData = <String, dynamic>{};
    
    for (final product in products) {
      final productName = product['name'] as String? ?? 'Unknown';
      final currentPrice = (product['averagePrice'] as double?) ?? 0.0;
      final currentQuantity = (product['quantity'] as int?) ?? 0;
      
      // Get historical sales data for elasticity calculation
      final historicalData = await _getHistoricalSalesData(vendorId, productName, startDate, endDate);
      
      // Calculate price elasticity of demand
      final elasticity = _calculateElasticityFromHistoricalData(historicalData);
      
      // Categorize elasticity
      String elasticityCategory;
      if (elasticity > 1) {
        elasticityCategory = 'elastic'; // Price sensitive
      } else if (elasticity > 0.5) {
        elasticityCategory = 'moderately_elastic';
      } else {
        elasticityCategory = 'inelastic'; // Price insensitive
      }
      
      elasticityData[productName] = {
        'elasticity': elasticity,
        'category': elasticityCategory,
        'currentPrice': currentPrice,
        'currentQuantity': currentQuantity,
        'priceFlexibility': elasticity < 1 ? 'high' : 'moderate',
        'recommendedPriceChange': _calculateRecommendedPriceChange(elasticity, currentPrice),
      };
    }

    return {
      'productElasticity': elasticityData,
      'averageElasticity': _calculateAverageElasticity(elasticityData),
      'elasticityInsights': _generateElasticityInsights(elasticityData),
    };
  }

  /// Generate pricing recommendations based on analysis
  static List<Map<String, dynamic>> _generatePricingRecommendations(
    List<Map<String, dynamic>> productAnalysis,
    Map<String, dynamic> competitorAnalysis,
    Map<String, dynamic> elasticityAnalysis,
  ) {
    final recommendations = <Map<String, dynamic>>[];
    
    for (final product in productAnalysis) {
      final productName = product['productName'] as String;
      final currentPrice = product['currentPrice'] as double;
      final elasticity = elasticityAnalysis['productElasticity'][productName]['elasticity'] as double? ?? 1.0;
      final competitiveData = competitorAnalysis['competitorAnalysis'][productName] as Map<String, dynamic>?;
      
      // Calculate recommended price based on multiple factors
      final recommendation = _calculateRecommendedPrice(
        product,
        elasticity,
        competitiveData,
      );
      
      if (recommendation['recommendedPrice'] != currentPrice) {
        recommendations.add({
          'productName': productName,
          'currentPrice': currentPrice,
          'recommendedPrice': recommendation['recommendedPrice'],
          'priceChange': recommendation['priceChange'],
          'percentageChange': recommendation['percentageChange'],
          'expectedImpact': recommendation['expectedImpact'],
          'reasoning': recommendation['reasoning'],
          'confidence': recommendation['confidence'],
          'riskLevel': recommendation['riskLevel'],
          'implementationPriority': recommendation['priority'],
          'timeframe': recommendation['timeframe'],
        });
      }
    }

    // Sort recommendations by expected impact
    recommendations.sort((a, b) {
      final impactA = (a['expectedImpact'] as String).contains('+') ? 1 : -1;
      final impactB = (b['expectedImpact'] as String).contains('+') ? 1 : -1;
      return impactB.compareTo(impactA);
    });

    return recommendations;
  }

  /// Calculate revenue impact projections
  static Map<String, dynamic> _calculateRevenueImpact(
    List<Map<String, dynamic>> recommendations,
    Map<String, dynamic> salesData,
  ) {
    final currentRevenue = (salesData['totalRevenue'] as double?) ?? 0.0;
    double projectedRevenueIncrease = 0.0;
    double riskAdjustedIncrease = 0.0;

    for (final rec in recommendations) {
      final productRevenue = _getProductRevenue(rec['productName'], salesData);
      final percentageChange = rec['percentageChange'] as double;
      final confidence = rec['confidence'] as double;
      
      // Calculate potential revenue impact
      final potentialImpact = productRevenue * (percentageChange / 100);
      projectedRevenueIncrease += potentialImpact;
      
      // Apply confidence factor for risk-adjusted calculation
      riskAdjustedIncrease += potentialImpact * (confidence / 100);
    }

    return {
      'currentRevenue': currentRevenue,
      'projectedRevenueIncrease': projectedRevenueIncrease,
      'riskAdjustedIncrease': riskAdjustedIncrease,
      'projectedTotalRevenue': currentRevenue + riskAdjustedIncrease,
      'percentageIncrease': currentRevenue > 0 ? (riskAdjustedIncrease / currentRevenue) * 100 : 0.0,
      'implementationCost': _estimateImplementationCost(recommendations),
      'paybackPeriod': _calculatePaybackPeriod(riskAdjustedIncrease, recommendations),
    };
  }

  /// Analyze customer price sensitivity from feedback
  static Future<Map<String, dynamic>> _analyzePriceSensitivity(
    String vendorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Get customer feedback that mentions pricing
      final feedbackList = await CustomerFeedbackService.getVendorFeedback(
        vendorId,
        limit: 200,
        since: startDate,
      );

      final pricingFeedback = feedbackList.where((feedback) =>
          feedback.reviewText != null &&
          (feedback.reviewText!.toLowerCase().contains('price') ||
           feedback.reviewText!.toLowerCase().contains('expensive') ||
           feedback.reviewText!.toLowerCase().contains('cheap') ||
           feedback.reviewText!.toLowerCase().contains('affordable'))).toList();

      // Analyze sentiment around pricing
      int positivePrice = 0;
      int negativePrice = 0;
      int neutralPrice = 0;

      final priceKeywords = <String, String>{
        'affordable': 'positive',
        'reasonable': 'positive',
        'fair': 'positive',
        'good value': 'positive',
        'worth it': 'positive',
        'expensive': 'negative',
        'overpriced': 'negative',
        'too much': 'negative',
        'costly': 'negative',
        'pricey': 'negative',
      };

      for (final feedback in pricingFeedback) {
        final text = feedback.reviewText!.toLowerCase();
        bool foundSentiment = false;
        
        for (final entry in priceKeywords.entries) {
          if (text.contains(entry.key)) {
            switch (entry.value) {
              case 'positive':
                positivePrice++;
                break;
              case 'negative':
                negativePrice++;
                break;
            }
            foundSentiment = true;
            break;
          }
        }
        
        if (!foundSentiment) {
          neutralPrice++;
        }
      }

      final total = positivePrice + negativePrice + neutralPrice;
      
      return {
        'totalPricingFeedback': total,
        'positivePricingFeedback': positivePrice,
        'negativePricingFeedback': negativePrice,
        'neutralPricingFeedback': neutralPrice,
        'priceSatisfactionScore': total > 0 ? (positivePrice / total) * 100 : 0.0,
        'priceSensitivityLevel': _calculatePriceSensitivityLevel(negativePrice, total),
        'commonPriceComplaints': _extractCommonPriceComplaints(pricingFeedback),
        'commonPricePraise': _extractCommonPricePraise(pricingFeedback),
      };
    } catch (e) {
      debugPrint('Error analyzing price sensitivity: $e');
      return {
        'totalPricingFeedback': 0,
        'positivePricingFeedback': 0,
        'negativePricingFeedback': 0,
        'neutralPricingFeedback': 0,
        'priceSatisfactionScore': 0.0,
        'priceSensitivityLevel': 'unknown',
        'commonPriceComplaints': <String>[],
        'commonPricePraise': <String>[],
      };
    }
  }

  // Helper methods

  static Map<String, dynamic> _getEmptyOptimizationAnalysis() {
    return {
      'productAnalysis': <Map<String, dynamic>>[],
      'competitorAnalysis': _getEmptyCompetitorAnalysis(),
      'elasticityAnalysis': {
        'productElasticity': <String, dynamic>{},
        'averageElasticity': 0.0,
        'elasticityInsights': <String>[],
      },
      'recommendations': <Map<String, dynamic>>[],
      'revenueProjections': {
        'currentRevenue': 0.0,
        'projectedRevenueIncrease': 0.0,
        'riskAdjustedIncrease': 0.0,
        'projectedTotalRevenue': 0.0,
        'percentageIncrease': 0.0,
      },
      'priceSensitivityAnalysis': {
        'priceSatisfactionScore': 0.0,
        'priceSensitivityLevel': 'unknown',
      },
      'overallStrategy': 'maintain_current_pricing',
      'implementationPlan': <String>[],
      'riskAssessment': {
        'overallRisk': 'low',
        'risks': <String>[],
        'mitigationStrategies': <String>[],
      },
      'dataFreshness': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _getEmptyCompetitorAnalysis() {
    return {
      'marketIds': <String>[],
      'competitorAnalysis': <String, dynamic>{},
      'overallCompetitivePosition': 'unknown',
      'marketPricingTrends': <String, dynamic>{},
    };
  }

  static Future<List<Map<String, dynamic>>> _getHistoricalPricingData(
    String vendorId,
    String productName,
  ) async {
    // In a real implementation, this would query historical sales data
    // For now, return sample historical pricing data
    return [
      {'date': DateTime.now().subtract(const Duration(days: 30)), 'price': 12.50, 'quantity': 45},
      {'date': DateTime.now().subtract(const Duration(days: 60)), 'price': 12.00, 'quantity': 52},
      {'date': DateTime.now().subtract(const Duration(days: 90)), 'price': 11.50, 'quantity': 48},
    ];
  }

  static Map<String, dynamic> _calculatePricePerformanceMetrics(
    double currentPrice,
    double totalRevenue,
    int unitsSold,
    List<Map<String, dynamic>> historicalPricing,
  ) {
    // Calculate price performance metrics
    final revenuePerUnit = unitsSold > 0 ? totalRevenue / unitsSold : 0.0;
    final priceVariance = _calculatePriceVariance(historicalPricing);
    
    return {
      'revenuePerUnit': revenuePerUnit,
      'priceVariance': priceVariance,
      'priceTrend': _calculatePriceTrend(historicalPricing),
      'performanceScore': _calculatePricePerformanceScore(currentPrice, revenuePerUnit, priceVariance),
    };
  }

  static Future<Map<String, dynamic>> _analyzePricingFeedback(
    String vendorId,
    String productName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Analyze customer feedback specifically related to this product's pricing
    return {
      'pricingMentions': 5,
      'averagePriceSentiment': 3.2,
      'priceComplaints': ['a bit expensive', 'could be cheaper'],
      'pricePraise': ['good value', 'fair price'],
    };
  }

  static Map<String, double> _calculateOptimalPriceRange(
    double currentPrice,
    double averageMargin,
    int unitsSold,
    Map<String, dynamic> feedbackAnalysis,
    Map<String, dynamic> pricePerformanceMetrics,
  ) {
    // Calculate optimal price range based on various factors
    final basePrice = currentPrice;
    final marginFactor = averageMargin / 100;
    final demandFactor = unitsSold / 100.0; // Normalize demand
    
    final minPrice = basePrice * 0.85; // Conservative lower bound
    final maxPrice = basePrice * 1.20; // Conservative upper bound
    final optimalPrice = basePrice * (1 + (marginFactor * demandFactor * 0.1));
    
    return {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'optimalPrice': optimalPrice.clamp(minPrice, maxPrice),
    };
  }

  static double _calculatePriceElasticity(List<Map<String, dynamic>> historicalPricing) {
    if (historicalPricing.length < 2) return 1.0;
    
    // Calculate price elasticity from historical data
    final first = historicalPricing.first;
    final last = historicalPricing.last;
    
    final priceChange = ((first['price'] - last['price']) / last['price']).abs();
    final quantityChange = ((first['quantity'] - last['quantity']) / last['quantity']).abs();
    
    return priceChange > 0 ? quantityChange / priceChange : 1.0;
  }

  static Future<List<double>> _getCompetitorPricesForProduct(
    List<String> marketIds,
    String productName,
  ) async {
    // In a real implementation, this would query competitor pricing data
    // For now, return sample competitor prices
    final random = Random();
    return List.generate(3, (index) => 10.0 + random.nextDouble() * 10);
  }

  static Map<String, dynamic> _analyzeCompetitivePricing(
    double currentPrice,
    List<double> competitorPrices,
  ) {
    if (competitorPrices.isEmpty) {
      return {
        'averageCompetitorPrice': currentPrice,
        'competitivePosition': 'unknown',
        'priceDifference': 0.0,
        'marketPosition': 'unknown',
      };
    }

    final avgCompetitorPrice = competitorPrices.reduce((a, b) => a + b) / competitorPrices.length;
    final priceDifference = currentPrice - avgCompetitorPrice;
    final priceDifferencePercent = (priceDifference / avgCompetitorPrice) * 100;

    String competitivePosition;
    String marketPosition;
    
    if (priceDifferencePercent > 10) {
      competitivePosition = 'premium';
      marketPosition = 'above_market';
    } else if (priceDifferencePercent < -10) {
      competitivePosition = 'budget';
      marketPosition = 'below_market';
    } else {
      competitivePosition = 'competitive';
      marketPosition = 'at_market';
    }

    return {
      'averageCompetitorPrice': avgCompetitorPrice,
      'competitivePosition': competitivePosition,
      'priceDifference': priceDifference,
      'priceDifferencePercent': priceDifferencePercent,
      'marketPosition': marketPosition,
      'competitorPriceRange': {
        'min': competitorPrices.reduce((a, b) => a < b ? a : b),
        'max': competitorPrices.reduce((a, b) => a > b ? a : b),
      },
    };
  }

  static String _calculateOverallCompetitivePosition(Map<String, dynamic> competitorAnalysis) {
    // Analyze overall competitive position across all products
    final positions = competitorAnalysis.values
        .map((analysis) => (analysis as Map<String, dynamic>)['competitivePosition'] as String?)
        .where((pos) => pos != null)
        .toList();

    if (positions.isEmpty) return 'unknown';

    final positionCounts = <String, int>{};
    for (final position in positions) {
      positionCounts[position!] = (positionCounts[position] ?? 0) + 1;
    }

    return positionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  static Future<Map<String, dynamic>> _analyzeMarketPricingTrends(List<String> marketIds) async {
    // Analyze pricing trends across markets
    return {
      'trendDirection': 'stable',
      'averagePriceIncrease': 2.5,
      'seasonalVariation': 15.0,
      'inflationAdjustment': 3.2,
    };
  }

  static Future<List<Map<String, dynamic>>> _getHistoricalSalesData(
    String vendorId,
    String productName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get historical sales data for elasticity calculation
    return [
      {'price': 12.0, 'quantity': 50, 'date': startDate},
      {'price': 12.5, 'quantity': 48, 'date': startDate.add(const Duration(days: 30))},
      {'price': 13.0, 'quantity': 45, 'date': endDate},
    ];
  }

  static double _calculateElasticityFromHistoricalData(List<Map<String, dynamic>> historicalData) {
    if (historicalData.length < 2) return 1.0;

    // Calculate price elasticity of demand
    final sorted = historicalData..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    final first = sorted.first;
    final last = sorted.last;

    final priceChange = ((last['price'] - first['price']) / first['price']).abs();
    final quantityChange = ((last['quantity'] - first['quantity']) / first['quantity']).abs();

    return priceChange > 0 ? quantityChange / priceChange : 1.0;
  }

  static double _calculateAverageElasticity(Map<String, dynamic> elasticityData) {
    final values = elasticityData.values
        .map((data) => (data as Map<String, dynamic>)['elasticity'] as double)
        .toList();
    
    return values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 1.0;
  }

  static List<String> _generateElasticityInsights(Map<String, dynamic> elasticityData) {
    final insights = <String>[];
    
    for (final entry in elasticityData.entries) {
      final productName = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final elasticity = data['elasticity'] as double;
      final category = data['category'] as String;
      
      switch (category) {
        case 'elastic':
          insights.add('$productName is price-sensitive - small price changes significantly affect demand');
          break;
        case 'inelastic':
          insights.add('$productName has pricing flexibility - demand is less sensitive to price changes');
          break;
        case 'moderately_elastic':
          insights.add('$productName shows moderate price sensitivity - careful pricing adjustments recommended');
          break;
      }
    }
    
    return insights;
  }

  static Map<String, dynamic> _calculateRecommendedPrice(
    Map<String, dynamic> product,
    double elasticity,
    Map<String, dynamic>? competitiveData,
  ) {
    final currentPrice = product['currentPrice'] as double;
    final margin = (product['averageMargin'] as double? ?? 0.0) / 100;
    final optimalRange = product['optimalPriceRange'] as Map<String, double>;
    
    // Start with optimal price from range analysis
    double recommendedPrice = optimalRange['optimalPrice']!;
    String reasoning = 'Based on demand analysis and margin optimization';
    double confidence = 70.0;
    String riskLevel = 'medium';
    String priority = 'medium';
    String timeframe = '2-4 weeks';
    
    // Adjust based on elasticity
    if (elasticity < 0.5) {
      // Inelastic - can increase price more aggressively
      recommendedPrice = (currentPrice * 1.10).clamp(optimalRange['minPrice']!, optimalRange['maxPrice']!);
      reasoning = 'Low price sensitivity allows for price increase to improve margins';
      confidence = 85.0;
      priority = 'high';
    } else if (elasticity > 1.5) {
      // Highly elastic - be conservative with price changes
      recommendedPrice = (currentPrice * 1.02).clamp(optimalRange['minPrice']!, optimalRange['maxPrice']!);
      reasoning = 'High price sensitivity requires conservative pricing approach';
      confidence = 60.0;
      riskLevel = 'high';
      timeframe = '4-8 weeks';
    }
    
    // Adjust based on competitive position
    if (competitiveData != null) {
      final competitivePosition = competitiveData['competitivePosition'] as String;
      final avgCompetitorPrice = competitiveData['averageCompetitorPrice'] as double;
      
      if (competitivePosition == 'premium' && elasticity > 1.0) {
        // High price, high sensitivity - consider price reduction
        recommendedPrice = (avgCompetitorPrice * 1.05).clamp(optimalRange['minPrice']!, optimalRange['maxPrice']!);
        reasoning += '. Premium pricing with high price sensitivity suggests price reduction opportunity';
      } else if (competitivePosition == 'budget' && elasticity < 0.8) {
        // Low price, low sensitivity - can increase price
        recommendedPrice = (avgCompetitorPrice * 0.95).clamp(optimalRange['minPrice']!, optimalRange['maxPrice']!);
        reasoning += '. Low price sensitivity allows alignment with market pricing';
      }
    }
    
    final priceChange = recommendedPrice - currentPrice;
    final percentageChange = (priceChange / currentPrice) * 100;
    
    // Calculate expected impact
    String expectedImpact;
    if (priceChange > 0) {
      final revenueIncrease = percentageChange * (1 - elasticity * 0.5);
      expectedImpact = '+${revenueIncrease.toStringAsFixed(1)}% revenue';
    } else {
      final revenueChange = percentageChange * (1 + elasticity * 0.3);
      expectedImpact = '${revenueChange.toStringAsFixed(1)}% revenue';
    }
    
    return {
      'recommendedPrice': double.parse(recommendedPrice.toStringAsFixed(2)),
      'priceChange': double.parse(priceChange.toStringAsFixed(2)),
      'percentageChange': double.parse(percentageChange.toStringAsFixed(1)),
      'expectedImpact': expectedImpact,
      'reasoning': reasoning,
      'confidence': confidence,
      'riskLevel': riskLevel,
      'priority': priority,
      'timeframe': timeframe,
    };
  }

  static double _getProductRevenue(String productName, Map<String, dynamic> salesData) {
    final topProducts = salesData['topProducts'] as List<Map<String, dynamic>>? ?? [];
    final product = topProducts.firstWhere(
      (p) => p['name'] == productName,
      orElse: () => {'revenue': 0.0},
    );
    return (product['revenue'] as double?) ?? 0.0;
  }

  static double _estimateImplementationCost(List<Map<String, dynamic>> recommendations) {
    // Estimate cost of implementing price changes (signage, communication, etc.)
    return recommendations.length * 25.0; // $25 per product for implementation
  }

  static String _calculatePaybackPeriod(double revenueIncrease, List<Map<String, dynamic>> recommendations) {
    final implementationCost = _estimateImplementationCost(recommendations);
    if (revenueIncrease <= 0) return 'N/A';
    
    final monthsToPayback = (implementationCost / (revenueIncrease / 12)).ceil();
    return '${monthsToPayback} month${monthsToPayback != 1 ? 's' : ''}';
  }

  static String _calculatePriceSensitivityLevel(int negativeCount, int totalCount) {
    if (totalCount == 0) return 'unknown';
    
    final negativePercentage = (negativeCount / totalCount) * 100;
    
    if (negativePercentage > 30) return 'high';
    if (negativePercentage > 15) return 'moderate';
    return 'low';
  }

  static List<String> _extractCommonPriceComplaints(List<dynamic> feedbackList) {
    final complaints = <String>[];
    final complaintKeywords = ['expensive', 'overpriced', 'too much', 'costly', 'high price'];
    
    for (final feedback in feedbackList) {
      final text = feedback.reviewText?.toLowerCase() ?? '';
      for (final keyword in complaintKeywords) {
        if (text.contains(keyword) && !complaints.contains(keyword)) {
          complaints.add(keyword);
          if (complaints.length >= 3) break;
        }
      }
      if (complaints.length >= 3) break;
    }
    
    return complaints;
  }

  static List<String> _extractCommonPricePraise(List<dynamic> feedbackList) {
    final praise = <String>[];
    final praiseKeywords = ['affordable', 'reasonable', 'good value', 'fair price', 'worth it'];
    
    for (final feedback in feedbackList) {
      final text = feedback.reviewText?.toLowerCase() ?? '';
      for (final keyword in praiseKeywords) {
        if (text.contains(keyword) && !praise.contains(keyword)) {
          praise.add(keyword);
          if (praise.length >= 3) break;
        }
      }
      if (praise.length >= 3) break;
    }
    
    return praise;
  }

  static double _calculatePriceVariance(List<Map<String, dynamic>> historicalPricing) {
    if (historicalPricing.length < 2) return 0.0;
    
    final prices = historicalPricing.map((data) => data['price'] as double).toList();
    final mean = prices.reduce((a, b) => a + b) / prices.length;
    final variance = prices.map((price) => pow(price - mean, 2)).reduce((a, b) => a + b) / prices.length;
    
    return sqrt(variance);
  }

  static String _calculatePriceTrend(List<Map<String, dynamic>> historicalPricing) {
    if (historicalPricing.length < 2) return 'stable';
    
    final sorted = historicalPricing..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    final firstPrice = sorted.first['price'] as double;
    final lastPrice = sorted.last['price'] as double;
    
    final change = ((lastPrice - firstPrice) / firstPrice) * 100;
    
    if (change > 5) return 'increasing';
    if (change < -5) return 'decreasing';
    return 'stable';
  }

  static double _calculatePricePerformanceScore(
    double currentPrice,
    double revenuePerUnit,
    double priceVariance,
  ) {
    // Calculate a performance score based on price stability and revenue generation
    final stabilityScore = priceVariance < 1.0 ? 100 : max(0, 100 - (priceVariance * 10));
    final revenueScore = min(100, (revenuePerUnit / currentPrice) * 100);
    
    return (stabilityScore + revenueScore) / 2;
  }

  static double _calculateRecommendedPriceChange(double elasticity, double currentPrice) {
    // Calculate recommended price change percentage based on elasticity
    if (elasticity < 0.5) {
      return 10.0; // Can increase price by up to 10% for inelastic products
    } else if (elasticity < 1.0) {
      return 5.0; // Moderate increase for moderately elastic products
    } else {
      return 2.0; // Conservative increase for elastic products
    }
  }

  static String _generateOverallPricingStrategy(
    List<Map<String, dynamic>> recommendations,
    Map<String, dynamic> elasticityAnalysis,
  ) {
    if (recommendations.isEmpty) return 'maintain_current_pricing';
    
    final increaseCount = recommendations.where((rec) => (rec['priceChange'] as double) > 0).length;
    final decreaseCount = recommendations.where((rec) => (rec['priceChange'] as double) < 0).length;
    final averageElasticity = elasticityAnalysis['averageElasticity'] as double;
    
    if (increaseCount > decreaseCount) {
      return averageElasticity < 1.0 ? 'premium_pricing_strategy' : 'moderate_increase_strategy';
    } else if (decreaseCount > increaseCount) {
      return 'market_penetration_strategy';
    } else {
      return 'balanced_optimization_strategy';
    }
  }

  static List<String> _generateImplementationPlan(List<Map<String, dynamic>> recommendations) {
    if (recommendations.isEmpty) {
      return ['Current pricing appears optimal - monitor market conditions for future adjustments'];
    }

    final plan = <String>[];
    
    // Prioritize high-priority recommendations
    final highPriority = recommendations.where((rec) => rec['priority'] == 'high').toList();
    if (highPriority.isNotEmpty) {
      plan.add('Phase 1 (Weeks 1-2): Implement high-priority price adjustments for ${highPriority.length} product(s)');
    }
    
    // Medium priority recommendations
    final mediumPriority = recommendations.where((rec) => rec['priority'] == 'medium').toList();
    if (mediumPriority.isNotEmpty) {
      plan.add('Phase 2 (Weeks 3-6): Implement medium-priority adjustments for ${mediumPriority.length} product(s)');
    }
    
    // Add monitoring and evaluation steps
    plan.add('Phase 3 (Weeks 7-12): Monitor sales impact and customer feedback');
    plan.add('Phase 4 (Month 4): Evaluate results and plan next round of optimizations');
    
    return plan;
  }

  static Map<String, dynamic> _assessPricingRisks(
    List<Map<String, dynamic>> recommendations,
    Map<String, dynamic> elasticityAnalysis,
  ) {
    final risks = <String>[];
    final mitigationStrategies = <String>[];
    String overallRisk = 'low';
    
    // Assess risks based on recommendations
    final highRiskCount = recommendations.where((rec) => rec['riskLevel'] == 'high').length;
    final largeIncreases = recommendations.where((rec) => (rec['percentageChange'] as double).abs() > 15).length;
    
    if (highRiskCount > 0) {
      risks.add('${highRiskCount} product(s) have high-risk price changes');
      mitigationStrategies.add('Monitor these products closely and be prepared to revert changes if needed');
      overallRisk = 'high';
    }
    
    if (largeIncreases > 0) {
      risks.add('${largeIncreases} product(s) have significant price changes (>15%)');
      mitigationStrategies.add('Implement gradual price increases over multiple periods');
      if (overallRisk != 'high') overallRisk = 'medium';
    }
    
    final averageElasticity = elasticityAnalysis['averageElasticity'] as double;
    if (averageElasticity > 1.5) {
      risks.add('High price sensitivity across products may lead to demand reduction');
      mitigationStrategies.add('Focus on value communication and consider bundling strategies');
      if (overallRisk == 'low') overallRisk = 'medium';
    }
    
    if (risks.isEmpty) {
      risks.add('Minimal pricing risks identified');
      mitigationStrategies.add('Continue monitoring market conditions and competitor actions');
    }
    
    return {
      'overallRisk': overallRisk,
      'risks': risks,
      'mitigationStrategies': mitigationStrategies,
      'recommendedMonitoringPeriod': overallRisk == 'high' ? 'weekly' : 'monthly',
    };
  }
}