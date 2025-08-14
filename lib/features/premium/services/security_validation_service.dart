import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'premium_error_handler.dart';
import 'debug_logger_service.dart';

/// 🔒 SECURITY: Comprehensive security validation service for premium operations
/// 
/// This service provides:
/// - CSRF protection for sensitive operations
/// - Rate limiting to prevent abuse
/// - Security monitoring for suspicious activities  
/// - Session validation and token management
/// - Input sanitization and validation
/// - Anti-fraud measures for subscription operations
class SecurityValidationService {
  static final SecurityValidationService _instance = SecurityValidationService._internal();
  static SecurityValidationService get instance => _instance;
  
  final _debugLogger = DebugLoggerService.instance;
  final Map<String, CsrfToken> _csrfTokens = {};
  final Map<String, List<SecurityEvent>> _securityEvents = {};
  final Map<String, RateLimitState> _rateLimits = {};
  
  // Security configuration
  static const Duration _csrfTokenLifetime = Duration(minutes: 30);
  static const Duration _sessionTimeout = Duration(hours: 24);
  static const int _maxCsrfTokensPerUser = 10;
  static const int _maxSecurityEventsPerUser = 100;
  
  // Rate limiting configuration
  static const Map<String, RateLimitConfig> _operationLimits = {
    'subscription_creation': RateLimitConfig(maxAttempts: 3, windowMinutes: 60),
    'subscription_upgrade': RateLimitConfig(maxAttempts: 5, windowMinutes: 30),
    'subscription_cancellation': RateLimitConfig(maxAttempts: 2, windowMinutes: 15),
    'payment_processing': RateLimitConfig(maxAttempts: 5, windowMinutes: 10),
    'feature_validation': RateLimitConfig(maxAttempts: 100, windowMinutes: 5),
    'usage_check': RateLimitConfig(maxAttempts: 200, windowMinutes: 5),
  };
  
  SecurityValidationService._internal();
  
  /// Generate CSRF token for sensitive operations
  Future<String> generateCsrfToken(String userId, String operation) async {
    final operationId = 'generate_csrf_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      // Validate user ID
      if (userId.isEmpty || !RegExp(r'^[a-zA-Z0-9]{28}$').hasMatch(userId)) {
        throw PremiumError.validation('Invalid user ID for CSRF token generation');
      }
      
      // Clean up expired tokens for user
      await _cleanupExpiredTokens(userId);
      
      // Check if user has too many active tokens
      final userTokens = _csrfTokens.entries
          .where((entry) => entry.value.userId == userId && entry.value.isValid)
          .length;
      
      if (userTokens >= _maxCsrfTokensPerUser) {
        await _logSecurityEvent(userId, SecurityEventType.csrfTokenLimitExceeded, {
          'active_tokens': userTokens,
          'operation': operation,
        });
        throw PremiumError.rateLimit('Too many active security tokens');
      }
      
      // Generate secure token
      final tokenData = {
        'user_id': userId,
        'operation': operation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'nonce': _generateSecureNonce(),
      };
      
      final tokenString = base64Encode(utf8.encode(jsonEncode(tokenData)));
      final tokenHash = sha256.convert(utf8.encode(tokenString + userId)).toString();
      
      final csrfToken = CsrfToken(
        token: tokenHash,
        userId: userId,
        operation: operation,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(_csrfTokenLifetime),
      );
      
      _csrfTokens[tokenHash] = csrfToken;
      
      _debugLogger.logInfo(
        operation: 'generateCsrfToken',
        message: 'CSRF token generated successfully',
        context: {
          'user_id': userId,
          'operation': operation,
          'token_expires_at': csrfToken.expiresAt.toIso8601String(),
        },
        userId: userId,
      );
      
      await _logSecurityEvent(userId, SecurityEventType.csrfTokenGenerated, {
        'operation': operation,
        'token_id': tokenHash.substring(0, 8),
      });
      
      return tokenHash;
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'generateCsrfToken',
        message: 'Failed to generate CSRF token',
        context: {
          'user_id': userId,
          'operation': operation,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }
  
  /// Validate CSRF token for sensitive operations
  Future<bool> validateCsrfToken(String userId, String operation, String token) async {
    try {
      // Basic validation
      if (userId.isEmpty || operation.isEmpty || token.isEmpty) {
        await _logSecurityEvent(userId, SecurityEventType.csrfValidationFailed, {
          'operation': operation,
          'reason': 'empty_parameters',
        });
        return false;
      }
      
      // Find token
      final csrfToken = _csrfTokens[token];
      if (csrfToken == null) {
        await _logSecurityEvent(userId, SecurityEventType.csrfValidationFailed, {
          'operation': operation,
          'reason': 'token_not_found',
          'token_id': token.substring(0, 8),
        });
        return false;
      }
      
      // Validate token ownership and operation
      if (csrfToken.userId != userId || csrfToken.operation != operation) {
        await _logSecurityEvent(userId, SecurityEventType.csrfValidationFailed, {
          'operation': operation,
          'reason': 'token_mismatch',
          'expected_user': userId,
          'token_user': csrfToken.userId,
          'expected_operation': operation,
          'token_operation': csrfToken.operation,
        });
        return false;
      }
      
      // Check expiration
      if (!csrfToken.isValid) {
        await _logSecurityEvent(userId, SecurityEventType.csrfValidationFailed, {
          'operation': operation,
          'reason': 'token_expired',
          'token_id': token.substring(0, 8),
          'expired_at': csrfToken.expiresAt.toIso8601String(),
        });
        _csrfTokens.remove(token); // Clean up expired token
        return false;
      }
      
      // Token is valid - mark as used (one-time use)
      _csrfTokens.remove(token);
      
      _debugLogger.logInfo(
        operation: 'validateCsrfToken',
        message: 'CSRF token validated successfully',
        context: {
          'user_id': userId,
          'operation': operation,
          'token_id': token.substring(0, 8),
        },
        userId: userId,
      );
      
      await _logSecurityEvent(userId, SecurityEventType.csrfTokenValidated, {
        'operation': operation,
        'token_id': token.substring(0, 8),
      });
      
      return true;
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'validateCsrfToken',
        message: 'Error validating CSRF token',
        context: {
          'user_id': userId,
          'operation': operation,
          'error': e.toString(),
        },
        userId: userId,
      );
      
      await _logSecurityEvent(userId, SecurityEventType.csrfValidationError, {
        'operation': operation,
        'error': e.toString(),
      });
      
      return false;
    }
  }
  
  /// Check rate limits for operations
  Future<bool> checkRateLimit(String userId, String operation) async {
    try {
      final config = _operationLimits[operation];
      if (config == null) {
        // No rate limit configured for this operation
        return true;
      }
      
      final key = '${userId}_$operation';
      final now = DateTime.now();
      
      // Get or create rate limit state
      var rateLimitState = _rateLimits[key];
      if (rateLimitState == null) {
        rateLimitState = RateLimitState(
          attempts: [],
          windowStart: now,
        );
        _rateLimits[key] = rateLimitState;
      }
      
      // Clean up old attempts outside the window
      final windowStart = now.subtract(Duration(minutes: config.windowMinutes));
      rateLimitState.attempts.removeWhere((attempt) => attempt.isBefore(windowStart));
      rateLimitState.windowStart = windowStart;
      
      // Check if limit is exceeded
      if (rateLimitState.attempts.length >= config.maxAttempts) {
        final oldestAttempt = rateLimitState.attempts.first;
        final resetTime = oldestAttempt.add(Duration(minutes: config.windowMinutes));
        
        await _logSecurityEvent(userId, SecurityEventType.rateLimitExceeded, {
          'operation': operation,
          'attempts': rateLimitState.attempts.length,
          'limit': config.maxAttempts,
          'window_minutes': config.windowMinutes,
          'reset_time': resetTime.toIso8601String(),
        });
        
        _debugLogger.logWarning(
          operation: 'checkRateLimit',
          message: 'Rate limit exceeded',
          context: {
            'user_id': userId,
            'operation': operation,
            'attempts': rateLimitState.attempts.length,
            'limit': config.maxAttempts,
            'reset_in_seconds': resetTime.difference(now).inSeconds,
          },
          userId: userId,
        );
        
        return false;
      }
      
      // Record this attempt
      rateLimitState.attempts.add(now);
      
      return true;
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'checkRateLimit',
        message: 'Error checking rate limit',
        context: {
          'user_id': userId,
          'operation': operation,
          'error': e.toString(),
        },
        userId: userId,
      );
      
      // In case of error, allow the operation but log it
      return true;
    }
  }
  
  /// Monitor for suspicious activity patterns
  Future<bool> detectSuspiciousActivity(String userId, String operation, Map<String, dynamic> context) async {
    try {
      final suspiciousPatterns = <String>[];
      
      // Check for rapid succession of operations
      final recentEvents = await _getRecentSecurityEvents(userId, Duration(minutes: 5));
      final sameOperationEvents = recentEvents
          .where((event) => event.context['operation'] == operation)
          .length;
      
      if (sameOperationEvents > 10) {
        suspiciousPatterns.add('rapid_operation_repetition');
      }
      
      // Check for unusual operation patterns
      final recentDifferentOps = recentEvents
          .map((event) => event.context['operation'])
          .toSet()
          .length;
      
      if (recentDifferentOps > 5) {
        suspiciousPatterns.add('diverse_operation_pattern');
      }
      
      // Check for unusual times (basic implementation)
      final hour = DateTime.now().hour;
      if (hour < 6 || hour > 23) {
        // Activity during unusual hours - less weight
        if (sameOperationEvents > 5) {
          suspiciousPatterns.add('unusual_hours_activity');
        }
      }
      
      // Check for invalid data patterns in context
      if (context.containsKey('price_id') && context['price_id'] is String) {
        final priceId = context['price_id'] as String;
        if (!priceId.startsWith('price_') || priceId.length < 10) {
          suspiciousPatterns.add('invalid_price_id_format');
        }
      }
      
      if (suspiciousPatterns.isNotEmpty) {
        await _logSecurityEvent(userId, SecurityEventType.suspiciousActivityDetected, {
          'operation': operation,
          'patterns': suspiciousPatterns,
          'context': context,
          'recent_events': recentEvents.length,
        });
        
        _debugLogger.logWarning(
          operation: 'detectSuspiciousActivity',
          message: 'Suspicious activity detected',
          context: {
            'user_id': userId,
            'operation': operation,
            'suspicious_patterns': suspiciousPatterns,
            'pattern_count': suspiciousPatterns.length,
          },
          userId: userId,
        );
        
        // For now, just log and continue. In production, you might want to:
        // - Require additional authentication
        // - Temporarily restrict account
        // - Send alerts to security team
        return true; // Still allow operation but flag it
      }
      
      return false; // No suspicious activity detected
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'detectSuspiciousActivity',
        message: 'Error detecting suspicious activity',
        context: {
          'user_id': userId,
          'operation': operation,
          'error': e.toString(),
        },
        userId: userId,
      );
      
      return false; // In case of error, don't flag as suspicious
    }
  }
  
  /// Comprehensive security check for premium operations
  Future<SecurityCheckResult> performSecurityCheck({
    required String userId,
    required String operation,
    String? csrfToken,
    Map<String, dynamic> context = const {},
    bool requireCsrfToken = false,
  }) async {
    final flowTracker = _debugLogger.startFlow(
      'security_validation',
      userId,
      {
        'operation': operation,
        'requires_csrf': requireCsrfToken,
        'has_csrf_token': csrfToken != null,
      },
    );
    
    try {
      final violations = <SecurityViolation>[];
      
      _debugLogger.updateFlow(flowTracker.flowId, 'checking_rate_limits');
      
      // Check rate limits
      final rateLimitOk = await checkRateLimit(userId, operation);
      if (!rateLimitOk) {
        violations.add(SecurityViolation(
          type: SecurityViolationType.rateLimitExceeded,
          message: 'Operation rate limit exceeded',
          severity: SecuritySeverity.high,
        ));
      }
      
      _debugLogger.updateFlow(flowTracker.flowId, 'validating_csrf_token');
      
      // Validate CSRF token if required
      if (requireCsrfToken) {
        if (csrfToken == null || csrfToken.isEmpty) {
          violations.add(SecurityViolation(
            type: SecurityViolationType.missingCsrfToken,
            message: 'CSRF token required for this operation',
            severity: SecuritySeverity.critical,
          ));
        } else {
          final csrfValid = await validateCsrfToken(userId, operation, csrfToken);
          if (!csrfValid) {
            violations.add(SecurityViolation(
              type: SecurityViolationType.invalidCsrfToken,
              message: 'Invalid or expired CSRF token',
              severity: SecuritySeverity.critical,
            ));
          }
        }
      }
      
      _debugLogger.updateFlow(flowTracker.flowId, 'detecting_suspicious_activity');
      
      // Check for suspicious activity
      final suspiciousActivity = await detectSuspiciousActivity(userId, operation, context);
      if (suspiciousActivity) {
        violations.add(SecurityViolation(
          type: SecurityViolationType.suspiciousActivity,
          message: 'Suspicious activity pattern detected',
          severity: SecuritySeverity.medium,
        ));
      }
      
      _debugLogger.updateFlow(flowTracker.flowId, 'evaluating_security_result');
      
      // Determine overall result
      final criticalViolations = violations.where((v) => v.severity == SecuritySeverity.critical).toList();
      final highViolations = violations.where((v) => v.severity == SecuritySeverity.high).toList();
      
      final result = SecurityCheckResult(
        passed: criticalViolations.isEmpty && highViolations.isEmpty,
        violations: violations,
        securityScore: _calculateSecurityScore(violations),
        recommendedAction: _getRecommendedAction(violations),
      );
      
      _debugLogger.logInfo(
        operation: 'performSecurityCheck',
        message: 'Security check completed',
        context: {
          'user_id': userId,
          'operation': operation,
          'passed': result.passed,
          'violations_count': violations.length,
          'security_score': result.securityScore,
          'recommended_action': result.recommendedAction.name,
        },
        userId: userId,
      );
      
      if (result.passed) {
        _debugLogger.completeFlow(flowTracker.flowId, {
          'security_check_passed': true,
          'security_score': result.securityScore,
        });
      } else {
        _debugLogger.failFlow(
          flowTracker.flowId,
          'Security check failed: ${violations.map((v) => v.message).join(', ')}',
          null,
          {
            'violations': violations.map((v) => v.type.name).toList(),
            'security_score': result.securityScore,
          },
        );
      }
      
      return result;
      
    } catch (e) {
      _debugLogger.failFlow(flowTracker.flowId, 'Security check error: $e');
      
      _debugLogger.logError(
        operation: 'performSecurityCheck',
        message: 'Error during security check',
        context: {
          'user_id': userId,
          'operation': operation,
          'error': e.toString(),
        },
        userId: userId,
      );
      
      // In case of error, deny access for security
      return SecurityCheckResult(
        passed: false,
        violations: [
          SecurityViolation(
            type: SecurityViolationType.systemError,
            message: 'Security system error',
            severity: SecuritySeverity.critical,
          )
        ],
        securityScore: 0,
        recommendedAction: SecurityAction.denyAccess,
      );
    }
  }
  
  /// Clean up expired tokens and old security events
  Future<void> performMaintenance() async {
    try {
      final now = DateTime.now();
      
      // Clean up expired CSRF tokens
      final expiredTokens = _csrfTokens.entries
          .where((entry) => !entry.value.isValid)
          .map((entry) => entry.key)
          .toList();
      
      for (final token in expiredTokens) {
        _csrfTokens.remove(token);
      }
      
      // Clean up old security events (keep only last 24 hours)
      final cutoff = now.subtract(const Duration(hours: 24));
      for (final userId in _securityEvents.keys) {
        _securityEvents[userId]?.removeWhere((event) => event.timestamp.isBefore(cutoff));
        if (_securityEvents[userId]?.isEmpty == true) {
          _securityEvents.remove(userId);
        }
      }
      
      // Clean up old rate limit states
      final rateLimitCutoff = now.subtract(const Duration(hours: 2));
      _rateLimits.removeWhere((key, state) => 
          state.windowStart.isBefore(rateLimitCutoff));
      
      _debugLogger.logDebug(
        operation: 'performMaintenance',
        message: 'Security service maintenance completed',
        context: {
          'expired_tokens_removed': expiredTokens.length,
          'active_tokens': _csrfTokens.length,
          'users_with_events': _securityEvents.length,
          'active_rate_limits': _rateLimits.length,
        },
      );
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'performMaintenance',
        message: 'Error during security maintenance',
        context: {'error': e.toString()},
      );
    }
  }
  
  /// Get security summary for a user
  Future<Map<String, dynamic>> getUserSecuritySummary(String userId) async {
    try {
      final activeTokens = _csrfTokens.values
          .where((token) => token.userId == userId && token.isValid)
          .length;
      
      final recentEvents = await _getRecentSecurityEvents(userId, Duration(hours: 24));
      final eventsByType = <String, int>{};
      
      for (final event in recentEvents) {
        final type = event.type.name;
        eventsByType[type] = (eventsByType[type] ?? 0) + 1;
      }
      
      final rateLimitStatus = <String, Map<String, dynamic>>{};
      for (final operation in _operationLimits.keys) {
        final key = '${userId}_$operation';
        final state = _rateLimits[key];
        final config = _operationLimits[operation]!;
        
        rateLimitStatus[operation] = {
          'attempts': state?.attempts.length ?? 0,
          'limit': config.maxAttempts,
          'window_minutes': config.windowMinutes,
          'reset_time': state?.attempts.isNotEmpty == true
              ? state!.attempts.first.add(Duration(minutes: config.windowMinutes)).toIso8601String()
              : null,
        };
      }
      
      return {
        'user_id': userId,
        'active_csrf_tokens': activeTokens,
        'security_events_24h': recentEvents.length,
        'events_by_type': eventsByType,
        'rate_limit_status': rateLimitStatus,
        'last_activity': recentEvents.isNotEmpty 
            ? recentEvents.last.timestamp.toIso8601String()
            : null,
      };
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'getUserSecuritySummary',
        message: 'Error getting user security summary',
        context: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      
      return {'error': 'Unable to retrieve security summary'};
    }
  }
  
  // Private helper methods
  
  Future<void> _cleanupExpiredTokens(String userId) async {
    final expiredTokens = _csrfTokens.entries
        .where((entry) => entry.value.userId == userId && !entry.value.isValid)
        .map((entry) => entry.key)
        .toList();
    
    for (final token in expiredTokens) {
      _csrfTokens.remove(token);
    }
  }
  
  String _generateSecureNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }
  
  Future<void> _logSecurityEvent(
    String userId,
    SecurityEventType type,
    Map<String, dynamic> context,
  ) async {
    try {
      final event = SecurityEvent(
        type: type,
        userId: userId,
        timestamp: DateTime.now(),
        context: context,
      );
      
      _securityEvents.putIfAbsent(userId, () => []).add(event);
      
      // Limit events per user to prevent memory issues
      final userEvents = _securityEvents[userId]!;
      if (userEvents.length > _maxSecurityEventsPerUser) {
        userEvents.removeAt(0);
      }
      
      // In production, also store critical events in Firestore
      if (type.isCritical && !kDebugMode) {
        await FirebaseFirestore.instance
            .collection('security_events')
            .add({
              'user_id': userId,
              'type': type.name,
              'timestamp': event.timestamp.toIso8601String(),
              'context': context,
            });
      }
      
    } catch (e) {
      _debugLogger.logError(
        operation: 'logSecurityEvent',
        message: 'Failed to log security event',
        context: {
          'user_id': userId,
          'event_type': type.name,
          'error': e.toString(),
        },
        userId: userId,
      );
    }
  }
  
  Future<List<SecurityEvent>> _getRecentSecurityEvents(String userId, Duration duration) async {
    final cutoff = DateTime.now().subtract(duration);
    final userEvents = _securityEvents[userId] ?? [];
    
    return userEvents
        .where((event) => event.timestamp.isAfter(cutoff))
        .toList();
  }
  
  int _calculateSecurityScore(List<SecurityViolation> violations) {
    if (violations.isEmpty) return 100;
    
    int score = 100;
    for (final violation in violations) {
      switch (violation.severity) {
        case SecuritySeverity.critical:
          score -= 50;
          break;
        case SecuritySeverity.high:
          score -= 25;
          break;
        case SecuritySeverity.medium:
          score -= 10;
          break;
        case SecuritySeverity.low:
          score -= 5;
          break;
      }
    }
    
    return score.clamp(0, 100);
  }
  
  SecurityAction _getRecommendedAction(List<SecurityViolation> violations) {
    if (violations.any((v) => v.severity == SecuritySeverity.critical)) {
      return SecurityAction.denyAccess;
    } else if (violations.any((v) => v.severity == SecuritySeverity.high)) {
      return SecurityAction.requireReauth;
    } else if (violations.any((v) => v.severity == SecuritySeverity.medium)) {
      return SecurityAction.monitor;
    } else {
      return SecurityAction.allow;
    }
  }
}

// Data models and enums

class CsrfToken {
  final String token;
  final String userId;
  final String operation;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  CsrfToken({
    required this.token,
    required this.userId,
    required this.operation,
    required this.createdAt,
    required this.expiresAt,
  });
  
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class SecurityEvent {
  final SecurityEventType type;
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  
  SecurityEvent({
    required this.type,
    required this.userId,
    required this.timestamp,
    required this.context,
  });
}

class RateLimitState {
  final List<DateTime> attempts;
  DateTime windowStart;
  
  RateLimitState({
    required this.attempts,
    required this.windowStart,
  });
}

class RateLimitConfig {
  final int maxAttempts;
  final int windowMinutes;
  
  const RateLimitConfig({
    required this.maxAttempts,
    required this.windowMinutes,
  });
}

class SecurityCheckResult {
  final bool passed;
  final List<SecurityViolation> violations;
  final int securityScore;
  final SecurityAction recommendedAction;
  
  SecurityCheckResult({
    required this.passed,
    required this.violations,
    required this.securityScore,
    required this.recommendedAction,
  });
}

class SecurityViolation {
  final SecurityViolationType type;
  final String message;
  final SecuritySeverity severity;
  
  SecurityViolation({
    required this.type,
    required this.message,
    required this.severity,
  });
}

enum SecurityEventType {
  csrfTokenGenerated,
  csrfTokenValidated,
  csrfValidationFailed,
  csrfValidationError,
  csrfTokenLimitExceeded,
  rateLimitExceeded,
  suspiciousActivityDetected,
  unauthorizedAccess,
  invalidAuthentication,
  dataIntegrityViolation,
  unusualLocationAccess,
  multipleFailedAttempts;
  
  bool get isCritical {
    switch (this) {
      case SecurityEventType.unauthorizedAccess:
      case SecurityEventType.dataIntegrityViolation:
      case SecurityEventType.multipleFailedAttempts:
        return true;
      default:
        return false;
    }
  }
}

enum SecurityViolationType {
  rateLimitExceeded,
  missingCsrfToken,
  invalidCsrfToken,
  suspiciousActivity,
  invalidAuthentication,
  insufficientPermissions,
  dataIntegrityViolation,
  systemError,
}

enum SecuritySeverity {
  low,
  medium,
  high,
  critical,
}

enum SecurityAction {
  allow,
  monitor,
  requireReauth,
  denyAccess,
  suspendAccount,
}