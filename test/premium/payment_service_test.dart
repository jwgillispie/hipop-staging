import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hipop/features/premium/services/payment_service.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for tests with minimal config
    dotenv.testLoad(mergeWith: {
      'STRIPE_PRICE_VENDOR_PRO': 'price_test_vendor',
      'STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM': 'price_test_organizer',
      'STRIPE_PRICE_SHOPPER_PREMIUM': 'price_test_shopper',
    });
  });

  group('PaymentService', () {
    group('Static Methods', () {
      test('getPricingForUserType returns correct pricing for vendor', () {
        // Act
        final pricing = PaymentService.getPricingForUserType('vendor');
        
        // Assert
        expect(pricing.name, equals('Vendor Pro'));
        expect(pricing.amount, equals(29.00));
        expect(pricing.currency, equals('USD'));
        expect(pricing.interval, equals('month'));
        expect(pricing.features, contains('Unlimited market applications'));
      });

      test('getPricingForUserType returns correct pricing for market_organizer', () {
        // Act
        final pricing = PaymentService.getPricingForUserType('market_organizer');
        
        // Assert
        expect(pricing.name, equals('Market Organizer Premium'));
        expect(pricing.amount, equals(69.00));
        expect(pricing.currency, equals('USD'));
        expect(pricing.interval, equals('month'));
        expect(pricing.features, contains('Unlimited vendor posts'));
      });

      test('getPricingForUserType returns correct pricing for shopper', () {
        // Act
        final pricing = PaymentService.getPricingForUserType('shopper');
        
        // Assert
        expect(pricing.name, equals('Shopper Premium'));
        expect(pricing.amount, equals(4.00));
        expect(pricing.currency, equals('USD'));
        expect(pricing.interval, equals('month'));
        expect(pricing.features, contains('Follow unlimited vendors'));
      });

      test('getPricingForUserType throws for invalid user type', () {
        // Act & Assert
        expect(
          () => PaymentService.getPricingForUserType('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('getSubscriptionTierForUserType returns correct tiers', () {
        // Act & Assert
        expect(PaymentService.getSubscriptionTierForUserType('vendor'), 
               equals(SubscriptionTier.vendorPro));
        expect(PaymentService.getSubscriptionTierForUserType('market_organizer'), 
               equals(SubscriptionTier.marketOrganizerPro));
        expect(PaymentService.getSubscriptionTierForUserType('shopper'), 
               equals(SubscriptionTier.shopperPro));
      });

      test('getSubscriptionTierForUserType throws for invalid user type', () {
        // Act & Assert
        expect(
          () => PaymentService.getSubscriptionTierForUserType('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('calculateFinalAmount applies percentage discount correctly', () {
        // Arrange
        const originalAmount = 100.0;
        const promoValidation = PromoCodeValidation(
          isValid: true,
          discountPercent: 20.0,
        );

        // Act
        final finalAmount = PaymentService.calculateFinalAmount(originalAmount, promoValidation);

        // Assert
        expect(finalAmount, equals(80.0));
      });

      test('calculateFinalAmount applies fixed discount correctly', () {
        // Arrange
        const originalAmount = 100.0;
        const promoValidation = PromoCodeValidation(
          isValid: true,
          discountAmount: 15.0,
        );

        // Act
        final finalAmount = PaymentService.calculateFinalAmount(originalAmount, promoValidation);

        // Assert
        expect(finalAmount, equals(85.0));
      });

      test('calculateFinalAmount returns original amount for invalid promo', () {
        // Arrange
        const originalAmount = 100.0;
        const promoValidation = PromoCodeValidation(
          isValid: false,
        );

        // Act
        final finalAmount = PaymentService.calculateFinalAmount(originalAmount, promoValidation);

        // Assert
        expect(finalAmount, equals(originalAmount));
      });

      test('calculateFinalAmount returns original amount for null promo', () {
        // Arrange
        const originalAmount = 100.0;

        // Act
        final finalAmount = PaymentService.calculateFinalAmount(originalAmount, null);

        // Assert
        expect(finalAmount, equals(originalAmount));
      });

      test('calculateFinalAmount clamps discount to not go below zero', () {
        // Arrange
        const originalAmount = 50.0;
        const promoValidation = PromoCodeValidation(
          isValid: true,
          discountAmount: 75.0, // More than original amount
        );

        // Act
        final finalAmount = PaymentService.calculateFinalAmount(originalAmount, promoValidation);

        // Assert
        expect(finalAmount, equals(0.0));
      });

      test('isApplePaySupported returns false on web', () async {
        // Act
        final isSupported = await PaymentService.isApplePaySupported();

        // Assert
        expect(isSupported, isFalse);
      });

      test('isGooglePaySupported returns false on web', () async {
        // Act
        final isSupported = await PaymentService.isGooglePaySupported();

        // Assert
        expect(isSupported, isFalse);
      });
    });

    group('SubscriptionPricing', () {
      test('formattedAmount displays correctly', () {
        // Arrange
        const pricing = SubscriptionPricing(
          priceId: 'price_test',
          amount: 29.99,
          currency: 'USD',
          interval: 'month',
          name: 'Test Plan',
          description: 'Test description',
          features: ['Feature 1'],
        );

        // Act & Assert
        expect(pricing.formattedAmount, equals('\$29.99'));
      });

      test('displayName combines name, amount, and interval', () {
        // Arrange
        const pricing = SubscriptionPricing(
          priceId: 'price_test',
          amount: 29.99,
          currency: 'USD',
          interval: 'month',
          name: 'Test Plan',
          description: 'Test description',
          features: ['Feature 1'],
        );

        // Act & Assert
        expect(pricing.displayName, equals('Test Plan - \$29.99/month'));
      });
    });

    group('PaymentException', () {
      test('creates exception with message', () {
        // Arrange
        const message = 'Payment failed';
        const exception = PaymentException(message);

        // Act & Assert
        expect(exception.message, equals(message));
        expect(exception.toString(), equals('PaymentException: Payment failed'));
      });
    });

    group('PromoCodeValidation', () {
      test('creates validation result with all fields', () {
        // Arrange & Act
        const validation = PromoCodeValidation(
          isValid: true,
          discountPercent: 20.0,
          discountAmount: 10.0,
          description: 'Test discount',
          errorMessage: null,
        );

        // Assert
        expect(validation.isValid, isTrue);
        expect(validation.discountPercent, equals(20.0));
        expect(validation.discountAmount, equals(10.0));
        expect(validation.description, equals('Test discount'));
        expect(validation.errorMessage, isNull);
      });

      test('creates invalid validation result with error', () {
        // Arrange & Act
        const validation = PromoCodeValidation(
          isValid: false,
          errorMessage: 'Invalid code',
        );

        // Assert
        expect(validation.isValid, isFalse);
        expect(validation.errorMessage, equals('Invalid code'));
        expect(validation.discountPercent, isNull);
        expect(validation.discountAmount, isNull);
      });
    });
  });
}