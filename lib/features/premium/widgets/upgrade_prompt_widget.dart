import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../models/user_subscription.dart';

/// Smart upgrade prompt widget that appears contextually when users hit limits
/// or try to access premium features
class UpgradePromptWidget extends StatelessWidget {
  final String userId;
  final String userType;
  final String featureName;
  final String contextMessage;
  final VoidCallback? onDismiss;

  const UpgradePromptWidget({
    super.key,
    required this.userId,
    required this.userType,
    required this.featureName,
    required this.contextMessage,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildContent(context),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HiPopColors.primaryDeepSage, HiPopColors.accentMauve],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade to Premium',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contextMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureBenefits(context),
          const SizedBox(height: 20),
          _buildPricingPreview(context),
        ],
      ),
    );
  }

  Widget _buildFeatureBenefits(BuildContext context) {
    final benefits = _getBenefitsForFeature();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unlock Premium Features:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...benefits.map((benefit) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPreview(BuildContext context) {
    final recommendedTier = _getRecommendedTier();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.primaryOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HiPopColors.primaryOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer,
            color: HiPopColors.primaryDeepSage,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendedTier['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Starting at ${recommendedTier['price']}/month',
                  style: TextStyle(
                    color: HiPopColors.primaryDeepSage,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showUpgradeFlow(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Upgrade Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  List<String> _getBenefitsForFeature() {
    switch (featureName) {
      case 'advanced_analytics':
        return [
          'Detailed performance insights',
          'Customer behavior analysis',
          'Revenue optimization recommendations',
          'Competitive benchmarking',
        ];
      case 'market_expansion':
        return [
          'Market opportunity analysis',
          'Expansion recommendations',
          'Risk assessment tools',
          'ROI projections',
        ];
      case 'unlimited_markets':
        return [
          'Participate in unlimited markets',
          'Multi-market analytics',
          'Centralized management',
          'Performance comparison tools',
        ];
      case 'unlimited_photos per post':
      case 'unlimited_photo_uploads':
        return [
          'Upload unlimited photos per post',
          'Showcase your products better',
          'Advanced photo management',
          'Higher engagement rates',
        ];
      case 'api_access':
        return [
          'Full API access',
          'Custom integrations',
          'Data export capabilities',
          'Third-party tool connections',
        ];
      case 'white_label':
        return [
          'Custom branding',
          'White-label platform',
          'Custom domain support',
          'Branded reports',
        ];
      default:
        return [
          'Advanced analytics and insights',
          'Priority customer support',
          'Enhanced features and tools',
          'Regular feature updates',
        ];
    }
  }

  Map<String, dynamic> _getRecommendedTier() {
    switch (userType) {
      case 'vendor':
        return {
          'title': 'Vendor Premium',
          'price': '\$29.00',
          'tier': SubscriptionTier.vendorPremium,
        };
      case 'market_organizer':
        return {
          'title': 'Market Organizer Premium',
          'price': '\$69.00',
          'tier': SubscriptionTier.marketOrganizerPremium,
        };
      default:
        return {
          'title': 'Vendor Premium',
          'price': '\$29.00',
          'tier': SubscriptionTier.vendorPremium,
        };
    }
  }

  void _showUpgradeFlow(BuildContext context) {
    // Use GoRouter for consistent navigation
    context.go('/premium/upgrade?tier=$userType&userId=$userId');
  }
}

/// Contextual upgrade prompts for specific scenarios
class ContextualUpgradePrompts {
  /// Show upgrade prompt when hitting usage limits
  static void showLimitReachedPrompt(
    BuildContext context, {
    required String userId,
    required String userType,
    required String limitName,
    required int currentUsage,
    required int limit,
  }) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptWidget(
        userId: userId,
        userType: userType,
        featureName: 'unlimited_$limitName',
        contextMessage: 'You\'ve reached your limit of $limit $limitName. '
            'Upgrade to premium to unlock unlimited access and advanced features.',
      ),
    );
  }

  /// Show upgrade prompt when accessing premium features
  static void showFeatureLockedPrompt(
    BuildContext context, {
    required String userId,
    required String userType,
    required String featureName,
    required String featureDisplayName,
  }) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptWidget(
        userId: userId,
        userType: userType,
        featureName: featureName,
        contextMessage: '$featureDisplayName is a premium feature. '
            'Upgrade now to unlock this and many other powerful tools.',
      ),
    );
  }

  /// Show upgrade prompt with custom message
  static void showCustomPrompt(
    BuildContext context, {
    required String userId,
    required String userType,
    required String featureName,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptWidget(
        userId: userId,
        userType: userType,
        featureName: featureName,
        contextMessage: message,
        onDismiss: onDismiss,
      ),
    );
  }
}

/// In-line upgrade banner widget for non-intrusive prompts
class UpgradeBannerWidget extends StatelessWidget {
  final String userId;
  final String userType;
  final String message;
  final VoidCallback? onDismiss;

  const UpgradeBannerWidget({
    super.key,
    required this.userId,
    required this.userType,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HiPopColors.accentMauve.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.star,
            color: HiPopColors.accentMauve,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.accentMauveDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: HiPopColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => context.go('/premium/upgrade?tier=$userType&userId=$userId'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upgrade'),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: HiPopColors.accentMauve,
                size: 20,
              ),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ],
      ),
    );
  }
}