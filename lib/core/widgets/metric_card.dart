import 'package:flutter/material.dart';
import '../theme/hipop_colors.dart';

/// Metric Card Widget for Analytics Displays
/// Provides consistent styling for metric cards across the app
/// Supports different metric types with appropriate color coding
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final MetricType type;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showTrend;
  final double? trendValue;
  final bool isLoading;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.type = MetricType.neutral,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showTrend = false,
    this.trendValue,
    this.isLoading = false,
  });

  Color _getColorForType(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    switch (type) {
      case MetricType.success:
      case MetricType.active:
        return HiPopColors.primaryDeepSage;
      case MetricType.warning:
      case MetricType.happening:
        return HiPopColors.accentMauve;
      case MetricType.error:
        return HiPopColors.errorPlum;
      case MetricType.info:
        return HiPopColors.infoBlueGray;
      case MetricType.premium:
        return HiPopColors.premiumGold;
      case MetricType.neutral:
      default:
        return isDarkMode 
            ? HiPopColors.darkTextSecondary 
            : HiPopColors.lightTextSecondary;
    }
  }

  Color _getBackgroundColorForType(BuildContext context) {
    final color = _getColorForType(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Use Soft Pink background for light mode, dark surface for dark mode
    if (isDarkMode) {
      return HiPopColors.darkSurfaceVariant;
    } else {
      // Return a very light tinted version of the metric color mixed with Soft Pink
      return Color.alphaBlend(
        color.withValues(alpha: 0.08),
        HiPopColors.surfaceSoftPink,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final metricColor = _getColorForType(context);
    final backgroundColor = _getBackgroundColorForType(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: metricColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: metricColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? _buildLoadingState(theme)
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon and optional trailing widget
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: metricColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 24,
                            color: metricColor,
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDarkMode
                            ? HiPopColors.darkTextSecondary
                            : HiPopColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Value with optional trend
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: metricColor,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showTrend && trendValue != null)
                          _buildTrendIndicator(trendValue!, theme),
                      ],
                    ),
                    // Optional subtitle
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDarkMode
                              ? HiPopColors.darkTextTertiary
                              : HiPopColors.lightTextTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(double trend, ThemeData theme) {
    final isPositive = trend > 0;
    final trendColor = isPositive 
        ? HiPopColors.successGreen 
        : HiPopColors.errorPlum;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${trend.abs().toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: trendColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enum for different metric types
enum MetricType {
  success,
  warning,
  error,
  info,
  neutral,
  premium,
  active,
  happening,
}

/// Grid layout for multiple metric cards
class MetricCardGrid extends StatelessWidget {
  final List<MetricCard> cards;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;

  const MetricCardGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
        children: cards,
      ),
    );
  }
}

/// Horizontal scrollable list of metric cards
class MetricCardList extends StatelessWidget {
  final List<MetricCard> cards;
  final double cardWidth;
  final double cardHeight;
  final EdgeInsets padding;

  const MetricCardList({
    super.key,
    required this.cards,
    this.cardWidth = 160,
    this.cardHeight = 140,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: EdgeInsets.only(
              right: index < cards.length - 1 ? 12 : 0,
            ),
            child: cards[index],
          );
        },
      ),
    );
  }
}