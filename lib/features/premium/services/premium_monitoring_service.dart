import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'premium_error_handler.dart';

/// 🔒 SECURE: Comprehensive monitoring and debugging service for premium operations
/// 
/// This service provides:
/// - Performance monitoring and metrics collection
/// - Real-time operation tracking and analytics
/// - Debug information collection for testing real flows
/// - Error rate monitoring and alerting
/// - User behavior analytics for premium features
/// - System health monitoring
/// - Comprehensive error reporting and analytics
class PremiumMonitoringService {
  static final PremiumMonitoringService _instance = PremiumMonitoringService._internal();
  static PremiumMonitoringService get instance => _instance;
  
  final _logger = PremiumLogger.instance;
  final _firestore = FirebaseFirestore.instance;
  final _metrics = <String, OperationMetric>{};
  final _userSessions = <String, UserSession>{};
  final _performanceData = <PerformanceEntry>[];
  
  Timer? _metricsFlushTimer;
  Timer? _healthCheckTimer;
  
  PremiumMonitoringService._internal();
  
  /// Initialize monitoring service
  Future<void> initialize() async {
    final operationId = 'monitoring_init_${DateTime.now().millisecondsSinceEpoch}';
    
    await _logger.logOperation(
      operationId: operationId,
      operationName: 'initializeMonitoring',
      level: LogLevel.info,
      message: 'Initializing premium monitoring service',
    );
    
    // Start periodic metrics flushing
    _metricsFlushTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _flushMetrics(),
    );
    
    // Start health checks
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _performHealthCheck(),
    );
    
    await _logger.logOperation(
      operationId: operationId,
      operationName: 'initializeMonitoring',
      level: LogLevel.info,
      message: 'Premium monitoring service initialized',
    );
  }
  
  /// Dispose monitoring resources
  void dispose() {
    _metricsFlushTimer?.cancel();
    _healthCheckTimer?.cancel();
    _flushMetrics(); // Final flush
  }
  
  /// Track operation performance
  Future<T> trackOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    required String userId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final startTime = DateTime.now();
    final operationId = 'tracked_${startTime.microsecondsSinceEpoch}';
    
    // Initialize or update metric
    final metric = _metrics[operationName] ?? OperationMetric(
      operationName: operationName,
      totalCalls: 0,
      successfulCalls: 0,
      failedCalls: 0,
      totalDuration: Duration.zero,
      averageResponseTime: Duration.zero,
      lastCalled: startTime,
      errorTypes: {},
    );
    
    metric.totalCalls++;
    metric.lastCalled = startTime;
    
    try {
      // Execute operation
      final result = await operation();
      
      // Calculate performance metrics
      final duration = DateTime.now().difference(startTime);
      metric.successfulCalls++;
      metric.totalDuration = metric.totalDuration + duration;
      metric.averageResponseTime = Duration(
        milliseconds: metric.totalDuration.inMilliseconds ~/ metric.totalCalls,
      );
      
      // Store performance entry
      _performanceData.add(PerformanceEntry(
        operationId: operationId,
        operationName: operationName,
        userId: userId,
        startTime: startTime,
        duration: duration,
        success: true,
        metadata: metadata,
      ));
      
      // Update user session
      _updateUserSession(userId, operationName, true, duration);
      
      // Log detailed performance data for debugging
      await _logger.logOperation(
        operationId: operationId,
        operationName: operationName,
        level: LogLevel.debug,
        message: 'Operation completed successfully',
        context: {
          'user_id': userId,
          'duration_ms': duration.inMilliseconds,
          'operation_count': metric.totalCalls,
          'success_rate': (metric.successfulCalls / metric.totalCalls * 100).toStringAsFixed(2),
          'avg_response_time_ms': metric.averageResponseTime.inMilliseconds,
          ...metadata,
        },
      );
      
      _metrics[operationName] = metric;
      return result;
      
    } catch (error) {
      // Calculate performance metrics for failed operation
      final duration = DateTime.now().difference(startTime);
      metric.failedCalls++;
      metric.totalDuration = metric.totalDuration + duration;
      metric.averageResponseTime = Duration(
        milliseconds: metric.totalDuration.inMilliseconds ~/ metric.totalCalls,
      );
      
      // Track error types
      final errorType = error is PremiumError ? error.type.name : 'unknown';
      metric.errorTypes[errorType] = (metric.errorTypes[errorType] ?? 0) + 1;
      
      // Store performance entry
      _performanceData.add(PerformanceEntry(
        operationId: operationId,
        operationName: operationName,
        userId: userId,
        startTime: startTime,
        duration: duration,
        success: false,
        error: error,
        metadata: metadata,
      ));
      
      // Update user session
      _updateUserSession(userId, operationName, false, duration);
      
      // Log detailed error information
      await _logger.logOperation(
        operationId: operationId,
        operationName: operationName,
        level: LogLevel.error,
        message: 'Operation failed',
        context: {
          'user_id': userId,
          'duration_ms': duration.inMilliseconds,
          'operation_count': metric.totalCalls,
          'success_rate': (metric.successfulCalls / metric.totalCalls * 100).toStringAsFixed(2),
          'error_rate': (metric.failedCalls / metric.totalCalls * 100).toStringAsFixed(2),
          'error_type': errorType,
          ...metadata,
        },
        error: error is PremiumError ? error : PremiumError.unknown('Tracked operation failed: $error'),
      );
      
      _metrics[operationName] = metric;
      rethrow;
    }
  }
  
  /// Record user interaction for analytics
  Future<void> recordUserInteraction({
    required String userId,
    required String interactionType,
    required String feature,
    Map<String, dynamic> properties = const {},
  }) async {
    try {
      await _logger.logOperation(
        operationId: 'interaction_${DateTime.now().microsecondsSinceEpoch}',
        operationName: 'userInteraction',
        level: LogLevel.info,
        message: 'User interaction recorded',
        context: {
          'user_id': userId,
          'interaction_type': interactionType,
          'feature': feature,
          'properties': properties,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Update user session
      final session = _getUserSession(userId);
      session.interactions.add(UserInteraction(
        interactionType: interactionType,
        feature: feature,
        timestamp: DateTime.now(),
        properties: properties,
      ));
      
    } catch (error) {
      // Fail silently to avoid disrupting user experience
      debugPrint('Failed to record user interaction: $error');
    }
  }
  
  /// Get comprehensive analytics report
  Future<Map<String, dynamic>> getAnalyticsReport({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    List<String>? operations,
  }) async {
    final operationId = 'analytics_report_${DateTime.now().millisecondsSinceEpoch}';
    
    await _logger.logOperation(
      operationId: operationId,
      operationName: 'generateAnalyticsReport',
      level: LogLevel.info,
      message: 'Generating analytics report',
      context: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'user_id': userId,
        'operations': operations,
      },
    );
    
    final report = <String, dynamic>{
      'generated_at': DateTime.now().toIso8601String(),
      'period': {
        'start': startDate?.toIso8601String(),
        'end': endDate?.toIso8601String(),
      },
      'operations': {},
      'user_sessions': {},
      'performance_summary': {},
      'error_analysis': {},
      'system_health': await _getSystemHealthMetrics(),
    };
    
    // Filter performance data
    final filteredData = _performanceData.where((entry) {
      bool withinTimeRange = true;
      if (startDate != null && entry.startTime.isBefore(startDate)) {
        withinTimeRange = false;
      }
      if (endDate != null && entry.startTime.isAfter(endDate)) {
        withinTimeRange = false;
      }
      
      bool matchesUser = userId == null || entry.userId == userId;
      bool matchesOperation = operations == null || operations.contains(entry.operationName);
      
      return withinTimeRange && matchesUser && matchesOperation;
    }).toList();
    
    // Generate operation analytics
    final operationAnalytics = <String, dynamic>{};
    for (final operationName in _metrics.keys) {
      final metric = _metrics[operationName]!;
      operationAnalytics[operationName] = {
        'total_calls': metric.totalCalls,
        'successful_calls': metric.successfulCalls,
        'failed_calls': metric.failedCalls,
        'success_rate': metric.totalCalls > 0 
            ? (metric.successfulCalls / metric.totalCalls * 100).toStringAsFixed(2)
            : '0.00',
        'average_response_time_ms': metric.averageResponseTime.inMilliseconds,
        'total_duration_ms': metric.totalDuration.inMilliseconds,
        'last_called': metric.lastCalled.toIso8601String(),
        'error_breakdown': metric.errorTypes,
      };
    }
    report['operations'] = operationAnalytics;
    
    // Generate performance summary
    final performanceSummary = _generatePerformanceSummary(filteredData);
    report['performance_summary'] = performanceSummary;
    
    // Generate error analysis
    final errorAnalysis = _generateErrorAnalysis(filteredData);
    report['error_analysis'] = errorAnalysis;
    
    // Generate user session analytics if specific user
    if (userId != null && _userSessions.containsKey(userId)) {
      final session = _userSessions[userId]!;
      report['user_sessions'][userId] = {
        'session_start': session.sessionStart.toIso8601String(),
        'last_activity': session.lastActivity.toIso8601String(),
        'total_operations': session.operationCount,
        'successful_operations': session.successfulOperations,
        'failed_operations': session.failedOperations,
        'session_duration_ms': DateTime.now().difference(session.sessionStart).inMilliseconds,
        'interactions': session.interactions.map((i) => {
          'type': i.interactionType,
          'feature': i.feature,
          'timestamp': i.timestamp.toIso8601String(),
          'properties': i.properties,
        }).toList(),
      };
    }
    
    await _logger.logOperation(
      operationId: operationId,
      operationName: 'generateAnalyticsReport',
      level: LogLevel.info,
      message: 'Analytics report generated successfully',
      context: {
        'total_operations': filteredData.length,
        'unique_operation_types': filteredData.map((e) => e.operationName).toSet().length,
        'report_size_bytes': json.encode(report).length,
      },
    );
    
    return report;
  }
  
  /// Get real-time debug information
  Map<String, dynamic> getDebugInformation() {
    return {
      'monitoring_status': {
        'active_metrics': _metrics.length,
        'active_sessions': _userSessions.length,
        'performance_entries': _performanceData.length,
        'uptime_ms': DateTime.now().millisecondsSinceEpoch,
      },
      'current_metrics': _metrics.map((name, metric) => MapEntry(name, {
        'total_calls': metric.totalCalls,
        'success_rate': metric.totalCalls > 0 
            ? (metric.successfulCalls / metric.totalCalls * 100).toStringAsFixed(2)
            : '0.00',
        'avg_response_ms': metric.averageResponseTime.inMilliseconds,
        'last_called': metric.lastCalled.toIso8601String(),
      })),
      'recent_performance': _performanceData
          .where((entry) => DateTime.now().difference(entry.startTime).inMinutes < 10)
          .map((entry) => {
            'operation': entry.operationName,
            'duration_ms': entry.duration.inMilliseconds,
            'success': entry.success,
            'timestamp': entry.startTime.toIso8601String(),
          })
          .toList(),
      'error_rates': _calculateErrorRates(),
    };
  }
  
  /// Helper methods
  void _updateUserSession(String userId, String operationName, bool success, Duration duration) {
    final session = _getUserSession(userId);
    session.lastActivity = DateTime.now();
    session.operationCount++;
    
    if (success) {
      session.successfulOperations++;
    } else {
      session.failedOperations++;
    }
  }
  
  UserSession _getUserSession(String userId) {
    return _userSessions.putIfAbsent(userId, () => UserSession(
      userId: userId,
      sessionStart: DateTime.now(),
      lastActivity: DateTime.now(),
      operationCount: 0,
      successfulOperations: 0,
      failedOperations: 0,
      interactions: [],
    ));
  }
  
  Future<void> _flushMetrics() async {
    if (_performanceData.isEmpty) return;
    
    try {
      // In production, send metrics to external analytics service
      // For debugging, log to Firestore (in chunks to avoid document size limits)
      if (kDebugMode && _performanceData.isNotEmpty) {
        final chunk = _performanceData.take(50).toList();
        
        await _firestore
            .collection('premium_metrics')
            .add({
              'timestamp': DateTime.now().toIso8601String(),
              'entries': chunk.map((entry) => {
                'operation_id': entry.operationId,
                'operation_name': entry.operationName,
                'user_id': entry.userId,
                'start_time': entry.startTime.toIso8601String(),
                'duration_ms': entry.duration.inMilliseconds,
                'success': entry.success,
                'error': entry.error?.toString(),
                'metadata': entry.metadata,
              }).toList(),
            });
        
        _performanceData.removeRange(0, chunk.length);
      }
    } catch (error) {
      debugPrint('Failed to flush metrics: $error');
    }
  }
  
  Future<void> _performHealthCheck() async {
    final healthMetrics = await _getSystemHealthMetrics();
    
    await _logger.logOperation(
      operationId: 'health_check_${DateTime.now().millisecondsSinceEpoch}',
      operationName: 'systemHealthCheck',
      level: LogLevel.info,
      message: 'System health check completed',
      context: healthMetrics,
    );
  }
  
  Future<Map<String, dynamic>> _getSystemHealthMetrics() async {
    final now = DateTime.now();
    final lastHour = now.subtract(const Duration(hours: 1));
    
    final recentEntries = _performanceData
        .where((entry) => entry.startTime.isAfter(lastHour))
        .toList();
    
    final totalOperations = recentEntries.length;
    final successfulOperations = recentEntries.where((e) => e.success).length;
    final errorRate = totalOperations > 0 
        ? ((totalOperations - successfulOperations) / totalOperations * 100)
        : 0.0;
    
    return {
      'timestamp': now.toIso8601String(),
      'operations_last_hour': totalOperations,
      'error_rate_percentage': errorRate.toStringAsFixed(2),
      'active_metrics': _metrics.length,
      'active_user_sessions': _userSessions.length,
      'performance_entries_cached': _performanceData.length,
      'memory_usage': {
        'metrics_count': _metrics.length,
        'sessions_count': _userSessions.length,
        'performance_entries': _performanceData.length,
      },
    };
  }
  
  Map<String, dynamic> _generatePerformanceSummary(List<PerformanceEntry> entries) {
    if (entries.isEmpty) return {};
    
    final durations = entries.map((e) => e.duration.inMilliseconds).toList();
    durations.sort();
    
    final successful = entries.where((e) => e.success).length;
    
    return {
      'total_operations': entries.length,
      'successful_operations': successful,
      'success_rate': (successful / entries.length * 100).toStringAsFixed(2),
      'average_duration_ms': durations.reduce((a, b) => a + b) ~/ durations.length,
      'median_duration_ms': durations[durations.length ~/ 2],
      'p95_duration_ms': durations[(durations.length * 0.95).round() - 1],
      'p99_duration_ms': durations[(durations.length * 0.99).round() - 1],
      'fastest_operation_ms': durations.first,
      'slowest_operation_ms': durations.last,
    };
  }
  
  Map<String, dynamic> _generateErrorAnalysis(List<PerformanceEntry> entries) {
    final errors = entries.where((e) => !e.success && e.error != null).toList();
    
    if (errors.isEmpty) return {'error_count': 0};
    
    final errorTypes = <String, int>{};
    final errorOperations = <String, int>{};
    
    for (final error in errors) {
      final errorType = error.error is PremiumError 
          ? (error.error as PremiumError).type.name 
          : 'unknown';
      
      errorTypes[errorType] = (errorTypes[errorType] ?? 0) + 1;
      errorOperations[error.operationName] = (errorOperations[error.operationName] ?? 0) + 1;
    }
    
    return {
      'error_count': errors.length,
      'error_rate': (errors.length / entries.length * 100).toStringAsFixed(2),
      'error_types': errorTypes,
      'errors_by_operation': errorOperations,
      'most_common_error': errorTypes.entries
          .reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }
  
  Map<String, double> _calculateErrorRates() {
    final errorRates = <String, double>{};
    
    for (final entry in _metrics.entries) {
      final metric = entry.value;
      final errorRate = metric.totalCalls > 0 
          ? (metric.failedCalls / metric.totalCalls * 100)
          : 0.0;
      errorRates[entry.key] = errorRate;
    }
    
    return errorRates;
  }
}

/// Operation performance metric
class OperationMetric {
  String operationName;
  int totalCalls;
  int successfulCalls;
  int failedCalls;
  Duration totalDuration;
  Duration averageResponseTime;
  DateTime lastCalled;
  Map<String, int> errorTypes;
  
  OperationMetric({
    required this.operationName,
    required this.totalCalls,
    required this.successfulCalls,
    required this.failedCalls,
    required this.totalDuration,
    required this.averageResponseTime,
    required this.lastCalled,
    required this.errorTypes,
  });
}

/// User session tracking
class UserSession {
  final String userId;
  final DateTime sessionStart;
  DateTime lastActivity;
  int operationCount;
  int successfulOperations;
  int failedOperations;
  List<UserInteraction> interactions;
  
  UserSession({
    required this.userId,
    required this.sessionStart,
    required this.lastActivity,
    required this.operationCount,
    required this.successfulOperations,
    required this.failedOperations,
    required this.interactions,
  });
}

/// User interaction tracking
class UserInteraction {
  final String interactionType;
  final String feature;
  final DateTime timestamp;
  final Map<String, dynamic> properties;
  
  UserInteraction({
    required this.interactionType,
    required this.feature,
    required this.timestamp,
    required this.properties,
  });
}

/// Performance entry for detailed tracking
class PerformanceEntry {
  final String operationId;
  final String operationName;
  final String userId;
  final DateTime startTime;
  final Duration duration;
  final bool success;
  final dynamic error;
  final Map<String, dynamic> metadata;
  
  PerformanceEntry({
    required this.operationId,
    required this.operationName,
    required this.userId,
    required this.startTime,
    required this.duration,
    required this.success,
    this.error,
    required this.metadata,
  });
}