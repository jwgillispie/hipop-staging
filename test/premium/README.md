# Premium Subscription Testing Suite

This comprehensive testing suite covers all aspects of the premium subscription system, including subscription cancellation, account deletion, payment method management, and cross-platform integration.

## Test Structure

### 1. Unit Tests

#### `/test/premium/subscription_cancellation_test.dart`
**Purpose**: Tests the subscription cancellation and retention flows

**Coverage Areas**:
- Basic subscription cancellation logic
- Enhanced cancellation with retention offers
- Immediate vs end-of-period cancellation
- Prorated refund calculations
- Stripe webhook handling
- Error recovery scenarios
- Subscription pause functionality

**Key Test Scenarios**:
```dart
// Basic cancellation flow
test('should successfully cancel active subscription')

// Enhanced cancellation with options
test('should handle immediate cancellation with prorated refund')
test('should handle end-of-period cancellation')

// Error handling
test('should handle cancellation failure with retry')
test('should handle partial cancellation states')

// Retention flow
test('should provide tier-specific retention offers')
test('should collect structured feedback during cancellation')
```

#### `/test/premium/enhanced_account_deletion_test.dart`
**Purpose**: Tests account deletion with premium subscription handling

**Coverage Areas**:
- Premium subscription cancellation during account deletion
- Comprehensive data cleanup across all collections
- Stripe customer data cleanup coordination
- Error handling for partial failures
- Progress tracking and user feedback
- Authentication and authorization checks

**Key Test Scenarios**:
```dart
// Premium integration
test('should cancel active premium subscription before data deletion')
test('should handle subscription cancellation failure and abort deletion')

// Data cleanup
test('should verify all premium-related data is cleaned')
test('should handle large datasets with batch processing')

// Error recovery
test('should rollback changes on critical failures')
test('should maintain data integrity during partial failures')
```

#### `/test/premium/payment_method_management_test.dart`
**Purpose**: Tests payment method updates and billing functionality

**Coverage Areas**:
- Secure payment method updates
- Billing history retrieval and display
- Invoice download functionality
- Failed payment recovery flows
- Payment method validation and security
- International payment support

**Key Test Scenarios**:
```dart
// Payment method updates
test('should create payment method update session successfully')
test('should handle invalid customer ID for payment method update')

// Billing history
test('should fetch billing history successfully')
test('should paginate through large billing history')

// Recovery flows
test('should detect failed payment and initiate recovery')
test('should provide payment method update options for recovery')

// Security
test('should validate payment method ownership')
test('should detect payment method tampering')
```

### 2. Integration Tests

#### `/test/integration/premium_flows_integration_test.dart`
**Purpose**: End-to-end testing of complete premium workflows

**Coverage Areas**:
- Complete subscription lifecycle (signup to cancellation)
- Cross-platform compatibility (web/mobile)
- Error recovery across multiple services
- Security validation throughout flows
- Performance testing with large datasets
- GDPR compliance workflows

**Key Test Scenarios**:
```dart
// Complete lifecycle
testWidgets('should handle complete subscription flow from signup to cancellation')

// Platform-specific
testWidgets('should handle subscription management on web platform')
testWidgets('should handle subscription management on mobile platform')

// Error recovery
testWidgets('should recover from payment failures gracefully')
testWidgets('should handle network failures during subscription operations')

// Security
testWidgets('should validate user permissions throughout subscription flows')
testWidgets('should handle authentication changes during subscription flows')
```

### 3. Widget Tests

#### `/test/widgets/subscription_management_widget_test.dart`
**Purpose**: Tests UI components and user interactions

**Coverage Areas**:
- Subscription management screen rendering
- Interactive elements (buttons, dialogs, forms)
- Loading states and error handling
- Accessibility compliance
- User feedback and progress indicators

**Key Test Scenarios**:
```dart
// UI rendering
testWidgets('should display current subscription plan correctly')
testWidgets('should display free tier usage with upgrade prompt')

// Interactions
testWidgets('should trigger upgrade dialog when upgrade button is tapped')
testWidgets('should show cancellation flow when cancel is tapped')

// Error handling
testWidgets('should show error when subscription loading fails')
testWidgets('should handle payment method update failure gracefully')

// Accessibility
testWidgets('should have proper accessibility labels')
testWidgets('should support keyboard navigation')
```

## Running the Tests

### Prerequisites

1. **Add Required Dependencies** to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.2
  build_runner: ^2.4.7
  fake_cloud_firestore: ^2.4.2
```

2. **Generate Mock Classes**:
```bash
flutter packages pub run build_runner build
```

### Running Individual Test Suites

#### Unit Tests
```bash
# Run subscription cancellation tests
flutter test test/premium/subscription_cancellation_test.dart

# Run account deletion tests
flutter test test/premium/enhanced_account_deletion_test.dart

# Run payment method tests
flutter test test/premium/payment_method_management_test.dart

# Run all premium unit tests
flutter test test/premium/
```

#### Widget Tests
```bash
# Run subscription management widget tests
flutter test test/widgets/subscription_management_widget_test.dart

# Run all widget tests
flutter test test/widgets/
```

#### Integration Tests
```bash
# Run premium flows integration tests
flutter test integration_test/premium_flows_integration_test.dart

# Run all integration tests
flutter test integration_test/
```

### Running All Tests
```bash
# Run all tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Data Setup

### Mock Data Patterns

**User Subscriptions**:
```dart
// Free subscription
final freeSubscription = UserSubscription.createFree('user_123', 'vendor');

// Premium subscription
final premiumSubscription = UserSubscription.createFree('user_123', 'vendor')
    .upgradeToTier(
  SubscriptionTier.vendorPro,
  stripeCustomerId: 'cus_test123',
  stripeSubscriptionId: 'sub_test123',
);
```

**Billing History**:
```dart
final mockBillingHistory = [
  {
    'id': 'in_test123',
    'amount': 2900, // $29.00 in cents
    'currency': 'usd',
    'status': 'paid',
    'created': DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000,
    'invoice_pdf': 'https://pay.stripe.com/invoice/test.pdf',
  },
];
```

### Environment Setup

**Test Environment Variables**:
```env
# .env.test
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PRICE_VENDOR_PRO=price_test_vendor_pro
STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM=price_test_organizer_premium
STRIPE_PRICE_SHOPPER_PREMIUM=price_test_shopper_premium
ENVIRONMENT=test
```

## Test Coverage Goals

### Coverage Targets
- **Unit Tests**: > 90% code coverage
- **Integration Tests**: > 80% critical path coverage
- **Widget Tests**: > 85% UI component coverage

### Key Metrics to Monitor
1. **Subscription Operations**: 100% coverage
2. **Payment Processing**: 95% coverage
3. **Error Handling**: 90% coverage
4. **Security Validation**: 100% coverage
5. **Data Cleanup**: 95% coverage

## Continuous Integration

### GitHub Actions Configuration
```yaml
name: Premium Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Install dependencies
        run: flutter pub get
        
      - name: Generate mocks
        run: flutter packages pub run build_runner build
        
      - name: Run unit tests
        run: flutter test test/premium/ --coverage
        
      - name: Run widget tests
        run: flutter test test/widgets/ --coverage
        
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
```

## Best Practices

### Test Organization
1. **Group Related Tests**: Use `group()` to organize related test cases
2. **Descriptive Names**: Use clear, descriptive test names that explain what is being tested
3. **Setup/Teardown**: Use `setUp()` and `tearDown()` for common test initialization
4. **Mock Isolation**: Each test should have isolated mock setups

### Test Quality
1. **Arrange-Act-Assert**: Follow the AAA pattern for test structure
2. **Single Responsibility**: Each test should focus on one specific behavior
3. **Edge Cases**: Include tests for edge cases and error scenarios
4. **Real-world Data**: Use realistic test data that matches production patterns

### Performance Testing
1. **Large Datasets**: Test with datasets similar to production scale
2. **Timeout Handling**: Include appropriate timeouts for async operations
3. **Memory Usage**: Monitor memory usage during large data operations
4. **Concurrent Operations**: Test concurrent user operations

## Debugging Test Failures

### Common Issues and Solutions

**Mock Generation Errors**:
```bash
# Clean and regenerate mocks
flutter packages pub run build_runner clean
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Async Test Issues**:
```dart
// Always use pumpAndSettle for async operations
await tester.pumpAndSettle();

// For specific timing
await tester.pump(const Duration(seconds: 1));
```

**Firestore Mock Issues**:
```dart
// Use FakeFirebaseFirestore for realistic Firestore behavior
final firestore = FakeFirebaseFirestore();
// Pre-populate with test data before running tests
```

### Test Debugging Tips
1. **Use `debugPrint()`** in tests to trace execution flow
2. **Check widget tree** with `tester.widget()` and `find.byType()`
3. **Verify mock calls** with `verify()` and `verifyNever()`
4. **Use `pumpAndSettle()`** for all async UI operations

## Contributing

When adding new tests:

1. **Follow Naming Convention**: `feature_functionality_test.dart`
2. **Add Documentation**: Include clear documentation for test purpose and coverage
3. **Update Coverage**: Ensure new features maintain coverage targets
4. **Test Edge Cases**: Include both happy path and error scenarios
5. **Performance Considerations**: Add performance tests for new features

## Monitoring and Alerts

### Test Health Monitoring
- **Test Execution Time**: Monitor for performance degradation
- **Flaky Test Detection**: Track tests that fail intermittently
- **Coverage Trends**: Monitor coverage metrics over time
- **Error Patterns**: Track common test failure patterns

### Production Correlation
- **Test Scenarios**: Ensure test scenarios match real user patterns
- **Error Rates**: Correlate test error handling with production error rates
- **Performance Baselines**: Use test performance data to set production baselines