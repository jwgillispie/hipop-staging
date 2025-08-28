import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Vendor Info Card Widget
/// 
/// Displays vendor information consistently across all screens
/// Includes avatar, name, rating, location, and action buttons
/// 
/// Usage:
/// ```dart
/// VendorInfoCard(
///   vendorName: 'Artisan Crafts',
///   vendorId: 'vendor123',
///   avatarUrl: 'https://...',
///   rating: 4.5,
///   location: 'Denver, CO',
///   isFollowing: false,
///   onFollowTap: () {},
/// )
/// ```
class VendorInfoCard extends StatelessWidget {
  final String vendorName;
  final String vendorId;
  final String? avatarUrl;
  final double? rating;
  final int? reviewCount;
  final String? location;
  final String? description;
  final bool isVerified;
  final bool isPremium;
  final bool? isFollowing;
  final VoidCallback? onFollowTap;
  final VoidCallback? onContactTap;
  final VoidCallback? onCardTap;
  final VendorCardVariant variant;
  final List<String>? tags;
  final Widget? customAction;
  final bool showActions;

  const VendorInfoCard({
    super.key,
    required this.vendorName,
    required this.vendorId,
    this.avatarUrl,
    this.rating,
    this.reviewCount,
    this.location,
    this.description,
    this.isVerified = false,
    this.isPremium = false,
    this.isFollowing,
    this.onFollowTap,
    this.onContactTap,
    this.onCardTap,
    this.variant = VendorCardVariant.standard,
    this.tags,
    this.customAction,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case VendorCardVariant.compact:
        return _buildCompactCard(context);
      case VendorCardVariant.detailed:
        return _buildDetailedCard(context);
      case VendorCardVariant.list:
        return _buildListCard(context);
      case VendorCardVariant.standard:
        return _buildStandardCard(context);
    }
  }

  Widget _buildStandardCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onCardTap ?? () => context.go('/vendor/detail/$vendorId'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatar(context, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vendorName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: HiPopColors.infoBlueGray,
                              ),
                            ],
                            if (isPremium) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.diamond,
                                size: 16,
                                color: HiPopColors.premiumGold,
                              ),
                            ],
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 4),
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
                                  location!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: HiPopColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (rating != null) ...[
                          const SizedBox(height: 4),
                          _buildRating(context),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 12),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tags != null && tags!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildTags(context),
              ],
              if (showActions) ...[
                const SizedBox(height: 12),
                _buildActions(context),
              ],
            ],
          ),
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
        onTap: onCardTap ?? () => context.go('/vendor/detail/$vendorId'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildAvatar(context, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendorName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPremium)
                          Icon(
                            Icons.diamond,
                            size: 14,
                            color: HiPopColors.premiumGold,
                          ),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        location!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HiPopColors.lightTextSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (showActions && customAction != null)
                customAction!
              else if (showActions && onFollowTap != null)
                _buildFollowButton(context, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onCardTap ?? () => context.go('/vendor/detail/$vendorId'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HiPopColors.vendorAccent.withValues(alpha: 0.1),
                    HiPopColors.vendorAccent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  _buildAvatar(context, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vendorName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified)
                              Tooltip(
                                message: 'Verified Vendor',
                                child: Icon(
                                  Icons.verified,
                                  size: 20,
                                  color: HiPopColors.infoBlueGray,
                                ),
                              ),
                            if (isPremium) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Premium Vendor',
                                child: Icon(
                                  Icons.diamond,
                                  size: 20,
                                  color: HiPopColors.premiumGold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: HiPopColors.lightTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                location!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: HiPopColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (rating != null) ...[
                          const SizedBox(height: 6),
                          _buildRating(context, showReviewCount: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (tags != null && tags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildTags(context),
              ),
            if (showActions)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildActions(context, expanded: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    return InkWell(
      onTap: onCardTap ?? () => context.go('/vendor/detail/$vendorId'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            _buildAvatar(context, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vendorName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremium)
                        Icon(
                          Icons.diamond,
                          size: 16,
                          color: HiPopColors.premiumGold,
                        ),
                    ],
                  ),
                  if (location != null || rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (location != null) ...[
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: HiPopColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            location!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: HiPopColors.lightTextSecondary,
                            ),
                          ),
                        ],
                        if (location != null && rating != null)
                          const SizedBox(width: 12),
                        if (rating != null)
                          _buildRating(context, compact: true),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (showActions && onFollowTap != null)
              _buildFollowButton(context, compact: true),
            Icon(
              Icons.chevron_right,
              color: HiPopColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isPremium ? HiPopColors.premiumGold : HiPopColors.lightBorder,
          width: isPremium ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
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
                errorWidget: (context, url, error) => _buildAvatarPlaceholder(size),
              )
            : _buildAvatarPlaceholder(size),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(double size) {
    return Container(
      color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.store,
          size: size * 0.5,
          color: HiPopColors.vendorAccent,
        ),
      ),
    );
  }

  Widget _buildRating(BuildContext context, {bool showReviewCount = false, bool compact = false}) {
    final starSize = compact ? 12.0 : 14.0;
    final textStyle = compact
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.bodySmall;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final filled = index < (rating ?? 0).floor();
          final half = index == (rating ?? 0).floor() && (rating ?? 0) % 1 >= 0.5;
          return Icon(
            half ? Icons.star_half : (filled ? Icons.star : Icons.star_outline),
            size: starSize,
            color: HiPopColors.warningAmber,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating?.toStringAsFixed(1) ?? '0.0',
          style: textStyle?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (showReviewCount && reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: textStyle?.copyWith(
              color: HiPopColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags!.take(5).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: HiPopColors.accentMauve.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HiPopColors.accentMauve.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            tag,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HiPopColors.accentMauveDark,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(BuildContext context, {bool expanded = false}) {
    final buttons = <Widget>[];

    if (onFollowTap != null) {
      buttons.add(_buildFollowButton(context));
    }

    if (onContactTap != null) {
      buttons.add(
        expanded
            ? Expanded(
                child: OutlinedButton.icon(
                  onPressed: onContactTap,
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HiPopColors.primaryDeepSage,
                    side: BorderSide(color: HiPopColors.primaryDeepSage),
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onContactTap,
                icon: const Icon(Icons.message, size: 16),
                label: const Text('Contact'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HiPopColors.primaryDeepSage,
                  side: BorderSide(color: HiPopColors.primaryDeepSage),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
      );
    }

    if (customAction != null) {
      buttons.add(expanded ? Expanded(child: customAction!) : customAction!);
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ...buttons.expand((button) => [
          button,
          if (buttons.last != button) const SizedBox(width: 8),
        ]),
      ],
    );
  }

  Widget _buildFollowButton(BuildContext context, {bool compact = false}) {
    final isFollowingValue = isFollowing ?? false;

    if (compact) {
      return IconButton(
        onPressed: onFollowTap,
        icon: Icon(
          isFollowingValue ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: isFollowingValue 
            ? HiPopColors.errorPlum 
            : HiPopColors.lightTextSecondary,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    }

    return ElevatedButton.icon(
      onPressed: onFollowTap,
      icon: Icon(
        isFollowingValue ? Icons.check : Icons.add,
        size: 16,
      ),
      label: Text(isFollowingValue ? 'Following' : 'Follow'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowingValue 
          ? HiPopColors.lightBorder 
          : HiPopColors.vendorAccent,
        foregroundColor: isFollowingValue 
          ? HiPopColors.lightTextPrimary 
          : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}

/// Vendor card display variants
enum VendorCardVariant {
  /// Standard card with avatar, name, and basic info
  standard,
  
  /// Compact card with minimal info
  compact,
  
  /// Detailed card with full information
  detailed,
  
  /// List item style
  list,
}