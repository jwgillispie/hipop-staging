import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../../../blocs/subscription/subscription_bloc.dart';
import '../../../blocs/subscription/subscription_state.dart';
import '../../../blocs/subscription/subscription_event.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../models/user_subscription.dart';
import 'subscription_tier_badge.dart';
import 'feature_gate_widget.dart';
import 'vendor_premium_dashboard_components.dart';

/// Collection of premium access control widgets for consistent UI/UX
class PremiumAccessControls {
  
  /// Build an upgrade button with tier-specific styling and messaging
  static Widget buildUpgradeButton({
    required BuildContext context,
    required String userType,
    String? customText,
    VoidCallback? onPressed,
    bool showPremiumBadge = true,
    ButtonSize size = ButtonSize.medium,
  }) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        final subscription = state is SubscriptionLoaded ? state.subscription : null;
        
        // Don't show upgrade button if already premium
        if (subscription?.isPremium == true) {
          return const SizedBox.shrink();
        }
        
        final config = _getUpgradeButtonConfig(userType, size);
        
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: config.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onPressed ?? () => _navigateToUpgrade(context, userType),
            style: ElevatedButton.styleFrom(
              backgroundColor: config.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: config.horizontalPadding,
                vertical: config.verticalPadding,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(config.borderRadius),
              ),
              elevation: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPremiumBadge) ...[
                  Icon(Icons.diamond, size: config.iconSize),
                  SizedBox(width: config.spacing),
                ],
                Text(
                  customText ?? config.defaultText,
                  style: TextStyle(
                    fontSize: config.fontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: config.spacing),
                Icon(Icons.arrow_forward, size: config.iconSize),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build subscription status indicator with real-time updates
  static Widget buildSubscriptionStatus({
    required BuildContext context,
    bool showTierBadge = true,
    bool showExpirationInfo = true,
    bool showUsageIndicators = false,
  }) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        if (state is SubscriptionLoading) {
          return _buildLoadingStatus();
        }
        
        if (state is SubscriptionError) {
          return _buildErrorStatus(state);
        }
        
        if (state is! SubscriptionLoaded) {
          return const SizedBox.shrink();
        }
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with tier badge
                Row(
                  children: [
                    if (showTierBadge)
                      SubscriptionTierBadge(
                        subscription: state.subscription,
                        onTap: () => _showSubscriptionDetails(context, state.subscription),
                      ),
                    const Spacer(),
                    if (state.subscription.isPremium)
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _navigateToSubscriptionManagement(context),
                        tooltip: 'Manage Subscription',
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Subscription details
                _buildSubscriptionDetails(state, showExpirationInfo),
                
                // Usage indicators
                if (showUsageIndicators && state.usageLimits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildUsageIndicators(state),
                ],
                
                // Action buttons
                const SizedBox(height: 16),
                _buildActionButtons(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build feature unlock animation overlay
  static Widget buildFeatureUnlockAnimation({
    required String featureName,
    required VoidCallback onComplete,
    Duration duration = const Duration(seconds: 2),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      onEnd: onComplete,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            color: HiPopColors.primaryDeepSage.withValues(alpha: value * 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Unlock icon with scale animation
                Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_open,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Feature unlocked text with fade
                Opacity(
                  opacity: value,
                  child: Column(
                    children: [
                      const Text(
                        'Feature Unlocked!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        featureName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Progress indicator
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build usage limit warning with upgrade prompt
  static Widget buildUsageLimitWarning({
    required BuildContext context,
    required String limitName,
    required int currentUsage,
    required int limit,
    String? customMessage,
    VoidCallback? onUpgrade,
  }) {
    final percentage = limit > 0 ? (currentUsage / limit) : 0.0;
    final isNearLimit = percentage >= 0.8;
    final hasReachedLimit = currentUsage >= limit;
    
    if (!isNearLimit) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      color: hasReachedLimit ? Colors.red.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasReachedLimit ? Icons.warning : Icons.info_outline,
                  color: hasReachedLimit ? Colors.red.shade600 : Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasReachedLimit ? 'Limit Reached' : 'Approaching Limit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasReachedLimit ? Colors.red.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Text(
              customMessage ?? 
              'You\'ve used $currentUsage of $limit ${limitName.replaceAll('_', ' ')}.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Usage progress bar
            LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasReachedLimit ? Colors.red.shade600 : Colors.orange.shade600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade ?? () => _navigateToUpgrade(context, 'vendor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasReachedLimit ? Colors.red.shade600 : Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(hasReachedLimit ? 'Upgrade Now' : 'Upgrade to Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build premium feature teaser card
  static Widget buildPremiumFeatureTeaser({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    List<String>? benefits,
    VoidCallback? onUpgrade,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              
              if (benefits != null) ...[
                const SizedBox(height: 16),
                ...benefits.take(3).map((benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgrade ?? () => _navigateToUpgrade(context, 'vendor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Unlock with Premium',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  static Widget _buildLoadingStatus() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading subscription...'),
          ],
        ),
      ),
    );
  }

  static Widget _buildErrorStatus(SubscriptionError error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error loading subscription: ${error.message}',
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSubscriptionDetails(SubscriptionLoaded state, bool showExpirationInfo) {
    final subscription = state.subscription;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subscription.isPremium 
              ? 'Premium subscription active'
              : 'Free tier - limited features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: subscription.isPremium ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
        
        if (showExpirationInfo && subscription.nextPaymentDate != null) ...[
          const SizedBox(height: 4),
          Text(
            'Renews on ${subscription.nextPaymentDate!.toLocal().toString().split(' ')[0]}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  static Widget _buildUsageIndicators(SubscriptionLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Usage This Month',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...state.usageLimits.entries.take(3).map((entry) {
          final current = state.currentUsage?[entry.key] as int? ?? 0;
          final limit = entry.value;
          final percentage = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '$current${limit > 0 ? '/$limit' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentage > 0.8 ? Colors.red : 
                    percentage > 0.6 ? Colors.orange : 
                    Colors.green
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static Widget _buildActionButtons(BuildContext context, SubscriptionLoaded state) {
    if (state.subscription.isPremium) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _navigateToSubscriptionManagement(context),
              child: const Text('Manage'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showUsageDetails(context, state),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Usage'),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _navigateToUpgrade(context, state.subscription.userType),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Upgrade to Premium'),
        ),
      );
    }
  }

  static ButtonConfiguration _getUpgradeButtonConfig(String userType, ButtonSize size) {
    final baseConfig = ButtonConfiguration(
      primaryColor: Colors.orange.shade600,
      defaultText: 'Upgrade to Premium',
    );
    
    switch (size) {
      case ButtonSize.small:
        return baseConfig.copyWith(
          fontSize: 12,
          horizontalPadding: 12,
          verticalPadding: 6,
          iconSize: 14,
          spacing: 4,
          borderRadius: 8,
        );
      case ButtonSize.medium:
        return baseConfig.copyWith(
          fontSize: 14,
          horizontalPadding: 16,
          verticalPadding: 8,
          iconSize: 16,
          spacing: 6,
          borderRadius: 10,
        );
      case ButtonSize.large:
        return baseConfig.copyWith(
          fontSize: 16,
          horizontalPadding: 20,
          verticalPadding: 12,
          iconSize: 18,
          spacing: 8,
          borderRadius: 12,
        );
    }
  }

  static void _navigateToUpgrade(BuildContext context, String userType) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    context.go('/premium/upgrade?tier=$userType&userId=$userId');
  }

  static void _navigateToSubscriptionManagement(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      context.go('/subscription-management/$userId');
    } else {
      // Handle case where user is not authenticated
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to access subscription management'),
        ),
      );
    }
  }

  static void _showSubscriptionDetails(BuildContext context, UserSubscription subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tier: ${subscription.tier.name}'),
            Text('Status: ${subscription.status.name}'),
            if (subscription.nextPaymentDate != null)
              Text('Next Payment: ${subscription.nextPaymentDate!.toLocal().toString().split(' ')[0]}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static void _showUsageDetails(BuildContext context, SubscriptionLoaded state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usage Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: state.usageLimits.entries.map((entry) {
              final current = state.currentUsage?[entry.key] as int? ?? 0;
              final limit = entry.value;
              
              return ListTile(
                title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                trailing: Text('$current${limit > 0 ? '/$limit' : ''}'),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

enum ButtonSize { small, medium, large }

class ButtonConfiguration {
  final Color primaryColor;
  final String defaultText;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double spacing;
  final double borderRadius;

  const ButtonConfiguration({
    required this.primaryColor,
    required this.defaultText,
    this.fontSize = 14,
    this.horizontalPadding = 16,
    this.verticalPadding = 8,
    this.iconSize = 16,
    this.spacing = 6,
    this.borderRadius = 10,
  });

  ButtonConfiguration copyWith({
    Color? primaryColor,
    String? defaultText,
    double? fontSize,
    double? horizontalPadding,
    double? verticalPadding,
    double? iconSize,
    double? spacing,
    double? borderRadius,
  }) {
    return ButtonConfiguration(
      primaryColor: primaryColor ?? this.primaryColor,
      defaultText: defaultText ?? this.defaultText,
      fontSize: fontSize ?? this.fontSize,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      iconSize: iconSize ?? this.iconSize,
      spacing: spacing ?? this.spacing,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}