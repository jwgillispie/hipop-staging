import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/managed_vendor.dart';
import '../models/recipe.dart';
import '../services/managed_vendor_service.dart';
import '../services/recipe_service.dart';
import '../services/url_launcher_service.dart';
import '../widgets/common/favorite_button.dart';

class VendorDetailScreen extends StatefulWidget {
  final String vendorId;

  const VendorDetailScreen({
    super.key,
    required this.vendorId,
  });

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ManagedVendor? _vendor;
  List<Recipe> _vendorRecipes = [];
  bool _isLoading = true;
  bool _isLoadingRecipes = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadVendor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    try {
      final vendor = await ManagedVendorService.getVendor(widget.vendorId);
      setState(() {
        _vendor = vendor;
        _isLoading = false;
      });
      if (vendor != null) {
        _loadVendorRecipes();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadVendorRecipes() {
    if (_vendor != null) {
      RecipeService.getRecipesByVendor(_vendor!.marketId, widget.vendorId).listen(
        (recipes) {
          if (mounted) {
            setState(() {
              _vendorRecipes = recipes;
              _isLoadingRecipes = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoadingRecipes = false;
            });
          }
        },
      );
    } else {
      setState(() {
        _isLoadingRecipes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_vendor == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: _buildErrorView(),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildVendorHeader(),
                _buildTabBar(),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(),
                _buildProductsTab(),
                _buildContactTab(),
                _buildRecipesTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildSliverAppBar() {
    final hasImages = _vendor!.imageUrls.isNotEmpty || _vendor!.imageUrl != null;
    
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _vendor!.businessName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black45,
              ),
            ],
          ),
        ),
        background: hasImages
            ? _buildImageCarousel()
            : _buildImagePlaceholder(),
      ),
      actions: [
        FavoriteButton(
          itemId: widget.vendorId,
          type: FavoriteType.vendor,
          size: 24,
          favoriteColor: Colors.white,
          unfavoriteColor: Colors.white,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareVendor,
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final allImages = [
      if (_vendor!.imageUrl != null) _vendor!.imageUrl!,
      ..._vendor!.imageUrls,
    ];

    if (allImages.isEmpty) {
      return _buildImagePlaceholder();
    }

    return PageView.builder(
      itemCount: allImages.length,
      itemBuilder: (context, index) {
        return Image.network(
          allImages[index],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    final category = _vendor!.categories.isNotEmpty 
        ? _vendor!.categories.first 
        : VendorCategory.other;
    final color = _getCategoryColor(category);
    
    return Container(
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 80,
              color: color,
            ),
            const SizedBox(height: 16),
            if (_vendor!.logoUrl != null)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  image: DecorationImage(
                    image: NetworkImage(_vendor!.logoUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business Name and Categories
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vendor!.businessName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_vendor!.slogan != null && _vendor!.slogan!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _vendor!.slogan!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_vendor!.isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[800]),
                      const SizedBox(width: 4),
                      Text(
                        'Featured',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Categories
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _vendor!.categories.take(4).map((category) {
              return Chip(
                label: Text(
                  category.displayName,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getCategoryColor(category).withValues(alpha: 0.1),
                labelStyle: TextStyle(color: _getCategoryColor(category)),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Info Row
          Row(
            children: [
              _buildInfoChip(
                Icons.location_on,
                _vendor!.city ?? 'Location',
                Colors.blue,
              ),
              const SizedBox(width: 12),
              if (_vendor!.priceRange != null && _vendor!.priceRange!.isNotEmpty)
                _buildInfoChip(
                  Icons.attach_money,
                  _vendor!.priceRange!,
                  Colors.green,
                ),
              const SizedBox(width: 12),
              if (_vendor!.isOrganic)
                _buildInfoChip(
                  Icons.eco,
                  'Organic',
                  Colors.green,
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description Preview
          Text(
            _vendor!.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[50],
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.orange,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.orange,
        tabs: const [
          Tab(text: 'About'),
          Tab(text: 'Products'),
          Tab(text: 'Contact'),
          Tab(text: 'Recipes'),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Full Description
        if (_vendor!.description.isNotEmpty) ...[
          const Text(
            'About Us',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _vendor!.description,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
        
        // Vendor Story
        if (_vendor!.story != null && _vendor!.story!.isNotEmpty) ...[
          const Text(
            'Our Story',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _vendor!.story!,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
        
        // Specialties
        if (_vendor!.specialties.isNotEmpty) ...[
          const Text(
            'Our Specialties',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _vendor!.specialties.map((specialty) {
              return Chip(
                label: Text(specialty),
                backgroundColor: Colors.purple[100],
                labelStyle: TextStyle(color: Colors.purple[800]),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Certifications & Quality
        _buildQualitySection(),
        
        // Operating Information
        _buildOperatingSection(),
      ],
    );
  }

  Widget _buildQualitySection() {
    final qualityIndicators = <Widget>[];
    
    if (_vendor!.isOrganic) {
      qualityIndicators.add(_buildQualityIndicator(
        Icons.eco,
        'Certified Organic',
        Colors.green,
      ));
    }
    
    if (_vendor!.isLocallySourced) {
      qualityIndicators.add(_buildQualityIndicator(
        Icons.location_on,
        'Locally Sourced',
        Colors.blue,
      ));
    }
    
    if (_vendor!.certifications != null && _vendor!.certifications!.isNotEmpty) {
      final certsList = _vendor!.certifications!.split(',').map((cert) => cert.trim()).toList();
      for (final cert in certsList) {
        qualityIndicators.add(_buildQualityIndicator(
          Icons.verified,
          cert,
          Colors.orange,
        ));
      }
    }
    
    if (qualityIndicators.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quality & Certifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...qualityIndicators,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQualityIndicator(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Market Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        if (_vendor!.operatingDays.isNotEmpty) ...[
          _buildInfoRow(
            Icons.schedule,
            'Operating Days',
            _vendor!.operatingDays.join(', '),
          ),
        ],
        
        if (_vendor!.boothPreferences != null && _vendor!.boothPreferences!.isNotEmpty) ...[
          _buildInfoRow(
            Icons.store,
            'Booth Preferences',
            _vendor!.boothPreferences!,
          ),
        ],
        
        if (_vendor!.canDeliver) ...[
          _buildInfoRow(
            Icons.local_shipping,
            'Delivery Available',
            _vendor!.deliveryNotes != null && _vendor!.deliveryNotes!.isNotEmpty ? _vendor!.deliveryNotes! : 'Yes',
          ),
        ],
        
        if (_vendor!.acceptsOrders) ...[
          _buildInfoRow(
            Icons.shopping_cart,
            'Accepts Orders',
            'Advance orders accepted',
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // All Categories
        const Text(
          'Categories',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _vendor!.categories.map((category) {
            return Chip(
              label: Text(category.displayName),
              backgroundColor: _getCategoryColor(category).withValues(alpha: 0.1),
              labelStyle: TextStyle(color: _getCategoryColor(category)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        
        // Products
        if (_vendor!.products.isNotEmpty) ...[
          const Text(
            'Products & Services',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...(_vendor!.products.map((product) => _buildProductCard(product))),
          const SizedBox(height: 24),
        ],
        
        // Price Range
        if (_vendor!.priceRange != null && _vendor!.priceRange!.isNotEmpty) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: const Text('Price Range'),
              subtitle: Text(_vendor!.priceRange!),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductCard(String product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.shopping_basket, color: Colors.orange),
        title: Text(product),
        trailing: _vendor!.acceptsOrders 
            ? const Icon(Icons.add_shopping_cart, color: Colors.grey)
            : null,
      ),
    );
  }

  Widget _buildContactTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact Information
        const Text(
          'Contact Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (_vendor!.contactName.isNotEmpty) ...[
          _buildContactCard(
            Icons.person,
            'Contact Person',
            _vendor!.contactName,
            null,
          ),
        ],
        
        if (_vendor!.phoneNumber != null && _vendor!.phoneNumber!.isNotEmpty) ...[
          _buildContactCard(
            Icons.phone,
            'Phone',
            _vendor!.phoneNumber!,
            () => _launchUrl('tel:${_vendor!.phoneNumber!}'),
          ),
        ],
        
        if (_vendor!.email != null && _vendor!.email!.isNotEmpty) ...[
          _buildContactCard(
            Icons.email,
            'Email',
            _vendor!.email!,
            () => _launchUrl('mailto:${_vendor!.email!}'),
          ),
        ],
        
        if (_vendor!.website != null && _vendor!.website!.isNotEmpty) ...[
          _buildContactCard(
            Icons.language,
            'Website',
            _vendor!.website!,
            () => _launchUrl(_vendor!.website!),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Social Media
        const Text(
          'Social Media',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (_vendor!.instagramHandle != null && _vendor!.instagramHandle!.isNotEmpty) ...[
          _buildContactCard(
            Icons.camera_alt,
            'Instagram',
            '@${_vendor!.instagramHandle!}',
            () => _launchUrl('https://instagram.com/${_vendor!.instagramHandle!}'),
          ),
        ],
        
        if (_vendor!.facebookHandle != null && _vendor!.facebookHandle!.isNotEmpty) ...[
          _buildContactCard(
            Icons.facebook,
            'Facebook',
            _vendor!.facebookHandle!,
            () => _launchUrl('https://facebook.com/${_vendor!.facebookHandle!}'),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Location
        const Text(
          'Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        _buildContactCard(
          Icons.location_on,
          'Address',
          _vendor!.locationDisplay,
          () => _launchUrl('https://maps.google.com/?q=${Uri.encodeComponent(_vendor!.locationDisplay)}'),
        ),
      ],
    );
  }

  Widget _buildContactCard(IconData icon, String label, String value, VoidCallback? onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap != null ? const Icon(Icons.launch, color: Colors.grey) : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecipesTab() {
    if (_isLoadingRecipes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vendorRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Recipes Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This vendor hasn\'t been featured in any recipes yet.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _vendorRecipes.length,
      itemBuilder: (context, index) {
        return _buildRecipeCard(_vendorRecipes[index]);
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.pushNamed('recipeDetail', pathParameters: {'recipeId': recipe.id});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: recipe.imageUrl != null
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.restaurant_menu,
                            size: 48,
                            color: Colors.grey[400],
                          );
                        },
                      )
                    : Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: Colors.grey[400],
                      ),
              ),
            ),
            // Recipe Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          recipe.formattedTotalTime,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Icon(Icons.favorite, size: 12, color: Colors.red[300]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.likes}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_vendor!.phoneNumber != null && _vendor!.phoneNumber!.isNotEmpty)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl('tel:${_vendor!.phoneNumber!}'),
                icon: const Icon(Icons.phone),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (_vendor!.phoneNumber != null && _vendor!.phoneNumber!.isNotEmpty && 
              _vendor!.instagramHandle != null && _vendor!.instagramHandle!.isNotEmpty)
            const SizedBox(width: 12),
          if (_vendor!.instagramHandle != null && _vendor!.instagramHandle!.isNotEmpty)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl('https://instagram.com/${_vendor!.instagramHandle!}'),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Instagram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Vendor not found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('The vendor you\'re looking for doesn\'t exist.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (url.startsWith('tel:')) {
        await UrlLauncherService.launchPhone(url.substring(4));
      } else if (url.startsWith('mailto:')) {
        await UrlLauncherService.launchEmail(url.substring(7));
      } else if (url.contains('instagram.com/')) {
        final handle = url.split('instagram.com/').last;
        await UrlLauncherService.launchInstagram(handle);
      } else if (url.contains('facebook.com/')) {
        await UrlLauncherService.launchWebsite(url);
      } else if (url.startsWith('https://maps.google.com/')) {
        // Extract address from Google Maps URL
        final uri = Uri.parse(url);
        final query = uri.queryParameters['q'];
        if (query != null) {
          await UrlLauncherService.launchMaps(query);
        } else {
          await UrlLauncherService.launchWebsite(url);
        }
      } else {
        await UrlLauncherService.launchWebsite(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareVendor() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vendor "${_vendor!.businessName}" shared!')),
    );
  }

  IconData _getCategoryIcon(VendorCategory category) {
    switch (category) {
      case VendorCategory.produce:
        return Icons.eco;
      case VendorCategory.bakery:
        return Icons.cake;
      case VendorCategory.dairy:
        return Icons.local_drink;
      case VendorCategory.meat:
        return Icons.restaurant;
      case VendorCategory.prepared_foods:
        return Icons.fastfood;
      case VendorCategory.beverages:
        return Icons.local_cafe;
      case VendorCategory.flowers:
        return Icons.local_florist;
      case VendorCategory.crafts:
        return Icons.palette;
      case VendorCategory.skincare:
        return Icons.face;
      case VendorCategory.clothing:
        return Icons.checkroom;
      case VendorCategory.jewelry:
        return Icons.diamond;
      case VendorCategory.art:
        return Icons.brush;
      case VendorCategory.plants:
        return Icons.eco;
      case VendorCategory.honey:
        return Icons.hexagon;
      case VendorCategory.preserves:
        return Icons.local_dining;
      case VendorCategory.spices:
        return Icons.grass;
      case VendorCategory.other:
        return Icons.store;
    }
  }

  Color _getCategoryColor(VendorCategory category) {
    switch (category) {
      case VendorCategory.produce:
        return Colors.green;
      case VendorCategory.bakery:
        return Colors.brown;
      case VendorCategory.dairy:
        return Colors.blue;
      case VendorCategory.meat:
        return Colors.red;
      case VendorCategory.prepared_foods:
        return Colors.deepOrange;
      case VendorCategory.beverages:
        return Colors.orange;
      case VendorCategory.flowers:
        return Colors.pinkAccent;
      case VendorCategory.crafts:
        return Colors.deepPurple;
      case VendorCategory.skincare:
        return Colors.purple;
      case VendorCategory.clothing:
        return Colors.indigo;
      case VendorCategory.jewelry:
        return Colors.teal;
      case VendorCategory.art:
        return Colors.blueGrey;
      case VendorCategory.plants:
        return Colors.green;
      case VendorCategory.honey:
        return Colors.amber;
      case VendorCategory.preserves:
        return Colors.orange;
      case VendorCategory.spices:
        return Colors.lightGreen;
      case VendorCategory.other:
        return Colors.grey;
    }
  }
}