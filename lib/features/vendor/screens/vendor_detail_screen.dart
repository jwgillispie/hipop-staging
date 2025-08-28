import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hipop/features/shared/services/url_launcher_service.dart';
import 'package:hipop/features/shared/services/real_time_analytics_service.dart';
import 'package:hipop/features/shared/widgets/common/favorite_button.dart';
import 'package:hipop/features/vendor/models/managed_vendor.dart';
import 'package:hipop/features/vendor/services/managed_vendor_service.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/widgets/hipop_card.dart';
import 'package:hipop/features/vendor/widgets/vendor_photo_carousel.dart';


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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        // Track vendor profile view
        await RealTimeAnalyticsService.trackVendorInteraction(
          VendorActions.profileView,
          widget.vendorId,
          FirebaseAuth.instance.currentUser?.uid,
          metadata: {
            'vendorName': vendor.businessName,
            'categories': vendor.categories.map((c) => c.displayName).toList(),
            'source': 'vendor_detail_screen',
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HiPopColors.vendorAccent,
                  HiPopColors.accentMauve,
                ],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(
          color: HiPopColors.vendorAccent,
        )),
      );
    }

    if (_vendor == null) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HiPopColors.vendorAccent,
                  HiPopColors.accentMauve,
                ],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: _buildErrorView(),
      );
    }

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          // Add photo carousel at the top if vendor has photos
          if (_vendor!.imageUrls.isNotEmpty || _vendor!.imageUrl != null)
            SliverToBoxAdapter(
              child: VendorPhotoCarousel(
                photoUrls: [
                  if (_vendor!.imageUrl != null) _vendor!.imageUrl!,
                  ..._vendor!.imageUrls,
                ],
                height: 300,
                borderRadius: 0,
              ),
            ),
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
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildSliverAppBar() {
    // Simplified app bar when photo carousel is shown separately
    final hasImages = _vendor!.imageUrls.isNotEmpty || _vendor!.imageUrl != null;
    
    return SliverAppBar(
      expandedHeight: hasImages ? 120 : 250,
      pinned: true,
      backgroundColor: HiPopColors.vendorAccent,
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
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HiPopColors.vendorAccent,
                      HiPopColors.accentMauve,
                    ],
                  ),
                ),
              )
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HiPopColors.darkSurface.withValues(alpha: 0.5),
            HiPopColors.darkBackground,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row - Business Name and Featured Badge
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
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    if (_vendor!.slogan != null && _vendor!.slogan!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _vendor!.slogan!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: HiPopColors.darkTextSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_vendor!.isFeatured)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: HiPopColors.premiumGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: HiPopColors.premiumGold.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text(
                        'Featured',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Categories Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _vendor!.categories.take(5).map((category) {
                final color = _getCategoryColor(category);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Info Row - Improved Layout
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildEnhancedInfoChip(
                  Icons.location_on,
                  _vendor!.city ?? 'Location',
                  HiPopColors.primaryDeepSage,
                ),
                if (_vendor!.priceRange != null && _vendor!.priceRange!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildEnhancedInfoChip(
                    Icons.attach_money,
                    _vendor!.priceRange!,
                    HiPopColors.successGreen,
                  ),
                ],
                if (_vendor!.isOrganic) ...[
                  const SizedBox(width: 8),
                  _buildEnhancedInfoChip(
                    Icons.eco,
                    'Organic',
                    HiPopColors.primaryDeepSage,
                  ),
                ],
                if (_vendor!.acceptsOrders) ...[
                  const SizedBox(width: 8),
                  _buildEnhancedInfoChip(
                    Icons.shopping_cart,
                    'Accepts Orders',
                    HiPopColors.infoBlueGray,
                  ),
                ],
                if (_vendor!.canDeliver) ...[
                  const SizedBox(width: 8),
                  _buildEnhancedInfoChip(
                    Icons.local_shipping,
                    'Delivery',
                    HiPopColors.accentMauve,
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Description Preview
          Text(
            _vendor!.description,
            style: const TextStyle(
              fontSize: 16,
              color: HiPopColors.darkTextSecondary,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        border: Border(
          bottom: BorderSide(
            color: HiPopColors.darkBorder,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: HiPopColors.vendorAccent,
        unselectedLabelColor: HiPopColors.darkTextTertiary,
        indicatorColor: HiPopColors.vendorAccent,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'About'),
          Tab(text: 'Products'),
          Tab(text: 'Contact'),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _vendor!.description,
            style: const TextStyle(fontSize: 16, height: 1.5, color: HiPopColors.darkTextSecondary),
          ),
          const SizedBox(height: 24),
        ],
        
        // Vendor Story
        if (_vendor!.story != null && _vendor!.story!.isNotEmpty) ...[
          const Text(
            'Our Story',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _vendor!.story!,
            style: const TextStyle(fontSize: 16, height: 1.5, color: HiPopColors.darkTextSecondary),
          ),
          const SizedBox(height: 24),
        ],
        
        // Specialties
        if (_vendor!.specialties.isNotEmpty) ...[
          const Text(
            'Our Specialties',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _vendor!.specialties.map((specialty) {
              return Chip(
                label: Text(specialty),
                backgroundColor: HiPopColors.accentMauve.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: HiPopColors.accentMauve),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
        ),
        const SizedBox(height: 12),
        ...qualityIndicators,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQualityIndicator(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
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
          Icon(icon, color: HiPopColors.darkTextTertiary, size: 20),
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
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: HiPopColors.darkTextSecondary,
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
          ),
          const SizedBox(height: 12),
          ...(_vendor!.products.map((product) => _buildProductCard(product))),
          const SizedBox(height: 24),
        ],
        
        // Price Range
        if (_vendor!.priceRange != null && _vendor!.priceRange!.isNotEmpty) ...[
          HiPopCard(
            borderRadius: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.attach_money,
                    color: HiPopColors.successGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Range',
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _vendor!.priceRange!,
                      style: TextStyle(
                        fontSize: 16,
                        color: HiPopColors.darkTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductCard(String product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_basket,
              color: HiPopColors.primaryDeepSage,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              product,
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_vendor!.acceptsOrders)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: HiPopColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_shopping_cart,
                    size: 14,
                    color: HiPopColors.successGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Order',
                    style: TextStyle(
                      fontSize: 11,
                      color: HiPopColors.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
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
    return HiPopCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 12,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HiPopColors.accentMauve.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: HiPopColors.accentMauve,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: onTap != null ? Colors.blue[700] : HiPopColors.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: HiPopColors.darkTextTertiary,
            ),
        ],
      ),
    );
  }


  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HiPopColors.darkSurface.withValues(alpha: 0.95),
            HiPopColors.darkSurface,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 8,
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
                  backgroundColor: HiPopColors.primaryDeepSage,
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
                  backgroundColor: HiPopColors.accentMauve,
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
          Icon(
            Icons.store_outlined,
            size: 64,
            color: HiPopColors.darkTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'Vendor not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The vendor you\'re looking for doesn\'t exist.',
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.vendorAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
          await UrlLauncherService.launchMaps(query, context: context);
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

  Future<void> _shareVendor() async {
    if (_vendor == null) return;
    
    try {
      final content = _buildVendorShareContent(_vendor!);
      
      final result = await Share.share(
        content,
        subject: 'Check out this vendor on HiPop!',
      );

      // Show success message if sharing was successful
      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Vendor shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to share vendor: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _buildVendorShareContent(ManagedVendor vendor) {
    final buffer = StringBuffer();
    
    buffer.writeln('Vendor Spotlight!');
    buffer.writeln();
    buffer.writeln(vendor.businessName);
    if (vendor.description.isNotEmpty) {
      buffer.writeln(vendor.description);
    }
    buffer.writeln();
    
    // Add products if available
    if (vendor.products.isNotEmpty) {
      buffer.writeln('Products: ${vendor.products.take(3).join(', ')}');
      if (vendor.products.length > 3) {
        buffer.writeln('...and ${vendor.products.length - 3} more!');
      }
      buffer.writeln();
    }
    
    // Add contact info if available
    if (vendor.phoneNumber != null && vendor.phoneNumber!.isNotEmpty) {
      buffer.writeln('Phone: ${vendor.phoneNumber}');
    }
    if (vendor.instagramHandle != null && vendor.instagramHandle!.isNotEmpty) {
      buffer.writeln('Instagram: @${vendor.instagramHandle}');
    }
    buffer.writeln();
    
    buffer.writeln('Discovered on HiPop - Discover local pop-ups and markets');
    buffer.writeln('Download: https://hipop-markets.web.app');
    buffer.writeln();
    buffer.writeln('#LocalVendor #SmallBusiness #SupportLocal #HiPop');
    
    return buffer.toString();
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