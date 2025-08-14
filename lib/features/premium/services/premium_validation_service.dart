import 'package:flutter/foundation.dart';
import 'premium_error_handler.dart';

/// 🔒 SECURE: Comprehensive input validation and sanitization service
/// 
/// This service provides:
/// - Input validation for all subscription-related data
/// - Data sanitization to prevent injection attacks
/// - Type checking and format validation
/// - Business rule validation
/// - Secure error handling with detailed validation feedback
class PremiumValidationService {
  static final _logger = PremiumLogger.instance;
  
  /// Validate user ID format and security
  static ValidationResult validateUserId(String? userId) {
    if (userId == null || userId.isEmpty) {
      return ValidationResult.failure(
        'USER_ID_REQUIRED',
        'User ID is required',
        'Please ensure you are properly signed in',
      );
    }
    
    // Check for valid format (assuming Firebase Auth UID format)
    if (!RegExp(r'^[a-zA-Z0-9]{28}$').hasMatch(userId)) {
      return ValidationResult.failure(
        'USER_ID_INVALID_FORMAT',
        'Invalid user ID format',
        'User ID must be a valid authentication identifier',
      );
    }
    
    // Check for potential injection attempts
    if (_containsSuspiciousChars(userId)) {
      return ValidationResult.failure(
        'USER_ID_INVALID_CHARS',
        'User ID contains invalid characters',
        'User ID can only contain alphanumeric characters',
      );
    }
    
    return ValidationResult.success(userId.trim());
  }
  
  /// Validate email address format and security
  static ValidationResult validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return ValidationResult.failure(
        'EMAIL_REQUIRED',
        'Email address is required',
        'Please provide a valid email address',
      );
    }
    
    final sanitizedEmail = email.trim().toLowerCase();
    
    // Check for valid email format (RFC 5322 simplified)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9]+([._+-]?[a-zA-Z0-9]+)*@[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'
    );
    
    if (!emailRegex.hasMatch(sanitizedEmail)) {
      return ValidationResult.failure(
        'EMAIL_INVALID_FORMAT',
        'Invalid email address format',
        'Please enter a valid email address (e.g., user@example.com)',
      );
    }
    
    // Check for common disposable email domains (security measure)
    if (_isDisposableEmail(sanitizedEmail)) {
      return ValidationResult.failure(
        'EMAIL_DISPOSABLE',
        'Disposable email addresses are not allowed',
        'Please use a permanent email address',
      );
    }
    
    // Check email length limits
    if (sanitizedEmail.length > 254) {
      return ValidationResult.failure(
        'EMAIL_TOO_LONG',
        'Email address is too long',
        'Email address must be less than 254 characters',
      );
    }
    
    return ValidationResult.success(sanitizedEmail);
  }
  
  /// Validate user type
  static ValidationResult validateUserType(String? userType) {
    if (userType == null || userType.isEmpty) {
      return ValidationResult.failure(
        'USER_TYPE_REQUIRED',
        'User type is required',
        'Please specify whether you are a shopper, vendor, or market organizer',
      );
    }
    
    const validUserTypes = ['shopper', 'vendor', 'market_organizer'];
    final sanitizedUserType = userType.trim().toLowerCase();
    
    if (!validUserTypes.contains(sanitizedUserType)) {
      return ValidationResult.failure(
        'USER_TYPE_INVALID',
        'Invalid user type',
        'User type must be one of: ${validUserTypes.join(', ')}',
      );
    }
    
    return ValidationResult.success(sanitizedUserType);
  }
  
  /// Validate subscription tier
  static ValidationResult validateSubscriptionTier(String? tier) {
    if (tier == null || tier.isEmpty) {
      return ValidationResult.failure(
        'TIER_REQUIRED',
        'Subscription tier is required',
        'Please specify a subscription tier',
      );
    }
    
    const validTiers = ['free', 'shopperPro', 'vendorPro', 'marketOrganizerPro', 'enterprise'];
    final sanitizedTier = tier.trim();
    
    if (!validTiers.contains(sanitizedTier)) {
      return ValidationResult.failure(
        'TIER_INVALID',
        'Invalid subscription tier',
        'Tier must be one of: ${validTiers.join(', ')}',
      );
    }
    
    return ValidationResult.success(sanitizedTier);
  }
  
  /// Validate Stripe price ID
  static ValidationResult validateStripePriceId(String? priceId) {
    if (priceId == null || priceId.isEmpty) {
      return ValidationResult.failure(
        'PRICE_ID_REQUIRED',
        'Stripe price ID is required',
        'A valid price ID must be provided for subscription',
      );
    }
    
    final sanitizedPriceId = priceId.trim();
    
    // Stripe price IDs start with 'price_'
    if (!sanitizedPriceId.startsWith('price_')) {
      return ValidationResult.failure(
        'PRICE_ID_INVALID_FORMAT',
        'Invalid Stripe price ID format',
        'Price ID must start with "price_"',
      );
    }
    
    // Check for valid characters (Stripe uses alphanumeric and underscores)
    if (!RegExp(r'^price_[a-zA-Z0-9_]+$').hasMatch(sanitizedPriceId)) {
      return ValidationResult.failure(
        'PRICE_ID_INVALID_CHARS',
        'Price ID contains invalid characters',
        'Price ID can only contain alphanumeric characters and underscores',
      );
    }
    
    // Check reasonable length limits
    if (sanitizedPriceId.length < 8 || sanitizedPriceId.length > 100) {
      return ValidationResult.failure(
        'PRICE_ID_INVALID_LENGTH',
        'Price ID length is invalid',
        'Price ID must be between 8 and 100 characters',
      );
    }
    
    return ValidationResult.success(sanitizedPriceId);
  }
  
  /// Validate Stripe customer ID
  static ValidationResult validateStripeCustomerId(String? customerId) {
    if (customerId == null || customerId.isEmpty) {
      return ValidationResult.success(null); // Optional field
    }
    
    final sanitizedCustomerId = customerId.trim();
    
    // Stripe customer IDs start with 'cus_'
    if (!sanitizedCustomerId.startsWith('cus_')) {
      return ValidationResult.failure(
        'CUSTOMER_ID_INVALID_FORMAT',
        'Invalid Stripe customer ID format',
        'Customer ID must start with "cus_"',
      );
    }
    
    // Check for valid characters
    if (!RegExp(r'^cus_[a-zA-Z0-9_]+$').hasMatch(sanitizedCustomerId)) {
      return ValidationResult.failure(
        'CUSTOMER_ID_INVALID_CHARS',
        'Customer ID contains invalid characters',
        'Customer ID can only contain alphanumeric characters and underscores',
      );
    }
    
    return ValidationResult.success(sanitizedCustomerId);
  }
  
  /// Validate Stripe subscription ID
  static ValidationResult validateStripeSubscriptionId(String? subscriptionId) {
    if (subscriptionId == null || subscriptionId.isEmpty) {
      return ValidationResult.success(null); // Optional field
    }
    
    final sanitizedSubscriptionId = subscriptionId.trim();
    
    // Stripe subscription IDs start with 'sub_'
    if (!sanitizedSubscriptionId.startsWith('sub_')) {
      return ValidationResult.failure(
        'SUBSCRIPTION_ID_INVALID_FORMAT',
        'Invalid Stripe subscription ID format',
        'Subscription ID must start with "sub_"',
      );
    }
    
    // Check for valid characters
    if (!RegExp(r'^sub_[a-zA-Z0-9_]+$').hasMatch(sanitizedSubscriptionId)) {
      return ValidationResult.failure(
        'SUBSCRIPTION_ID_INVALID_CHARS',
        'Subscription ID contains invalid characters',
        'Subscription ID can only contain alphanumeric characters and underscores',
      );
    }
    
    return ValidationResult.success(sanitizedSubscriptionId);
  }
  
  /// Validate metadata for subscription operations
  static ValidationResult validateMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      return ValidationResult.success(<String, dynamic>{});
    }
    
    final sanitizedMetadata = <String, dynamic>{};
    
    // Check total size limit
    final metadataString = metadata.toString();
    if (metadataString.length > 5000) {
      return ValidationResult.failure(
        'METADATA_TOO_LARGE',
        'Metadata is too large',
        'Metadata must be less than 5000 characters total',
      );
    }
    
    // Check individual key-value pairs
    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Validate key
      if (key.isEmpty || key.length > 100) {
        return ValidationResult.failure(
          'METADATA_KEY_INVALID',
          'Invalid metadata key: $key',
          'Metadata keys must be 1-100 characters',
        );
      }
      
      if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(key)) {
        return ValidationResult.failure(
          'METADATA_KEY_INVALID_CHARS',
          'Metadata key contains invalid characters: $key',
          'Metadata keys can only contain alphanumeric characters, underscores, dots, and hyphens',
        );
      }
      
      // Validate value
      final sanitizedValue = _sanitizeMetadataValue(value);
      if (sanitizedValue == null) {
        return ValidationResult.failure(
          'METADATA_VALUE_INVALID',
          'Invalid metadata value for key: $key',
          'Metadata values must be strings, numbers, or booleans',
        );
      }
      
      sanitizedMetadata[key] = sanitizedValue;
    }
    
    return ValidationResult.success(sanitizedMetadata);
  }
  
  /// Validate feature name
  static ValidationResult validateFeatureName(String? featureName) {
    if (featureName == null || featureName.isEmpty) {
      return ValidationResult.failure(
        'FEATURE_NAME_REQUIRED',
        'Feature name is required',
        'Please specify which feature you want to check',
      );
    }
    
    final sanitizedFeatureName = featureName.trim().toLowerCase();
    
    // Check for valid format (snake_case)
    if (!RegExp(r'^[a-z][a-z0-9_]*[a-z0-9]$|^[a-z]$').hasMatch(sanitizedFeatureName)) {
      return ValidationResult.failure(
        'FEATURE_NAME_INVALID_FORMAT',
        'Invalid feature name format',
        'Feature names must use snake_case format (e.g., advanced_analytics)',
      );
    }
    
    // Check reasonable length limits
    if (sanitizedFeatureName.length > 50) {
      return ValidationResult.failure(
        'FEATURE_NAME_TOO_LONG',
        'Feature name is too long',
        'Feature names must be less than 50 characters',
      );
    }
    
    return ValidationResult.success(sanitizedFeatureName);
  }
  
  /// Validate limit name
  static ValidationResult validateLimitName(String? limitName) {
    if (limitName == null || limitName.isEmpty) {
      return ValidationResult.failure(
        'LIMIT_NAME_REQUIRED',
        'Limit name is required',
        'Please specify which limit you want to check',
      );
    }
    
    final sanitizedLimitName = limitName.trim().toLowerCase();
    
    // Check for valid format (snake_case)
    if (!RegExp(r'^[a-z][a-z0-9_]*[a-z0-9]$|^[a-z]$').hasMatch(sanitizedLimitName)) {
      return ValidationResult.failure(
        'LIMIT_NAME_INVALID_FORMAT',
        'Invalid limit name format',
        'Limit names must use snake_case format (e.g., monthly_markets)',
      );
    }
    
    // Check reasonable length limits
    if (sanitizedLimitName.length > 50) {
      return ValidationResult.failure(
        'LIMIT_NAME_TOO_LONG',
        'Limit name is too long',
        'Limit names must be less than 50 characters',
      );
    }
    
    return ValidationResult.success(sanitizedLimitName);
  }
  
  /// Validate usage count
  static ValidationResult validateUsageCount(int? count) {
    if (count == null) {
      return ValidationResult.failure(
        'USAGE_COUNT_REQUIRED',
        'Usage count is required',
        'Please provide the current usage count',
      );
    }
    
    if (count < 0) {
      return ValidationResult.failure(
        'USAGE_COUNT_NEGATIVE',
        'Usage count cannot be negative',
        'Usage count must be zero or greater',
      );
    }
    
    // Reasonable upper limit to prevent abuse
    if (count > 1000000) {
      return ValidationResult.failure(
        'USAGE_COUNT_TOO_HIGH',
        'Usage count is unreasonably high',
        'Usage count must be less than 1,000,000',
      );
    }
    
    return ValidationResult.success(count);
  }
  
  /// Comprehensive validation for subscription creation
  static Future<ValidationResult> validateSubscriptionCreation({
    required String? userId,
    required String? userType,
    String? stripeCustomerId,
    String? stripePriceId,
    Map<String, dynamic>? metadata,
  }) async {
    final operationId = 'validate_subscription_creation_${DateTime.now().millisecondsSinceEpoch}';
    
    await _logger.logOperation(
      operationId: operationId,
      operationName: 'validateSubscriptionCreation',
      level: LogLevel.debug,
      message: 'Starting subscription creation validation',
      context: {
        'has_user_id': userId != null,
        'has_user_type': userType != null,
        'has_customer_id': stripeCustomerId != null,
        'has_price_id': stripePriceId != null,
        'has_metadata': metadata != null,
      },
    );
    
    // Validate required fields
    final userIdResult = validateUserId(userId);
    if (!userIdResult.isValid) return userIdResult;
    
    final userTypeResult = validateUserType(userType);
    if (!userTypeResult.isValid) return userTypeResult;
    
    // Validate optional Stripe fields
    if (stripeCustomerId != null) {
      final customerIdResult = validateStripeCustomerId(stripeCustomerId);
      if (!customerIdResult.isValid) return customerIdResult;
    }
    
    if (stripePriceId != null) {
      final priceIdResult = validateStripePriceId(stripePriceId);
      if (!priceIdResult.isValid) return priceIdResult;
    }
    
    // Validate metadata
    final metadataResult = validateMetadata(metadata);
    if (!metadataResult.isValid) return metadataResult;
    
    await _logger.logOperation(
      operationId: operationId,
      operationName: 'validateSubscriptionCreation',
      level: LogLevel.info,
      message: 'Subscription creation validation completed successfully',
    );
    
    return ValidationResult.success({
      'userId': userIdResult.value,
      'userType': userTypeResult.value,
      'stripeCustomerId': stripeCustomerId,
      'stripePriceId': stripePriceId,
      'metadata': metadataResult.value,
    });
  }
  
  /// Check for suspicious characters that might indicate injection attempts
  static bool _containsSuspiciousChars(String input) {
    // Check for common injection patterns
    final suspiciousPatterns = [
      RegExp(r'[<>]'), // HTML injection chars
      RegExp(r'(script|javascript|onload|onerror)', caseSensitive: false), // Script tags
      RegExp(r'(union|select|insert|update|delete|drop)', caseSensitive: false), // SQL injection
    ];
    
    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if email is from a known disposable email provider
  static bool _isDisposableEmail(String email) {
    // Common disposable email domains (partial list for security)
    const disposableDomains = {
      '10minutemail.com',
      'tempmail.org',
      'guerrillamail.com',
      'mailinator.com',
      'yopmail.com',
      'temp-mail.org',
      'throwaway.email',
    };
    
    final domain = email.split('@').last.toLowerCase();
    return disposableDomains.contains(domain);
  }
  
  /// Sanitize metadata value to safe types
  static dynamic _sanitizeMetadataValue(dynamic value) {
    if (value is String) {
      final sanitized = value.trim();
      if (sanitized.length > 500) {
        return sanitized.substring(0, 500); // Truncate long strings
      }
      return sanitized;
    } else if (value is num || value is bool) {
      return value;
    } else if (value == null) {
      return null;
    }
    
    // Invalid type
    return null;
  }
}

/// Result wrapper for validation operations
class ValidationResult {
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
  final String? userGuidance;
  final dynamic value;
  
  const ValidationResult._({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
    this.userGuidance,
    this.value,
  });
  
  /// Create successful validation result
  static ValidationResult success(dynamic value) {
    return ValidationResult._(
      isValid: true,
      value: value,
    );
  }
  
  /// Create failed validation result
  static ValidationResult failure(
    String errorCode,
    String errorMessage,
    String userGuidance,
  ) {
    return ValidationResult._(
      isValid: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
      userGuidance: userGuidance,
    );
  }
  
  /// Convert to PremiumError
  PremiumError toError() {
    if (isValid) {
      throw StateError('Cannot convert successful validation to error');
    }
    
    return PremiumError.validation(
      errorMessage!,
      context: {
        'error_code': errorCode,
        'user_guidance': userGuidance,
      },
    );
  }
  
  /// Get user-friendly error message with guidance
  String get userMessage => userGuidance ?? errorMessage ?? 'Validation failed';
  
  @override
  String toString() => isValid 
      ? 'ValidationResult(success: $value)' 
      : 'ValidationResult(error: $errorCode - $errorMessage)';
}