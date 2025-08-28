import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Premium Status Indicator Widget
/// 
/// Displays premium status consistently across all vendor screens
/// Includes upgrade CTA if not premium
/// 
/// Usage:
/// ```dart
/// PremiumStatusIndicator(
///   hasPremiumAccess: true,
///   isCheckingPremium: false,
///   variant: PremiumIndicatorVariant.compact,
/// )
/// ```
class PremiumStatusIndicator extends StatelessWidget {
  final bool hasPremiumAccess;
  final bool isCheckingPremium;
  final PremiumIndicatorVariant variant;
  final VoidCallback? onUpgradeTap;
  final String? customMessage;
  final bool showIcon;

  const PremiumStatusIndicator({
    super.key,
    required this.hasPremiumAccess,
    required this.isCheckingPremium,
    this.variant = PremiumIndicatorVariant.standard,
    this.onUpgradeTap,
    this.customMessage,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case PremiumIndicatorVariant.compact:
        return _buildCompactIndicator(context);
      case PremiumIndicatorVariant.card:
        return _buildCardIndicator(context);
      case PremiumIndicatorVariant.banner:
        return _buildBannerIndicator(context);
      case PremiumIndicatorVariant.inline:
        return _buildInlineIndicator(context);
      case PremiumIndicatorVariant.standard:
        return _buildStandardIndicator(context);
    }
  }

  Widget _buildStandardIndicator(BuildContext context) {
    if (isCheckingPremium) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HiPopColors.infoBlueGrayLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: HiPopColors.infoBlueGray,
            width: 1.5,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Checking Premium Access...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: HiPopColors.infoBlueGray,
              ),
            ),
          ],
        ),
      );
    }

    final message = customMessage ?? 
      (hasPremiumAccess ? 'Premium Access: ACTIVE' : 'Premium Access: NOT ACTIVE');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasPremiumAccess 
          ? HiPopColors.successGreenLight.withValues(alpha: 0.1) 
          : HiPopColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasPremiumAccess 
            ? HiPopColors.successGreen 
            : HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(
              hasPremiumAccess ? Icons.diamond : Icons.info_outline,
              color: hasPremiumAccess 
                ? HiPopColors.successGreen 
                : HiPopColors.lightTextSecondary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasPremiumAccess 
                  ? HiPopColors.successGreenDark 
                  : HiPopColors.lightTextSecondary,
              ),
            ),
          ),
          if (!hasPremiumAccess && onUpgradeTap != null)
            TextButton(
              onPressed: onUpgradeTap,
              child: const Text(
                'Upgrade',
                style: TextStyle(color: HiPopColors.premiumGold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactIndicator(BuildContext context) {
    if (isCheckingPremium) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.premiumGold),
        ),
      );
    }

    if (!hasPremiumAccess) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HiPopColors.premiumGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.premiumGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond,
            size: 14,
            color: HiPopColors.premiumGold,
          ),
          const SizedBox(width: 4),
          const Text(
            'PRO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: HiPopColors.premiumGold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardIndicator(BuildContext context) {
    if (isCheckingPremium) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.premiumGold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Checking premium status...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: hasPremiumAccess ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasPremiumAccess 
            ? HiPopColors.premiumGold.withValues(alpha: 0.5)
            : Colors.transparent,
          width: 2,
        ),
      ),
      child: Container(
        decoration: hasPremiumAccess ? BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HiPopColors.premiumGold.withValues(alpha: 0.05),
              HiPopColors.premiumGold.withValues(alpha: 0.1),
            ],
          ),
        ) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPremiumAccess ? Icons.diamond : Icons.lock_outline,
                size: 48,
                color: hasPremiumAccess 
                  ? HiPopColors.premiumGold 
                  : HiPopColors.lightTextSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                hasPremiumAccess ? 'Premium Active' : 'Upgrade to Premium',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hasPremiumAccess 
                    ? HiPopColors.premiumGold 
                    : HiPopColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasPremiumAccess 
                  ? 'Enjoy all premium features'
                  : 'Unlock advanced analytics and tools',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HiPopColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (!hasPremiumAccess) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onUpgradeTap ?? () => context.go('/premium'),
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Upgrade Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.premiumGold,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerIndicator(BuildContext context) {
    if (isCheckingPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HiPopColors.infoBlueGray.withValues(alpha: 0.1),
              HiPopColors.infoBlueGray.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Checking premium status...'),
          ],
        ),
      );
    }

    if (hasPremiumAccess) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HiPopColors.premiumGold.withValues(alpha: 0.15),
            HiPopColors.premiumGold.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.diamond_outlined,
            color: HiPopColors.premiumGold,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Upgrade to Premium for advanced features',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onUpgradeTap ?? () => context.go('/premium'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              backgroundColor: HiPopColors.premiumGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineIndicator(BuildContext context) {
    if (isCheckingPremium) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.premiumGold),
            ),
          ),
          SizedBox(width: 4),
          Text(
            'Checking...',
            style: TextStyle(
              fontSize: 11,
              color: HiPopColors.lightTextSecondary,
            ),
          ),
        ],
      );
    }

    if (!hasPremiumAccess) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.diamond,
          size: 16,
          color: HiPopColors.premiumGold,
        ),
        const SizedBox(width: 4),
        const Text(
          'Premium',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HiPopColors.premiumGold,
          ),
        ),
      ],
    );
  }
}

/// Variants for different display styles
enum PremiumIndicatorVariant {
  /// Standard box indicator with message
  standard,
  
  /// Compact badge style
  compact,
  
  /// Card with icon and description
  card,
  
  /// Full-width banner
  banner,
  
  /// Simple inline text with icon
  inline,
}