import 'package:flutter/material.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Application Status Badge Widget
/// 
/// Displays application status (pending, approved, rejected, etc.) 
/// with consistent styling across all vendor screens
/// 
/// Usage:
/// ```dart
/// ApplicationStatusBadge(
///   status: ApplicationStatus.approved,
///   size: BadgeSize.medium,
/// )
/// ```
class ApplicationStatusBadge extends StatelessWidget {
  final ApplicationStatus status;
  final BadgeSize size;
  final bool showIcon;
  final bool showAnimation;
  final VoidCallback? onTap;

  const ApplicationStatusBadge({
    super.key,
    required this.status,
    this.size = BadgeSize.medium,
    this.showIcon = true,
    this.showAnimation = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    final dimensions = _getSizeDimensions(size);

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              config.icon,
              size: dimensions.iconSize,
              color: config.textColor,
            ),
            SizedBox(width: dimensions.spacing),
          ],
          Text(
            config.label,
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w600,
              color: config.textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (showAnimation && status == ApplicationStatus.pending) {
      badge = _AnimatedPendingBadge(
        child: badge,
      );
    }

    if (onTap != null) {
      badge = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        child: badge,
      );
    }

    return badge;
  }

  _StatusConfig _getStatusConfig(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return _StatusConfig(
          label: 'PENDING',
          icon: Icons.access_time,
          backgroundColor: HiPopColors.warningAmber.withValues(alpha: 0.1),
          borderColor: HiPopColors.warningAmber.withValues(alpha: 0.3),
          textColor: HiPopColors.warningAmberDark,
        );
      case ApplicationStatus.approved:
        return _StatusConfig(
          label: 'APPROVED',
          icon: Icons.check_circle,
          backgroundColor: HiPopColors.successGreen.withValues(alpha: 0.1),
          borderColor: HiPopColors.successGreen.withValues(alpha: 0.3),
          textColor: HiPopColors.successGreenDark,
        );
      case ApplicationStatus.rejected:
        return _StatusConfig(
          label: 'REJECTED',
          icon: Icons.cancel,
          backgroundColor: HiPopColors.errorPlum.withValues(alpha: 0.1),
          borderColor: HiPopColors.errorPlum.withValues(alpha: 0.3),
          textColor: HiPopColors.errorPlumDark,
        );
      case ApplicationStatus.waitlisted:
        return _StatusConfig(
          label: 'WAITLISTED',
          icon: Icons.hourglass_empty,
          backgroundColor: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
          borderColor: HiPopColors.infoBlueGray.withValues(alpha: 0.3),
          textColor: HiPopColors.infoBlueGrayDark,
        );
      case ApplicationStatus.expired:
        return _StatusConfig(
          label: 'EXPIRED',
          icon: Icons.schedule,
          backgroundColor: HiPopColors.lightTextTertiary.withValues(alpha: 0.1),
          borderColor: HiPopColors.lightTextTertiary.withValues(alpha: 0.3),
          textColor: HiPopColors.lightTextTertiary,
        );
      case ApplicationStatus.inReview:
        return _StatusConfig(
          label: 'IN REVIEW',
          icon: Icons.rate_review,
          backgroundColor: HiPopColors.accentMauve.withValues(alpha: 0.1),
          borderColor: HiPopColors.accentMauve.withValues(alpha: 0.3),
          textColor: HiPopColors.accentMauveDark,
        );
      case ApplicationStatus.cancelled:
        return _StatusConfig(
          label: 'CANCELLED',
          icon: Icons.block,
          backgroundColor: HiPopColors.lightTextTertiary.withValues(alpha: 0.1),
          borderColor: HiPopColors.lightTextTertiary.withValues(alpha: 0.3),
          textColor: HiPopColors.lightTextTertiary,
        );
    }
  }

  _SizeDimensions _getSizeDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return _SizeDimensions(
          fontSize: 10,
          iconSize: 12,
          horizontalPadding: 6,
          verticalPadding: 3,
          borderRadius: 6,
          spacing: 3,
        );
      case BadgeSize.medium:
        return _SizeDimensions(
          fontSize: 12,
          iconSize: 14,
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 8,
          spacing: 4,
        );
      case BadgeSize.large:
        return _SizeDimensions(
          fontSize: 14,
          iconSize: 18,
          horizontalPadding: 12,
          verticalPadding: 6,
          borderRadius: 10,
          spacing: 6,
        );
    }
  }
}

/// Animated wrapper for pending badges
class _AnimatedPendingBadge extends StatefulWidget {
  final Widget child;

  const _AnimatedPendingBadge({required this.child});

  @override
  State<_AnimatedPendingBadge> createState() => _AnimatedPendingBadgeState();
}

class _AnimatedPendingBadgeState extends State<_AnimatedPendingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 1.0,
      end: 0.3,
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
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Configuration for status appearance
class _StatusConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

/// Size dimensions for badge
class _SizeDimensions {
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double spacing;

  const _SizeDimensions({
    required this.fontSize,
    required this.iconSize,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.borderRadius,
    required this.spacing,
  });
}

/// Application status enum
enum ApplicationStatus {
  pending,
  approved,
  rejected,
  waitlisted,
  expired,
  inReview,
  cancelled,
}

/// Badge size options
enum BadgeSize {
  small,
  medium,
  large,
}

/// Helper extension to convert string to ApplicationStatus
extension ApplicationStatusExtension on String {
  ApplicationStatus? toApplicationStatus() {
    switch (toLowerCase()) {
      case 'pending':
        return ApplicationStatus.pending;
      case 'approved':
        return ApplicationStatus.approved;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'waitlisted':
        return ApplicationStatus.waitlisted;
      case 'expired':
        return ApplicationStatus.expired;
      case 'in_review':
      case 'inreview':
        return ApplicationStatus.inReview;
      case 'cancelled':
      case 'canceled':
        return ApplicationStatus.cancelled;
      default:
        return null;
    }
  }
}

/// Status group helper for batch operations
class ApplicationStatusGroup {
  static const activeStatuses = [
    ApplicationStatus.approved,
    ApplicationStatus.pending,
    ApplicationStatus.inReview,
  ];

  static const inactiveStatuses = [
    ApplicationStatus.rejected,
    ApplicationStatus.expired,
    ApplicationStatus.cancelled,
  ];

  static const needsActionStatuses = [
    ApplicationStatus.pending,
    ApplicationStatus.inReview,
    ApplicationStatus.waitlisted,
  ];

  static bool isActive(ApplicationStatus status) {
    return activeStatuses.contains(status);
  }

  static bool isInactive(ApplicationStatus status) {
    return inactiveStatuses.contains(status);
  }

  static bool needsAction(ApplicationStatus status) {
    return needsActionStatuses.contains(status);
  }
}