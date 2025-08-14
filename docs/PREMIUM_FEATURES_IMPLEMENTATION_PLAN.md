# Premium Features - Categorized Fixes & Implementation Plan

## 🚨 CRITICAL SECURITY FIXES (Do First)

### 1. Remove Stripe Secret Key from Client Code
**Current Issue:** `lib/features/premium/services/stripe_service.dart` exposes secret key
```dart
// CURRENT (INSECURE)
static String get _secretKey {
  final key = dotenv.env['STRIPE_SECRET_KEY'];
  // This exposes secret key in client!
}
```

**Fix Implementation:**
```dart
// Step 1: Create server-side Cloud Function (Firebase)
// functions/index.js
exports.createCheckoutSession = functions.https.onCall(async (data, context) => {
  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
  const { priceId, userId, userEmail, userType } = data;
  
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{
      price: priceId,
      quantity: 1,
    }],
    customer_email: userEmail,
    success_url: `${process.env.APP_URL}/#/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.APP_URL}/#/subscription/cancel`,
    metadata: { userId, userType }
  });
  
  return { url: session.url };
});

// Step 2: Update stripe_service.dart
class StripeService {
  static Future<String> createCheckoutSession({
    required String priceId,
    required String customerEmail,
    required Map<String, String> metadata,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final result = await callable.call({
        'priceId': priceId,
        'userId': metadata['user_id'],
        'userEmail': customerEmail,
        'userType': metadata['user_type'],
      });
      return result.data['url'];
    } catch (e) {
      throw Exception('Failed to create checkout session: $e');
    }
  }
}
```

### 2. Implement Webhook Handler for Payment Validation
**Current Issue:** No webhook validation, success callback can be spoofed

**Fix Implementation:**
```javascript
// functions/index.js - Add webhook handler
exports.handleStripeWebhook = functions.https.onRequest(async (req, res) => {
  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
  const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;
  
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      req.headers['stripe-signature'],
      endpointSecret
    );
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }
  
  switch (event.type) {
    case 'checkout.session.completed':
      const session = event.data.object;
      await handleSuccessfulPayment(session);
      break;
    case 'customer.subscription.deleted':
      await handleSubscriptionCancellation(event.data.object);
      break;
    case 'invoice.payment_failed':
      await handleFailedPayment(event.data.object);
      break;
  }
  
  res.json({received: true});
});

async function handleSuccessfulPayment(session) {
  const { userId, userType } = session.metadata;
  
  // Update Firestore directly from server
  await admin.firestore()
    .collection('user_profiles')
    .doc(userId)
    .update({
      isPremium: true,
      stripeCustomerId: session.customer,
      stripeSubscriptionId: session.subscription,
      stripePriceId: session.line_items.data[0].price.id,
      subscriptionStatus: 'active',
      subscriptionStartDate: admin.firestore.FieldValue.serverTimestamp(),
    });
}
```

### 3. Secure Feature Access Validation
**Current Issue:** Feature checks only client-side

**Fix Implementation:**
```dart
// Create lib/features/premium/services/secure_subscription_service.dart
class SecureSubscriptionService {
  static final _cache = <String, CachedSubscription>{};
  static const _cacheTimeout = Duration(minutes: 5);
  
  /// Validates feature access with server-side check for sensitive operations
  static Future<bool> validateFeatureAccess(
    String userId, 
    String featureName, {
    bool serverValidation = false,
  }) async {
    // Check cache first
    final cached = _cache[userId];
    if (cached != null && cached.isValid) {
      return cached.subscription.hasFeature(featureName);
    }
    
    if (serverValidation) {
      // Call Cloud Function for sensitive features
      final callable = FirebaseFunctions.instance.httpsCallable('validateFeatureAccess');
      final result = await callable.call({
        'userId': userId,
        'featureName': featureName,
      });
      return result.data['hasAccess'] ?? false;
    }
    
    // Regular client-side check with caching
    final subscription = await SubscriptionService.getUserSubscription(userId);
    _cache[userId] = CachedSubscription(subscription, DateTime.now());
    return subscription?.hasFeature(featureName) ?? false;
  }
}
```

## 🔴 HIGH PRIORITY FIXES

### 4. Remove Test Code from Production
**Files to Clean:**
- `lib/features/premium/screens/subscription_test_screen.dart` - Delete entire file
- `lib/features/premium/services/subscription_success_service.dart` - Remove test logic

**Fix Implementation:**
```dart
// subscription_success_service.dart - Clean version
static Future<bool> handleSubscriptionSuccess({
  required String userId,
  required String sessionId,
}) async {
  try {
    // Remove all test session handling
    // if (sessionId.startsWith('cs_test_fake_session')) { DELETE THIS BLOCK }
    
    // Only process real Stripe sessions
    final sessionData = await _verifyStripeSession(sessionId);
    if (sessionData == null || sessionData['payment_status'] != 'paid') {
      return false;
    }
    
    // Extract and process real data only
    final customerId = _extractCustomerId(sessionData);
    final subscriptionId = _extractSubscriptionId(sessionData);
    final priceId = _extractPriceId(sessionData);
    
    await _userProfileService.upgradeToPremium(
      userId: userId,
      stripeCustomerId: customerId!,
      stripeSubscriptionId: subscriptionId!,
      stripePriceId: priceId!,
    );
    
    return true;
  } catch (e) {
    debugPrint('Error handling subscription success: $e');
    return false;
  }
}
```

**Staging Environment Alternative:**
```dart
// Create lib/features/premium/services/staging_test_service.dart
class StagingTestService {
  static bool get isStagingEnvironment => 
    dotenv.env['ENVIRONMENT'] == 'staging';
  
  static Future<void> simulatePremiumUpgrade(String userId) async {
    if (!isStagingEnvironment) {
      throw Exception('Test functions only available in staging');
    }
    
    // Staging-only test upgrade
    await FirebaseFirestore.instance
      .collection('user_profiles')
      .doc(userId)
      .update({
        'isPremium': true,
        'subscriptionStatus': 'active',
        'testSubscription': true, // Mark as test
      });
  }
}
```

### 5. Implement Subscription Management UI
**Current Issue:** No way for users to cancel or manage subscriptions

**Fix Implementation:**
```dart
// Create lib/features/premium/screens/subscription_management_screen.dart
class SubscriptionManagementScreen extends StatefulWidget {
  final String userId;
  
  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  UserSubscription? _subscription;
  bool _isLoading = true;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Subscription')),
      body: _isLoading 
        ? const LoadingWidget()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCurrentPlanCard(),
                _buildBillingInfoCard(),
                _buildUsageStatsCard(),
                _buildActionsCard(),
              ],
            ),
          ),
    );
  }
  
  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            // Update Payment Method
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Update Payment Method'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _updatePaymentMethod,
            ),
            
            // Cancel Subscription
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.red.shade600),
              title: Text('Cancel Subscription', 
                style: TextStyle(color: Colors.red.shade600)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showCancellationDialog,
            ),
            
            // Pause Subscription (if applicable)
            if (_subscription?.tier != SubscriptionTier.free)
              ListTile(
                leading: const Icon(Icons.pause_circle),
                title: const Text('Pause Subscription'),
                subtitle: const Text('Temporarily pause billing'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _pauseSubscription,
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showCancellationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel your subscription?'),
            const SizedBox(height: 16),
            Text('You will lose access to:', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_subscription?.features.keys ?? []).map((feature) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $feature'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _cancelSubscription();
    }
  }
  
  Future<void> _cancelSubscription() async {
    try {
      // Call Cloud Function to cancel with Stripe
      final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
      await callable.call({'userId': widget.userId});
      
      // Update local state
      await SubscriptionService.cancelSubscription(widget.userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription cancelled successfully')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling subscription: $e')),
      );
    }
  }
}
```

### 6. Add Global State Management for Subscriptions
**Current Issue:** Multiple redundant checks, no caching

**Fix Implementation:**
```dart
// Create lib/blocs/subscription/subscription_bloc.dart
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final String userId;
  StreamSubscription? _subscriptionListener;
  
  SubscriptionBloc({required this.userId}) : super(SubscriptionInitial()) {
    on<LoadSubscription>(_onLoadSubscription);
    on<UpdateSubscription>(_onUpdateSubscription);
    on<SubscriptionChanged>(_onSubscriptionChanged);
    
    // Listen to real-time updates
    _initializeListener();
  }
  
  void _initializeListener() {
    _subscriptionListener = FirebaseFirestore.instance
      .collection('subscriptions')
      .doc(userId)
      .snapshots()
      .listen((snapshot) {
        if (snapshot.exists) {
          add(SubscriptionChanged(
            UserSubscription.fromFirestore(snapshot)
          ));
        }
      });
  }
  
  Future<void> _onLoadSubscription(
    LoadSubscription event, 
    Emitter<SubscriptionState> emit
  ) async {
    emit(SubscriptionLoading());
    try {
      final subscription = await SubscriptionService.getUserSubscription(userId);
      emit(SubscriptionLoaded(subscription: subscription));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }
  
  @override
  Future<void> close() {
    _subscriptionListener?.cancel();
    return super.close();
  }
}

// Update main.dart to provide SubscriptionBloc
MultiBlocProvider(
  providers: [
    BlocProvider(create: (context) => AuthBloc()),
    BlocProvider(create: (context) {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        return SubscriptionBloc(userId: authState.user.uid)
          ..add(LoadSubscription());
      }
      return SubscriptionBloc(userId: '');
    }),
  ],
  child: MyApp(),
)
```

## 🟡 MEDIUM PRIORITY IMPROVEMENTS

### 7. Implement Subscription Caching Strategy
**Current Issue:** Excessive database calls for premium checks

**Fix Implementation:**
```dart
// Create lib/features/premium/services/subscription_cache_service.dart
class SubscriptionCacheService {
  static final Map<String, CachedEntry> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  static const Duration _shortCacheTimeout = Duration(seconds: 30);
  
  static Future<UserSubscription?> getCachedSubscription(String userId) async {
    final cached = _cache[userId];
    
    // Check if cache is valid
    if (cached != null && cached.isValid) {
      return cached.subscription;
    }
    
    // Fetch fresh data
    final subscription = await SubscriptionService.getUserSubscription(userId);
    
    // Cache the result
    _cache[userId] = CachedEntry(
      subscription: subscription,
      timestamp: DateTime.now(),
      timeout: subscription?.isPremium == true ? _cacheTimeout : _shortCacheTimeout,
    );
    
    return subscription;
  }
  
  static void invalidateCache(String userId) {
    _cache.remove(userId);
  }
  
  static void invalidateAll() {
    _cache.clear();
  }
}

class CachedEntry {
  final UserSubscription? subscription;
  final DateTime timestamp;
  final Duration timeout;
  
  CachedEntry({
    required this.subscription,
    required this.timestamp,
    required this.timeout,
  });
  
  bool get isValid => 
    DateTime.now().difference(timestamp) < timeout;
}
```

### 8. Add Comprehensive Error Handling
**Current Issue:** Basic try-catch without user feedback

**Fix Implementation:**
```dart
// Create lib/features/premium/services/subscription_error_handler.dart
class SubscriptionErrorHandler {
  static Future<T?> handleSubscriptionOperation<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? customErrorMessage,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }
    
    try {
      final result = await operation();
      if (showLoading && context.mounted) {
        Navigator.pop(context); // Close loading
      }
      return result;
    } catch (error) {
      if (showLoading && context.mounted) {
        Navigator.pop(context); // Close loading
      }
      
      final message = _getErrorMessage(error, customErrorMessage);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => handleSubscriptionOperation(
                operation: operation,
                context: context,
                customErrorMessage: customErrorMessage,
                showLoading: showLoading,
              ),
            ),
          ),
        );
      }
      
      // Log error for debugging
      debugPrint('Subscription Error: $error');
      
      // Send to analytics
      await _logError(error, message);
      
      return null;
    }
  }
  
  static String _getErrorMessage(dynamic error, String? customMessage) {
    if (customMessage != null) return customMessage;
    
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action';
        case 'not-found':
          return 'Subscription not found';
        case 'already-exists':
          return 'Subscription already exists';
        default:
          return 'An error occurred. Please try again.';
      }
    }
    
    if (error.toString().contains('Stripe')) {
      return 'Payment processing error. Please check your payment method.';
    }
    
    return 'Something went wrong. Please try again later.';
  }
  
  static Future<void> _logError(dynamic error, String message) async {
    // Log to analytics service
    debugPrint('Error logged: $message - $error');
  }
}
```

### 9. Implement Usage Limit Enforcement
**Current Issue:** Limits defined but not enforced

**Fix Implementation:**
```dart
// Create lib/features/premium/services/usage_limit_service.dart
class UsageLimitService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check and enforce usage limits before allowing action
  static Future<LimitCheckResult> checkLimit({
    required String userId,
    required String limitName,
    int incrementBy = 1,
  }) async {
    // Get subscription and current usage
    final subscription = await SubscriptionCacheService.getCachedSubscription(userId);
    final usage = await _getCurrentUsage(userId, limitName);
    
    // Get limit for user's tier
    final limit = subscription?.getLimit(limitName) ?? 
                  _getFreeTierLimit(limitName);
    
    // Check if unlimited (-1 means unlimited)
    if (limit == -1) {
      return LimitCheckResult(
        allowed: true,
        currentUsage: usage,
        limit: limit,
        isUnlimited: true,
      );
    }
    
    // Check if within limit
    final wouldExceed = (usage + incrementBy) > limit;
    
    if (wouldExceed) {
      return LimitCheckResult(
        allowed: false,
        currentUsage: usage,
        limit: limit,
        message: 'You\'ve reached your limit of $limit $limitName',
        suggestUpgrade: true,
      );
    }
    
    // Increment usage
    await _incrementUsage(userId, limitName, incrementBy);
    
    return LimitCheckResult(
      allowed: true,
      currentUsage: usage + incrementBy,
      limit: limit,
    );
  }
  
  static Future<int> _getCurrentUsage(String userId, String limitName) async {
    final doc = await _firestore
      .collection('usage_tracking')
      .doc(userId)
      .get();
    
    if (!doc.exists) return 0;
    
    final data = doc.data()!;
    final period = _getResetPeriod(limitName);
    
    // Check if usage needs reset
    if (_shouldResetUsage(data['lastReset'], period)) {
      await _resetUsage(userId, limitName);
      return 0;
    }
    
    return data[limitName] ?? 0;
  }
  
  static Future<void> _incrementUsage(
    String userId, 
    String limitName, 
    int incrementBy
  ) async {
    await _firestore
      .collection('usage_tracking')
      .doc(userId)
      .set({
        limitName: FieldValue.increment(incrementBy),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
  }
  
  static int _getFreeTierLimit(String limitName) {
    const freeLimits = {
      'monthly_markets': 5,
      'photo_uploads_per_post': 3,
      'global_products': 3,
      'product_lists': 1,
      'saved_favorites': 10,
    };
    return freeLimits[limitName] ?? 0;
  }
}

// Usage in UI
class VendorPhotoUpload extends StatelessWidget {
  Future<void> _uploadPhoto() async {
    final limitCheck = await UsageLimitService.checkLimit(
      userId: currentUserId,
      limitName: 'photo_uploads_per_post',
    );
    
    if (!limitCheck.allowed) {
      // Show upgrade prompt
      ContextualUpgradePrompts.showLimitReachedPrompt(
        context,
        userId: currentUserId,
        userType: 'vendor',
        limitName: 'photos',
        currentUsage: limitCheck.currentUsage,
        limit: limitCheck.limit,
      );
      return;
    }
    
    // Proceed with upload
    await _performUpload();
  }
}
```

### 10. Add Retry Logic for Failed Operations
**Current Issue:** No retry mechanism for network failures

**Fix Implementation:**
```dart
// Create lib/features/premium/services/retry_service.dart
class RetryService {
  static Future<T?> retryOperation<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
    bool exponentialBackoff = true,
  }) async {
    int attempt = 0;
    Duration currentDelay = delay;
    
    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempt++;
        
        if (attempt >= maxAttempts) {
          debugPrint('Operation failed after $maxAttempts attempts');
          rethrow;
        }
        
        debugPrint('Attempt $attempt failed, retrying in ${currentDelay.inSeconds}s...');
        await Future.delayed(currentDelay);
        
        if (exponentialBackoff) {
          currentDelay *= 2;
        }
      }
    }
    
    return null;
  }
  
  /// Retry with circuit breaker pattern
  static Future<T?> retryWithCircuitBreaker<T>({
    required Future<T> Function() operation,
    required String operationKey,
  }) async {
    // Check if circuit is open
    if (_circuitBreaker.isOpen(operationKey)) {
      throw Exception('Service temporarily unavailable');
    }
    
    try {
      final result = await retryOperation(operation: operation);
      _circuitBreaker.recordSuccess(operationKey);
      return result;
    } catch (error) {
      _circuitBreaker.recordFailure(operationKey);
      rethrow;
    }
  }
}

class CircuitBreaker {
  static final Map<String, CircuitState> _states = {};
  static const int _failureThreshold = 5;
  static const Duration _timeout = Duration(minutes: 1);
  
  bool isOpen(String key) {
    final state = _states[key];
    if (state == null) return false;
    
    if (state.isOpen && 
        DateTime.now().difference(state.lastFailure) > _timeout) {
      // Reset circuit after timeout
      _states.remove(key);
      return false;
    }
    
    return state.isOpen;
  }
  
  void recordSuccess(String key) {
    _states.remove(key);
  }
  
  void recordFailure(String key) {
    final state = _states[key] ?? CircuitState();
    state.failures++;
    state.lastFailure = DateTime.now();
    
    if (state.failures >= _failureThreshold) {
      state.isOpen = true;
    }
    
    _states[key] = state;
  }
}
```

## 🟢 NICE-TO-HAVE ENHANCEMENTS

### 11. Add Subscription Analytics Dashboard
```dart
// Create lib/features/premium/screens/subscription_analytics_screen.dart
class SubscriptionAnalyticsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Analytics')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _getAnalyticsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingWidget();
          
          final analytics = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMetricCard('Monthly Revenue', analytics['mrr']),
                _buildMetricCard('Active Subscriptions', analytics['active']),
                _buildMetricCard('Churn Rate', '${analytics['churn']}%'),
                _buildConversionFunnel(analytics['funnel']),
                _buildRevenueChart(analytics['revenueHistory']),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

### 12. Implement A/B Testing for Pricing
```dart
class PricingExperimentService {
  static Future<Map<String, dynamic>> getExperimentalPricing(String userId) async {
    // Determine experiment group
    final group = _getExperimentGroup(userId);
    
    switch (group) {
      case 'control':
        return {'vendor_pro': 29.00, 'variant': 'control'};
      case 'variant_a':
        return {'vendor_pro': 24.99, 'variant': 'lower_price'};
      case 'variant_b':
        return {'vendor_pro': 29.00, 'variant': 'with_trial'};
      default:
        return {'vendor_pro': 29.00, 'variant': 'control'};
    }
  }
}
```

## 📊 STAGING ENVIRONMENT SPECIFIC

### Testing Infrastructure for Staging
```dart
// Create lib/features/premium/staging/staging_tools.dart
class StagingTools {
  static Widget buildStagingToolbar() {
    if (dotenv.env['ENVIRONMENT'] != 'staging') {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Colors.yellow.shade200,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Text('STAGING', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(
            onPressed: _simulatePremiumUpgrade,
            child: const Text('Test Premium'),
          ),
          TextButton(
            onPressed: _clearSubscription,
            child: const Text('Clear Sub'),
          ),
          TextButton(
            onPressed: _simulateWebhook,
            child: const Text('Test Webhook'),
          ),
        ],
      ),
    );
  }
}
```

## 📝 IMPLEMENTATION PRIORITY ORDER

### Phase 1 (Week 1) - Security & Critical Fixes
1. Move Stripe secret to server-side ✅
2. Implement webhook handler ✅
3. Remove test code from production ✅
4. Add basic subscription management UI ✅

### Phase 2 (Week 2) - Core Improvements
5. Global state management with BlocProvider ✅
6. Subscription caching service ✅
7. Comprehensive error handling ✅
8. Usage limit enforcement ✅

### Phase 3 (Week 3) - Polish & Optimization
9. Retry logic and circuit breaker ✅
10. Subscription analytics dashboard ✅
11. A/B testing framework ✅
12. Performance optimizations ✅

## 🔍 MONITORING & DEBUGGING

### Add Debug Logging for Staging
```dart
class SubscriptionDebugger {
  static void logSubscriptionEvent(String event, Map<String, dynamic> data) {
    if (kDebugMode || dotenv.env['ENVIRONMENT'] == 'staging') {
      debugPrint('🔵 [SUBSCRIPTION] $event');
      data.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    }
  }
}
```

### Error Tracking Integration
```dart
// Integrate with Sentry or similar
class ErrorReporter {
  static Future<void> reportSubscriptionError(dynamic error, StackTrace? stack) async {
    if (dotenv.env['ENVIRONMENT'] == 'production') {
      await Sentry.captureException(error, stackTrace: stack);
    } else {
      debugPrint('Error: $error\nStack: $stack');
    }
  }
}
```

## ✅ VALIDATION CHECKLIST

Before deploying each fix:
- [ ] Test in staging environment
- [ ] Verify no secret keys in client code
- [ ] Check error handling works correctly
- [ ] Validate subscription state updates
- [ ] Test with real Stripe test cards
- [ ] Verify webhook signature validation
- [ ] Check subscription cancellation flow
- [ ] Test retry logic under network failure
- [ ] Validate usage limit enforcement
- [ ] Confirm proper caching behavior