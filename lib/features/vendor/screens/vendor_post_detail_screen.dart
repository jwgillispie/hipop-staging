import 'package:flutter/material.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/favorite_button.dart';
import 'package:hipop/features/shared/services/url_launcher_service.dart';
import 'package:flutter/services.dart';
import 'package:hipop/features/vendor/services/vendor_product_service.dart';
import 'package:hipop/features/vendor/models/vendor_product.dart';

class VendorPostDetailScreen extends StatefulWidget {
  final VendorPost vendorPost;

  const VendorPostDetailScreen({
    super.key,
    required this.vendorPost,
  });

  @override
  State<VendorPostDetailScreen> createState() => _VendorPostDetailScreenState();
}

class _VendorPostDetailScreenState extends State<VendorPostDetailScreen> {
  List<VendorProduct> _vendorProducts = [];
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadVendorProducts();
  }

  Future<void> _loadVendorProducts() async {
    if (widget.vendorPost.productListIds.isEmpty) return;
    
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final productIds = <String>{};
      
      // Get all product IDs from the associated product lists
      for (final listId in widget.vendorPost.productListIds) {
        final productList = await VendorProductService.getProductList(listId);
        if (productList != null) {
          productIds.addAll(productList.productIds);
        }
      }
      
      // Fetch products concurrently with timeout
      final productFutures = productIds.map((productId) => 
        VendorProductService.getProduct(productId).timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        ).catchError((_) => null));
      
      final productResults = await Future.wait(productFutures);
      final products = productResults.whereType<VendorProduct>().toList();

      if (mounted) {
        setState(() {
          _vendorProducts = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor products: $e');
      if (mounted) {
        setState(() {
          _vendorProducts = [];
          _isLoadingProducts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendorPost.vendorName),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6F9686), // Soft Sage
                Color(0xFF946C7E), // Mauve
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          FavoriteButton.post(
            postId: widget.vendorPost.id,
            vendorId: widget.vendorPost.vendorId,
            size: 24,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange,
                          radius: 30,
                          child: Text(
                            widget.vendorPost.vendorName.isNotEmpty 
                                ? widget.vendorPost.vendorName[0].toUpperCase() 
                                : 'V',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.vendorPost.vendorName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Independent Pop-up',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.vendorPost.isHappening 
                                ? Colors.green 
                                : widget.vendorPost.isUpcoming 
                                    ? Colors.orange 
                                    : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.vendorPost.isHappening 
                                ? 'LIVE NOW' 
                                : widget.vendorPost.isUpcoming 
                                    ? 'UPCOMING' 
                                    : 'PAST EVENT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Description
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.vendorPost.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Products Section
            if (_vendorProducts.isNotEmpty || _isLoadingProducts) ...[
              Text(
                'Products Available',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildProductsCard(),
              const SizedBox(height: 20),
            ],
            
            // Event Details
            Text(
              'Event Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.access_time,
                      'Date & Time',
                      widget.vendorPost.formattedDateTime,
                      widget.vendorPost.formattedTimeRange,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      widget.vendorPost.location,
                      null,
                    ),
                    if (widget.vendorPost.instagramHandle != null) ...[
                      const Divider(),
                      _buildDetailRow(
                        Icons.alternate_email,
                        'Instagram',
                        '@${widget.vendorPost.instagramHandle!}',
                        null,
                        onTap: () => _launchInstagram(context, widget.vendorPost.instagramHandle!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            if (widget.vendorPost.isHappening || widget.vendorPost.isUpcoming) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchLocation(context, widget.vendorPost),
                  icon: const Icon(Icons.directions),
                  label: Text(widget.vendorPost.isHappening ? 'View Location' : 'Save Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.vendorPost.instagramHandle != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _launchInstagram(context, widget.vendorPost.instagramHandle!),
                  icon: const Icon(Icons.alternate_email),
                  label: const Text('Instagram Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String value,
    String? subtitle, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchLocation(BuildContext context, VendorPost vendorPost) async {
    try {
      // Use coordinates if available for more precise location
      if (widget.vendorPost.latitude != null && widget.vendorPost.longitude != null) {
        final url = 'https://maps.google.com/?q=${widget.vendorPost.latitude},${widget.vendorPost.longitude}';
        await UrlLauncherService.launchWebsite(url);
      } else {
        // Fall back to address search
        await UrlLauncherService.launchMaps(widget.vendorPost.location);
      }
    } catch (e) {
      if (context.mounted) {
        // Show fallback dialog if launching fails
        _showLocationFallback(context, widget.vendorPost.location);
      }
    }
  }
  
  void _showLocationFallback(BuildContext context, String location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location),
            const SizedBox(height: 16),
            const Text(
              'Could not open maps app. Address copied to clipboard.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Clipboard.setData(ClipboardData(text: location));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied to clipboard')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy Address'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchInstagram(BuildContext context, String handle) async {
    try {
      await UrlLauncherService.launchInstagram(handle);
    } catch (e) {
      if (context.mounted) {
        // Show fallback dialog if launching fails
        _showInstagramFallback(context, handle);
      }
    }
  }
  
  void _showInstagramFallback(BuildContext context, String handle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Follow on Instagram'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Instagram: @$handle'),
            const SizedBox(height: 16),
            const Text(
              'Could not open Instagram app. Username copied to clipboard.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Clipboard.setData(ClipboardData(text: '@$handle'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Instagram handle copied to clipboard')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy Handle'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductsCard() {
    if (_isLoadingProducts) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading products...'),
            ],
          ),
        ),
      );
    }
    
    if (_vendorProducts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 12),
              Text('No products listed for this popup'),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_vendorProducts.length} ${_vendorProducts.length == 1 ? 'Product' : 'Products'}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ..._vendorProducts.take(5).map((product) => 
              _buildProductRow(product)
            ),
            if (_vendorProducts.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                'and ${_vendorProducts.length - 5} more...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildProductRow(VendorProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: product.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shopping_basket,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                )
              : const Icon(
                  Icons.shopping_basket,
                  color: Colors.orange,
                  size: 20,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (product.basePrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '\$${product.basePrice!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}