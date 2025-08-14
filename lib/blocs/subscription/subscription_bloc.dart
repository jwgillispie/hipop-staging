import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/premium/models/user_subscription.dart';
import '../../features/premium/services/subscription_service.dart';
import '../../features/premium/services/secure_subscription_service.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

/// Global BLoC for managing subscription state across the app
/// 
/// This bloc provides:
/// - Real-time subscription status updates via Firestore listeners
/// - Feature access validation with caching
/// - Usage limit tracking and enforcement
/// - Premium feature unlock animations and notifications
/// - Integration with Stripe billing and payment status
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  static const String _logPrefix = '🔔 SUBSCRIPTION_BLOC:';
  
  // Services removed as they are now accessed statically
  final FirebaseFirestore _firestore;
  
  // Real-time subscription stream
  StreamSubscription<UserSubscription?>? _subscriptionStreamSubscription;
  
  // Cache for feature access and limits
  final Map<String, bool> _featureAccessCache = {};
  final Map<String, int> _usageLimitsCache = {};
  final Map<String, dynamic> _currentUsageCache = {};
  
  // Expiration and billing issue timers
  Timer? _expirationCheckTimer;
  Timer? _billingIssueCheckTimer;
  
  String? _currentUserId;

  SubscriptionBloc({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const SubscriptionInitial()) {

    // Register event handlers
    on<SubscriptionInitialized>(_onSubscriptionInitialized);
    on<SubscriptionChanged>(_onSubscriptionChanged);
    on<SubscriptionUpgraded>(_onSubscriptionUpgraded);
    on<SubscriptionCancelled>(_onSubscriptionCancelled);
    on<FeatureAccessRequested>(_onFeatureAccessRequested);
    on<UsageLimitRequested>(_onUsageLimitRequested);
    on<PaymentInfoUpdated>(_onPaymentInfoUpdated);
    on<SubscriptionRefreshed>(_onSubscriptionRefreshed);
    on<SubscriptionErrorOccurred>(_onSubscriptionErrorOccurred);
    on<SubscriptionErrorCleared>(_onSubscriptionErrorCleared);
    on<SubscriptionPreloaded>(_onSubscriptionPreloaded);
    on<UpgradeRecommendationsRequested>(_onUpgradeRecommendationsRequested);
    on<FeatureUsageTracked>(_onFeatureUsageTracked);
    on<SubscriptionIssuesRequested>(_onSubscriptionIssuesRequested);
  }

  /// Initialize subscription monitoring for a user
  Future<void> _onSubscriptionInitialized(
    SubscriptionInitialized event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      debugPrint('$_logPrefix Initializing subscription for user: ${event.userId}');
      _currentUserId = event.userId;
      
      emit(const SubscriptionLoading(message: 'Loading subscription data...'));
      
      // Cancel any existing subscription
      await _subscriptionStreamSubscription?.cancel();
      
      // Set up real-time subscription listener
      _subscriptionStreamSubscription = SubscriptionService
          .streamUserSubscription(event.userId)
          .listen(
            (subscription) {
              debugPrint('$_logPrefix Subscription stream update: ${subscription?.tier.name}');
              add(SubscriptionChanged(subscription));
            },
            onError: (error) {
              debugPrint('$_logPrefix Subscription stream error: $error');
              add(SubscriptionErrorOccurred(error.toString()));
            },
          );

      // Start monitoring timers
      _startExpirationMonitoring();
      _startBillingIssueMonitoring();
      
      debugPrint('$_logPrefix Successfully initialized subscription monitoring');
      
    } catch (e) {
      debugPrint('$_logPrefix Error initializing subscription: $e');
      emit(SubscriptionError(message: 'Failed to initialize subscription: $e'));
    }
  }

  /// Handle subscription data changes from Firestore
  Future<void> _onSubscriptionChanged(
    SubscriptionChanged event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final subscription = event.subscription;
      
      if (subscription == null) {
        debugPrint('$_logPrefix No subscription found - user likely needs free subscription created');
        emit(const SubscriptionError(message: 'No subscription found'));
        return;
      }

      debugPrint('$_logPrefix Processing subscription change: ${subscription.tier.name} (${subscription.status.name})');
      
      // Clear caches when subscription changes
      _clearCaches();
      
      // Load additional data for complete state
      final featureAccess = await _loadFeatureAccess(subscription);
      final usageLimits = await _loadUsageLimits(subscription);
      final currentUsage = await _loadCurrentUsage(subscription);
      
      // Check for subscription status issues
      await _checkSubscriptionIssues(subscription, emit);
      
      // Emit loaded state with all data
      emit(SubscriptionLoaded(
        subscription: subscription,
        featureAccess: featureAccess,
        usageLimits: usageLimits,
        currentUsage: currentUsage,
      ));
      
      debugPrint('$_logPrefix Successfully loaded subscription state');
      
    } catch (e) {
      debugPrint('$_logPrefix Error processing subscription change: $e');
      emit(SubscriptionError(
        message: 'Failed to process subscription change: $e',
        subscription: event.subscription,
      ));
    }
  }

  /// Handle subscription upgrade
  Future<void> _onSubscriptionUpgraded(
    SubscriptionUpgraded event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for upgrade'));
        return;
      }

      debugPrint('$_logPrefix Processing upgrade to ${event.tier.name}');
      
      // Get current subscription for previous tier tracking
      final currentState = state;
      final currentSubscription = currentState is SubscriptionLoaded 
          ? currentState.subscription 
          : null;
      
      emit(SubscriptionUpgrading(
        targetTier: event.tier,
        currentSubscription: currentSubscription,
      ));

      // Perform the upgrade
      final upgradedSubscription = await SubscriptionService.upgradeToTier(
        _currentUserId!,
        event.tier,
        stripeCustomerId: event.stripeCustomerId,
        stripeSubscriptionId: event.stripeSubscriptionId,
        paymentMethodId: event.paymentMethodId,
        stripePriceId: event.stripePriceId,
      );

      // Clear security caches
      SecureSubscriptionService.invalidateCache(_currentUserId!);
      
      debugPrint('$_logPrefix Successfully upgraded to ${event.tier.name}');
      
      // Emit upgrade success state
      emit(SubscriptionUpgradedState(
        subscription: upgradedSubscription,
        previousTier: currentSubscription?.tier ?? SubscriptionTier.free,
      ));
      
      // The subscription stream will update the main state
      
    } catch (e) {
      debugPrint('$_logPrefix Error upgrading subscription: $e');
      emit(SubscriptionError(message: 'Failed to upgrade subscription: $e'));
    }
  }

  /// Handle subscription cancellation
  Future<void> _onSubscriptionCancelled(
    SubscriptionCancelled event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for cancellation'));
        return;
      }

      debugPrint('$_logPrefix Processing subscription cancellation');
      
      // Get current subscription
      final currentState = state;
      if (currentState is! SubscriptionLoaded) {
        emit(const SubscriptionError(message: 'No active subscription to cancel'));
        return;
      }
      
      emit(SubscriptionCancelling(currentState.subscription));

      // Perform the cancellation
      final cancelledSubscription = await SubscriptionService.cancelSubscription(_currentUserId!);
      
      // Clear security caches
      SecureSubscriptionService.invalidateCache(_currentUserId!);
      
      debugPrint('$_logPrefix Successfully cancelled subscription');
      
      emit(SubscriptionCancelledState(
        subscription: cancelledSubscription,
        cancellationDate: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('$_logPrefix Error cancelling subscription: $e');
      emit(SubscriptionError(message: 'Failed to cancel subscription: $e'));
    }
  }

  /// Handle feature access requests
  Future<void> _onFeatureAccessRequested(
    FeatureAccessRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for feature check'));
        return;
      }

      debugPrint('$_logPrefix Checking access to feature: ${event.featureName}');
      
      // Check cache first
      if (_featureAccessCache.containsKey(event.featureName)) {
        final hasAccess = _featureAccessCache[event.featureName]!;
        debugPrint('$_logPrefix Feature access cached: $hasAccess');
        
        final currentState = state;
        if (currentState is SubscriptionLoaded) {
          emit(FeatureAccessResult(
            featureName: event.featureName,
            hasAccess: hasAccess,
            subscription: currentState.subscription,
          ));
          return;
        }
      }
      
      // Use secure validation service
      final hasAccess = await SecureSubscriptionService.validateFeatureAccess(
        _currentUserId!,
        event.featureName,
      );
      
      // Cache the result
      _featureAccessCache[event.featureName] = hasAccess;
      
      debugPrint('$_logPrefix Feature access result: $hasAccess');
      
      final currentState = state;
      if (currentState is SubscriptionLoaded) {
        emit(FeatureAccessResult(
          featureName: event.featureName,
          hasAccess: hasAccess,
          subscription: currentState.subscription,
        ));
      }
      
    } catch (e) {
      debugPrint('$_logPrefix Error checking feature access: $e');
      emit(SubscriptionError(message: 'Failed to check feature access: $e'));
    }
  }

  /// Handle usage limit requests
  Future<void> _onUsageLimitRequested(
    UsageLimitRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for limit check'));
        return;
      }

      debugPrint('$_logPrefix Checking usage limit: ${event.limitName} (current: ${event.currentUsage})');
      
      // Use secure validation service for critical limits
      final withinLimit = await SecureSubscriptionService.validateUsageLimit(
        _currentUserId!,
        event.limitName,
        event.currentUsage,
      );
      
      // Get the actual limit value
      final limit = await SubscriptionService.getUserLimit(_currentUserId!, event.limitName);
      
      debugPrint('$_logPrefix Usage limit result: $withinLimit (limit: $limit)');
      
      final currentState = state;
      if (currentState is SubscriptionLoaded) {
        emit(UsageLimitResult(
          limitName: event.limitName,
          currentUsage: event.currentUsage,
          limit: limit,
          withinLimit: withinLimit,
          subscription: currentState.subscription,
        ));
      }
      
    } catch (e) {
      debugPrint('$_logPrefix Error checking usage limit: $e');
      emit(SubscriptionError(message: 'Failed to check usage limit: $e'));
    }
  }

  /// Handle payment info updates
  Future<void> _onPaymentInfoUpdated(
    PaymentInfoUpdated event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for payment update'));
        return;
      }

      debugPrint('$_logPrefix Updating payment information');
      
      final updatedSubscription = await SubscriptionService.updatePaymentInfo(
        _currentUserId!,
        paymentMethodId: event.paymentMethodId,
        stripeCustomerId: event.stripeCustomerId,
        stripeSubscriptionId: event.stripeSubscriptionId,
        nextPaymentDate: event.nextPaymentDate,
      );
      
      debugPrint('$_logPrefix Successfully updated payment information');
      
      emit(PaymentInfoUpdatedState(updatedSubscription));
      
    } catch (e) {
      debugPrint('$_logPrefix Error updating payment info: $e');
      emit(SubscriptionError(message: 'Failed to update payment information: $e'));
    }
  }

  /// Handle subscription refresh requests
  Future<void> _onSubscriptionRefreshed(
    SubscriptionRefreshed event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      debugPrint('$_logPrefix Refreshing subscription (force: ${event.forceRefresh})');
      
      if (event.forceRefresh) {
        _clearCaches();
        SecureSubscriptionService.invalidateCache(_currentUserId!);
      }
      
      // Re-initialize to trigger fresh data load
      add(SubscriptionInitialized(_currentUserId!));
      
    } catch (e) {
      debugPrint('$_logPrefix Error refreshing subscription: $e');
      emit(SubscriptionError(message: 'Failed to refresh subscription: $e'));
    }
  }

  /// Handle subscription errors
  Future<void> _onSubscriptionErrorOccurred(
    SubscriptionErrorOccurred event,
    Emitter<SubscriptionState> emit,
  ) async {
    debugPrint('$_logPrefix Processing subscription error: ${event.error}');
    
    // Try to preserve current subscription data if available
    final currentState = state;
    final currentSubscription = currentState is SubscriptionLoaded 
        ? currentState.subscription 
        : null;
    
    emit(SubscriptionError(
      message: event.error,
      subscription: currentSubscription,
    ));
  }

  /// Clear subscription errors
  Future<void> _onSubscriptionErrorCleared(
    SubscriptionErrorCleared event,
    Emitter<SubscriptionState> emit,
  ) async {
    debugPrint('$_logPrefix Clearing subscription error');
    
    // Return to previous valid state or re-initialize
    if (_currentUserId != null) {
      add(SubscriptionRefreshed());
    } else {
      emit(const SubscriptionInitial());
    }
  }

  /// Preload subscription for better UX
  Future<void> _onSubscriptionPreloaded(
    SubscriptionPreloaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      debugPrint('$_logPrefix Preloading subscription data');
      
      // Preload via secure service
      await SecureSubscriptionService.preloadSubscription(_currentUserId!);
      
      debugPrint('$_logPrefix Subscription data preloaded');
      
    } catch (e) {
      debugPrint('$_logPrefix Error preloading subscription: $e');
      // Don't emit error for preloading failures
    }
  }

  /// Get upgrade recommendations
  Future<void> _onUpgradeRecommendationsRequested(
    UpgradeRecommendationsRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      debugPrint('$_logPrefix Loading upgrade recommendations');
      
      final recommendations = await SubscriptionService.getUpgradeRecommendations(_currentUserId!);
      
      final currentState = state;
      if (currentState is SubscriptionLoaded) {
        emit(UpgradeRecommendationsLoaded(
          recommendations: recommendations,
          subscription: currentState.subscription,
        ));
      }
      
    } catch (e) {
      debugPrint('$_logPrefix Error loading upgrade recommendations: $e');
      // Don't emit error for recommendations failures
    }
  }

  /// Track feature usage for analytics
  Future<void> _onFeatureUsageTracked(
    FeatureUsageTracked event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      debugPrint('$_logPrefix Tracking feature usage: ${event.featureName}');
      
      // Update usage analytics in Firestore
      await _firestore
          .collection('subscription_feature_usage')
          .add({
            'userId': _currentUserId,
            'featureName': event.featureName,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': event.metadata ?? {},
          });
      
    } catch (e) {
      debugPrint('$_logPrefix Error tracking feature usage: $e');
      // Don't emit error for tracking failures
    }
  }

  /// Load feature access for subscription
  Future<Map<String, bool>> _loadFeatureAccess(UserSubscription subscription) async {
    try {
      // Load commonly used features to cache them
      final commonFeatures = _getCommonFeatures(subscription.userType);
      final results = <String, bool>{};
      
      for (final feature in commonFeatures) {
        if (!_featureAccessCache.containsKey(feature)) {
          final hasAccess = await SecureSubscriptionService.validateFeatureAccess(
            subscription.userId,
            feature,
          );
          _featureAccessCache[feature] = hasAccess;
        }
        results[feature] = _featureAccessCache[feature]!;
      }
      
      return results;
    } catch (e) {
      debugPrint('$_logPrefix Error loading feature access: $e');
      return {};
    }
  }

  /// Load usage limits for subscription
  Future<Map<String, int>> _loadUsageLimits(UserSubscription subscription) async {
    try {
      final commonLimits = _getCommonLimits(subscription.userType);
      final results = <String, int>{};
      
      for (final limitName in commonLimits) {
        if (!_usageLimitsCache.containsKey(limitName)) {
          final limit = await SubscriptionService.getUserLimit(subscription.userId, limitName);
          _usageLimitsCache[limitName] = limit;
        }
        results[limitName] = _usageLimitsCache[limitName]!;
      }
      
      return results;
    } catch (e) {
      debugPrint('$_logPrefix Error loading usage limits: $e');
      return {};
    }
  }

  /// Load current usage data
  Future<Map<String, dynamic>> _loadCurrentUsage(UserSubscription subscription) async {
    try {
      return await SubscriptionService.getCurrentUsage(subscription.userId);
    } catch (e) {
      debugPrint('$_logPrefix Error loading current usage: $e');
      return {};
    }
  }

  /// Check for subscription issues (expiration, billing)
  Future<void> _checkSubscriptionIssues(
    UserSubscription subscription,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      // Check expiration warning with multiple thresholds
      if (subscription.isPremium && subscription.nextPaymentDate != null) {
        final timeUntilExpiration = subscription.nextPaymentDate!.difference(DateTime.now());
        final daysUntilExpiration = timeUntilExpiration.inDays;
        
        // Emit different warnings based on time remaining
        if (daysUntilExpiration <= 1 && daysUntilExpiration >= 0) {
          emit(SubscriptionExpirationWarning(
            subscription: subscription,
            timeUntilExpiration: timeUntilExpiration,
            severity: ExpirationSeverity.critical, // Expires within 24 hours
            message: 'Your subscription expires in ${timeUntilExpiration.inHours} hours!',
          ));
        } else if (daysUntilExpiration <= 3) {
          emit(SubscriptionExpirationWarning(
            subscription: subscription,
            timeUntilExpiration: timeUntilExpiration,
            severity: ExpirationSeverity.high, // Expires within 3 days
            message: 'Your subscription expires in $daysUntilExpiration days.',
          ));
        } else if (daysUntilExpiration <= 7) {
          emit(SubscriptionExpirationWarning(
            subscription: subscription,
            timeUntilExpiration: timeUntilExpiration,
            severity: ExpirationSeverity.medium, // Expires within 7 days
            message: 'Your subscription expires in $daysUntilExpiration days.',
          ));
        }
      }
      
      // Enhanced billing issue detection
      if (subscription.status == SubscriptionStatus.pastDue) {
        emit(BillingIssueDetected(
          subscription: subscription,
          issueType: 'payment_failed',
          issueMessage: 'Your last payment failed. Please update your payment method to continue using premium features.',
          severity: BillingIssueSeverity.high,
          actionRequired: true,
        ));
      } else if (subscription.status == SubscriptionStatus.pastDue) {
        emit(BillingIssueDetected(
          subscription: subscription,
          issueType: 'payment_incomplete',
          issueMessage: 'Your payment is incomplete. Please complete the payment process.',
          severity: BillingIssueSeverity.medium,
          actionRequired: true,
        ));
      }
      
      // Check for grace period expiration
      if (subscription.status == SubscriptionStatus.cancelled && 
          subscription.nextPaymentDate != null &&
          DateTime.now().isAfter(subscription.nextPaymentDate!)) {
        emit(SubscriptionGracePeriodExpired(
          subscription: subscription,
          expiredDate: subscription.nextPaymentDate!,
        ));
      }
      
    } catch (e) {
      debugPrint('$_logPrefix Error checking subscription issues: $e');
    }
  }

  /// Start monitoring for subscription expiration with dynamic intervals
  void _startExpirationMonitoring() {
    _expirationCheckTimer?.cancel();
    
    // More frequent checks as expiration approaches
    final checkInterval = _getExpirationCheckInterval();
    
    _expirationCheckTimer = Timer.periodic(
      checkInterval,
      (timer) {
        final currentState = state;
        if (currentState is SubscriptionLoaded) {
          add(SubscriptionIssuesRequested(currentState.subscription));
          
          // Adjust check frequency based on subscription status
          final newInterval = _getExpirationCheckInterval();
          if (newInterval != checkInterval) {
            debugPrint('$_logPrefix Adjusting expiration check interval to ${newInterval.inMinutes} minutes');
            _startExpirationMonitoring(); // Restart with new interval
          }
        }
      },
    );
  }
  
  /// Get dynamic check interval based on subscription status
  Duration _getExpirationCheckInterval() {
    final currentState = state;
    if (currentState is SubscriptionLoaded && 
        currentState.subscription.isPremium && 
        currentState.subscription.nextPaymentDate != null) {
      
      final timeUntilExpiration = currentState.subscription.nextPaymentDate!.difference(DateTime.now());
      final daysUntilExpiration = timeUntilExpiration.inDays;
      
      // More frequent checks as expiration approaches
      if (daysUntilExpiration <= 1) {
        return const Duration(hours: 1); // Check every hour in final day
      } else if (daysUntilExpiration <= 3) {
        return const Duration(hours: 6); // Check every 6 hours in final 3 days
      } else if (daysUntilExpiration <= 7) {
        return const Duration(hours: 12); // Check twice daily in final week
      }
    }
    
    return const Duration(hours: 24); // Daily checks for active subscriptions
  }

  /// Start monitoring for billing issues with enhanced webhook integration
  void _startBillingIssueMonitoring() {
    _billingIssueCheckTimer?.cancel();
    _billingIssueCheckTimer = Timer.periodic(
      const Duration(hours: 3), // More frequent billing checks
      (timer) {
        final currentState = state;
        if (currentState is SubscriptionLoaded) {
          add(SubscriptionIssuesRequested(currentState.subscription));
          _checkPaymentMethodExpiration(currentState.subscription);
        }
      },
    );
  }
  
  /// Check for payment method expiration
  Future<void> _checkPaymentMethodExpiration(UserSubscription subscription) async {
    try {
      if (subscription.isPremium && subscription.paymentMethodId != null) {
        // This would integrate with Stripe to check payment method status
        // For now, we'll implement a basic check
        
        final paymentMethodDoc = await _firestore
            .collection('payment_methods')
            .doc(subscription.paymentMethodId)
            .get();
            
        if (paymentMethodDoc.exists) {
          final data = paymentMethodDoc.data()!;
          final expiryMonth = data['exp_month'] as int?;
          final expiryYear = data['exp_year'] as int?;
          
          if (expiryMonth != null && expiryYear != null) {
            final expiryDate = DateTime(expiryYear, expiryMonth + 1, 0);
            final now = DateTime.now();
            
            // Warn if payment method expires within 30 days
            if (expiryDate.isBefore(now.add(const Duration(days: 30)))) {
              emit(PaymentMethodExpirationWarning(
                subscription: subscription,
                expiryDate: expiryDate,
                timeUntilExpiration: expiryDate.difference(now),
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('$_logPrefix Error checking payment method expiration: $e');
    }
  }

  /// Clear all caches
  void _clearCaches() {
    _featureAccessCache.clear();
    _usageLimitsCache.clear();
    _currentUsageCache.clear();
    debugPrint('$_logPrefix Cleared all caches');
  }

  /// Get common features for user type
  List<String> _getCommonFeatures(String userType) {
    switch (userType) {
      case 'vendor':
        return [
          'product_performance_analytics',
          'revenue_tracking',
          'market_discovery',
          'unlimited_markets',
        ];
      case 'market_organizer':
        return [
          'vendor_discovery',
          'bulk_messaging',
          'vendor_analytics_dashboard',
        ];
      case 'shopper':
        return [
          'enhanced_search',
          'vendor_following',
          'unlimited_favorites',
        ];
      default:
        return [];
    }
  }

  /// Get common limits for user type
  List<String> _getCommonLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return [
          'global_products',
          'photo_uploads_per_post',
          'monthly_markets',
        ];
      case 'market_organizer':
        return [
          'markets_managed',
          'events_per_month',
        ];
      case 'shopper':
        return [
          'saved_favorites',
          'followed_vendors',
        ];
      default:
        return [];
    }
  }

  /// Handle subscription issues requests from timers
  Future<void> _onSubscriptionIssuesRequested(
    SubscriptionIssuesRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      await _checkSubscriptionIssues(event.subscription, emit);
    } catch (e) {
      debugPrint('$_logPrefix Error checking subscription issues: $e');
    }
  }

  @override
  Future<void> close() {
    debugPrint('$_logPrefix Closing subscription bloc');
    
    _subscriptionStreamSubscription?.cancel();
    _expirationCheckTimer?.cancel();
    _billingIssueCheckTimer?.cancel();
    
    return super.close();
  }
}