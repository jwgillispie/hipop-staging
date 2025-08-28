import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/hipop_colors.dart';
import './application_status_badge.dart';

/// Reusable Market Discovery Card Widget
/// 
/// For displaying markets in vendor discovery screen
/// Consistent with shopper view but vendor-focused
/// Shows application status if applicable
/// 
/// Usage:
/// ```dart
/// MarketDiscoveryCard(
///   marketId: 'market123',
///   marketName: 'Downtown Farmers Market',
///   location: 'Denver, CO',
///   date: DateTime.now(),
///   imageUrl: 'https://...',
///   applicationStatus: ApplicationStatus.pending,
///   onApply: () => _applyToMarket(),
/// )
/// ```
class MarketDiscoveryCard extends StatelessWidget {
  final String marketId;
  final String marketName;
  final String location;
  final DateTime? date;
  final String? imageUrl;
  final String? description;
  final ApplicationStatus? applicationStatus;
  final int? vendorCount;
  final int? availableSpots;
  final double? boothFee;
  final bool isRecurring;
  final bool isFeatured;
  final bool acceptingApplications;
  final VoidCallback? onTap;
  final VoidCallback? onApply;
  final VoidCallback? onViewDetails;
  final MarketCardVariant variant;
  final List<String>? categories;
  final String? organizerName;
  final double? rating;

  const MarketDiscoveryCard({
    super.key,
    required this.marketId,
    required this.marketName,
    required this.location,
    this.date,
    this.imageUrl,
    this.description,
    this.applicationStatus,
    this.vendorCount,
    this.availableSpots,
    this.boothFee,
    this.isRecurring = false,
    this.isFeatured = false,
    this.acceptingApplications = true,
    this.onTap,
    this.onApply,
    this.onViewDetails,
    this.variant = MarketCardVariant.standard,
    this.categories,
    this.organizerName,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case MarketCardVariant.compact:
        return _buildCompactCard(context);
      case MarketCardVariant.detailed:
        return _buildDetailedCard(context);
      case MarketCardVariant.list:
        return _buildListCard(context);
      case MarketCardVariant.standard:
        return _buildStandardCard(context);
    }
  }

  Widget _buildStandardCard(BuildContext context) {
    return Card(
      elevation: isFeatured ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isFeatured ? BorderSide(
          color: HiPopColors.premiumGold,
          width: 2,
        ) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap ?? () => context.go('/vendor/market/$marketId'),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              _buildMarketImage(context, height: 160),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          marketName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (applicationStatus != null)
                        ApplicationStatusBadge(
                          status: applicationStatus!,
                          size: BadgeSize.small,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: HiPopColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HiPopColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: HiPopColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildMetrics(context),
                  const SizedBox(height: 12),
                  _buildActions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap ?? () => context.go('/vendor/market/$marketId'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (imageUrl != null) ...[
                _buildMarketImage(context, width: 60, height: 60),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            marketName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (applicationStatus != null)
                          ApplicationStatusBadge(
                            status: applicationStatus!,
                            size: BadgeSize.small,
                            showIcon: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: HiPopColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: HiPopColors.lightTextSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(date!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HiPopColors.lightTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: HiPopColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedCard(BuildContext context) {
    return Card(
      elevation: isFeatured ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isFeatured ? BorderSide(
          color: HiPopColors.premiumGold,
          width: 2,
        ) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap ?? () => context.go('/vendor/market/$marketId'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Stack(
                children: [
                  _buildMarketImage(context, height: 200),
                  if (isFeatured)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: HiPopColors.premiumGold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (applicationStatus != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: ApplicationStatusBadge(
                        status: applicationStatus!,
                        size: BadgeSize.medium,
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marketName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (organizerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by $organizerName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HiPopColors.lightTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: HiPopColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HiPopColors.lightTextSecondary,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: HiPopColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date!),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ],
                      if (isRecurring) ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 12,
                                color: HiPopColors.infoBlueGray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Recurring',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: HiPopColors.infoBlueGray,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (rating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final filled = index < (rating ?? 0).floor();
                          return Icon(
                            filled ? Icons.star : Icons.star_outline,
                            size: 16,
                            color: HiPopColors.warningAmber,
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (categories != null && categories!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categories!.take(5).map((category) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: HiPopColors.accentMauve.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: HiPopColors.accentMauve.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              color: HiPopColors.accentMauveDark,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HiPopColors.surfacePalePink.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildMetrics(context, detailed: true),
                  ),
                  const SizedBox(height: 16),
                  _buildActions(context, expanded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => context.go('/vendor/market/$marketId'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: HiPopColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            if (imageUrl != null) ...[
              _buildMarketImage(context, width: 72, height: 72),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          marketName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (applicationStatus != null)
                        ApplicationStatusBadge(
                          status: applicationStatus!,
                          size: BadgeSize.small,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: HiPopColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HiPopColors.lightTextSecondary,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(date!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildMetrics(context, compact: true),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: HiPopColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketImage(BuildContext context, {
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height ?? 160,
      decoration: BoxDecoration(
        borderRadius: width != null 
          ? BorderRadius.circular(8)
          : const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: ClipRRect(
        borderRadius: width != null 
          ? BorderRadius.circular(8)
          : const BorderRadius.vertical(top: Radius.circular(12)),
        child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: HiPopColors.surfacePalePink,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HiPopColors.vendorAccent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => _buildImagePlaceholder(),
            )
          : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.store_mall_directory,
          size: 48,
          color: HiPopColors.vendorAccent.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, {bool detailed = false, bool compact = false}) {
    if (compact) {
      return Row(
        children: [
          if (availableSpots != null)
            Text(
              '$availableSpots spots',
              style: TextStyle(
                fontSize: 12,
                color: availableSpots! > 0 
                  ? HiPopColors.successGreen 
                  : HiPopColors.errorPlum,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (boothFee != null) ...[
            if (availableSpots != null) const SizedBox(width: 12),
            Text(
              '\$${boothFee!.toStringAsFixed(0)} fee',
              style: TextStyle(
                fontSize: 12,
                color: HiPopColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      );
    }

    final metrics = <Widget>[];

    if (availableSpots != null) {
      metrics.add(
        _MetricChip(
          icon: Icons.event_seat,
          label: '$availableSpots spots',
          color: availableSpots! > 0 
            ? HiPopColors.successGreen 
            : HiPopColors.errorPlum,
        ),
      );
    }

    if (vendorCount != null) {
      metrics.add(
        _MetricChip(
          icon: Icons.store,
          label: '$vendorCount vendors',
          color: HiPopColors.vendorAccent,
        ),
      );
    }

    if (boothFee != null) {
      metrics.add(
        _MetricChip(
          icon: Icons.attach_money,
          label: '${boothFee!.toStringAsFixed(0)} fee',
          color: HiPopColors.infoBlueGray,
        ),
      );
    }

    if (!acceptingApplications) {
      metrics.add(
        _MetricChip(
          icon: Icons.block,
          label: 'Closed',
          color: HiPopColors.errorPlum,
        ),
      );
    }

    if (detailed) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: metrics.take(3).toList(),
          ),
          if (metrics.length > 3) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: metrics.skip(3).toList(),
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics,
    );
  }

  Widget _buildActions(BuildContext context, {bool expanded = false}) {
    if (applicationStatus != null) {
      // Already applied
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onViewDetails != null)
            TextButton(
              onPressed: onViewDetails,
              child: const Text('View Details'),
            ),
        ],
      );
    }

    if (!acceptingApplications) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: HiPopColors.lightTextTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Applications Closed',
          style: TextStyle(
            fontSize: 12,
            color: HiPopColors.lightTextTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (availableSpots != null && availableSpots == 0)
          Text(
            'FULL',
            style: TextStyle(
              fontSize: 12,
              color: HiPopColors.errorPlum,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onViewDetails != null)
              TextButton(
                onPressed: onViewDetails,
                child: const Text('Details'),
              ),
            if (onApply != null) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: availableSpots == 0 ? null : onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.vendorAccent,
                  foregroundColor: Colors.white,
                  padding: expanded 
                    ? const EdgeInsets.symmetric(horizontal: 24, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
                child: const Text('Apply Now'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0 && date.day == now.day) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      return '${difference.inDays} days';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Small metric chip widget
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Market card display variants
enum MarketCardVariant {
  /// Standard card with key info
  standard,
  
  /// Compact card with minimal info
  compact,
  
  /// Detailed card with full information
  detailed,
  
  /// List item style
  list,
}