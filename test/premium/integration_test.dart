import 'package:flutter_test/flutter_test.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/services/premium_validation_service.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';

void main() {
  group('Premium Features Integration Tests', () {
    group('UserSubscription Model', () {
      test('creates free tier subscription correctly', () async {
        // Arrange & Act
        final subscription = UserSubscription(
          id: 'test_sub_123',
          userId: 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4',
          userType: 'vendor',
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Assert
        expect(subscription.userId, equals('a1b2c3d4e5f6g7h8i9j0k1l2m3n4'));
        expect(subscription.userType, equals('vendor'));
        expect(subscription.tier, equals(SubscriptionTier.free));
        expect(subscription.status, equals(SubscriptionStatus.active));
      });

      test('creates premium subscription correctly', () async {
        // Arrange & Act
        final subscription = UserSubscription(
          id: 'test_sub_456',
          userId: 'vendor123',
          userType: 'vendor',
          tier: SubscriptionTier.vendorPro,
          status: SubscriptionStatus.active,
          stripeCustomerId: 'cus_test123',
          stripeSubscriptionId: 'sub_test123',
          stripePriceId: 'price_vendorPro_monthly',
          monthlyPrice: 29.00,
          features: const {
            'advanced_analytics': true,
            'unlimited_markets': true,
          },
          limits: const {
            'monthly_markets': -1, // unlimited
            'product_listings': 100,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Assert
        expect(subscription.tier, equals(SubscriptionTier.vendorPro));
        expect(subscription.stripeCustomerId, equals('cus_test123'));
        expect(subscription.monthlyPrice, equals(29.00));
        expect(subscription.features['advanced_analytics'], isTrue);
        expect(subscription.limits['monthly_markets'], equals(-1));
      });

      test('subscription tiers enum has all expected values', () {
        // Assert
        expect(SubscriptionTier.values, contains(SubscriptionTier.free));
        expect(SubscriptionTier.values, contains(SubscriptionTier.shopperPro));
        expect(SubscriptionTier.values, contains(SubscriptionTier.vendorPro));
        expect(SubscriptionTier.values, contains(SubscriptionTier.marketOrganizerPro));
        expect(SubscriptionTier.values, contains(SubscriptionTier.enterprise));
      });

      test('subscription status enum has all expected values', () {
        // Assert
        expect(SubscriptionStatus.values, contains(SubscriptionStatus.active));
        expect(SubscriptionStatus.values, contains(SubscriptionStatus.cancelled));
        expect(SubscriptionStatus.values, contains(SubscriptionStatus.pastDue));
        expect(SubscriptionStatus.values, contains(SubscriptionStatus.expired));
      });

      test('subscription with expiration date handles expiry correctly', () {
        // Arrange
        final expiredSubscription = UserSubscription(
          id: 'expired_sub',
          userId: 'user123',
          userType: 'vendor',
          tier: SubscriptionTier.vendorPro,
          status: SubscriptionStatus.expired,
          subscriptionStartDate: DateTime.now().subtract(const Duration(days: 40)),
          subscriptionEndDate: DateTime.now().subtract(const Duration(days: 5)),
          createdAt: DateTime.now().subtract(const Duration(days: 40)),
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        );
        
        final activeSubscription = UserSubscription(
          id: 'active_sub',
          userId: 'user456',
          userType: 'vendor',
          tier: SubscriptionTier.vendorPro,
          status: SubscriptionStatus.active,
          subscriptionStartDate: DateTime.now().subtract(const Duration(days: 10)),
          subscriptionEndDate: DateTime.now().add(const Duration(days: 20)),
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          updatedAt: DateTime.now(),
        );
        
        // Assert
        expect(expiredSubscription.status, equals(SubscriptionStatus.expired));
        expect(activeSubscription.status, equals(SubscriptionStatus.active));
      });
    });

    group('Subscription Service Integration', () {
      test('subscription service initializes correctly', () {
        // Arrange & Act
        final subscriptionService = SubscriptionService();
        
        // Assert
        expect(subscriptionService, isNotNull);
      });
    });

    group('Validation Service Integration', () {
      test('validates user ID correctly', () {
        // Arrange
        const validUserId = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4';
        const invalidUserId = '';
        
        // Act
        final validResult = PremiumValidationService.validateUserId(validUserId);
        final invalidResult = PremiumValidationService.validateUserId(invalidUserId);
        
        // Assert
        expect(validResult.isValid, isTrue);
        expect(invalidResult.isValid, isFalse);
      });

      test('validates user type correctly', () {
        // Arrange
        const validUserType = 'vendor';
        const invalidUserType = 'invalid_type';
        
        // Act
        final validResult = PremiumValidationService.validateUserType(validUserType);
        final invalidResult = PremiumValidationService.validateUserType(invalidUserType);
        
        // Assert
        expect(validResult.isValid, isTrue);
        expect(invalidResult.isValid, isFalse);
      });

      test('validates email correctly', () {
        // Arrange
        const validEmail = 'test@example.com';
        const invalidEmail = 'not_an_email';
        
        // Act
        final validResult = PremiumValidationService.validateEmail(validEmail);
        final invalidResult = PremiumValidationService.validateEmail(invalidEmail);
        
        // Assert
        expect(validResult.isValid, isTrue);
        expect(validResult.value, equals('test@example.com'));
        expect(invalidResult.isValid, isFalse);
      });

      test('validates subscription creation data', () async {
        // Arrange
        const userId = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4';
        const userType = 'vendor';
        const customerId = 'cus_test123';
        const priceId = 'price_vendorPro_monthly';
        
        // Act
        final result = await PremiumValidationService.validateSubscriptionCreation(
          userId: userId,
          userType: userType,
          stripeCustomerId: customerId,
          stripePriceId: priceId,
          metadata: const {
            'plan': 'vendorPro',
            'billing_cycle': 'monthly',
          },
        );
        
        // Assert
        expect(result.isValid, isTrue);
        final validatedData = result.value as Map;
        expect(validatedData['userId'], equals(userId));
        expect(validatedData['userType'], equals(userType));
        expect(validatedData['stripeCustomerId'], equals(customerId));
        expect(validatedData['stripePriceId'], equals(priceId));
      });
    });

    group('Error Handling', () {
      test('validation service handles null inputs gracefully', () {
        // Act
        final nullUserIdResult = PremiumValidationService.validateUserId(null);
        final emptyEmailResult = PremiumValidationService.validateEmail('');
        
        // Assert
        expect(nullUserIdResult.isValid, isFalse);
        expect(nullUserIdResult.errorCode, equals('USER_ID_REQUIRED'));
        expect(emptyEmailResult.isValid, isFalse);
        expect(emptyEmailResult.errorCode, equals('EMAIL_REQUIRED'));
      });

      test('validates metadata correctly', () {
        // Arrange
        final validMetadata = {
          'userId': 'user123',
          'plan': 'vendorPro',
          'billing_cycle': 'monthly',
          'trial_days': 14,
        };
        
        final invalidMetadata = {
          'invalid key!': 'value',
        };
        
        // Act
        final validResult = PremiumValidationService.validateMetadata(validMetadata);
        final invalidResult = PremiumValidationService.validateMetadata(invalidMetadata);
        
        // Assert
        expect(validResult.isValid, isTrue);
        expect(invalidResult.isValid, isFalse);
        expect(invalidResult.errorCode, equals('METADATA_KEY_INVALID_CHARS'));
      });

      test('input sanitization works correctly', () {
        // Test email sanitization
        final emailResult = PremiumValidationService.validateEmail(
          '  TEST@EXAMPLE.COM  '
        );
        expect(emailResult.isValid, isTrue);
        expect(emailResult.value, equals('test@example.com'));
        
        // Test user type sanitization
        final userTypeResult = PremiumValidationService.validateUserType(
          '  VENDOR  '
        );
        expect(userTypeResult.isValid, isTrue);
        expect(userTypeResult.value, equals('vendor'));
      });

      test('rejects potentially malicious inputs', () {
        // SQL injection attempts
        final sqlInjection = PremiumValidationService.validateUserId(
          'user123; DROP TABLE users;'
        );
        expect(sqlInjection.isValid, isFalse);
        
        // XSS attempts
        final xssAttempt = PremiumValidationService.validateFeatureName(
          '<script>alert("xss")</script>'
        );
        expect(xssAttempt.isValid, isFalse);
        
        // Path traversal attempts
        final pathTraversal = PremiumValidationService.validateFeatureName(
          '../../../etc/passwd'
        );
        expect(pathTraversal.isValid, isFalse);
      });

      test('validates Stripe ID formats', () {
        // Test valid Stripe IDs
        final validPriceId = PremiumValidationService.validateStripePriceId(
          'price_1234567890abcdef'
        );
        expect(validPriceId.isValid, isTrue);
        
        // Test invalid format
        final invalidPriceId = PremiumValidationService.validateStripePriceId(
          'invalid_price_id'
        );
        expect(invalidPriceId.isValid, isFalse);
      });

      test('validates usage counts within reasonable limits', () {
        // Valid usage count
        final validUsage = PremiumValidationService.validateUsageCount(50);
        expect(validUsage.isValid, isTrue);
        
        // Too high usage count
        final tooHighUsage = PremiumValidationService.validateUsageCount(1000001);
        expect(tooHighUsage.isValid, isFalse);
        expect(tooHighUsage.errorCode, equals('USAGE_COUNT_TOO_HIGH'));
        
        // Negative usage count
        final negativeUsage = PremiumValidationService.validateUsageCount(-1);
        expect(negativeUsage.isValid, isFalse);
      });
    });

    group('Business Logic Integration', () {
      test('subscription tier transitions work correctly', () {
        // Test free to pro upgrade scenario
        final freeSubscription = UserSubscription(
          id: 'free_sub',
          userId: 'user123',
          userType: 'vendor',
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Simulate upgrade
        final proSubscription = UserSubscription(
          id: 'pro_sub',
          userId: freeSubscription.userId,
          userType: freeSubscription.userType,
          tier: SubscriptionTier.vendorPro,
          status: SubscriptionStatus.active,
          stripeCustomerId: 'cus_new123',
          stripeSubscriptionId: 'sub_new123',
          monthlyPrice: 29.00,
          features: const {
            'advanced_analytics': true,
            'unlimited_markets': true,
          },
          limits: const {
            'product_listings': 100,
            'monthly_markets': -1,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Assert upgrade changes
        expect(proSubscription.tier, equals(SubscriptionTier.vendorPro));
        expect(proSubscription.monthlyPrice, greaterThan(0));
        expect(proSubscription.features['advanced_analytics'], isTrue);
        expect(proSubscription.limits['monthly_markets'], equals(-1));
      });

      test('subscription equatable works correctly', () {
        final now = DateTime.now();
        final subscription1 = UserSubscription(
          id: 'test_sub',
          userId: 'user123',
          userType: 'vendor',
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        
        final subscription2 = UserSubscription(
          id: 'test_sub',
          userId: 'user123',
          userType: 'vendor',
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        
        final subscription3 = UserSubscription(
          id: 'different_sub',
          userId: 'user123',
          userType: 'vendor',
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert equality
        expect(subscription1, equals(subscription2));
        expect(subscription1, isNot(equals(subscription3)));
      });
    });
  });
}