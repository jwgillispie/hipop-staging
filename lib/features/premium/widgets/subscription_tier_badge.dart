import 'package:flutter/material.dart';
import '../models/user_subscription.dart';

/// Subscription tier badge widget for displaying user's current subscription status
/// 
/// This widget provides visual indicators for different subscription tiers with:
/// - Tier-specific colors and gradients
/// - Animated pulse effects for premium tiers
/// - Customizable sizes and styles
/// - Status indicators (active, expired, trial)
/// - Integration with subscription state management
class SubscriptionTierBadge extends StatefulWidget {
  /// The subscription to display the badge for
  final UserSubscription subscription;
  
  /// Size of the badge
  final BadgeSize size;
  
  /// Badge style variant
  final BadgeStyle style;
  
  /// Whether to show animated effects
  final bool showAnimation;
  
  /// Whether to show status indicators (trial, expired, etc.)
  final bool showStatus;
  
  /// Custom badge text override
  final String? customText;
  
  /// Callback when badge is tapped
  final VoidCallback? onTap;

  const SubscriptionTierBadge({
    super.key,
    required this.subscription,
    this.size = BadgeSize.medium,
    this.style = BadgeStyle.gradient,
    this.showAnimation = true,
    this.showStatus = true,
    this.customText,
    this.onTap,
  });

  @override
  State<SubscriptionTierBadge> createState() => _SubscriptionTierBadgeState();
}

class _SubscriptionTierBadgeState extends State<SubscriptionTierBadge>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation for premium tiers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.showAnimation && widget.subscription.isPremium) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: widget.showAnimation && widget.subscription.isPremium
          ? AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: _buildBadge(),
                );
              },
            )
          : _buildBadge(),
    );
  }

  Widget _buildBadge() {
    final tierConfig = _getTierConfiguration();
    final sizeConfig = _getSizeConfiguration();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizeConfig.horizontalPadding,
        vertical: sizeConfig.verticalPadding,
      ),
      decoration: _buildBadgeDecoration(tierConfig),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tier icon
          if (sizeConfig.showIcon) ...[
            Icon(
              tierConfig.icon,
              size: sizeConfig.iconSize,
              color: tierConfig.textColor,
            ),
            SizedBox(width: sizeConfig.iconSpacing),
          ],
          
          // Badge text
          Text(
            widget.customText ?? tierConfig.displayName,
            style: TextStyle(
              fontSize: sizeConfig.fontSize,
              fontWeight: FontWeight.bold,
              color: tierConfig.textColor,
              letterSpacing: 0.5,
            ),
          ),
          
          // Status indicator
          if (widget.showStatus && _getStatusText() != null) ...[
            SizedBox(width: sizeConfig.statusSpacing),
            _buildStatusIndicator(tierConfig, sizeConfig),
          ],
        ],
      ),
    );
  }

  Decoration _buildBadgeDecoration(TierConfiguration tierConfig) {
    switch (widget.style) {
      case BadgeStyle.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: tierConfig.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: tierConfig.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      
      case BadgeStyle.solid:
        return BoxDecoration(
          color: tierConfig.primaryColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: tierConfig.primaryColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      
      case BadgeStyle.outlined:
        return BoxDecoration(
          border: Border.all(
            color: tierConfig.primaryColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
          color: tierConfig.backgroundColor,
        );
      
      case BadgeStyle.minimal:
        return BoxDecoration(
          color: tierConfig.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        );
    }
  }

  Widget _buildStatusIndicator(TierConfiguration tierConfig, SizeConfiguration sizeConfig) {
    final statusText = _getStatusText();
    if (statusText == null) return const SizedBox.shrink();
    
    final statusConfig = _getStatusConfiguration();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizeConfig.statusPadding,
        vertical: sizeConfig.statusPadding * 0.5,
      ),
      decoration: BoxDecoration(
        color: statusConfig.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusConfig.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusConfig.icon != null) ...[
            Icon(
              statusConfig.icon,
              size: sizeConfig.statusIconSize,
              color: statusConfig.textColor,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            statusText,
            style: TextStyle(
              fontSize: sizeConfig.statusFontSize,
              fontWeight: FontWeight.w600,
              color: statusConfig.textColor,
            ),
          ),
        ],
      ),
    );
  }

  TierConfiguration _getTierConfiguration() {
    switch (widget.subscription.tier) {
      case SubscriptionTier.free:
        return TierConfiguration(
          displayName: 'Free',
          primaryColor: Colors.grey.shade600,
          backgroundColor: Colors.grey.shade50,
          textColor: Colors.white,
          gradientColors: [Colors.grey.shade500, Colors.grey.shade600],
          icon: Icons.person,
        );
      
      case SubscriptionTier.vendorPremium:
        return TierConfiguration(
          displayName: 'Vendor Premium',
          primaryColor: Colors.orange.shade600,
          backgroundColor: Colors.orange.shade50,
          textColor: Colors.white,
          gradientColors: [Colors.orange.shade400, Colors.orange.shade600],
          icon: Icons.diamond,
        );
      
      case SubscriptionTier.marketOrganizerPremium:
        return TierConfiguration(
          displayName: 'Organizer Premium',
          primaryColor: Colors.purple.shade600,
          backgroundColor: Colors.purple.shade50,
          textColor: Colors.white,
          gradientColors: [Colors.purple.shade400, Colors.purple.shade600],
          icon: Icons.business_center,
        );
      
      case SubscriptionTier.shopperPremium:
        return TierConfiguration(
          displayName: 'Shopper Pro',
          primaryColor: Colors.blue.shade600,
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.white,
          gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
          icon: Icons.shopping_bag,
        );
      
      case SubscriptionTier.enterprise:
        return TierConfiguration(
          displayName: 'Enterprise',
          primaryColor: Colors.green.shade800,
          backgroundColor: Colors.green.shade50,
          textColor: Colors.white,
          gradientColors: [Colors.green.shade600, Colors.green.shade800],
          icon: Icons.corporate_fare,
        );
    }
  }

  SizeConfiguration _getSizeConfiguration() {
    switch (widget.size) {
      case BadgeSize.small:
        return SizeConfiguration(
          fontSize: 10,
          horizontalPadding: 6,
          verticalPadding: 3,
          iconSize: 12,
          iconSpacing: 3,
          statusSpacing: 4,
          statusPadding: 3,
          statusFontSize: 8,
          statusIconSize: 8,
          showIcon: false,
        );
      
      case BadgeSize.medium:
        return SizeConfiguration(
          fontSize: 12,
          horizontalPadding: 10,
          verticalPadding: 5,
          iconSize: 16,
          iconSpacing: 5,
          statusSpacing: 6,
          statusPadding: 4,
          statusFontSize: 9,
          statusIconSize: 10,
          showIcon: true,
        );
      
      case BadgeSize.large:
        return SizeConfiguration(
          fontSize: 14,
          horizontalPadding: 14,
          verticalPadding: 7,
          iconSize: 20,
          iconSpacing: 7,
          statusSpacing: 8,
          statusPadding: 5,
          statusFontSize: 11,
          statusIconSize: 12,
          showIcon: true,
        );
    }
  }

  String? _getStatusText() {
    if (!widget.showStatus) return null;
    
    final now = DateTime.now();
    
    // Check for trial status
    if (false) { // trial functionality not implemented
      return 'TRIAL';
    }
    
    // Check for expiration
    if (widget.subscription.nextPaymentDate != null) {
      final daysUntilExpiration = widget.subscription.nextPaymentDate!.difference(now).inDays;
      
      if (daysUntilExpiration <= 0) {
        return 'EXPIRED';
      } else if (daysUntilExpiration <= 7) {
        return '${daysUntilExpiration}D';
      }
    }
    
    // Check for cancelled status
    if (widget.subscription.status == SubscriptionStatus.cancelled) {
      return 'CANCELLED';
    }
    
    // Check for billing issues
    if (widget.subscription.status == SubscriptionStatus.pastDue) {
      return 'PAST DUE';
    }
    
    return null;
  }

  StatusConfiguration _getStatusConfiguration() {
    final statusText = _getStatusText();
    
    switch (statusText) {
      case 'TRIAL':
        return StatusConfiguration(
          backgroundColor: Colors.blue.shade100,
          borderColor: Colors.blue.shade300,
          textColor: Colors.blue.shade700,
          icon: Icons.access_time,
        );
      
      case 'EXPIRED':
      case 'PAST DUE':
        return StatusConfiguration(
          backgroundColor: Colors.red.shade100,
          borderColor: Colors.red.shade300,
          textColor: Colors.red.shade700,
          icon: Icons.error_outline,
        );
      
      case 'CANCELLED':
        return StatusConfiguration(
          backgroundColor: Colors.grey.shade100,
          borderColor: Colors.grey.shade300,
          textColor: Colors.grey.shade700,
          icon: Icons.cancel_outlined,
        );
      
      case 'INCOMPLETE':
        return StatusConfiguration(
          backgroundColor: Colors.orange.shade100,
          borderColor: Colors.orange.shade300,
          textColor: Colors.orange.shade700,
          icon: Icons.warning_outlined,
        );
      
      default:
        // Days remaining
        return StatusConfiguration(
          backgroundColor: Colors.amber.shade100,
          borderColor: Colors.amber.shade300,
          textColor: Colors.amber.shade700,
          icon: Icons.schedule,
        );
    }
  }
}

/// Badge size variants
enum BadgeSize { small, medium, large }

/// Badge style variants
enum BadgeStyle { gradient, solid, outlined, minimal }

/// Configuration for different subscription tiers
class TierConfiguration {
  final String displayName;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;
  final List<Color> gradientColors;
  final IconData icon;

  TierConfiguration({
    required this.displayName,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.gradientColors,
    required this.icon,
  });
}

/// Configuration for different badge sizes
class SizeConfiguration {
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double iconSpacing;
  final double statusSpacing;
  final double statusPadding;
  final double statusFontSize;
  final double statusIconSize;
  final bool showIcon;

  SizeConfiguration({
    required this.fontSize,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.iconSpacing,
    required this.statusSpacing,
    required this.statusPadding,
    required this.statusFontSize,
    required this.statusIconSize,
    required this.showIcon,
  });
}

/// Configuration for status indicators
class StatusConfiguration {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;

  StatusConfiguration({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.icon,
  });
}