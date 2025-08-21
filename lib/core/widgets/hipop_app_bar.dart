import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/hipop_colors.dart';

/// HiPop Standard App Bar with Gradient Support
/// Provides consistent app bar styling across all screens
/// Supports both solid and gradient backgrounds based on user role
class HiPopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final bool useGradient;
  final bool showPremiumBadge;
  final VoidCallback? onTitleTap;
  final String? userRole; // 'vendor', 'organizer', 'shopper'
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  const HiPopAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.useGradient = true,
    this.showPremiumBadge = false,
    this.onTitleTap,
    this.userRole,
    this.backgroundColor,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  LinearGradient _getGradientForRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'vendor':
        // Soft Sage to Mauve gradient for vendors
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.secondarySoftSage,
            HiPopColors.accentMauve,
          ],
        );
      case 'organizer':
        // Deep Sage gradient for organizers
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.primaryDeepSage,
            HiPopColors.primaryDeepSageLight,
          ],
        );
      case 'shopper':
        // Soft gradient for shoppers
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.secondarySoftSage,
            HiPopColors.secondarySoftSageLight,
          ],
        );
      default:
        // Default navigation gradient
        return HiPopColors.navigationGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Determine text color based on background
    final textColor = isDarkMode || useGradient
        ? Colors.white
        : theme.colorScheme.onSurface;

    return AppBar(
      title: GestureDetector(
        onTap: onTitleTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showPremiumBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: HiPopColors.premiumGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? 
          (useGradient ? Colors.transparent : theme.colorScheme.surface),
      foregroundColor: textColor,
      iconTheme: IconThemeData(color: textColor),
      actionsIconTheme: IconThemeData(color: textColor),
      systemOverlayStyle: isDarkMode || useGradient
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      flexibleSpace: useGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: _getGradientForRole(userRole),
              ),
            )
          : null,
      bottom: bottom,
    );
  }
}

/// Sliver version of HiPopAppBar for use in CustomScrollView
class HiPopSliverAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final bool useGradient;
  final bool showPremiumBadge;
  final VoidCallback? onTitleTap;
  final String? userRole;
  final Color? backgroundColor;
  final bool floating;
  final bool pinned;
  final double? expandedHeight;
  final Widget? flexibleSpace;

  const HiPopSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.useGradient = true,
    this.showPremiumBadge = false,
    this.onTitleTap,
    this.userRole,
    this.backgroundColor,
    this.floating = false,
    this.pinned = true,
    this.expandedHeight,
    this.flexibleSpace,
  });

  LinearGradient _getGradientForRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'vendor':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.secondarySoftSage,
            HiPopColors.accentMauve,
          ],
        );
      case 'organizer':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.primaryDeepSage,
            HiPopColors.primaryDeepSageLight,
          ],
        );
      case 'shopper':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.secondarySoftSage,
            HiPopColors.secondarySoftSageLight,
          ],
        );
      default:
        return HiPopColors.navigationGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode || useGradient
        ? Colors.white
        : theme.colorScheme.onSurface;

    return SliverAppBar(
      title: GestureDetector(
        onTap: onTitleTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showPremiumBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: HiPopColors.premiumGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? 
          (useGradient ? Colors.transparent : theme.colorScheme.surface),
      foregroundColor: textColor,
      iconTheme: IconThemeData(color: textColor),
      actionsIconTheme: IconThemeData(color: textColor),
      systemOverlayStyle: isDarkMode || useGradient
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      flexibleSpace: flexibleSpace ??
          (useGradient
              ? Container(
                  decoration: BoxDecoration(
                    gradient: _getGradientForRole(userRole),
                  ),
                )
              : null),
      floating: floating,
      pinned: pinned,
      expandedHeight: expandedHeight,
    );
  }
}