import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../blocs/subscription/subscription_bloc.dart';
import '../../../blocs/subscription/subscription_state.dart';
import '../../../blocs/subscription/subscription_event.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import 'vendor_premium_dashboard_components.dart';

/// FeatureGateWidget - Advanced subscription-based access control with animations
/// 
/// This widget provides sophisticated feature gating for premium functionality,
/// including:
/// - Real-time subscription state monitoring
/// - Animated upgrade prompts and unlock effects
/// - Graceful degradation for free users
/// - Comprehensive error handling
/// - Usage limit enforcement
/// - Tier-specific feature access
class FeatureGateWidget extends StatefulWidget {
  /// The feature name to check access for
  final String featureName;
  
  /// Widget to display when user has access
  final Widget child;
  
  /// Optional custom upgrade prompt
  final Widget? upgradePrompt;
  
  /// Optional fallback widget for no access (defaults to upgrade prompt)
  final Widget? fallback;
  
  /// Whether to show usage limits along with the feature
  final bool showUsageLimit;
  
  /// Usage limit name to check (if showUsageLimit is true)
  final String? usageLimitName;
  
  /// Current usage count (if checking usage limits)
  final int? currentUsage;
  
  /// Whether to show animations for unlock/upgrade prompts
  final bool showAnimations;
  
  /// Custom animation duration
  final Duration animationDuration;
  
  /// Whether to track feature usage analytics
  final bool trackUsage;
  
  /// Additional metadata for usage tracking
  final Map<String, dynamic>? usageMetadata;
  
  /// Callback when user attempts to access locked feature
  final VoidCallback? onAccessAttempt;
  
  /// Callback when upgrade is triggered
  final VoidCallback? onUpgradeTriggered;

  const FeatureGateWidget({
    super.key,
    required this.featureName,
    required this.child,
    this.upgradePrompt,
    this.fallback,
    this.showUsageLimit = false,
    this.usageLimitName,
    this.currentUsage,
    this.showAnimations = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.trackUsage = true,
    this.usageMetadata,
    this.onAccessAttempt,
    this.onUpgradeTriggered,
  });

  @override
  State<FeatureGateWidget> createState() => _FeatureGateWidgetState();
}

class _FeatureGateWidgetState extends State<FeatureGateWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _hasCheckedAccess = false;
  bool _hasAccess = false;
  bool _isWithinLimit = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _initializeFeatureCheck();
  }

  void _initializeFeatureCheck() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      
      // Initialize subscription monitoring
      context.read<SubscriptionBloc>().add(
        SubscriptionInitialized(_currentUserId!),
      );
      
      // Request feature access check
      context.read<SubscriptionBloc>().add(
        FeatureAccessRequested(widget.featureName),
      );
      
      // Check usage limits if required
      if (widget.showUsageLimit && 
          widget.usageLimitName != null && 
          widget.currentUsage != null) {
        context.read<SubscriptionBloc>().add(
          UsageLimitRequested(widget.usageLimitName!, widget.currentUsage!),
        );
      }
      
      // Track usage if enabled
      if (widget.trackUsage) {
        context.read<SubscriptionBloc>().add(
          FeatureUsageTracked(
            widget.featureName, 
            metadata: widget.usageMetadata,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return _buildLoadingState();
        }

        return BlocConsumer<SubscriptionBloc, SubscriptionState>(
          listener: _handleSubscriptionStateChange,
          builder: (context, subscriptionState) {
            return _buildFeatureContent(subscriptionState);
          },
        );
      },
    );
  }

  void _handleSubscriptionStateChange(BuildContext context, SubscriptionState state) {
    if (state is FeatureAccessResult && state.featureName == widget.featureName) {
      setState(() {
        _hasAccess = state.hasAccess;
        _hasCheckedAccess = true;
      });
      
      if (state.hasAccess && widget.showAnimations) {
        _animationController.forward();
      }
      
      // Call access attempt callback if feature is locked
      if (!state.hasAccess && widget.onAccessAttempt != null) {
        widget.onAccessAttempt!();
      }
    }
    
    if (state is UsageLimitResult && 
        state.limitName == widget.usageLimitName) {
      setState(() {
        _isWithinLimit = state.withinLimit;
      });
    }
    
    if (state is SubscriptionLoaded) {
      setState(() {
        _hasAccess = state.hasFeature(widget.featureName);
        _hasCheckedAccess = true;
        
        if (widget.showUsageLimit && 
            widget.usageLimitName != null && 
            widget.currentUsage != null) {
          _isWithinLimit = state.isWithinLimit(
            widget.usageLimitName!, 
            widget.currentUsage!,
          );
        }
      });
      
      if (_hasAccess && widget.showAnimations) {
        _animationController.forward();
      }
    }
    
    // Handle subscription upgrade success
    if (state is SubscriptionUpgraded) {
      _showUpgradeSuccessAnimation();
    }
    
    // Handle expiration warnings
    if (state is SubscriptionExpirationWarning) {
      _showExpirationWarning(state);
    }
    
    // Handle billing issues
    if (state is BillingIssueDetected) {
      _showBillingIssueDialog(state);
    }
  }

  Widget _buildFeatureContent(SubscriptionState subscriptionState) {
    if (!_hasCheckedAccess || subscriptionState is SubscriptionLoading) {
      return _buildLoadingState();
    }
    
    // Check both feature access and usage limits
    final canAccess = _hasAccess && _isWithinLimit;
    
    if (canAccess) {
      return _buildAccessGranted();
    } else {
      return _buildAccessDenied(subscriptionState);
    }
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              'Checking access...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessGranted() {
    if (!widget.showAnimations) {
      return widget.child;
    }
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccessDenied(SubscriptionState subscriptionState) {
    // Use custom fallback or upgrade prompt
    if (widget.fallback != null) {
      return _animateWidget(widget.fallback!);
    }
    
    if (widget.upgradePrompt != null) {
      return _animateWidget(widget.upgradePrompt!);
    }
    
    // Build default access denied content
    return _animateWidget(_buildDefaultAccessDenied(subscriptionState));
  }

  Widget _buildDefaultAccessDenied(SubscriptionState subscriptionState) {
    final subscription = subscriptionState is SubscriptionLoaded 
        ? subscriptionState.subscription 
        : null;
    
    // Check if it's a usage limit issue vs feature access issue
    final isUsageLimitIssue = _hasAccess && !_isWithinLimit;
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade50,
              Colors.orange.shade100.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium feature icon with animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUsageLimitIssue ? Icons.speed : Icons.diamond,
                  color: Colors.orange.shade700,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                isUsageLimitIssue 
                    ? 'Usage Limit Reached'
                    : 'Premium Feature',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                isUsageLimitIssue
                    ? 'You\'ve reached your current plan\'s limit for ${widget.usageLimitName}. Upgrade to continue using this feature.'
                    : '${_getFeatureDisplayName(widget.featureName)} is available exclusively for premium subscribers.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Usage limit details (if applicable)
              if (isUsageLimitIssue && widget.currentUsage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current usage: ${widget.currentUsage} (limit reached)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Benefits preview
              _buildFeatureBenefits(),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.onUpgradeTriggered != null) {
                          widget.onUpgradeTriggered!();
                        }
                        _navigateToUpgrade();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isUsageLimitIssue ? Icons.upgrade : Icons.diamond,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isUsageLimitIssue ? 'Upgrade Plan' : 'Unlock Premium',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBenefits() {
    final benefits = _getFeatureBenefits(widget.featureName);
    if (benefits.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premium includes:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 12),
        ...benefits.take(3).map((benefit) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  benefit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _animateWidget(Widget child) {
    if (!widget.showAnimations) return child;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  void _showUpgradeSuccessAnimation() {
    if (!widget.showAnimations) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You now have access to ${_getFeatureDisplayName(widget.featureName)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Refresh feature access
              _initializeFeatureCheck();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showExpirationWarning(SubscriptionExpirationWarning state) {
    if (state.severity == ExpirationSeverity.critical) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(state.message)),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          action: SnackBarAction(
            label: 'Renew',
            textColor: Colors.white,
            onPressed: _navigateToUpgrade,
          ),
        ),
      );
    }
  }

  void _showBillingIssueDialog(BillingIssueDetected state) {
    if (state.actionRequired) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Billing Issue'),
          content: Text(state.issueMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToUpgrade();
              },
              child: const Text('Fix Now'),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToUpgrade() {
    context.go('/premium-onboarding');
  }

  String _getFeatureDisplayName(String featureName) {
    switch (featureName) {
      case 'product_performance_analytics':
        return 'Advanced Analytics';
      case 'revenue_tracking':
        return 'Revenue Tracking';
      case 'market_discovery':
        return 'Market Discovery';
      case 'unlimited_markets':
        return 'Unlimited Markets';
      case 'vendor_discovery':
        return 'Vendor Discovery';
      case 'bulk_messaging':
        return 'Bulk Messaging';
      case 'enhanced_search':
        return 'Enhanced Search';
      default:
        return featureName.replaceAll('_', ' ').split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  List<String> _getFeatureBenefits(String featureName) {
    switch (featureName) {
      case 'product_performance_analytics':
        return [
          'Real-time revenue tracking',
          'Customer engagement insights',
          'Performance optimization tips',
          'Market trend analysis',
        ];
      case 'revenue_tracking':
        return [
          'Automated sales tracking',
          'Revenue growth charts',
          'Profit margin analysis',
          'Financial forecasting',
        ];
      case 'market_discovery':
        return [
          'Access to premium markets',
          'Market matching algorithm',
          'Early market notifications',
          'Priority vendor placement',
        ];
      case 'unlimited_markets':
        return [
          'Join unlimited markets',
          'Multi-market management',
          'Cross-market analytics',
          'Bulk market operations',
        ];
      default:
        return [
          'Advanced feature access',
          'Priority customer support',
          'Enhanced functionality',
          'Professional tools',
        ];
    }
  }
}