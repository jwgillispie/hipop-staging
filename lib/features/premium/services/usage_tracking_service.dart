import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Enhanced usage tracking service with caching and real-time enforcement
class UsageTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Cache for usage data to reduce Firestore reads
  static final Map<String, _CachedUsageData> _usageCache = {};
  static final Map<String, _CachedLimitData> _limitCache = {};
  
  // Cache expiry times (in milliseconds)
  static const int _usageCacheExpiry = 60000; // 1 minute
  static const int _limitCacheExpiry = 300000; // 5 minutes
  
  /// Track usage for a specific feature with server-side validation
  static Future<UsageTrackingResult> trackUsage(
    String userId,
    String featureName, {
    int amount = 1,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('📊 Tracking usage: $featureName for user: $userId (amount: $amount)');

      // Call server-side tracking function for security
      final result = await _functions.httpsCallable('trackUsage').call({
        'userId': userId,
        'featureName': featureName,
        'amount': amount,
        'metadata': metadata,
      });

      final data = result.data as Map<String, dynamic>;
      
      // Update local cache
      _updateUsageCache(userId, featureName, data['currentUsage'] ?? 0);
      
      debugPrint('✅ Usage tracked successfully: $featureName = ${data['currentUsage']}/${data['limit']}');
      
      return UsageTrackingResult(
        success: data['success'] ?? false,
        currentUsage: data['currentUsage'] ?? 0,
        limit: data['limit'] ?? 0,
        percentageUsed: data['percentageUsed'] ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Error tracking usage: $e');
      return UsageTrackingResult(
        success: false,
        currentUsage: 0,
        limit: 0,
        percentageUsed: 0,
        error: e.toString(),
      );
    }
  }

  /// Check if user can perform an action without exceeding limits
  static Future<UsageLimitResult> canUseFeature(
    String userId,
    String featureName, {
    int requestedAmount = 1,
  }) async {
    try {
      debugPrint('🔒 Checking usage limit: $featureName for user: $userId (requested: $requestedAmount)');

      // Check cache first
      final cachedResult = _getCachedLimitCheck(userId, featureName, requestedAmount);
      if (cachedResult != null) {
        debugPrint('💨 Using cached limit check result');
        return cachedResult;
      }

      // Call server-side enforcement function
      final result = await _functions.httpsCallable('enforceUsageLimit').call({
        'userId': userId,
        'featureName': featureName,
        'requestedAmount': requestedAmount,
      });

      final data = result.data as Map<String, dynamic>;
      
      final limitResult = UsageLimitResult(
        allowed: data['allowed'] ?? false,
        currentUsage: data['currentUsage'] ?? 0,
        limit: data['limit'] ?? 0,
        requestedAmount: data['requestedAmount'] ?? requestedAmount,
        tier: data['tier'] ?? 'free',
        wouldExceedLimit: data['wouldExceedLimit'] ?? false,
        percentageUsed: data['percentageUsed'] ?? 0,
        remainingUsage: data['remainingUsage'] ?? 0,
      );

      // Cache the result
      _cacheLimitResult(userId, featureName, limitResult);
      
      debugPrint('✅ Usage limit check: ${limitResult.allowed ? 'ALLOWED' : 'DENIED'} (${limitResult.currentUsage}/${limitResult.limit})');
      
      return limitResult;
    } catch (e) {
      debugPrint('❌ Error checking usage limit: $e');
      // Fail secure - deny access on error
      return UsageLimitResult(
        allowed: false,
        currentUsage: 0,
        limit: 0,
        requestedAmount: requestedAmount,
        tier: 'free',
        wouldExceedLimit: true,
        percentageUsed: 100,
        remainingUsage: 0,
        error: e.toString(),
      );
    }
  }

  /// Track usage and enforce limits in a single operation
  static Future<TrackAndEnforceResult> trackAndEnforce(
    String userId,
    String featureName, {
    int amount = 1,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🔄 Track and enforce: $featureName for user: $userId');

      // First check if the action is allowed
      final limitResult = await canUseFeature(userId, featureName, requestedAmount: amount);
      
      if (!limitResult.allowed) {
        debugPrint('❌ Action denied by usage limits');
        return TrackAndEnforceResult(
          allowed: false,
          usageResult: UsageTrackingResult(
            success: false,
            currentUsage: limitResult.currentUsage,
            limit: limitResult.limit,
            percentageUsed: limitResult.percentageUsed,
          ),
          limitResult: limitResult,
          reason: 'Usage limit exceeded',
        );
      }

      // Track the usage
      final trackingResult = await trackUsage(userId, featureName, amount: amount, metadata: metadata);
      
      if (!trackingResult.success) {
        debugPrint('❌ Failed to track usage');
        return TrackAndEnforceResult(
          allowed: false,
          usageResult: trackingResult,
          limitResult: limitResult,
          reason: 'Failed to track usage',
        );
      }

      debugPrint('✅ Track and enforce completed successfully');
      return TrackAndEnforceResult(
        allowed: true,
        usageResult: trackingResult,
        limitResult: limitResult,
      );
    } catch (e) {
      debugPrint('❌ Error in track and enforce: $e');
      return TrackAndEnforceResult(
        allowed: false,
        usageResult: UsageTrackingResult(success: false, currentUsage: 0, limit: 0, percentageUsed: 0),
        limitResult: UsageLimitResult(
          allowed: false,
          currentUsage: 0,
          limit: 0,
          requestedAmount: amount,
          tier: 'free',
          wouldExceedLimit: true,
          percentageUsed: 100,
          remainingUsage: 0,
        ),
        reason: 'System error',
        error: e.toString(),
      );
    }
  }

  /// Get comprehensive usage analytics for a user
  static Future<UsageAnalytics?> getUserAnalytics(
    String userId, {
    int months = 6,
  }) async {
    try {
      debugPrint('📈 Getting usage analytics for user: $userId');

      final result = await _functions.httpsCallable('getUserUsageAnalytics').call({
        'userId': userId,
        'months': months,
      });

      final data = result.data as Map<String, dynamic>;
      
      return UsageAnalytics.fromMap(data);
    } catch (e) {
      debugPrint('❌ Error getting usage analytics: $e');
      return null;
    }
  }

  /// Get current usage for specific features
  static Future<Map<String, int>> getCurrentUsage(String userId, List<String> features) async {
    try {
      final usage = <String, int>{};
      
      // Check cache first
      bool hasAllCached = true;
      for (final feature in features) {
        final cached = _getCachedUsage(userId, feature);
        if (cached != null) {
          usage[feature] = cached;
        } else {
          hasAllCached = false;
          break;
        }
      }
      
      if (hasAllCached) {
        debugPrint('💨 Using cached usage data');
        return usage;
      }

      // Get from server if not cached
      final doc = await _firestore.collection('usage_tracking').doc(userId).get();
      
      if (!doc.exists) {
        debugPrint('🆕 No usage data found for user');
        return {};
      }

      final data = doc.data() as Map<String, dynamic>;
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final monthlyData = data[currentMonth] as Map<String, dynamic>? ?? {};

      for (final feature in features) {
        final featureUsage = monthlyData[feature] as int? ?? 0;
        usage[feature] = featureUsage;
        _updateUsageCache(userId, feature, featureUsage);
      }

      return usage;
    } catch (e) {
      debugPrint('❌ Error getting current usage: $e');
      return {};
    }
  }

  /// Stream real-time usage updates for a user
  static Stream<Map<String, dynamic>> streamUserUsage(String userId) {
    return _firestore
        .collection('usage_tracking')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return <String, dynamic>{};
          
          final data = snapshot.data() as Map<String, dynamic>;
          final now = DateTime.now();
          final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
          
          return data[currentMonth] as Map<String, dynamic>? ?? <String, dynamic>{};
        });
  }

  /// Clear usage cache for a user (useful after subscription changes)
  static void clearUserCache(String userId) {
    _usageCache.removeWhere((key, value) => key.startsWith('${userId}_'));
    _limitCache.removeWhere((key, value) => key.startsWith('${userId}_'));
    debugPrint('🧹 Cleared cache for user: $userId');
  }

  /// Clear all caches
  static void clearAllCaches() {
    _usageCache.clear();
    _limitCache.clear();
    debugPrint('🧹 Cleared all usage caches');
  }

  // PRIVATE HELPER METHODS

  static void _updateUsageCache(String userId, String featureName, int usage) {
    final key = '${userId}_$featureName';
    _usageCache[key] = _CachedUsageData(
      usage: usage,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static int? _getCachedUsage(String userId, String featureName) {
    final key = '${userId}_$featureName';
    final cached = _usageCache[key];
    
    if (cached == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cached.timestamp > _usageCacheExpiry) {
      _usageCache.remove(key);
      return null;
    }
    
    return cached.usage;
  }

  static void _cacheLimitResult(String userId, String featureName, UsageLimitResult result) {
    final key = '${userId}_$featureName';
    _limitCache[key] = _CachedLimitData(
      result: result,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static UsageLimitResult? _getCachedLimitCheck(String userId, String featureName, int requestedAmount) {
    final key = '${userId}_$featureName';
    final cached = _limitCache[key];
    
    if (cached == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cached.timestamp > _limitCacheExpiry) {
      _limitCache.remove(key);
      return null;
    }
    
    // Only use cached result if requested amount matches
    if (cached.result.requestedAmount == requestedAmount) {
      return cached.result;
    }
    
    return null;
  }
}

// CACHE DATA CLASSES

class _CachedUsageData {
  final int usage;
  final int timestamp;

  _CachedUsageData({
    required this.usage,
    required this.timestamp,
  });
}

class _CachedLimitData {
  final UsageLimitResult result;
  final int timestamp;

  _CachedLimitData({
    required this.result,
    required this.timestamp,
  });
}

// RESULT CLASSES

class UsageTrackingResult {
  final bool success;
  final int currentUsage;
  final int limit;
  final int percentageUsed;
  final String? error;

  UsageTrackingResult({
    required this.success,
    required this.currentUsage,
    required this.limit,
    required this.percentageUsed,
    this.error,
  });

  bool get isNearLimit => percentageUsed >= 80;
  bool get isAtLimit => percentageUsed >= 100;
  int get remainingUsage => limit > 0 ? (limit - currentUsage).clamp(0, limit) : -1;
}

class UsageLimitResult {
  final bool allowed;
  final int currentUsage;
  final int limit;
  final int requestedAmount;
  final String tier;
  final bool wouldExceedLimit;
  final int percentageUsed;
  final int remainingUsage;
  final String? error;

  UsageLimitResult({
    required this.allowed,
    required this.currentUsage,
    required this.limit,
    required this.requestedAmount,
    required this.tier,
    required this.wouldExceedLimit,
    required this.percentageUsed,
    required this.remainingUsage,
    this.error,
  });

  bool get isUnlimited => limit == -1;
  bool get isNearLimit => !isUnlimited && percentageUsed >= 80;
  bool get isAtLimit => !isUnlimited && percentageUsed >= 100;
}

class TrackAndEnforceResult {
  final bool allowed;
  final UsageTrackingResult usageResult;
  final UsageLimitResult limitResult;
  final String? reason;
  final String? error;

  TrackAndEnforceResult({
    required this.allowed,
    required this.usageResult,
    required this.limitResult,
    this.reason,
    this.error,
  });
}

class UsageAnalytics {
  final String userId;
  final DateTime generatedAt;
  final Map<String, Map<String, dynamic>> monthlyUsage;
  final Map<String, List<TrendData>> trends;
  final List<UsageAlert> alerts;
  final List<UsageRecommendation> recommendations;
  final TierInfo tierInfo;

  UsageAnalytics({
    required this.userId,
    required this.generatedAt,
    required this.monthlyUsage,
    required this.trends,
    required this.alerts,
    required this.recommendations,
    required this.tierInfo,
  });

  factory UsageAnalytics.fromMap(Map<String, dynamic> map) {
    return UsageAnalytics(
      userId: map['userId'] ?? '',
      generatedAt: DateTime.now(), // Simplified for this example
      monthlyUsage: Map<String, Map<String, dynamic>>.from(map['monthlyUsage'] ?? {}),
      trends: _parseTrends(map['trends'] ?? {}),
      alerts: _parseAlerts(map['alerts'] ?? []),
      recommendations: _parseRecommendations(map['recommendations'] ?? []),
      tierInfo: TierInfo.fromMap(map['tierInfo'] ?? {}),
    );
  }

  static Map<String, List<TrendData>> _parseTrends(Map<String, dynamic> trendsMap) {
    final trends = <String, List<TrendData>>{};
    
    for (final entry in trendsMap.entries) {
      final trendList = entry.value as List? ?? [];
      trends[entry.key] = trendList
          .map((item) => TrendData.fromMap(item as Map<String, dynamic>))
          .toList();
    }
    
    return trends;
  }

  static List<UsageAlert> _parseAlerts(List<dynamic> alertsList) {
    return alertsList
        .map((item) => UsageAlert.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static List<UsageRecommendation> _parseRecommendations(List<dynamic> recList) {
    return recList
        .map((item) => UsageRecommendation.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}

class TrendData {
  final String month;
  final int usage;
  final int limit;
  final int percentage;

  TrendData({
    required this.month,
    required this.usage,
    required this.limit,
    required this.percentage,
  });

  factory TrendData.fromMap(Map<String, dynamic> map) {
    return TrendData(
      month: map['month'] ?? '',
      usage: map['usage'] ?? 0,
      limit: map['limit'] ?? 0,
      percentage: map['percentage'] ?? 0,
    );
  }
}

class UsageAlert {
  final String id;
  final String userId;
  final String featureName;
  final int currentUsage;
  final int limit;
  final int percentage;
  final DateTime timestamp;

  UsageAlert({
    required this.id,
    required this.userId,
    required this.featureName,
    required this.currentUsage,
    required this.limit,
    required this.percentage,
    required this.timestamp,
  });

  factory UsageAlert.fromMap(Map<String, dynamic> map) {
    return UsageAlert(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      featureName: map['featureName'] ?? '',
      currentUsage: map['currentUsage'] ?? 0,
      limit: map['limit'] ?? 0,
      percentage: map['percentage'] ?? 0,
      timestamp: DateTime.now(), // Simplified
    );
  }
}

class UsageRecommendation {
  final String type;
  final String feature;
  final String message;
  final String priority;

  UsageRecommendation({
    required this.type,
    required this.feature,
    required this.message,
    required this.priority,
  });

  factory UsageRecommendation.fromMap(Map<String, dynamic> map) {
    return UsageRecommendation(
      type: map['type'] ?? '',
      feature: map['feature'] ?? '',
      message: map['message'] ?? '',
      priority: map['priority'] ?? 'low',
    );
  }

  bool get isHighPriority => priority == 'high';
  bool get isMediumPriority => priority == 'medium';
}

class TierInfo {
  final String currentTier;
  final Map<String, int> limits;
  final bool upgradeRecommended;

  TierInfo({
    required this.currentTier,
    required this.limits,
    required this.upgradeRecommended,
  });

  factory TierInfo.fromMap(Map<String, dynamic> map) {
    return TierInfo(
      currentTier: map['currentTier'] ?? 'free',
      limits: Map<String, int>.from(map['limits'] ?? {}),
      upgradeRecommended: map['upgradeRecommended'] ?? false,
    );
  }
}