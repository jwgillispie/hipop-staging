import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:hipop/features/premium/screens/subscription_management_screen.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/services/stripe_service.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';

import 'subscription_management_widget_test.mocks.dart';

@GenerateMocks([
  SubscriptionService,
  StripeService,
])
void main() {
  group('Subscription Management Widget Tests', () {
    late MockSubscriptionService mockSubscriptionService;
    late MockStripeService mockStripeService;

    setUp(() {
      mockSubscriptionService = MockSubscriptionService();
      mockStripeService = MockStripeService();
    });

    group('Subscription Management Screen Widget Tests', () {
      testWidgets('should display current subscription plan correctly', (WidgetTester tester) async {
        // Arrange
        const userId = 'test_user_123';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(
          SubscriptionTier.vendorPro,
          stripeCustomerId: 'cus_test123',
          stripeSubscriptionId: 'sub_test123',
        );

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);
        when(mockSubscriptionService.getCurrentUsage(userId))
            .thenAnswer((_) async => {
          'utilizationPercentage': {'monthly_markets': 60.0},
          'totalUsage': 60.0,
        });

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Manage Subscription'), findsOneWidget);
        expect(find.text('Vendor Pro'), findsOneWidget);
        expect(find.text('\$29.00'), findsOneWidget);
        expect(find.text('per month'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
      });

      testWidgets('should display free tier usage with upgrade prompt', (WidgetTester tester) async {
        // Arrange
        const userId = 'free_user_123';
        final freeSubscription = UserSubscription.createFree(userId, 'vendor');

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => freeSubscription);
        when(mockSubscriptionService.getCurrentUsage(userId))
            .thenAnswer((_) async => {});

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Free Plan'), findsOneWidget);
        expect(find.text('Free Tier Usage'), findsOneWidget);
        expect(find.text('Upgrade for Unlimited'), findsOneWidget);
        expect(find.byIcon(Icons.upgrade), findsOneWidget);
      });

      testWidgets('should display usage indicators for free tier limits', (WidgetTester tester) async {
        // Arrange
        const userId = 'limited_user_123';
        final freeSubscription = UserSubscription.createFree(userId, 'vendor');

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => freeSubscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Products'), findsOneWidget);
        expect(find.text('3 / 3'), findsOneWidget);
        expect(find.text('Product Lists'), findsOneWidget);
        expect(find.text('1 / 1'), findsOneWidget);
        expect(find.text('Monthly Markets'), findsOneWidget);
        expect(find.text('5 / 5'), findsOneWidget);
        
        // Check progress indicators
        expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      });

      testWidgets('should show unlimited access for premium users', (WidgetTester tester) async {
        // Arrange
        const userId = 'premium_user_123';
        final premiumSubscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => premiumSubscription);
        when(mockSubscriptionService.getCurrentUsage(userId))
            .thenAnswer((_) async => {});

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Unlimited Access'), findsOneWidget);
        expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
      });

      testWidgets('should display billing information for premium users', (WidgetTester tester) async {
        // Arrange
        const userId = 'billing_user_123';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(
          SubscriptionTier.vendorPro,
          stripeCustomerId: 'cus_test123',
          stripeSubscriptionId: 'sub_test123',
        ).copyWith(
          nextPaymentDate: DateTime(2024, 3, 15),
          lastPaymentDate: DateTime(2024, 2, 15),
        );

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Billing Information'), findsOneWidget);
        expect(find.text('Customer ID'), findsOneWidget);
        expect(find.text('cus_test123'), findsOneWidget);
        expect(find.text('Subscription ID'), findsOneWidget);
        expect(find.text('sub_test123'), findsOneWidget);
        expect(find.text('Next Payment'), findsOneWidget);
        expect(find.text('Last Payment'), findsOneWidget);
      });
    });

    group('Subscription Actions Widget Tests', () {
      testWidgets('should show upgrade option for free users', (WidgetTester tester) async {
        // Arrange
        const userId = 'free_action_user';
        final freeSubscription = UserSubscription.createFree(userId, 'vendor');

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => freeSubscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Subscription Actions'), findsOneWidget);
        expect(find.text('Upgrade to Premium'), findsOneWidget);
        expect(find.text('Unlock unlimited features'), findsOneWidget);
        expect(find.byIcon(Icons.upgrade), findsOneWidget);
      });

      testWidgets('should show premium management options for premium users', (WidgetTester tester) async {
        // Arrange
        const userId = 'premium_action_user';
        final premiumSubscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => premiumSubscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Update Payment Method'), findsOneWidget);
        expect(find.text('Change your billing information'), findsOneWidget);
        expect(find.byIcon(Icons.credit_card), findsOneWidget);
        
        expect(find.text('Billing History'), findsOneWidget);
        expect(find.text('View past invoices and payments'), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long), findsOneWidget);
        
        expect(find.text('Download Latest Invoice'), findsOneWidget);
        expect(find.text('Get PDF of your most recent bill'), findsOneWidget);
        expect(find.byIcon(Icons.download), findsOneWidget);
        
        expect(find.text('Cancel Subscription'), findsOneWidget);
        expect(find.text('End your premium subscription'), findsOneWidget);
      });

      testWidgets('should show pause option for active subscriptions', (WidgetTester tester) async {
        // Arrange
        const userId = 'active_pause_user';
        final activeSubscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => activeSubscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Pause Subscription'), findsOneWidget);
        expect(find.text('Temporarily pause your subscription'), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsOneWidget);
      });
    });

    group('Interactive Widget Tests', () {
      testWidgets('should trigger upgrade dialog when upgrade button is tapped', (WidgetTester tester) async {
        // Arrange
        const userId = 'interactive_user';
        final freeSubscription = UserSubscription.createFree(userId, 'vendor');

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => freeSubscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Upgrade to Premium'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Upgrade to Premium'), findsNWidgets(2)); // Button and dialog title
        expect(find.text('Choose your premium plan to unlock unlimited features.'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Choose Plan'), findsOneWidget);
      });

      testWidgets('should handle payment method update tap', (WidgetTester tester) async {
        // Arrange
        const userId = 'payment_update_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(
          SubscriptionTier.vendorPro,
          stripeCustomerId: 'cus_test123',
        );

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);
        when(mockStripeService.createPaymentMethodUpdateSession('cus_test123'))
            .thenAnswer((_) async => 'https://billing.stripe.com/p/session/update_123');

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update Payment Method'));
        await tester.pumpAndSettle();

        // Assert - Should show loading dialog
        expect(find.text('Setting up payment method update...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should show billing history dialog when tapped', (WidgetTester tester) async {
        // Arrange
        const userId = 'billing_history_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        final mockBillingHistory = [
          {
            'id': 'in_test123',
            'amount': 2900,
            'status': 'paid',
            'created': DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000,
            'invoice_pdf': 'https://pay.stripe.com/invoice/test.pdf',
          },
        ];

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);
        when(mockStripeService.getBillingHistory(userId))
            .thenAnswer((_) async => mockBillingHistory);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Billing History'));
        await tester.pumpAndSettle();

        // Wait for async operation to complete
        await tester.pump();

        // Assert - Should show billing history dialog
        expect(find.text('Billing History'), findsNWidgets(2)); // Button and dialog title
        expect(find.text('\$29.00'), findsOneWidget);
        expect(find.text('Status: paid'), findsOneWidget);
        expect(find.byIcon(Icons.download), findsOneWidget);
      });

      testWidgets('should show cancellation flow when cancel is tapped', (WidgetTester tester) async {
        // Arrange
        const userId = 'cancel_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel Subscription'));
        await tester.pumpAndSettle();

        // Assert - Should show retention flow first
        expect(find.text('Wait! We have a special offer'), findsOneWidget);
        expect(find.text('Before you cancel, would any of these help?'), findsOneWidget);
        expect(find.text('Pause for 3 months'), findsOneWidget);
        expect(find.text('50% off for 6 months'), findsOneWidget);
        expect(find.text('Free consultation'), findsOneWidget);
      });

      testWidgets('should show pause subscription options', (WidgetTester tester) async {
        // Arrange
        const userId = 'pause_user';
        final activeSubscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => activeSubscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pause Subscription'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Pause Subscription'), findsNWidgets(2)); // Button and dialog title
        expect(find.text('How long would you like to pause your subscription?'), findsOneWidget);
        expect(find.text('1 month'), findsOneWidget);
        expect(find.text('2 months'), findsOneWidget);
        expect(find.text('3 months'), findsOneWidget);
        expect(find.text('No charges during pause'), findsNWidgets(3));
      });
    });

    group('Error Handling Widget Tests', () {
      testWidgets('should show error when subscription loading fails', (WidgetTester tester) async {
        // Arrange
        const userId = 'error_user';
        when(mockSubscriptionService.getUserSubscription(userId))
            .thenThrow(Exception('Failed to load subscription'));

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Error loading subscription data'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('should handle payment method update failure gracefully', (WidgetTester tester) async {
        // Arrange
        const userId = 'payment_error_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(
          SubscriptionTier.vendorPro,
          stripeCustomerId: 'cus_test123',
        );

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);
        when(mockStripeService.createPaymentMethodUpdateSession('cus_test123'))
            .thenThrow(Exception('Stripe service unavailable'));

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update Payment Method'));
        await tester.pumpAndSettle();

        // Assert - Should show error message
        expect(find.text('Error updating payment method'), findsOneWidget);
      });

      testWidgets('should handle billing history loading failure', (WidgetTester tester) async {
        // Arrange
        const userId = 'billing_error_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);
        when(mockStripeService.getBillingHistory(userId))
            .thenThrow(Exception('Failed to fetch billing history'));

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Billing History'));
        await tester.pumpAndSettle();

        // Assert - Should show error message
        expect(find.text('Error loading billing history'), findsOneWidget);
      });
    });

    group('Loading State Widget Tests', () {
      testWidgets('should show loading indicator while fetching subscription', (WidgetTester tester) async {
        // Arrange
        const userId = 'loading_user';
        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 1));
          return UserSubscription.createFree(userId, 'vendor');
        });

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );

        // Assert - Should show loading initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for loading to complete
        await tester.pumpAndSettle();

        // Assert - Should show content after loading
        expect(find.text('Free Plan'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('should show loading during subscription operations', (WidgetTester tester) async {
        // Arrange
        const userId = 'operation_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);
        when(mockStripeService.pauseSubscription(userId, 90))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 2));
          return true;
        });

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pause Subscription'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('3 months'));
        await tester.pumpAndSettle();

        // Assert - Should show loading during operation
        expect(find.text('Pausing subscription...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for operation to complete
        await tester.pumpAndSettle();

        // Assert - Should show success message
        expect(find.text('Subscription paused for 90 days'), findsOneWidget);
      });
    });

    group('Accessibility Widget Tests', () {
      testWidgets('should have proper accessibility labels', (WidgetTester tester) async {
        // Arrange
        const userId = 'accessibility_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert - Check semantic labels
        final semantics = tester.getSemantics(find.text('Update Payment Method'));
        expect(semantics.label, contains('Update Payment Method'));
        expect(semantics.hasEnabledState, isTrue);
        expect(semantics.isEnabled, isTrue);
      });

      testWidgets('should support keyboard navigation', (WidgetTester tester) async {
        // Arrange
        const userId = 'keyboard_user';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(SubscriptionTier.vendorPro);

        when(mockSubscriptionService.getUserSubscription(userId))
            .thenAnswer((_) async => subscription);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: SubscriptionManagementScreen(userId: userId),
          ),
        );
        await tester.pumpAndSettle();

        // Assert - Check focusable elements
        final focusableElements = find.byWidgetPredicate((widget) => 
            widget is ListTile || widget is ElevatedButton || widget is OutlinedButton);
        expect(focusableElements, findsWidgets);
      });
    });
  });
}