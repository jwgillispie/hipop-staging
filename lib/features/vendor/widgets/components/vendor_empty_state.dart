import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Vendor Empty State Widget
/// 
/// Provides consistent empty state displays across vendor screens
/// Includes illustrations and CTAs for different contexts
/// 
/// Usage:
/// ```dart
/// VendorEmptyStateWidget(
///   type: EmptyStateType.products,
///   onActionTap: () => _addProduct(),
/// )
/// ```
class VendorEmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customMessage;
  final IconData? customIcon;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final Widget? customAction;
  final bool showAnimation;

  const VendorEmptyStateWidget({
    super.key,
    this.type = EmptyStateType.generic,
    this.customTitle,
    this.customMessage,
    this.customIcon,
    this.onActionTap,
    this.actionLabel,
    this.customAction,
    this.showAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getEmptyStateConfig(context, type);
    final title = customTitle ?? config.title;
    final message = customMessage ?? config.message;
    final icon = customIcon ?? config.icon;
    final action = actionLabel ?? config.actionLabel;

    Widget content = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: config.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: showAnimation && type == EmptyStateType.loading
                  ? _AnimatedEmptyIcon(
                      icon: icon,
                      color: config.iconColor,
                    )
                  : Icon(
                      icon,
                      size: 56,
                      color: config.iconColor,
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.lightTextSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onActionTap != null || customAction != null || config.defaultRoute != null) ...[
              const SizedBox(height: 32),
              if (customAction != null)
                customAction!
              else if (onActionTap != null)
                ElevatedButton.icon(
                  onPressed: onActionTap,
                  icon: Icon(config.actionIcon),
                  label: Text(action),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else if (config.defaultRoute != null)
                ElevatedButton.icon(
                  onPressed: () => context.go(config.defaultRoute!),
                  icon: Icon(config.actionIcon),
                  label: Text(action),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
            if (config.secondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: config.secondaryAction,
                child: Text(
                  config.secondaryActionLabel ?? 'Learn More',
                  style: TextStyle(color: config.iconColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (type == EmptyStateType.search) {
      content = Column(
        children: [
          _buildSearchTips(context),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildSearchTips(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HiPopColors.infoBlueGrayLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: HiPopColors.infoBlueGray.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: HiPopColors.infoBlueGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tip: Try adjusting your filters or search terms',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HiPopColors.infoBlueGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _EmptyStateConfig _getEmptyStateConfig(BuildContext context, EmptyStateType type) {
    switch (type) {
      case EmptyStateType.products:
        return _EmptyStateConfig(
          title: 'No Products Yet',
          message: 'Start building your product catalog to showcase at markets',
          icon: Icons.inventory_2_outlined,
          backgroundColor: HiPopColors.vendorAccent.withValues(alpha: 0.1),
          iconColor: HiPopColors.vendorAccent,
          buttonColor: HiPopColors.vendorAccent,
          actionLabel: 'Add First Product',
          actionIcon: Icons.add,
          defaultRoute: '/vendor/products-management',
        );
        
      case EmptyStateType.applications:
        return _EmptyStateConfig(
          title: 'No Applications',
          message: 'You haven\'t applied to any markets yet. Discover markets looking for vendors like you!',
          icon: Icons.assignment_outlined,
          backgroundColor: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
          iconColor: HiPopColors.primaryDeepSage,
          buttonColor: HiPopColors.primaryDeepSage,
          actionLabel: 'Discover Markets',
          actionIcon: Icons.search,
          defaultRoute: '/vendor/market-discovery',
        );
        
      case EmptyStateType.sales:
        return _EmptyStateConfig(
          title: 'No Sales Data',
          message: 'Start tracking your sales to gain insights into your business performance',
          icon: Icons.trending_up,
          backgroundColor: HiPopColors.successGreen.withValues(alpha: 0.1),
          iconColor: HiPopColors.successGreen,
          buttonColor: HiPopColors.successGreen,
          actionLabel: 'Record First Sale',
          actionIcon: Icons.add_circle,
          defaultRoute: '/vendor/sales-tracker',
        );
        
      case EmptyStateType.events:
        return _EmptyStateConfig(
          title: 'No Events Yet',
          message: 'Create your first pop-up event to start connecting with customers',
          icon: Icons.event_available,
          backgroundColor: HiPopColors.accentMauve.withValues(alpha: 0.1),
          iconColor: HiPopColors.accentMauve,
          buttonColor: HiPopColors.accentMauve,
          actionLabel: 'Create Pop-up',
          actionIcon: Icons.add_business,
          defaultRoute: '/vendor/popup-creation',
        );
        
      case EmptyStateType.markets:
        return _EmptyStateConfig(
          title: 'No Markets Found',
          message: 'No markets match your criteria. Try adjusting your filters or check back later',
          icon: Icons.store_mall_directory,
          backgroundColor: HiPopColors.premiumGold.withValues(alpha: 0.1),
          iconColor: HiPopColors.premiumGold,
          buttonColor: HiPopColors.premiumGold,
          actionLabel: 'Clear Filters',
          actionIcon: Icons.filter_alt_off,
        );
        
      case EmptyStateType.analytics:
        return _EmptyStateConfig(
          title: 'No Analytics Data',
          message: 'Analytics will appear here once you start getting views and interactions',
          icon: Icons.analytics_outlined,
          backgroundColor: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
          iconColor: HiPopColors.infoBlueGray,
          buttonColor: HiPopColors.infoBlueGray,
          actionLabel: 'Learn About Analytics',
          actionIcon: Icons.help_outline,
        );
        
      case EmptyStateType.favorites:
        return _EmptyStateConfig(
          title: 'No Favorites',
          message: 'Markets and vendors you favorite will appear here',
          icon: Icons.favorite_border,
          backgroundColor: HiPopColors.errorPlum.withValues(alpha: 0.1),
          iconColor: HiPopColors.errorPlum,
          buttonColor: HiPopColors.errorPlum,
          actionLabel: 'Explore Markets',
          actionIcon: Icons.explore,
          defaultRoute: '/vendor/market-discovery',
        );
        
      case EmptyStateType.messages:
        return _EmptyStateConfig(
          title: 'No Messages',
          message: 'Your conversations with markets and customers will appear here',
          icon: Icons.chat_bubble_outline,
          backgroundColor: HiPopColors.accentDustyPlum.withValues(alpha: 0.1),
          iconColor: HiPopColors.accentDustyPlum,
          buttonColor: HiPopColors.accentDustyPlum,
          actionLabel: 'Start Conversation',
          actionIcon: Icons.message,
        );
        
      case EmptyStateType.notifications:
        return _EmptyStateConfig(
          title: 'No Notifications',
          message: 'You\'re all caught up! New notifications will appear here',
          icon: Icons.notifications_none,
          backgroundColor: HiPopColors.warningAmber.withValues(alpha: 0.1),
          iconColor: HiPopColors.warningAmber,
          buttonColor: HiPopColors.warningAmber,
          actionLabel: 'Notification Settings',
          actionIcon: Icons.settings,
        );
        
      case EmptyStateType.search:
        return _EmptyStateConfig(
          title: 'No Results Found',
          message: 'Try adjusting your search terms or filters',
          icon: Icons.search_off,
          backgroundColor: HiPopColors.lightTextTertiary.withValues(alpha: 0.1),
          iconColor: HiPopColors.lightTextTertiary,
          buttonColor: HiPopColors.primaryDeepSage,
          actionLabel: 'Clear Search',
          actionIcon: Icons.clear,
        );
        
      case EmptyStateType.loading:
        return _EmptyStateConfig(
          title: 'Loading...',
          message: 'Please wait while we fetch your data',
          icon: Icons.hourglass_empty,
          backgroundColor: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
          iconColor: HiPopColors.infoBlueGray,
          buttonColor: HiPopColors.infoBlueGray,
          actionLabel: '',
          actionIcon: Icons.refresh,
        );
        
      case EmptyStateType.generic:
        return _EmptyStateConfig(
          title: 'Nothing Here Yet',
          message: 'This area is empty, but it won\'t be for long!',
          icon: Icons.inbox_outlined,
          backgroundColor: HiPopColors.lightBorder.withValues(alpha: 0.3),
          iconColor: HiPopColors.lightTextSecondary,
          buttonColor: HiPopColors.primaryDeepSage,
          actionLabel: 'Go Back',
          actionIcon: Icons.arrow_back,
        );
    }
  }
}

/// Animated empty state icon
class _AnimatedEmptyIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _AnimatedEmptyIcon({
    required this.icon,
    required this.color,
  });

  @override
  State<_AnimatedEmptyIcon> createState() => _AnimatedEmptyIconState();
}

class _AnimatedEmptyIconState extends State<_AnimatedEmptyIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            widget.icon,
            size: 56,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// Configuration for empty state appearance
class _EmptyStateConfig {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color buttonColor;
  final String actionLabel;
  final IconData actionIcon;
  final String? defaultRoute;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;

  const _EmptyStateConfig({
    required this.title,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.buttonColor,
    required this.actionLabel,
    required this.actionIcon,
    this.defaultRoute,
    this.secondaryAction,
    this.secondaryActionLabel,
  });
}

/// Empty state types for different contexts
enum EmptyStateType {
  products,
  applications,
  sales,
  events,
  markets,
  analytics,
  favorites,
  messages,
  notifications,
  search,
  loading,
  generic,
}

/// Mini empty state for smaller containers
class VendorEmptyStateCompact extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onTap;

  const VendorEmptyStateCompact({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: HiPopColors.lightTextTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HiPopColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}