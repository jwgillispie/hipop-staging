import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../../market/models/market.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../shared/widgets/common/error_widget.dart';
import '../../premium/services/subscription_service.dart';
import '../../shared/services/real_time_analytics_service.dart';

/// Optimized Vendor Market Discovery Screen
/// Shows ONLY markets actively looking for vendors (isLookingForVendors = true)
/// Implements performance optimizations with proper Firestore queries and debouncing
class VendorMarketDiscoveryOptimized extends StatefulWidget {
  const VendorMarketDiscoveryOptimized({super.key});

  @override
  State<VendorMarketDiscoveryOptimized> createState() => _VendorMarketDiscoveryOptimizedState();
}

class _VendorMarketDiscoveryOptimizedState extends State<VendorMarketDiscoveryOptimized> {
  final _scrollController = ScrollController();
  
  // State management
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Market> _markets = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  
  // Pagination
  static const int _pageSize = 10;
  
  @override
  void initState() {
    super.initState();
    _loadMarkets();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreMarkets();
    }
  }
  
  /// Load initial markets with optimized Firestore query
  Future<void> _loadMarkets() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please log in to access Market Discovery');
      }
      
      // Query ONLY markets actively looking for vendors
      Query query = FirebaseFirestore.instance
          .collection('markets')
          .where('isLookingForVendors', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .orderBy('applicationDeadline', descending: false)
          .limit(_pageSize);
      
      final snapshot = await query.get();
      
      final markets = snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => 
              market.eventDate.isAfter(DateTime.now()) && // Future events only
              !market.isApplicationDeadlinePassed) // Open applications only
          .toList();
      
      setState(() {
        _markets = markets;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      // Debug print for Firestore index errors
      print('\n🔴 ERROR in _loadMarkets:');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      
      // Extract and print Firestore index creation link if present
      final errorString = e.toString();
      if (errorString.contains('index')) {
        print('\n⚠️ FIRESTORE INDEX REQUIRED!');
        print('Full error with index link:');
        print(errorString);
        
        // Try to extract the URL
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
          print('\n🔗 INDEX CREATION LINK:');
          print(match.group(0));
        }
      }
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  /// Load more markets with pagination
  Future<void> _loadMoreMarkets() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('markets')
          .where('isLookingForVendors', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .orderBy('applicationDeadline', descending: false)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);
      
      final snapshot = await query.get();
      
      final newMarkets = snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => 
              market.eventDate.isAfter(DateTime.now()) &&
              !market.isApplicationDeadlinePassed)
          .toList();
      
      setState(() {
        _markets.addAll(newMarkets);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      // Debug print for Firestore index errors
      print('\n🔴 ERROR in _loadMoreMarkets:');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      
      // Extract and print Firestore index creation link if present
      final errorString = e.toString();
      if (errorString.contains('index')) {
        print('\n⚠️ FIRESTORE INDEX REQUIRED!');
        print('Full error with index link:');
        print(errorString);
        
        // Try to extract the URL
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
          print('\n🔗 INDEX CREATION LINK:');
          print(match.group(0));
        }
      }
      
      setState(() => _isLoadingMore = false);
    }
  }
  
  /// Apply to a market
  Future<void> _applyToMarket(Market market) async {
    if (market.applicationUrl == null || market.applicationUrl!.isEmpty) {
      _showApplicationInfoDialog(market);
      return;
    }
    
    // Track application
    _trackApplication(market);
    
    // Launch application URL
    final uri = Uri.parse(market.applicationUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open application link'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  /// Show application info dialog when no URL is available
  void _showApplicationInfoDialog(Market market) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.store,
                color: HiPopColors.primaryDeepSage,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Apply to ${market.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact the market organizer directly to apply for a vendor spot.',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, market.fullAddress),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, market.eventDisplayInfo),
            if (market.vendorRequirements != null) ...[
              const SizedBox(height: 16),
              Text(
                'Requirements:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                market.vendorRequirements!,
                style: TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: HiPopColors.darkTextTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Save to interested markets
              _saveMarketInterest(market);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: HiPopColors.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save Market'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: HiPopColors.darkTextTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
  
  /// Track application for analytics
  Future<void> _trackApplication(Market market) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Log application event
      await FirebaseFirestore.instance
          .collection('vendor_applications')
          .add({
        'vendorId': user.uid,
        'marketId': market.id,
        'marketName': market.name,
        'appliedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error tracking application: $e');
    }
  }
  
  /// Save market to vendor's interested list
  Future<void> _saveMarketInterest(Market market) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('interested_markets')
          .doc(market.id)
          .set({
        'marketId': market.id,
        'marketName': market.name,
        'eventDate': market.eventDate,
        'savedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${market.name} saved to your markets'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving market interest: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const LoadingWidget(message: 'Finding markets looking for vendors...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Unable to Load Markets',
                  message: _error!,
                  onRetry: _loadMarkets,
                )
              : _markets.isEmpty
                  ? _buildEmptyState()
                  : _buildMarketsList(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Markets Looking for Vendors',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_markets.length} active opportunities',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: HiPopColors.darkSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HiPopColors.primaryDeepSage,
              HiPopColors.secondarySoftSage,
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: HiPopColors.darkSurface,
      elevation: 0,
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront,
                size: 60,
                color: HiPopColors.primaryDeepSage,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Markets Currently Recruiting',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check back soon for new vendor opportunities.\nMarkets update their recruitment status regularly.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadMarkets,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: HiPopColors.darkSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMarketsList() {
    return RefreshIndicator(
      onRefresh: _loadMarkets,
      color: HiPopColors.primaryDeepSage,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _markets.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _markets.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          final market = _markets[index];
          return _buildMarketCard(market);
        },
      ),
    );
  }
  
  Widget _buildMarketCard(Market market) {
    final isUrgent = market.isApplicationDeadlineUrgent;
    final hasSpots = market.hasAvailableSpots;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.darkShadow.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showMarketDetails(market),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isUrgent 
                  ? Border.all(color: HiPopColors.warningAmber, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with market name and urgency indicators
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            market.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: HiPopColors.darkTextTertiary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  market.fullAddress.isNotEmpty 
                                      ? market.fullAddress
                                      : '${market.city.isNotEmpty ? market.city : market.address}, ${market.state}',
                                  style: TextStyle(
                                    color: HiPopColors.darkTextSecondary,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: HiPopColors.warningAmber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 12,
                              color: HiPopColors.warningAmber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Urgent',
                              style: TextStyle(
                                color: HiPopColors.warningAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Key information grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.calendar_today,
                        market.eventDate.month == DateTime.now().month &&
                        market.eventDate.year == DateTime.now().year
                            ? 'This ${_getMonthName(market.eventDate.month)}'
                            : '${market.eventDate.month}/${market.eventDate.day}',
                        HiPopColors.primaryDeepSage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.access_time,
                        market.timeRange,
                        HiPopColors.infoBlueGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.groups,
                        market.spotsDisplay,
                        hasSpots 
                            ? HiPopColors.successGreen 
                            : HiPopColors.errorPlum,
                      ),
                    ),
                    if (market.applicationDeadline != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.schedule,
                          market.applicationDeadlineDisplay,
                          isUrgent 
                              ? HiPopColors.warningAmber 
                              : HiPopColors.accentMauve,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Fees section
                if (market.applicationFee != null || market.dailyBoothFee != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: HiPopColors.accentMauve.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments,
                          size: 16,
                          color: HiPopColors.accentMauve,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _buildFeesText(market),
                            style: TextStyle(
                              color: HiPopColors.darkTextPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showMarketDetails(market),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.primaryDeepSage,
                          side: BorderSide(color: HiPopColors.primaryDeepSage),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasSpots 
                            ? () => _applyToMarket(market)
                            : null,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Apply'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.primaryDeepSage,
                          foregroundColor: HiPopColors.darkSurface,
                          disabledBackgroundColor: HiPopColors.lightTextDisabled,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  String _buildFeesText(Market market) {
    final fees = <String>[];
    if (market.applicationFee != null && market.applicationFee! > 0) {
      fees.add('Application: \$${market.applicationFee!.toStringAsFixed(0)}');
    }
    if (market.dailyBoothFee != null && market.dailyBoothFee! > 0) {
      fees.add('Daily: \$${market.dailyBoothFee!.toStringAsFixed(0)}');
    }
    if (fees.isEmpty) {
      return 'No fees listed';
    }
    return fees.join(' • ');
  }
  
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
  
  void _showMarketDetails(Market market) {
    // Track recruitment post view if it's a recruitment-only post
    if (market.isRecruitmentOnly || market.isLookingForVendors) {
      _trackRecruitmentPostView(market);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MarketDetailsSheet(
        market: market,
        onApply: () => _applyToMarket(market),
        onSave: () => _saveMarketInterest(market),
      ),
    );
  }
  
  Future<void> _trackRecruitmentPostView(Market market) async {
    try {
      await RealTimeAnalyticsService.trackEvent(
        'recruitment_post_view',
        {
          'marketId': market.id,
          'marketName': market.name,
          'isRecruitmentOnly': market.isRecruitmentOnly,
          'applicationDeadline': market.applicationDeadline?.toIso8601String(),
          'spotsAvailable': market.vendorSpotsAvailable,
          'applicationFee': market.applicationFee,
          'dailyBoothFee': market.dailyBoothFee,
        },
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e) {
      debugPrint('Failed to track recruitment post view: $e');
    }
  }
}

/// Market Details Bottom Sheet
class _MarketDetailsSheet extends StatelessWidget {
  final Market market;
  final VoidCallback onApply;
  final VoidCallback onSave;
  
  const _MarketDetailsSheet({
    required this.market,
    required this.onApply,
    required this.onSave,
  });
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: HiPopColors.lightBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: HiPopColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                market.name,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                market.fullAddress,
                                style: TextStyle(
                                  color: HiPopColors.darkTextSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: HiPopColors.darkTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Event Details Section
                    _buildSection(
                      context,
                      title: 'Event Details',
                      icon: Icons.event,
                      children: [
                        _buildDetailRow('Date', market.eventDisplayInfo),
                        _buildDetailRow('Hours', market.timeRange),
                        if (market.spotsDisplay.isNotEmpty)
                          _buildDetailRow('Vendor Spots', market.spotsDisplay),
                        if (market.applicationDeadline != null)
                          _buildDetailRow(
                            'Application Deadline',
                            market.applicationDeadlineDisplay,
                            isHighlighted: market.isApplicationDeadlineUrgent,
                          ),
                      ],
                    ),
                    
                    // Fees Section
                    if (market.applicationFee != null || market.dailyBoothFee != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        title: 'Vendor Fees',
                        icon: Icons.payments,
                        children: [
                          if (market.applicationFee != null)
                            _buildDetailRow(
                              'Application Fee',
                              market.applicationFee! > 0 
                                  ? '\$${market.applicationFee!.toStringAsFixed(2)}'
                                  : 'Free',
                            ),
                          if (market.dailyBoothFee != null)
                            _buildDetailRow(
                              'Daily Booth Fee',
                              market.dailyBoothFee! > 0 
                                  ? '\$${market.dailyBoothFee!.toStringAsFixed(2)}'
                                  : 'Free',
                            ),
                        ],
                      ),
                    ],
                    
                    // Requirements Section
                    if (market.vendorRequirements != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        title: 'Vendor Requirements',
                        icon: Icons.checklist,
                        children: [
                          Text(
                            market.vendorRequirements!,
                            style: TextStyle(
                              color: HiPopColors.darkTextSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Description Section
                    if (market.description != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        title: 'About This Market',
                        icon: Icons.info,
                        children: [
                          Text(
                            market.description!,
                            style: TextStyle(
                              color: HiPopColors.darkTextSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onSave();
                            },
                            icon: const Icon(Icons.bookmark_border),
                            label: const Text('Save'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HiPopColors.accentMauve,
                              side: BorderSide(color: HiPopColors.accentMauve),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: market.hasAvailableSpots
                                ? () {
                                    Navigator.pop(context);
                                    onApply();
                                  }
                                : null,
                            icon: const Icon(Icons.send),
                            label: const Text('Apply Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HiPopColors.primaryDeepSage,
                              foregroundColor: HiPopColors.darkSurface,
                              disabledBackgroundColor: HiPopColors.lightTextDisabled,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: HiPopColors.primaryDeepSage,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: HiPopColors.darkTextTertiary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted 
                    ? HiPopColors.warningAmber 
                    : HiPopColors.darkTextPrimary,
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}