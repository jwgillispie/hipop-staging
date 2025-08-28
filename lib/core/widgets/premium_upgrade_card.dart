import 'package:flutter/material.dart';
import '../theme/hipop_colors.dart';

/// Premium Upgrade Card Widget
/// Consistent premium upgrade prompts across the app
/// Uses HiPop color palette for visual consistency
class PremiumUpgradeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? customMessage;
  final VoidCallback onUpgrade;
  final IconData icon;
  final List<String>? features;
  final bool showDismiss;
  final VoidCallback? onDismiss;

  const PremiumUpgradeCard({
    super.key,
    this.title = 'Upgrade to Premium',
    this.subtitle = 'Unlock advanced features',
    this.customMessage,
    required this.onUpgrade,
    this.icon = Icons.workspace_premium,
    this.features,
    this.showDismiss = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.surfaceSoftPink.withValues(alpha: isDarkMode ? 0.2 : 1.0),
            HiPopColors.surfacePalePink.withValues(alpha: isDarkMode ? 0.15 : 1.0),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.premiumGold.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.premiumGold.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Premium pattern overlay
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.auto_awesome,
              size: 100,
              color: HiPopColors.premiumGold.withValues(alpha: 0.1),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title above icon
                Column(
                  children: [
                    // Title with Premium badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? HiPopColors.darkTextPrimary
                                : HiPopColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HiPopColors.premiumGold,
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
                        if (showDismiss)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDarkMode
                                  ? HiPopColors.darkTextTertiary
                                  : HiPopColors.lightTextTertiary,
                            ),
                            onPressed: onDismiss,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HiPopColors.premiumGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: HiPopColors.premiumGold,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Subtitle
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDarkMode
                            ? HiPopColors.darkTextSecondary
                            : HiPopColors.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (customMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    customMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                if (features != null && features!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...features!.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: HiPopColors.primaryDeepSage,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? HiPopColors.darkTextPrimary
                                    : HiPopColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.primaryDeepSage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rocket_launch, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Upgrade Now',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal Premium Badge Widget
class PremiumBadge extends StatelessWidget {
  final double size;
  final bool showText;

  const PremiumBadge({
    super.key,
    this.size = 20,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 8 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: HiPopColors.premiumGold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: size * 0.8,
          ),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}