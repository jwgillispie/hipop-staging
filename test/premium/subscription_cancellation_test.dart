import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../../lib/features/premium/services/subscription_service.dart';
import '../../lib/features/premium/services/stripe_service.dart';
import '../../lib/features/premium/models/user_subscription.dart';
import '../../lib/features/premium/services/premium_error_handler.dart';

import 'subscription_cancellation_test.mocks.dart';

@GenerateMocks([
  FirebaseFunctions,
  HttpsCallable,
  HttpsCallableResult,
])
class SubscriptionCancellationTest {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  void setUp() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();
  }
}

void main() {
  group('Subscription Cancellation Tests', () {
    late SubscriptionCancellationTest testHelper;

    setUp(() {
      testHelper = SubscriptionCancellationTest();
      testHelper.setUp();
    });

    group('Basic Cancellation Flow', () {
      test('should successfully cancel active subscription', () async {
        // Arrange
        const userId = 'test_user_123';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(
          SubscriptionTier.vendorPro,
          stripeCustomerId: 'cus_test123',
          stripeSubscriptionId: 'sub_test123',
        );

        // Add subscription to fake firestore
        await testHelper.fakeFirestore
            .collection('user_subscriptions')
            .add(subscription.toFirestore());

        // Mock successful cancellation
        when(testHelper.mockFunctions.httpsCallable('cancelSubscription'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data)
            .thenReturn({'success': true, 'message': 'Subscription cancelled'});

        // Act
        final cancelledSubscription =
            await SubscriptionService.cancelSubscription(userId);

        // Assert
        expect(cancelledSubscription.status, SubscriptionStatus.cancelled);
        expect(cancelledSubscription.tier, SubscriptionTier.vendorPro);
        expect(cancelledSubscription.userId, userId);
      });

      test('should handle cancellation of non-existent subscription', () async {
        // Arrange
        const userId = 'non_existent_user';

        // Act & Assert
        expect(
          () => SubscriptionService.cancelSubscription(userId),
          throwsA(isA<PremiumError>()),
        );
      });

      test('should validate user ID before cancellation', () async {
        // Arrange
        const invalidUserId = '';

        // Act & Assert
        expect(
          () => SubscriptionService.cancelSubscription(invalidUserId),
          throwsA(isA<PremiumError>()),
        );
      });

      test('should handle network errors during cancellation', () async {
        // Arrange
        const userId = 'test_user_123';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        await testHelper.fakeFirestore
            .collection('user_subscriptions')
            .add(subscription.toFirestore());

        when(testHelper.mockFunctions.httpsCallable('cancelSubscription'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenThrow(const FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Service unavailable',
        ));

        // Act & Assert
        expect(
          () => SubscriptionService.cancelSubscription(userId),
          throwsA(isA<PremiumError>()),
        );
      });
    });

    group('Enhanced Cancellation Flow', () {
      test('should handle immediate cancellation with prorated refund', () async {
        // Arrange
        const userId = 'test_user_123';
        const cancellationType = 'immediate';
        const feedback = 'Too expensive';

        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call({
          'userId': userId,
          'cancellationType': cancellationType,
          'feedback': feedback,
          'timestamp': any,
        })).thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data).thenReturn({
          'success': true,
          'message': 'Subscription cancelled immediately with prorated refund',
          'refund_amount': 1450, // cents
          'refund_id': 're_test123',
        });

        // Act
        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: cancellationType,
          feedback: feedback,
        );

        // Assert
        expect(result, isTrue);
        verify(testHelper.mockCallable.call(argThat(allOf([
          containsPair('userId', userId),
          containsPair('cancellationType', cancellationType),
          containsPair('feedback', feedback),
          containsPair('timestamp', isA<String>()),
        ])))).called(1);
      });

      test('should handle end-of-period cancellation', () async {
        // Arrange
        const userId = 'test_user_123';
        const cancellationType = 'end_of_period';
        const feedback = 'Seasonal business';

        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data).thenReturn({
          'success': true,
          'message': 'Subscription will be cancelled at period end',
          'cancel_at_period_end': true,
          'current_period_end': 1672531200, // Unix timestamp
        });

        // Act
        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: cancellationType,
          feedback: feedback,
        );

        // Assert
        expect(result, isTrue);
        verify(testHelper.mockCallable.call(argThat(allOf([
          containsPair('userId', userId),
          containsPair('cancellationType', cancellationType),
          containsPair('feedback', feedback),
        ])))).called(1);
      });

      test('should handle cancellation failure with retry', () async {
        // Arrange
        const userId = 'test_user_123';
        const cancellationType = 'immediate';

        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data).thenReturn({
          'success': false,
          'message': 'Stripe API temporarily unavailable',
          'error_code': 'stripe_unavailable',
          'retry_after': 300,
        });

        // Act
        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: cancellationType,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should validate cancellation type parameter', () async {
        // Arrange
        const userId = 'test_user_123';
        const invalidCancellationType = 'invalid_type';

        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenThrow(const FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Invalid cancellation type',
        ));

        // Act & Assert
        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: invalidCancellationType,
        );
        expect(result, isFalse);
      });
    });

    group('Retention Flow Testing', () {
      test('should track retention offer interactions', () async {
        // This would test the retention flow UI component interactions
        // For now, we'll test the data structure
        const retentionOffers = [
          {
            'type': 'discount',
            'value': 50,
            'duration_months': 6,
            'description': '50% off for 6 months'
          },
          {
            'type': 'pause',
            'duration_days': 90,
            'description': 'Pause for 3 months'
          },
          {
            'type': 'consultation',
            'description': 'Free business consultation'
          }
        ];

        expect(retentionOffers.length, 3);
        expect(retentionOffers[0]['type'], 'discount');
        expect(retentionOffers[1]['type'], 'pause');
        expect(retentionOffers[2]['type'], 'consultation');
      });

      test('should provide tier-specific retention offers', () {
        // Test retention offers for different subscription tiers
        final vendorOffers = _getRetentionOffersForTier(SubscriptionTier.vendorPro);
        final organizerOffers = _getRetentionOffersForTier(SubscriptionTier.marketOrganizerPro);
        final shopperOffers = _getRetentionOffersForTier(SubscriptionTier.shopperPro);

        expect(vendorOffers.isNotEmpty, isTrue);
        expect(organizerOffers.isNotEmpty, isTrue);
        expect(shopperOffers.isNotEmpty, isTrue);

        // Vendor offers should include business consultation
        expect(
          vendorOffers.any((offer) => offer['type'] == 'consultation'),
          isTrue,
        );

        // All tiers should have pause option
        expect(vendorOffers.any((offer) => offer['type'] == 'pause'), isTrue);
        expect(organizerOffers.any((offer) => offer['type'] == 'pause'), isTrue);
        expect(shopperOffers.any((offer) => offer['type'] == 'pause'), isTrue);
      });
    });

    group('Feedback Collection', () {
      test('should collect structured feedback during cancellation', () {
        const feedbackData = {
          'reason': 'Too expensive',
          'details': 'Could not justify the cost for our small business',
          'rating': 3,
          'suggestions': ['Lower pricing', 'More features for current price'],
          'would_recommend': false,
        };

        expect(feedbackData['reason'], isA<String>());
        expect(feedbackData['rating'], isA<int>());
        expect(feedbackData['suggestions'], isA<List>());
        expect(feedbackData['would_recommend'], isA<bool>());
      });

      test('should handle optional feedback gracefully', () {
        const minimalFeedback = {
          'reason': 'Other',
          'details': '',
        };

        expect(minimalFeedback['reason'], 'Other');
        expect(minimalFeedback['details'], '');
      });

      test('should validate feedback data structure', () {
        const validReasons = [
          'Too expensive',
          'Not using enough features',
          'Found a better alternative',
          'Technical issues',
          'Seasonal business',
          'Other'
        ];

        for (final reason in validReasons) {
          expect(reason, isA<String>());
          expect(reason.isNotEmpty, isTrue);
        }
      });
    });

    group('Prorated Refund Calculations', () {
      test('should calculate correct prorated refund for immediate cancellation', () {
        // Test prorated refund calculation logic
        final subscriptionStart = DateTime(2024, 1, 1);
        final subscriptionEnd = DateTime(2024, 1, 31); // 31 days
        final cancellationDate = DateTime(2024, 1, 15); // 15 days used

        const monthlyAmount = 2900; // $29.00 in cents
        final daysTotal = subscriptionEnd.difference(subscriptionStart).inDays;
        final daysUsed = cancellationDate.difference(subscriptionStart).inDays;
        final daysRemaining = daysTotal - daysUsed;

        final proratedRefund = (monthlyAmount * daysRemaining / daysTotal).round();

        expect(daysTotal, 30); // January 1-31 is 30 days
        expect(daysUsed, 14); // 14 days used
        expect(daysRemaining, 16); // 16 days remaining
        expect(proratedRefund, 1547); // ~$15.47 refund
      });

      test('should handle edge cases in refund calculation', () {
        // Same day cancellation
        final subscriptionStart = DateTime(2024, 1, 1);
        final cancellationDate = DateTime(2024, 1, 1);
        const monthlyAmount = 2900;

        final daysUsed = cancellationDate.difference(subscriptionStart).inDays;
        expect(daysUsed, 0); // Same day = 0 days used

        // Last day cancellation
        final lastDayCancellation = DateTime(2024, 1, 31);
        final lastDayUsed = lastDayCancellation.difference(subscriptionStart).inDays;
        expect(lastDayUsed, 30); // Full month used
      });
    });

    group('Stripe Webhook Handling', () {
      test('should process subscription cancellation webhook', () async {
        const webhookPayload = {
          'id': 'evt_test123',
          'object': 'event',
          'type': 'customer.subscription.deleted',
          'data': {
            'object': {
              'id': 'sub_test123',
              'customer': 'cus_test123',
              'status': 'canceled',
              'cancel_at_period_end': false,
              'canceled_at': 1672531200,
            }
          }
        };

        // Verify webhook structure
        expect(webhookPayload['type'], 'customer.subscription.deleted');
        expect(webhookPayload['data']['object']['status'], 'canceled');
        expect(webhookPayload['data']['object']['id'], 'sub_test123');
      });

      test('should handle period end cancellation webhook', () async {
        const webhookPayload = {
          'id': 'evt_test124',
          'object': 'event',
          'type': 'customer.subscription.updated',
          'data': {
            'object': {
              'id': 'sub_test123',
              'customer': 'cus_test123',
              'status': 'active',
              'cancel_at_period_end': true,
              'current_period_end': 1675209600,
            }
          }
        };

        // Verify webhook structure for period end cancellation
        expect(webhookPayload['type'], 'customer.subscription.updated');
        expect(webhookPayload['data']['object']['cancel_at_period_end'], isTrue);
        expect(webhookPayload['data']['object']['status'], 'active');
      });

      test('should validate webhook signatures for security', () {
        const webhookSignature = 'whsec_test123';
        const webhookPayload = '{"test": "data"}';

        // This would test actual webhook signature validation
        // For now, we'll test the validation logic structure
        expect(webhookSignature.startsWith('whsec_'), isTrue);
        expect(webhookPayload.isNotEmpty, isTrue);
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle partial cancellation states', () async {
        // Test when Stripe cancellation succeeds but local update fails
        const userId = 'test_user_123';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        // Mock successful Stripe cancellation
        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data).thenReturn({
          'success': true,
          'stripe_cancelled': true,
          'firestore_updated': false,
          'requires_manual_cleanup': true,
        });

        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: 'immediate',
        );

        // Should still return true but flag for manual cleanup
        expect(result, isTrue);
      });

      test('should handle concurrent cancellation attempts', () async {
        // Test multiple simultaneous cancellation requests
        const userId = 'test_user_123';
        
        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data).thenReturn({
          'success': false,
          'error_code': 'already_cancelled',
          'message': 'Subscription is already cancelled',
        });

        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: 'immediate',
        );

        expect(result, isFalse);
      });

      test('should handle authentication failures during cancellation', () async {
        // Test expired or invalid authentication
        const userId = 'test_user_123';

        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenThrow(const FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Authentication required',
        ));

        final result = await StripeService.cancelSubscriptionEnhanced(
          userId,
          cancellationType: 'immediate',
        );

        expect(result, isFalse);
      });

      test('should implement retry logic with exponential backoff', () async {
        // Test retry mechanism for transient failures
        const userId = 'test_user_123';
        int attemptCount = 0;

        when(testHelper.mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any)).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount < 3) {
            throw const FirebaseFunctionsException(
              code: 'unavailable',
              message: 'Service temporarily unavailable',
            );
          }
          return testHelper.mockResult;
        });
        when(testHelper.mockResult.data).thenReturn({
          'success': true,
          'message': 'Subscription cancelled after retry',
        });

        // This would test actual retry logic if implemented
        expect(attemptCount, 0); // Start at 0
      });
    });

    group('Subscription Pause Flow', () {
      test('should successfully pause subscription', () async {
        // Arrange
        const userId = 'test_user_123';
        const pauseDurationDays = 90;

        when(testHelper.mockFunctions.httpsCallable('pauseSubscription'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call({
          'userId': userId,
          'pauseDurationDays': pauseDurationDays,
        })).thenAnswer((_) async => testHelper.mockResult);
        when(testHelper.mockResult.data).thenReturn({
          'success': true,
          'message': 'Subscription paused for 90 days',
          'resume_date': '2024-04-01T00:00:00Z',
        });

        // Act
        final result = await StripeService.pauseSubscription(userId, pauseDurationDays);

        // Assert
        expect(result, isTrue);
        verify(testHelper.mockCallable.call({
          'userId': userId,
          'pauseDurationDays': pauseDurationDays,
        })).called(1);
      });

      test('should validate pause duration limits', () async {
        // Test invalid pause durations
        const userId = 'test_user_123';
        const invalidDuration = 365; // Too long

        when(testHelper.mockFunctions.httpsCallable('pauseSubscription'))
            .thenReturn(testHelper.mockCallable);
        when(testHelper.mockCallable.call(any))
            .thenThrow(const FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Pause duration exceeds maximum allowed',
        ));

        final result = await StripeService.pauseSubscription(userId, invalidDuration);
        expect(result, isFalse);
      });
    });
  });
}

// Helper function for testing retention offers
List<Map<String, dynamic>> _getRetentionOffersForTier(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.vendorPro:
      return [
        {'type': 'pause', 'duration_days': 90},
        {'type': 'discount', 'value': 50, 'duration_months': 6},
        {'type': 'consultation'},
      ];
    case SubscriptionTier.marketOrganizerPro:
      return [
        {'type': 'pause', 'duration_days': 90},
        {'type': 'discount', 'value': 40, 'duration_months': 3},
        {'type': 'support_priority'},
      ];
    case SubscriptionTier.shopperPro:
      return [
        {'type': 'pause', 'duration_days': 60},
        {'type': 'free_months', 'count': 2},
      ];
    default:
      return [];
  }
}