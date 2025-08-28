import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Product Card Widget
/// 
/// Displays product information consistently across vendor screens
/// Used in product management and market item listings
/// 
/// Usage:
/// ```dart
/// ProductCard(
///   name: 'Handmade Soap',
///   price: 12.99,
///   imageUrl: 'https://...',
///   onEdit: () => _editProduct(),
///   onDelete: () => _deleteProduct(),
/// )
/// ```
class ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? description;
  final String? category;
  final int? stockQuantity;
  final bool isActive;
  final bool isFeatured;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onToggleFeatured;
  final ProductCardVariant variant;
  final List<String>? tags;
  final Widget? customAction;

  const ProductCard({
    super.key,
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    this.category,
    this.stockQuantity,
    this.isActive = true,
    this.isFeatured = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onToggleFeatured,
    this.variant = ProductCardVariant.standard,
    this.tags,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case ProductCardVariant.compact:
        return _buildCompactCard(context);
      case ProductCardVariant.grid:
        return _buildGridCard(context);
      case ProductCardVariant.list:
        return _buildListCard(context);
      case ProductCardVariant.standard:
        return _buildStandardCard(context);
    }
  }

  Widget _buildStandardCard(BuildContext context) {
    return Card(
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isActive ? 1.0 : 0.6,
          child: Container(
            decoration: isFeatured ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.premiumGold,
                width: 2,
              ),
            ) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildProductImage(context, size: 80),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFeatured)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: HiPopColors.premiumGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: HiPopColors.premiumGold,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Featured',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: HiPopColors.premiumGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.successGreen,
                              ),
                            ),
                            if (category != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: HiPopColors.accentMauve.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  category!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: HiPopColors.accentMauveDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: HiPopColors.lightTextSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (stockQuantity != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 14,
                                color: _getStockColor(stockQuantity!),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Stock: $stockQuantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStockColor(stockQuantity!),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (customAction != null)
                    customAction!
                  else
                    _buildActions(context),
                ],
              ),
            ),
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _buildProductImage(context, size: 48),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: HiPopColors.lightTextTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      color: HiPopColors.lightTextTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context) {
    return Card(
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isActive ? 1.0 : 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildProductImage(
                      context, 
                      size: double.infinity,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    if (isFeatured)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: HiPopColors.premiumGold,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (!isActive)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.successGreen,
                          ),
                        ),
                        if (stockQuantity != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStockColor(stockQuantity!).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$stockQuantity',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStockColor(stockQuantity!),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: HiPopColors.accentMauve.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category!,
                          style: TextStyle(
                            fontSize: 11,
                            color: HiPopColors.accentMauveDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            _buildProductImage(context, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFeatured)
                        Icon(
                          Icons.star,
                          size: 16,
                          color: HiPopColors.premiumGold,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.successGreen,
                        ),
                      ),
                      if (stockQuantity != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Stock: $stockQuantity',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStockColor(stockQuantity!),
                          ),
                        ),
                      ],
                      if (!isActive) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.lightTextTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: HiPopColors.lightTextSecondary,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                    case 'toggle_active':
                      onToggleActive?.call();
                      break;
                    case 'toggle_featured':
                      onToggleFeatured?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  if (onToggleActive != null)
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                  if (onToggleFeatured != null)
                    PopupMenuItem(
                      value: 'toggle_featured',
                      child: Row(
                        children: [
                          Icon(
                            isFeatured ? Icons.star_outline : Icons.star,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(isFeatured ? 'Remove Featured' : 'Make Featured'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context, {
    required dynamic size,
    BorderRadius? borderRadius,
  }) {
    final isFullWidth = size == double.infinity;
    
    Widget imageWidget;
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: HiPopColors.darkSurfaceVariant,
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
      );
    } else {
      imageWidget = _buildImagePlaceholder();
    }
    
    if (isFullWidth) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: imageWidget,
      );
    } else {
      return Container(
        width: size.toDouble(),
        height: size.toDouble(),
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: imageWidget,
        ),
      );
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: HiPopColors.vendorAccent.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: HiPopColors.lightTextSecondary,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
          case 'toggle_active':
            onToggleActive?.call();
            break;
          case 'toggle_featured':
            onToggleFeatured?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
        if (onToggleActive != null)
          PopupMenuItem(
            value: 'toggle_active',
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(isActive ? 'Deactivate' : 'Activate'),
              ],
            ),
          ),
        if (onToggleFeatured != null)
          PopupMenuItem(
            value: 'toggle_featured',
            child: Row(
              children: [
                Icon(
                  isFeatured ? Icons.star_outline : Icons.star,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(isFeatured ? 'Remove Featured' : 'Make Featured'),
              ],
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );
  }

  Color _getStockColor(int quantity) {
    if (quantity == 0) {
      return HiPopColors.errorPlum;
    } else if (quantity < 10) {
      return HiPopColors.warningAmber;
    } else {
      return HiPopColors.successGreen;
    }
  }
}

/// Product card display variants
enum ProductCardVariant {
  /// Standard card with all details
  standard,
  
  /// Compact card with minimal info
  compact,
  
  /// Grid layout card
  grid,
  
  /// List item style
  list,
}