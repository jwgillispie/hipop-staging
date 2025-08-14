import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

/// 🔍 DEBUG: Comprehensive debugging and logging service for premium features
/// 
/// This service provides:
/// - Detailed debug information for testing real subscription flows
/// - Performance monitoring for subscription operations
/// - Error reporting with stack traces and context
/// - Real-time flow tracking for development and testing
/// - Secure logging that doesn't expose sensitive information
/// - Integration with monitoring infrastructure
class DebugLoggerService {
  static final DebugLoggerService _instance = DebugLoggerService._internal();
  static DebugLoggerService get instance => _instance;
  
  final List<DebugLogEntry> _logBuffer = [];
  final Map<String, FlowTracker> _activeFlows = {};
  static const int _maxLogBufferSize = 1000;
  static const Duration _logFlushInterval = Duration(seconds: 30);
  
  Timer? _flushTimer;
  
  DebugLoggerService._internal() {
    _startPeriodicFlush();
  }
  
  /// Start a new subscription flow for tracking
  FlowTracker startFlow(String flowType, String userId, [Map<String, dynamic>? initialContext]) {
    final flowId = _generateFlowId();
    final tracker = FlowTracker(
      flowId: flowId,
      flowType: flowType,
      userId: userId,
      startTime: DateTime.now(),
      context: initialContext ?? {},
    );
    
    _activeFlows[flowId] = tracker;
    
    logDebug(
      operation: 'flow_start',
      message: 'Started $flowType flow',
      context: {
        'flow_id': flowId,
        'user_id': userId,
        'flow_type': flowType,
        ...?initialContext,
      },
    );
    
    return tracker;
  }
  
  /// Update flow with checkpoint
  void updateFlow(String flowId, String checkpoint, [Map<String, dynamic>? context]) {
    final tracker = _activeFlows[flowId];
    if (tracker == null) {
      logWarning(
        operation: 'flow_update',
        message: 'Attempted to update non-existent flow',
        context: {'flow_id': flowId, 'checkpoint': checkpoint},
      );
      return;
    }
    
    tracker.addCheckpoint(checkpoint, context);
    
    logDebug(
      operation: 'flow_checkpoint',
      message: 'Flow checkpoint: $checkpoint',
      context: {
        'flow_id': flowId,
        'checkpoint': checkpoint,
        'duration_ms': tracker.getDuration().inMilliseconds,
        ...?context,
      },
    );
  }
  
  /// Complete flow tracking
  void completeFlow(String flowId, [Map<String, dynamic>? finalContext]) {
    final tracker = _activeFlows.remove(flowId);
    if (tracker == null) {
      logWarning(
        operation: 'flow_complete',
        message: 'Attempted to complete non-existent flow',
        context: {'flow_id': flowId},
      );
      return;
    }
    
    tracker.markComplete(finalContext);
    
    logInfo(
      operation: 'flow_complete',
      message: 'Completed ${tracker.flowType} flow',
      context: {
        'flow_id': flowId,
        'flow_type': tracker.flowType,
        'duration_ms': tracker.getDuration().inMilliseconds,
        'checkpoints': tracker.checkpoints.length,
        'success': true,
        ...?finalContext,
      },
    );
  }
  
  /// Fail flow tracking
  void failFlow(String flowId, String error, [StackTrace? stackTrace, Map<String, dynamic>? errorContext]) {
    final tracker = _activeFlows.remove(flowId);
    if (tracker == null) {
      logWarning(
        operation: 'flow_fail',
        message: 'Attempted to fail non-existent flow',
        context: {'flow_id': flowId, 'error': error},
      );
      return;
    }
    
    tracker.markFailed(error, errorContext);
    
    logError(
      operation: 'flow_fail',
      message: 'Failed ${tracker.flowType} flow: $error',
      context: {
        'flow_id': flowId,
        'flow_type': tracker.flowType,
        'duration_ms': tracker.getDuration().inMilliseconds,
        'checkpoints': tracker.checkpoints.length,
        'error': error,
        'success': false,
        ...?errorContext,
      },
      stackTrace: stackTrace,
    );
  }
  
  /// Log debug information
  void logDebug({
    required String operation,
    required String message,
    Map<String, dynamic>? context,
    String? userId,
  }) {
    _addLogEntry(DebugLogLevel.debug, operation, message, context, userId);
  }
  
  /// Log info information
  void logInfo({
    required String operation,
    required String message,
    Map<String, dynamic>? context,
    String? userId,
  }) {
    _addLogEntry(DebugLogLevel.info, operation, message, context, userId);
  }
  
  /// Log warning information
  void logWarning({
    required String operation,
    required String message,
    Map<String, dynamic>? context,
    String? userId,
  }) {
    _addLogEntry(DebugLogLevel.warning, operation, message, context, userId);
  }
  
  /// Log error information
  void logError({
    required String operation,
    required String message,
    Map<String, dynamic>? context,
    String? userId,
    StackTrace? stackTrace,
  }) {
    _addLogEntry(DebugLogLevel.error, operation, message, context, userId, stackTrace);
  }
  
  /// Log performance metrics
  void logPerformance({
    required String operation,
    required Duration duration,
    Map<String, dynamic>? metrics,
    String? userId,
  }) {
    _addLogEntry(
      DebugLogLevel.performance,
      operation,
      'Performance metrics for $operation',
      {
        'duration_ms': duration.inMilliseconds,
        'duration_human': _formatDuration(duration),
        ...?metrics,
      },
      userId,
    );
  }
  
  /// Log subscription flow events with detailed context
  void logSubscriptionEvent({
    required String event,
    required String userId,
    String? subscriptionId,
    String? stripeSessionId,
    Map<String, dynamic>? additionalContext,
  }) {
    logInfo(
      operation: 'subscription_event',
      message: 'Subscription event: $event',
      context: {
        'event_type': event,
        'user_id': userId,
        'subscription_id': subscriptionId,
        'stripe_session_id': stripeSessionId,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalContext,
      },
      userId: userId,
    );
  }
  
  /// Log Stripe integration events
  void logStripeEvent({
    required String event,
    required String userId,
    String? priceId,
    String? sessionId,
    String? customerId,
    Map<String, dynamic>? stripeData,
  }) {
    logInfo(
      operation: 'stripe_event',
      message: 'Stripe event: $event',
      context: {
        'event_type': event,
        'user_id': userId,
        'price_id': priceId,
        'session_id': sessionId,
        'customer_id': customerId,
        'timestamp': DateTime.now().toIso8601String(),
        // Redact sensitive Stripe data while keeping useful debugging info
        'stripe_data_keys': stripeData?.keys.toList(),
        'stripe_data_size': stripeData?.length,
      },
      userId: userId,
    );
  }
  
  /// Log network request details
  void logNetworkRequest({
    required String method,
    required String endpoint,
    int? statusCode,
    Duration? responseTime,
    String? errorMessage,
    Map<String, dynamic>? requestHeaders,
    Map<String, dynamic>? responseHeaders,
  }) {
    logDebug(
      operation: 'network_request',
      message: '$method $endpoint${statusCode != null ? ' - $statusCode' : ''}',
      context: {
        'method': method,
        'endpoint': endpoint,
        'status_code': statusCode,
        'response_time_ms': responseTime?.inMilliseconds,
        'error_message': errorMessage,
        'request_headers_count': requestHeaders?.length,
        'response_headers_count': responseHeaders?.length,
        'success': statusCode != null && statusCode >= 200 && statusCode < 300,
      },
    );
  }
  
  /// Get recent debug logs for display in debug screens
  List<DebugLogEntry> getRecentLogs({
    int limit = 100,
    DebugLogLevel? levelFilter,
    String? operationFilter,
    String? userIdFilter,
  }) {
    var filteredLogs = _logBuffer.where((entry) {
      if (levelFilter != null && entry.level != levelFilter) return false;
      if (operationFilter != null && !entry.operation.contains(operationFilter)) return false;
      if (userIdFilter != null && entry.userId != userIdFilter) return false;
      return true;
    }).toList();
    
    // Sort by timestamp descending (newest first)
    filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return filteredLogs.take(limit).toList();
  }
  
  /// Get active flows for monitoring
  List<FlowTracker> getActiveFlows() {
    return _activeFlows.values.toList();
  }
  
  /// Get flow by ID
  FlowTracker? getFlow(String flowId) {
    return _activeFlows[flowId];
  }
  
  /// Clear old logs and completed flows
  void cleanup() {
    // Remove old log entries
    if (_logBuffer.length > _maxLogBufferSize) {
      _logBuffer.removeRange(0, _logBuffer.length - _maxLogBufferSize);
    }
    
    // Remove old completed flows (older than 1 hour)
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _activeFlows.removeWhere((key, flow) {
      return flow.isComplete && flow.startTime.isBefore(cutoff);
    });
  }
  
  /// Generate performance report
  Map<String, dynamic> generatePerformanceReport() {
    final performanceLogs = _logBuffer
        .where((entry) => entry.level == DebugLogLevel.performance)
        .toList();
    
    final operationStats = <String, List<int>>{};
    
    for (final entry in performanceLogs) {
      final duration = entry.context?['duration_ms'] as int? ?? 0;
      final operation = entry.operation;
      
      operationStats.putIfAbsent(operation, () => []).add(duration);
    }
    
    final report = <String, dynamic>{
      'generated_at': DateTime.now().toIso8601String(),
      'total_performance_logs': performanceLogs.length,
      'operations': <String, dynamic>{},
    };
    
    for (final entry in operationStats.entries) {
      final durations = entry.value;
      durations.sort();
      
      final avg = durations.isEmpty ? 0 : durations.reduce((a, b) => a + b) ~/ durations.length;
      final median = durations.isEmpty ? 0 : durations[durations.length ~/ 2];
      final p95 = durations.isEmpty ? 0 : durations[(durations.length * 0.95).round() - 1];
      
      report['operations'][entry.key] = {
        'count': durations.length,
        'avg_ms': avg,
        'median_ms': median,
        'p95_ms': p95,
        'min_ms': durations.isEmpty ? 0 : durations.first,
        'max_ms': durations.isEmpty ? 0 : durations.last,
      };
    }
    
    return report;
  }
  
  /// Export logs for debugging
  Map<String, dynamic> exportLogs({
    DateTime? since,
    DebugLogLevel? levelFilter,
  }) {
    var logsToExport = _logBuffer.where((entry) {
      if (since != null && entry.timestamp.isBefore(since)) return false;
      if (levelFilter != null && entry.level != levelFilter) return false;
      return true;
    }).toList();
    
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'log_count': logsToExport.length,
      'logs': logsToExport.map((entry) => entry.toMap()).toList(),
      'active_flows': _activeFlows.values.map((flow) => flow.toMap()).toList(),
    };
  }
  
  /// Add log entry to buffer
  void _addLogEntry(
    DebugLogLevel level,
    String operation,
    String message,
    Map<String, dynamic>? context,
    String? userId,
    [StackTrace? stackTrace]
  ) {
    final entry = DebugLogEntry(
      id: _generateLogId(),
      timestamp: DateTime.now(),
      level: level,
      operation: operation,
      message: message,
      context: _sanitizeContext(context),
      userId: userId,
      stackTrace: stackTrace?.toString(),
    );
    
    _logBuffer.add(entry);
    
    // Print to console in debug mode
    if (kDebugMode) {
      final emoji = _getLevelEmoji(level);
      final contextStr = context != null && context.isNotEmpty
          ? ' | ${_formatContextForConsole(context)}'
          : '';
      
      debugPrint('$emoji [$operation] $message$contextStr');
      
      if (stackTrace != null && level == DebugLogLevel.error) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
    
    // Cleanup if buffer is getting too large
    if (_logBuffer.length > _maxLogBufferSize + 100) {
      cleanup();
    }
  }
  
  /// Sanitize context to remove sensitive information
  Map<String, dynamic>? _sanitizeContext(Map<String, dynamic>? context) {
    if (context == null) return null;
    
    final sanitized = <String, dynamic>{};
    
    for (final entry in context.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      
      // Remove sensitive keys
      if (key.contains('password') ||
          key.contains('secret') ||
          key.contains('token') ||
          key.contains('key') && !key.contains('_id') ||
          key.contains('auth') && !key.endsWith('_id') ||
          key.contains('credential')) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (key.contains('email') && value is String) {
        // Partially redact email addresses
        final email = value as String;
        if (email.contains('@')) {
          final parts = email.split('@');
          final localPart = parts[0];
          final domain = parts[1];
          final redactedLocal = localPart.length > 2
              ? '${localPart.substring(0, 2)}***'
              : '***';
          sanitized[entry.key] = '$redactedLocal@$domain';
        } else {
          sanitized[entry.key] = '[REDACTED_EMAIL]';
        }
      } else if (value is String && value.length > 1000) {
        // Truncate long strings
        sanitized[entry.key] = '${value.substring(0, 997)}...';
      } else {
        sanitized[entry.key] = value;
      }
    }
    
    return sanitized;
  }
  
  /// Format context for console output
  String _formatContextForConsole(Map<String, dynamic> context) {
    final pairs = context.entries
        .take(3)
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    
    return context.length > 3 ? '$pairs, ...(+${context.length - 3})' : pairs;
  }
  
  /// Get emoji for log level
  String _getLevelEmoji(DebugLogLevel level) {
    switch (level) {
      case DebugLogLevel.debug:
        return '🔍';
      case DebugLogLevel.info:
        return 'ℹ️';
      case DebugLogLevel.warning:
        return '⚠️';
      case DebugLogLevel.error:
        return '❌';
      case DebugLogLevel.performance:
        return '⚡';
    }
  }
  
  /// Format duration for human reading
  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inSeconds < 60) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    } else {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
  }
  
  /// Generate unique log ID
  String _generateLogId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'log_${timestamp}_$random';
  }
  
  /// Generate unique flow ID
  String _generateFlowId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'flow_${timestamp}_$random';
  }
  
  /// Start periodic log flushing (for production use)
  void _startPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_logFlushInterval, (_) {
      _flushLogsToFirestore();
    });
  }
  
  /// Flush logs to Firestore for persistent storage
  Future<void> _flushLogsToFirestore() async {
    if (kDebugMode) return; // Don't flush in debug mode
    
    try {
      final logsToFlush = _logBuffer.where((entry) => 
          entry.level != DebugLogLevel.debug // Don't persist debug logs
      ).toList();
      
      if (logsToFlush.isEmpty) return;
      
      final batch = FirebaseFirestore.instance.batch();
      
      for (final entry in logsToFlush) {
        final docRef = FirebaseFirestore.instance
            .collection('debug_logs')
            .doc(entry.id);
        
        batch.set(docRef, entry.toMap());
      }
      
      await batch.commit();
      
      // Remove flushed logs from buffer
      _logBuffer.removeWhere((entry) => logsToFlush.contains(entry));
      
    } catch (e) {
      // Fail silently to avoid logging loops
      debugPrint('Failed to flush logs to Firestore: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _flushTimer?.cancel();
  }
}

/// Debug log entry model
class DebugLogEntry {
  final String id;
  final DateTime timestamp;
  final DebugLogLevel level;
  final String operation;
  final String message;
  final Map<String, dynamic>? context;
  final String? userId;
  final String? stackTrace;
  
  const DebugLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.operation,
    required this.message,
    this.context,
    this.userId,
    this.stackTrace,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'operation': operation,
      'message': message,
      'context': context,
      'user_id': userId,
      'has_stack_trace': stackTrace != null,
      'stack_trace_length': stackTrace?.length,
    };
  }
}

/// Flow tracker for monitoring subscription flows
class FlowTracker {
  final String flowId;
  final String flowType;
  final String userId;
  final DateTime startTime;
  final Map<String, dynamic> context;
  final List<FlowCheckpoint> checkpoints = [];
  
  DateTime? _endTime;
  bool _isComplete = false;
  bool _isFailed = false;
  String? _failureReason;
  Map<String, dynamic>? _finalContext;
  
  FlowTracker({
    required this.flowId,
    required this.flowType,
    required this.userId,
    required this.startTime,
    required this.context,
  });
  
  void addCheckpoint(String name, [Map<String, dynamic>? checkpointContext]) {
    checkpoints.add(FlowCheckpoint(
      name: name,
      timestamp: DateTime.now(),
      context: checkpointContext,
    ));
  }
  
  void markComplete([Map<String, dynamic>? finalContext]) {
    _endTime = DateTime.now();
    _isComplete = true;
    _finalContext = finalContext;
  }
  
  void markFailed(String reason, [Map<String, dynamic>? errorContext]) {
    _endTime = DateTime.now();
    _isFailed = true;
    _failureReason = reason;
    _finalContext = errorContext;
  }
  
  Duration getDuration() {
    final endTime = _endTime ?? DateTime.now();
    return endTime.difference(startTime);
  }
  
  bool get isComplete => _isComplete || _isFailed;
  bool get isSuccessful => _isComplete && !_isFailed;
  bool get isFailed => _isFailed;
  String? get failureReason => _failureReason;
  
  Map<String, dynamic> toMap() {
    return {
      'flow_id': flowId,
      'flow_type': flowType,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': _endTime?.toIso8601String(),
      'duration_ms': getDuration().inMilliseconds,
      'is_complete': isComplete,
      'is_successful': isSuccessful,
      'is_failed': isFailed,
      'failure_reason': _failureReason,
      'checkpoints_count': checkpoints.length,
      'checkpoints': checkpoints.map((c) => c.toMap()).toList(),
      'context': context,
      'final_context': _finalContext,
    };
  }
}

/// Flow checkpoint model
class FlowCheckpoint {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic>? context;
  
  const FlowCheckpoint({
    required this.name,
    required this.timestamp,
    this.context,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
    };
  }
}

/// Debug log levels
enum DebugLogLevel {
  debug,
  info,
  warning,
  error,
  performance,
}