import 'package:flutter_test/flutter_test.dart';
import 'package:hipop/features/premium/services/premium_validation_service.dart';

void main() {
  group('PremiumValidationService', () {
    group('validateUserId', () {
      test('accepts valid Firebase Auth UID', () {
        // Arrange
        const validUserId = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4';

        // Act
        final result = PremiumValidationService.validateUserId(validUserId);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals(validUserId));
      });

      test('rejects null or empty user ID', () {
        // Act & Assert
        final nullResult = PremiumValidationService.validateUserId(null);
        expect(nullResult.isValid, isFalse);
        expect(nullResult.errorCode, equals('USER_ID_REQUIRED'));

        final emptyResult = PremiumValidationService.validateUserId('');
        expect(emptyResult.isValid, isFalse);
        expect(emptyResult.errorCode, equals('USER_ID_REQUIRED'));
      });

      test('rejects user ID with invalid format', () {
        // Arrange
        const invalidUserIds = [
          'too_short',
          'contains-hyphens-not-allowed',
          'contains spaces in the middle',
          'special!@#chars',
          '123', // Too short
        ];

        // Act & Assert
        for (final userId in invalidUserIds) {
          final result = PremiumValidationService.validateUserId(userId);
          expect(result.isValid, isFalse,
              reason: 'Should reject userId: $userId');
        }
      });

      test('rejects user ID with injection attempts', () {
        // Arrange
        const maliciousUserIds = [
          '<script>alert("xss")</script>',
          'SELECT * FROM users',
          'DROP TABLE users',
          'onload=alert(1)',
        ];

        // Act & Assert
        for (final userId in maliciousUserIds) {
          final result = PremiumValidationService.validateUserId(userId);
          expect(result.isValid, isFalse,
              reason: 'Should reject malicious userId: $userId');
        }
      });
    });

    group('validateEmail', () {
      test('accepts valid email addresses', () {
        // Arrange
        const validEmails = [
          'user@example.com',
          'test.user@company.co.uk',
          'name+tag@domain.org',
          'user123@test-domain.com',
        ];

        // Act & Assert
        for (final email in validEmails) {
          final result = PremiumValidationService.validateEmail(email);
          expect(result.isValid, isTrue,
              reason: 'Should accept email: $email');
          expect(result.value, equals(email.toLowerCase().trim()));
        }
      });

      test('rejects invalid email formats', () {
        // Arrange
        const invalidEmails = [
          'notanemail',
          '@nodomain.com',
          'user@',
          'user @domain.com',
          'user@domain',
          'user@.com',
          'user..name@domain.com',
        ];

        // Act & Assert
        for (final email in invalidEmails) {
          final result = PremiumValidationService.validateEmail(email);
          expect(result.isValid, isFalse,
              reason: 'Should reject email: $email');
          expect(result.errorCode, equals('EMAIL_INVALID_FORMAT'));
        }
      });

      test('rejects disposable email addresses', () {
        // Arrange
        const disposableEmails = [
          'test@10minutemail.com',
          'user@tempmail.org',
          'throwaway@guerrillamail.com',
          'temp@mailinator.com',
        ];

        // Act & Assert
        for (final email in disposableEmails) {
          final result = PremiumValidationService.validateEmail(email);
          expect(result.isValid, isFalse,
              reason: 'Should reject disposable email: $email');
          expect(result.errorCode, equals('EMAIL_DISPOSABLE'));
        }
      });

      test('rejects email addresses that are too long', () {
        // Arrange
        final longEmail = '${'a' * 250}@example.com';

        // Act
        final result = PremiumValidationService.validateEmail(longEmail);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('EMAIL_TOO_LONG'));
      });

      test('normalizes email addresses', () {
        // Arrange
        const emailWithSpaces = '  User@Example.COM  ';

        // Act
        final result = PremiumValidationService.validateEmail(emailWithSpaces);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals('user@example.com'));
      });
    });

    group('validateUserType', () {
      test('accepts valid user types', () {
        // Arrange
        const validUserTypes = ['shopper', 'vendor', 'market_organizer'];

        // Act & Assert
        for (final userType in validUserTypes) {
          final result = PremiumValidationService.validateUserType(userType);
          expect(result.isValid, isTrue,
              reason: 'Should accept userType: $userType');
          expect(result.value, equals(userType));
        }
      });

      test('rejects invalid user types', () {
        // Arrange
        const invalidUserTypes = [
          'admin',
          'superuser',
          'customer',
          'buyer',
          '',
        ];

        // Act & Assert
        for (final userType in invalidUserTypes) {
          final result = PremiumValidationService.validateUserType(userType);
          expect(result.isValid, isFalse,
              reason: 'Should reject userType: $userType');
        }
      });

      test('normalizes user type case', () {
        // Arrange
        const mixedCaseUserType = '  VENDOR  ';

        // Act
        final result =
            PremiumValidationService.validateUserType(mixedCaseUserType);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals('vendor'));
      });
    });

    group('validateSubscriptionTier', () {
      test('accepts valid subscription tiers', () {
        // Arrange
        const validTiers = [
          'free',
          'shopperPro',
          'vendorPro',
          'marketOrganizerPro',
          'enterprise',
        ];

        // Act & Assert
        for (final tier in validTiers) {
          final result = PremiumValidationService.validateSubscriptionTier(tier);
          expect(result.isValid, isTrue, reason: 'Should accept tier: $tier');
          expect(result.value, equals(tier));
        }
      });

      test('rejects invalid subscription tiers', () {
        // Arrange
        const invalidTiers = [
          'basic',
          'premium',
          'gold',
          'platinum',
        ];

        // Act & Assert
        for (final tier in invalidTiers) {
          final result = PremiumValidationService.validateSubscriptionTier(tier);
          expect(result.isValid, isFalse,
              reason: 'Should reject tier: $tier');
          expect(result.errorCode, equals('TIER_INVALID'));
        }
        
        // Test empty tier separately
        final emptyResult = PremiumValidationService.validateSubscriptionTier('');
        expect(emptyResult.isValid, isFalse);
        expect(emptyResult.errorCode, equals('TIER_REQUIRED'));
      });
    });

    group('validateStripePriceId', () {
      test('accepts valid Stripe price IDs', () {
        // Arrange
        const validPriceIds = [
          'price_1234567890abcdef',
          'price_test_monthly_subscription',
          'price_ABCDEFGHIJKLMNOP',
        ];

        // Act & Assert
        for (final priceId in validPriceIds) {
          final result = PremiumValidationService.validateStripePriceId(priceId);
          expect(result.isValid, isTrue,
              reason: 'Should accept priceId: $priceId');
          expect(result.value, equals(priceId));
        }
      });

      test('rejects invalid Stripe price IDs', () {
        // Arrange
        const invalidPriceIds = [
          'not_price_id',
          'price-with-hyphens',
          'price_',
          'price_!@#',
          '',
        ];

        // Act & Assert
        for (final priceId in invalidPriceIds) {
          final result = PremiumValidationService.validateStripePriceId(priceId);
          expect(result.isValid, isFalse,
              reason: 'Should reject priceId: $priceId');
        }
      });

      test('rejects price IDs with invalid length', () {
        // Arrange
        const tooShort = 'price_1';
        final tooLong = 'price_${'a' * 100}';

        // Act & Assert
        expect(PremiumValidationService.validateStripePriceId(tooShort).isValid,
            isFalse);
        expect(PremiumValidationService.validateStripePriceId(tooLong).isValid,
            isFalse);
      });
    });

    group('validateStripeCustomerId', () {
      test('accepts valid Stripe customer IDs', () {
        // Arrange
        const validCustomerIds = [
          'cus_1234567890abcdef',
          'cus_test_customer',
          'cus_ABCDEFGHIJKLMNOP',
        ];

        // Act & Assert
        for (final customerId in validCustomerIds) {
          final result =
              PremiumValidationService.validateStripeCustomerId(customerId);
          expect(result.isValid, isTrue,
              reason: 'Should accept customerId: $customerId');
          expect(result.value, equals(customerId));
        }
      });

      test('accepts null customer ID as optional field', () {
        // Act
        final result = PremiumValidationService.validateStripeCustomerId(null);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, isNull);
      });

      test('rejects invalid Stripe customer IDs', () {
        // Arrange
        const invalidCustomerIds = [
          'not_customer_id',
          'cus-with-hyphens',
          'cus_!@#',
          'customer_id',
        ];

        // Act & Assert
        for (final customerId in invalidCustomerIds) {
          final result =
              PremiumValidationService.validateStripeCustomerId(customerId);
          expect(result.isValid, isFalse,
              reason: 'Should reject customerId: $customerId');
        }
      });
    });

    group('validateMetadata', () {
      test('accepts valid metadata', () {
        // Arrange
        final validMetadata = {
          'userId': 'user123',
          'planName': 'vendorPro',
          'isActive': true,
          'credits': 100,
        };

        // Act
        final result = PremiumValidationService.validateMetadata(validMetadata);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals(validMetadata));
      });

      test('accepts null metadata', () {
        // Act
        final result = PremiumValidationService.validateMetadata(null);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals({}));
      });

      test('rejects metadata with invalid key format', () {
        // Arrange
        final invalidMetadata = {
          'invalid key!': 'value',
        };

        // Act
        final result = PremiumValidationService.validateMetadata(invalidMetadata);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('METADATA_KEY_INVALID_CHARS'));
      });

      test('rejects metadata with keys that are too long', () {
        // Arrange
        final invalidMetadata = {
          'a' * 101: 'value',
        };

        // Act
        final result = PremiumValidationService.validateMetadata(invalidMetadata);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('METADATA_KEY_INVALID'));
      });

      test('truncates long string values', () {
        // Arrange
        final longValue = 'a' * 600;
        final metadata = {
          'description': longValue,
        };

        // Act
        final result = PremiumValidationService.validateMetadata(metadata);

        // Assert
        expect(result.isValid, isTrue);
        expect((result.value as Map)['description'].length, equals(500));
      });

      test('rejects metadata that is too large overall', () {
        // Arrange
        final largeMetadata = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          largeMetadata['key_$i'] = 'value' * 50;
        }

        // Act
        final result = PremiumValidationService.validateMetadata(largeMetadata);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('METADATA_TOO_LARGE'));
      });
    });

    group('validateFeatureName', () {
      test('accepts valid feature names in snake_case', () {
        // Arrange
        const validFeatureNames = [
          'advanced_analytics',
          'monthly_reports',
          'api_access',
          'custom_branding',
          'a',
        ];

        // Act & Assert
        for (final featureName in validFeatureNames) {
          final result = PremiumValidationService.validateFeatureName(featureName);
          expect(result.isValid, isTrue,
              reason: 'Should accept featureName: $featureName');
          expect(result.value, equals(featureName.toLowerCase()));
        }
      });

      test('rejects invalid feature name formats', () {
        // Arrange
        const invalidFeatureNames = [
          'kebab-case',
          'space separated',
          '123_starts_with_number',
          '_starts_with_underscore',
          'ends_with_underscore_',
        ];

        // Act & Assert
        for (final featureName in invalidFeatureNames) {
          final result = PremiumValidationService.validateFeatureName(featureName);
          expect(result.isValid, isFalse,
              reason: 'Should reject featureName: $featureName');
        }
      });

      test('converts mixed case to lowercase and validates', () {
        // Arrange
        const mixedCaseFeatureName = 'CamelCase';
        
        // Act
        final result = PremiumValidationService.validateFeatureName(mixedCaseFeatureName);
        
        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals('camelcase'));
      });

      test('rejects feature names that are too long', () {
        // Arrange
        final longFeatureName = 'a' * 51;

        // Act
        final result = PremiumValidationService.validateFeatureName(longFeatureName);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('FEATURE_NAME_TOO_LONG'));
      });
    });

    group('validateLimitName', () {
      test('accepts valid limit names in snake_case', () {
        // Arrange
        const validLimitNames = [
          'monthly_markets',
          'vendor_posts',
          'product_listings',
          'analytics_reports',
          'a',
        ];

        // Act & Assert
        for (final limitName in validLimitNames) {
          final result = PremiumValidationService.validateLimitName(limitName);
          expect(result.isValid, isTrue,
              reason: 'Should accept limitName: $limitName');
          expect(result.value, equals(limitName.toLowerCase()));
        }
      });

      test('rejects invalid limit name formats', () {
        // Arrange
        const invalidLimitNames = [
          'kebab-case',
          'space separated',
          '123_starts_with_number',
          '_starts_with_underscore',
          'ends_with_underscore_',
        ];

        // Act & Assert
        for (final limitName in invalidLimitNames) {
          final result = PremiumValidationService.validateLimitName(limitName);
          expect(result.isValid, isFalse,
              reason: 'Should reject limitName: $limitName');
        }
      });

      test('converts mixed case to lowercase and validates', () {
        // Arrange
        const mixedCaseLimitName = 'CamelCase';
        
        // Act
        final result = PremiumValidationService.validateLimitName(mixedCaseLimitName);
        
        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals('camelcase'));
      });

      test('rejects limit names that are too long', () {
        // Arrange
        final longLimitName = 'a' * 51;

        // Act
        final result = PremiumValidationService.validateLimitName(longLimitName);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('LIMIT_NAME_TOO_LONG'));
      });
    });

    group('validateUsageCount', () {
      test('accepts valid usage counts', () {
        // Arrange
        const validCounts = [0, 1, 100, 999999];

        // Act & Assert
        for (final count in validCounts) {
          final result = PremiumValidationService.validateUsageCount(count);
          expect(result.isValid, isTrue,
              reason: 'Should accept count: $count');
          expect(result.value, equals(count));
        }
      });

      test('rejects negative usage counts', () {
        // Act
        final result = PremiumValidationService.validateUsageCount(-1);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('USAGE_COUNT_NEGATIVE'));
      });

      test('rejects unreasonably high usage counts', () {
        // Act
        final result = PremiumValidationService.validateUsageCount(1000001);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('USAGE_COUNT_TOO_HIGH'));
      });

      test('rejects null usage count', () {
        // Act
        final result = PremiumValidationService.validateUsageCount(null);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('USAGE_COUNT_REQUIRED'));
      });
    });

    group('validateSubscriptionCreation', () {
      test('successfully validates complete subscription creation data', () async {
        // Arrange
        const userId = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4';
        const userType = 'vendor';
        const stripeCustomerId = 'cus_test123';
        const stripePriceId = 'price_test123';
        final metadata = {'plan': 'vendorPro'};

        // Act
        final result = await PremiumValidationService.validateSubscriptionCreation(
          userId: userId,
          userType: userType,
          stripeCustomerId: stripeCustomerId,
          stripePriceId: stripePriceId,
          metadata: metadata,
        );

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, isA<Map>());
        final validatedData = result.value as Map;
        expect(validatedData['userId'], equals(userId));
        expect(validatedData['userType'], equals(userType));
        expect(validatedData['stripeCustomerId'], equals(stripeCustomerId));
        expect(validatedData['stripePriceId'], equals(stripePriceId));
        expect(validatedData['metadata'], equals(metadata));
      });

      test('fails when required fields are missing', () async {
        // Act
        final result = await PremiumValidationService.validateSubscriptionCreation(
          userId: null,
          userType: 'vendor',
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('USER_ID_REQUIRED'));
      });

      test('fails when user type is invalid', () async {
        // Arrange
        const userId = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4';

        // Act
        final result = await PremiumValidationService.validateSubscriptionCreation(
          userId: userId,
          userType: 'invalid_type',
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('USER_TYPE_INVALID'));
      });
    });

    group('ValidationResult', () {
      test('creates successful result with value', () {
        // Act
        final result = ValidationResult.success('test_value');

        // Assert
        expect(result.isValid, isTrue);
        expect(result.value, equals('test_value'));
        expect(result.errorCode, isNull);
        expect(result.errorMessage, isNull);
      });

      test('creates failure result with error details', () {
        // Act
        final result = ValidationResult.failure(
          'ERROR_CODE',
          'Error message',
          'User guidance message',
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errorCode, equals('ERROR_CODE'));
        expect(result.errorMessage, equals('Error message'));
        expect(result.userGuidance, equals('User guidance message'));
      });

      test('converts to PremiumError correctly', () {
        // Arrange
        final result = ValidationResult.failure(
          'ERROR_CODE',
          'Error message',
          'User guidance message',
        );

        // Act
        final error = result.toError();

        // Assert
        expect(error.message, equals('Error message'));
        expect(error.context?['error_code'], equals('ERROR_CODE'));
        expect(error.context?['user_guidance'], equals('User guidance message'));
      });

      test('throws when converting successful result to error', () {
        // Arrange
        final result = ValidationResult.success('value');

        // Act & Assert
        expect(() => result.toError(), throwsStateError);
      });
    });
  });
}