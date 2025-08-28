import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'usage_tracking_service.dart';
import 'subscription_service.dart';

/// Comprehensive debugging and testing service for premium features
/// This service provides extensive logging, testing utilities, and debugging tools
/// for real subscription flow testing and troubleshooting
class PremiumDebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Debug logging configuration
  static bool _isDebugEnabled = kDebugMode;
  static final List<DebugLog> _debugLogs = [];
  static const int _maxLogEntries = 1000;
  
  // Test data and scenarios
  static final Map<String, TestScenario> _testScenarios = {};
  
  /// Enable or disable debug logging
  static void setDebugEnabled(bool enabled) {
    _isDebugEnabled = enabled;
    _log('Debug logging ${enabled ? 'enabled' : 'disabled'}', DebugLevel.info);
  }
  
  /// Get all debug logs
  static List<DebugLog> getDebugLogs() => List.unmodifiable(_debugLogs);
  
  /// Clear all debug logs
  static void clearLogs() {
    _debugLogs.clear();
    _log('Debug logs cleared', DebugLevel.info);
  }
  
  /// Export debug logs as JSON
  static String exportLogsAsJson() {
    final logsData = _debugLogs.map((log) => log.toMap()).toList();
    return jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'totalLogs': logsData.length,
      'logs': logsData,
    });
  }
  
  /// Test a complete subscription flow end-to-end
  static Future<SubscriptionFlowTestResult> testSubscriptionFlow(
    String userId,
    String userType, {
    bool includeUsageTracking = true,
    bool testFailureScenarios = false,
  }) async {
    _log('🧪 Starting complete subscription flow test', DebugLevel.info);
    
    final testResult = SubscriptionFlowTestResult(
      userId: userId,
      userType: userType,
      startTime: DateTime.now(),
    );
    
    try {
      // Step 1: Check initial subscription state
      _log('📋 Step 1: Checking initial subscription state', DebugLevel.test);
      testResult.steps.add(await _testStep('Initial Subscription Check', () async {
        final subscription = await SubscriptionService.getUserSubscription(userId);
        return {
          'hasSubscription': subscription != null,
          'tier': subscription?.tier.name ?? 'none',
          'status': subscription?.status ?? 'none',
        };
      }));
      
      // Step 2: Test feature access validation
      _log('🔐 Step 2: Testing feature access validation', DebugLevel.test);
      final testFeatures = _getTestFeatures(userType);
      for (final feature in testFeatures) {
        testResult.steps.add(await _testStep('Feature Access: $feature', () async {
          final hasAccess = await SubscriptionService.hasFeature(userId, feature);
          return {'feature': feature, 'hasAccess': hasAccess};
        }));
      }
      
      // Step 3: Test usage limit enforcement
      if (includeUsageTracking) {
        _log('📊 Step 3: Testing usage limit enforcement', DebugLevel.test);
        final testLimits = _getTestLimits(userType);
        for (final limit in testLimits) {
          testResult.steps.add(await _testStep('Usage Limit: $limit', () async {
            final limitResult = await UsageTrackingService.canUseFeature(userId, limit);
            return {
              'feature': limit,
              'allowed': limitResult.allowed,
              'currentUsage': limitResult.currentUsage,
              'limit': limitResult.limit,
              'percentageUsed': limitResult.percentageUsed,
            };
          }));
        }
      }
      
      // Step 4: Test usage tracking
      if (includeUsageTracking) {
        _log('📈 Step 4: Testing usage tracking', DebugLevel.test);
        for (final feature in _getTestLimits(userType)) {
          testResult.steps.add(await _testStep('Track Usage: $feature', () async {
            final trackResult = await UsageTrackingService.trackUsage(
              userId,
              feature,
              metadata: {'testRun': true, 'timestamp': DateTime.now().toIso8601String()},
            );
            return {
              'feature': feature,
              'success': trackResult.success,
              'newUsage': trackResult.currentUsage,
              'limit': trackResult.limit,
              'error': trackResult.error,
            };
          }));
        }
      }
      
      // Step 5: Test server-side validation
      _log('🔧 Step 5: Testing server-side validation', DebugLevel.test);
      testResult.steps.add(await _testStep('Server Validation', () async {
        final result = await _functions.httpsCallable('validateFeatureAccess').call({
          'userId': userId,
          'featureName': testFeatures.first,
        });
        
        return {
          'serverValidation': result.data,
        };
      }));
      
      // Step 6: Test analytics retrieval
      _log('📊 Step 6: Testing analytics retrieval', DebugLevel.test);
      testResult.steps.add(await _testStep('Analytics Retrieval', () async {
        final analytics = await UsageTrackingService.getUserAnalytics(userId);
        return {
          'analyticsAvailable': analytics != null,
          'recommendationsCount': analytics?.recommendations.length ?? 0,
          'alertsCount': analytics?.alerts.length ?? 0,
        };
      }));
      
      // Step 7: Test failure scenarios (if enabled)
      if (testFailureScenarios) {
        _log('⚠️ Step 7: Testing failure scenarios', DebugLevel.test);
        testResult.steps.add(await _testStep('Invalid User Test', () async {
          try {
            await SubscriptionService.hasFeature('invalid-user-id', testFeatures.first);
            return {'error': 'Should have failed but did not'};
          } catch (e) {
            return {'expectedError': e.toString()};
          }
        }));
      }
      
      testResult.endTime = DateTime.now();
      testResult.success = testResult.steps.every((step) => step.success);
      testResult.duration = testResult.endTime!.difference(testResult.startTime);
      
      _log('✅ Subscription flow test completed: ${testResult.success ? 'PASSED' : 'FAILED'}', 
           testResult.success ? DebugLevel.success : DebugLevel.error);
      
      return testResult;
    } catch (e) {
      testResult.endTime = DateTime.now();
      testResult.success = false;
      testResult.error = e.toString();
      testResult.duration = testResult.endTime!.difference(testResult.startTime);
      
      _log('❌ Subscription flow test failed: $e', DebugLevel.error);
      return testResult;
    }
  }
  
  /// Test payment processing scenarios
  static Future<PaymentTestResult> testPaymentScenarios(String userId) async {
    _log('💳 Starting payment processing tests', DebugLevel.info);
    
    final testResult = PaymentTestResult(
      userId: userId,
      startTime: DateTime.now(),
    );
    
    try {
      // Test 1: Create checkout session
      testResult.steps.add(await _testStep('Create Checkout Session', () async {
        final result = await _functions.httpsCallable('createCheckoutSession').call({
          'userId': userId,
          'userType': 'vendor',
          'priceId': 'price_test_\${userId.substring(0, 8)}',
          'customerEmail': 'test+\${userId.substring(0, 8)}@example.com',
          'successUrl': 'https://test.com/success?userId=\$userId',
          'cancelUrl': 'https://test.com/cancel?userId=\$userId',
          'environment': 'test',
        });
        
        return {
          'sessionCreated': result.data != null,
          'sessionUrl': result.data?['url'],
          'sessionId': result.data?['sessionId'],
        };
      }));
      
      // Test 2: Validate security measures
      testResult.steps.add(await _testStep('Security Validation', () async {
        try {
          // This should fail due to security measures
          await _functions.httpsCallable('createCheckoutSession').call({
            'userId': 'invalid_${DateTime.now().millisecondsSinceEpoch}', // Different user
            'userType': 'vendor',
            'priceId': 'price_test_\${userId.substring(0, 8)}',
            'customerEmail': 'test+\${userId.substring(0, 8)}@example.com',
            'successUrl': 'https://test.com/success',
            'cancelUrl': 'https://test.com/cancel',
            'environment': 'test',
          });
          return {'securityTest': 'FAILED - Should have blocked different user'};
        } catch (e) {
          return {'securityTest': 'PASSED - Correctly blocked unauthorized access'};
        }
      }));
      
      testResult.endTime = DateTime.now();
      testResult.success = testResult.steps.every((step) => step.success);
      testResult.duration = testResult.endTime!.difference(testResult.startTime);
      
      return testResult;
    } catch (e) {
      testResult.endTime = DateTime.now();
      testResult.success = false;
      testResult.error = e.toString();
      testResult.duration = testResult.endTime!.difference(testResult.startTime);
      
      _log('❌ Payment test failed: $e', DebugLevel.error);
      return testResult;
    }
  }
  
  /// Monitor real-time subscription events
  static Stream<SubscriptionEvent> monitorSubscriptionEvents(String userId) {
    _log('👁️ Starting subscription event monitoring for user: $userId', DebugLevel.info);
    
    return _firestore
        .collection('user_subscriptions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return SubscriptionEvent(
          userId: userId,
          eventType: 'subscription_updated',
          timestamp: DateTime.now(),
          data: data,
        );
      } else {
        return SubscriptionEvent(
          userId: userId,
          eventType: 'no_subscription',
          timestamp: DateTime.now(),
          data: {},
        );
      }
    });
  }
  
  /// Monitor usage tracking events
  static Stream<UsageEvent> monitorUsageEvents(String userId) {
    _log('📊 Starting usage event monitoring for user: $userId', DebugLevel.info);
    
    return _firestore
        .collection('usage_tracking')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data() ?? {};
      return UsageEvent(
        userId: userId,
        timestamp: DateTime.now(),
        data: data,
      );
    });
  }
  
  /// Generate comprehensive system health report
  static Future<SystemHealthReport> generateHealthReport() async {
    _log('🏥 Generating system health report', DebugLevel.info);
    
    final report = SystemHealthReport(generatedAt: DateTime.now());
    
    try {
      // Check Firebase Functions health
      report.steps.add(await _testStep('Functions Health Check', () async {
        try {
          final result = await _functions.httpsCallable('generatePerformanceDashboard').call({
            'timeRange': '1h',
            'includeDetails': false,
          });
          
          return {
            'functionsHealthy': true,
            'dashboardData': result.data != null,
          };
        } catch (e) {
          return {
            'functionsHealthy': false,
            'error': e.toString(),
          };
        }
      }));
      
      // Check Firestore connectivity
      report.steps.add(await _testStep('Firestore Connectivity', () async {
        try {
          await _firestore.collection('system_health').doc('test').set({
            'timestamp': FieldValue.serverTimestamp(),
            'test': true,
          });
          
          await _firestore.collection('system_health').doc('test').delete();
          
          return {'firestoreHealthy': true};
        } catch (e) {
          return {
            'firestoreHealthy': false,
            'error': e.toString(),
          };
        }
      }));
      
      // Check recent system alerts
      report.steps.add(await _testStep('System Alerts Check', () async {
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        final alertsSnapshot = await _firestore
            .collection('system_alerts')
            .where('timestamp', isGreaterThan: oneHourAgo)
            .get();
        
        final criticalAlerts = alertsSnapshot.docs
            .where((doc) => doc.data()['severity'] == 'critical')
            .length;
        
        return {
          'totalAlertsLastHour': alertsSnapshot.docs.length,
          'criticalAlerts': criticalAlerts,
          'systemStable': criticalAlerts == 0,
        };
      }));
      
      report.success = report.steps.every((step) => step.success);
      
      _log('✅ System health report completed', DebugLevel.success);
      return report;
    } catch (e) {
      report.success = false;
      report.error = e.toString();
      _log('❌ System health report failed: $e', DebugLevel.error);
      return report;
    }
  }
  
  /// Create a debug UI widget for testing
  static Widget createDebugPanel(BuildContext context, String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Debug Panel',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Test Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _debugButton(
                'Test Subscription Flow',
                () => testSubscriptionFlow(userId, 'vendor'),
                Colors.blue,
              ),
              _debugButton(
                'Test Payment Flow',
                () => testPaymentScenarios(userId),
                Colors.green,
              ),
              _debugButton(
                'Generate Health Report',
                () => generateHealthReport(),
                Colors.purple,
              ),
              _debugButton(
                'Clear Cache',
                () => UsageTrackingService.clearAllCaches(),
                Colors.red,
              ),
              _debugButton(
                'Export Logs',
                () => exportLogsAsJson(),
                Colors.teal,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Log Display
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _debugLogs.length,
              reverse: true,
              itemBuilder: (context, index) {
                final log = _debugLogs[_debugLogs.length - 1 - index];
                return Text(
                  '[${log.timestamp.toString().substring(11, 19)}] ${log.level.name.toUpperCase()}: ${log.message}',
                  style: TextStyle(
                    color: _getLogColor(log.level),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // PRIVATE HELPER METHODS
  
  static void _log(String message, DebugLevel level) {
    if (!_isDebugEnabled) return;
    
    final log = DebugLog(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );
    
    _debugLogs.add(log);
    
    // Keep log size manageable
    if (_debugLogs.length > _maxLogEntries) {
      _debugLogs.removeAt(0);
    }
    
    // Also log to console in debug mode
    if (kDebugMode) {
      debugPrint('[${level.name.toUpperCase()}] $message');
    }
  }
  
  static Future<TestStep> _testStep(String name, Future<Map<String, dynamic>> Function() test) async {
    final startTime = DateTime.now();
    
    try {
      _log('🔄 Running test: $name', DebugLevel.test);
      final result = await test();
      final duration = DateTime.now().difference(startTime);
      
      _log('✅ Test passed: $name (${duration.inMilliseconds}ms)', DebugLevel.success);
      
      return TestStep(
        name: name,
        success: true,
        duration: duration,
        result: result,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      _log('❌ Test failed: $name - $e', DebugLevel.error);
      
      return TestStep(
        name: name,
        success: false,
        duration: duration,
        error: e.toString(),
      );
    }
  }
  
  static List<String> _getTestFeatures(String userType) {
    switch (userType) {
      case 'vendor':
        return ['market_discovery', 'full_vendor_analytics', 'unlimited_markets'];
      case 'market_organizer':
        return ['vendor_discovery', 'multi_market_management', 'financial_reporting'];
      case 'shopper':
        return ['enhanced_search', 'unlimited_favorites', 'personalized_recommendations'];
      default:
        return ['enhanced_search'];
    }
  }
  
  static List<String> _getTestLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return ['monthly_markets', 'photo_uploads_per_post', 'global_products'];
      case 'market_organizer':
        return ['markets_managed', 'events_per_month'];
      case 'shopper':
        return ['saved_favorites'];
      default:
        return ['saved_favorites'];
    }
  }
  
  static Widget _debugButton(String label, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
  
  static Color _getLogColor(DebugLevel level) {
    switch (level) {
      case DebugLevel.error:
        return Colors.red;
      case DebugLevel.warning:
        return Colors.orange;
      case DebugLevel.success:
        return Colors.green;
      case DebugLevel.test:
        return Colors.blue;
      case DebugLevel.info:
        return Colors.white;
    }
  }
}

// DATA CLASSES

enum DebugLevel { info, warning, error, success, test }

class DebugLog {
  final String message;
  final DebugLevel level;
  final DateTime timestamp;

  DebugLog({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'level': level.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TestStep {
  final String name;
  final bool success;
  final Duration duration;
  final Map<String, dynamic>? result;
  final String? error;

  TestStep({
    required this.name,
    required this.success,
    required this.duration,
    this.result,
    this.error,
  });
}

class SubscriptionFlowTestResult {
  final String userId;
  final String userType;
  final DateTime startTime;
  DateTime? endTime;
  Duration? duration;
  bool success = false;
  String? error;
  final List<TestStep> steps = [];

  SubscriptionFlowTestResult({
    required this.userId,
    required this.userType,
    required this.startTime,
  });
}

class PaymentTestResult {
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  Duration? duration;
  bool success = false;
  String? error;
  final List<TestStep> steps = [];

  PaymentTestResult({
    required this.userId,
    required this.startTime,
  });
}

class SystemHealthReport {
  final DateTime generatedAt;
  bool success = false;
  String? error;
  final List<TestStep> steps = [];

  SystemHealthReport({
    required this.generatedAt,
  });
}

class TestScenario {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Function testFunction;

  TestScenario({
    required this.name,
    required this.description,
    required this.parameters,
    required this.testFunction,
  });
}

class SubscriptionEvent {
  final String userId;
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  SubscriptionEvent({
    required this.userId,
    required this.eventType,
    required this.timestamp,
    required this.data,
  });
}

class UsageEvent {
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  UsageEvent({
    required this.userId,
    required this.timestamp,
    required this.data,
  });
}