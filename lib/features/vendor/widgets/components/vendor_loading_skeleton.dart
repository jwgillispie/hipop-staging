import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Vendor Loading Skeleton Widget
/// 
/// Provides consistent skeleton loaders for vendor-related content
/// Replaces all CircularProgressIndicators with proper loading states
/// 
/// Usage:
/// ```dart
/// VendorLoadingSkeleton(
///   variant: SkeletonVariant.card,
///   count: 3,
/// )
/// ```
class VendorLoadingSkeleton extends StatelessWidget {
  final SkeletonVariant variant;
  final int count;
  final double? height;
  final EdgeInsets padding;
  final bool showShimmer;

  const VendorLoadingSkeleton({
    super.key,
    this.variant = SkeletonVariant.card,
    this.count = 1,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode 
      ? HiPopColors.darkSurfaceVariant 
      : Colors.grey[300]!;
    final highlightColor = isDarkMode 
      ? HiPopColors.darkSurfaceVariant.withValues(alpha: 0.6)
      : Colors.grey[100]!;

    Widget skeleton = _buildSkeletonContent(context);

    if (showShimmer) {
      skeleton = Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: skeleton,
      );
    }

    return Padding(
      padding: padding,
      child: skeleton,
    );
  }

  Widget _buildSkeletonContent(BuildContext context) {
    switch (variant) {
      case SkeletonVariant.card:
        return _buildCardSkeleton(context);
      case SkeletonVariant.list:
        return _buildListSkeleton(context);
      case SkeletonVariant.grid:
        return _buildGridSkeleton(context);
      case SkeletonVariant.metric:
        return _buildMetricSkeleton(context);
      case SkeletonVariant.product:
        return _buildProductSkeleton(context);
      case SkeletonVariant.market:
        return _buildMarketSkeleton(context);
      case SkeletonVariant.post:
        return _buildPostSkeleton(context);
      case SkeletonVariant.dashboard:
        return _buildDashboardSkeleton(context);
      case SkeletonVariant.analytics:
        return _buildAnalyticsSkeleton(context);
      case SkeletonVariant.application:
        return _buildApplicationSkeleton(context);
    }
  }

  Widget _buildCardSkeleton(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => Container(
        margin: EdgeInsets.only(bottom: index < count - 1 ? 16 : 0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCircle(56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBox(height: 16, width: double.infinity * 0.6),
                          const SizedBox(height: 8),
                          _buildBox(height: 12, width: double.infinity * 0.4),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBox(height: 12, width: double.infinity),
                const SizedBox(height: 8),
                _buildBox(height: 12, width: double.infinity * 0.8),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildListSkeleton(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
            _buildCircle(48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBox(height: 14, width: double.infinity * 0.5),
                  const SizedBox(height: 6),
                  _buildBox(height: 12, width: double.infinity * 0.3),
                ],
              ),
            ),
            _buildBox(height: 32, width: 80),
          ],
        ),
      )),
    );
  }

  Widget _buildGridSkeleton(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.75,
      children: List.generate(count, (index) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBox(height: 14, width: double.infinity),
                  const SizedBox(height: 6),
                  _buildBox(height: 12, width: double.infinity * 0.6),
                  const SizedBox(height: 8),
                  _buildBox(height: 20, width: double.infinity * 0.4),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildMetricSkeleton(BuildContext context) {
    return Row(
      children: List.generate(count.clamp(1, 3), (index) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: index < count - 1 ? 12 : 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBox(height: 40, width: 40),
              const SizedBox(height: 12),
              _buildBox(height: 12, width: double.infinity * 0.6),
              const SizedBox(height: 8),
              _buildBox(height: 24, width: double.infinity * 0.8),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildProductSkeleton(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => Container(
        margin: EdgeInsets.only(bottom: index < count - 1 ? 12 : 0),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBox(height: 16, width: double.infinity * 0.7),
                      const SizedBox(height: 8),
                      _buildBox(height: 12, width: double.infinity * 0.5),
                      const SizedBox(height: 8),
                      _buildBox(height: 20, width: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildMarketSkeleton(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => Container(
        margin: EdgeInsets.only(bottom: index < count - 1 ? 16 : 0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBox(height: 20, width: double.infinity * 0.7),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildBox(height: 12, width: 100),
                        const SizedBox(width: 16),
                        _buildBox(height: 12, width: 80),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBox(height: 12, width: double.infinity),
                    const SizedBox(height: 8),
                    _buildBox(height: 12, width: double.infinity * 0.8),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildPostSkeleton(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => Container(
        margin: EdgeInsets.only(bottom: index < count - 1 ? 16 : 0),
        child: Card(
          elevation: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                color: Colors.grey[300],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCircle(40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBox(height: 14, width: double.infinity * 0.5),
                              const SizedBox(height: 4),
                              _buildBox(height: 12, width: double.infinity * 0.3),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildBox(height: 16, width: double.infinity * 0.8),
                    const SizedBox(height: 8),
                    _buildBox(height: 12, width: double.infinity),
                    const SizedBox(height: 8),
                    _buildBox(height: 12, width: double.infinity * 0.9),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildDashboardSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildCircle(56),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBox(height: 16, width: 150),
                    const SizedBox(height: 8),
                    _buildBox(height: 12, width: 100),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Metrics skeleton
        Row(
          children: List.generate(3, (index) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: HiPopColors.lightBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBox(height: 12, width: double.infinity * 0.6),
                  const SizedBox(height: 8),
                  _buildBox(height: 24, width: double.infinity * 0.8),
                ],
              ),
            ),
          )),
        ),
        const SizedBox(height: 24),
        
        // Menu items skeleton
        ...List.generate(5, (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: HiPopColors.lightBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildBox(height: 48, width: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBox(height: 16, width: double.infinity * 0.4),
                    const SizedBox(height: 4),
                    _buildBox(height: 12, width: double.infinity * 0.6),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAnalyticsSkeleton(BuildContext context) {
    return Column(
      children: [
        // Date range selector skeleton
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: HiPopColors.lightBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBox(height: 16, width: 100),
              _buildBox(height: 16, width: 100),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Metrics grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: List.generate(4, (index) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: HiPopColors.lightBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBox(height: 12, width: double.infinity * 0.6),
                const SizedBox(height: 8),
                _buildBox(height: 24, width: double.infinity * 0.8),
                const SizedBox(height: 4),
                _buildBox(height: 10, width: double.infinity * 0.4),
              ],
            ),
          )),
        ),
        const SizedBox(height: 24),
        
        // Chart skeleton
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: HiPopColors.lightBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBox(height: 16, width: 150),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationSkeleton(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => Container(
        margin: EdgeInsets.only(bottom: index < count - 1 ? 12 : 0),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBox(height: 20, width: 150),
                    _buildBox(height: 24, width: 80),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    _buildBox(height: 12, width: 100),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    _buildBox(height: 12, width: 80),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBox(height: 12, width: double.infinity),
                const SizedBox(height: 8),
                _buildBox(height: 12, width: double.infinity * 0.7),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildBox(height: 32, width: 100),
                    const SizedBox(width: 8),
                    _buildBox(height: 32, width: 100),
                  ],
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildBox({required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton variant types
enum SkeletonVariant {
  /// Standard card skeleton
  card,
  
  /// List item skeleton
  list,
  
  /// Grid item skeleton
  grid,
  
  /// Metric card skeleton
  metric,
  
  /// Product card skeleton
  product,
  
  /// Market card skeleton
  market,
  
  /// Post/popup skeleton
  post,
  
  /// Dashboard skeleton
  dashboard,
  
  /// Analytics screen skeleton
  analytics,
  
  /// Application card skeleton
  application,
}