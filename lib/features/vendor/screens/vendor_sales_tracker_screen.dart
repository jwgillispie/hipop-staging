import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

import '../models/vendor_sales_data.dart';
import '../services/vendor_sales_service.dart';
import '../services/vendor_market_relationship_service.dart';
import '../../market/services/market_service.dart';
import '../../market/models/market.dart';
import '../../shared/services/real_time_analytics_service.dart';
import '../../premium/services/subscription_service.dart';
import '../../premium/widgets/upgrade_prompt_widget.dart';

/// Vendor Sales Tracker Screen
/// 
/// Provides a mobile-optimized interface for vendors to:
/// - Enter daily/weekly sales data
/// - Track product performance  
/// - Monitor revenue, commissions, and fees
/// - View historical sales data and analytics
/// - Comprehensive sales dashboard with charts and insights
class VendorSalesTrackerScreen extends StatefulWidget {
  final String? marketId;
  final DateTime? selectedDate;

  const VendorSalesTrackerScreen({
    super.key,
    this.marketId,
    this.selectedDate,
  });

  @override
  State<VendorSalesTrackerScreen> createState() => _VendorSalesTrackerScreenState();
}

class _VendorSalesTrackerScreenState extends State<VendorSalesTrackerScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _salesService = VendorSalesService();
  
  late TabController _tabController;
  
  // Historical data state
  List<VendorSalesData> _salesHistory = [];
  bool _loadingHistory = false;
  DateTime _historyStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _historyEndDate = DateTime.now();
  String? _historyMarketFilter;
  
  // Analytics state
  Map<String, dynamic>? _analyticsData;
  bool _loadingAnalytics = false;
  
  // Form controllers
  final _totalRevenueController = TextEditingController();
  final _transactionCountController = TextEditingController();
  final _marketFeeController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _notesController = TextEditingController();
  
  // State variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedMarketId;
  VenueDetails? _selectedVenueDetails; // New flexible venue selection
  bool _isLoading = false;
  bool _isSaving = false;
  VendorSalesData? _existingSalesData;
  int _currentTabIndex = 0; // Track current tab
  
  // Premium access state
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;
  
  // Quick entry mode for busy vendors
  bool _quickEntryMode = false;
  
  // Market selection state
  List<Market> _approvedMarkets = [];
  bool _loadingMarkets = false;
  
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _selectedMarketId = widget.marketId;
    _commissionRateController.text = '5.0'; // Default 5% commission
    _checkPremiumAccess();
    _loadApprovedMarkets();
    _loadExistingSalesData();
    _loadSalesHistory();
    _loadSalesAnalytics();
    
    // Track screen view
    RealTimeAnalyticsService.trackPageView(
      'vendor_sales_tracker',
      FirebaseAuth.instance.currentUser?.uid,
      metadata: {
        'marketId': _selectedMarketId,
        'date': _selectedDate.toIso8601String(),
      },
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _totalRevenueController.dispose();
    _transactionCountController.dispose();
    _marketFeeController.dispose();
    _commissionRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkPremiumAccess() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _hasPremiumAccess = false;
        _isCheckingPremium = false;
      });
      return;
    }

    try {
      final hasAccess = await SubscriptionService.hasFeature(
        userId,
        'sales_tracking',
      );
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
          _isCheckingPremium = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPremiumAccess = false;
          _isCheckingPremium = false;
        });
      }
    }
  }

  // Helper methods for date formatting without intl dependency
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  String _formatShortDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HiPopAppBar(
        title: 'Sales Tracker',
        userRole: 'vendor',
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: 'Entry'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_quickEntryMode ? Icons.edit : Icons.flash_on),
            onPressed: () {
              setState(() => _quickEntryMode = !_quickEntryMode);
            },
            tooltip: _quickEntryMode ? 'Detailed Entry' : 'Quick Entry',
          ),
        ],
      ),
      body: _isCheckingPremium
          ? const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    ))
          : !_hasPremiumAccess
              ? _buildPremiumRequiredScreen()
              : _isLoading
                  ? const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    ))
                  : Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRevenueTab(),
                          _buildHistoryTab(),
                          _buildAnalyticsTab(),
                        ],
                      ),
                    ),
      bottomNavigationBar: _hasPremiumAccess && _currentTabIndex == 0 ? Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSalesData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              minimumSize: const Size.fromHeight(56),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    _existingSalesData != null ? 'UPDATE REVENUE DATA' : 'SAVE REVENUE DATA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildPremiumRequiredScreen() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Premium icon with professional styling
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HiPopColors.premiumGold.withValues(alpha: 0.15),
                  HiPopColors.premiumGoldLight.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: HiPopColors.premiumGold.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.insights,
              size: 72,
              color: HiPopColors.premiumGold,
            ),
          ),
          const SizedBox(height: 32),
          // Title with premium badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sales Tracker',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode 
                      ? HiPopColors.darkTextPrimary
                      : HiPopColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HiPopColors.premiumGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Advanced sales tracking and analytics',
            style: theme.textTheme.titleMedium?.copyWith(
              color: HiPopColors.vendorAccent,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Gain deep insights into your business performance with comprehensive sales tracking, revenue analytics, and market-by-market reporting.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDarkMode
                  ? HiPopColors.darkTextSecondary
                  : HiPopColors.lightTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Premium upgrade card with gradient and professional styling
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HiPopColors.surfaceSoftPink.withValues(alpha: isDarkMode ? 0.2 : 1.0),
                  HiPopColors.surfacePalePink.withValues(alpha: isDarkMode ? 0.15 : 1.0),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: HiPopColors.premiumGold.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: HiPopColors.premiumGold.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: isDarkMode 
                      ? Colors.black.withValues(alpha: 0.3)
                      : HiPopColors.lightShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative background pattern
                Positioned(
                  right: -30,
                  top: -30,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 120,
                    color: HiPopColors.premiumGold.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Icon(
                    Icons.trending_up,
                    size: 100,
                    color: HiPopColors.vendorAccent.withValues(alpha: 0.08),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  HiPopColors.vendorAccent.withValues(alpha: 0.2),
                                  HiPopColors.vendorAccentLight.withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: HiPopColors.vendorAccent.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.workspace_premium,
                              color: HiPopColors.vendorAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vendor Premium',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? HiPopColors.darkTextPrimary
                                        : HiPopColors.primaryDeepSage,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: HiPopColors.premiumGradient,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    '\$29/month',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Feature list title
                      Text(
                        'Everything you need to grow your business:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? HiPopColors.darkTextPrimary
                              : HiPopColors.primaryDeepSage,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Feature items with enhanced styling
                      _buildEnhancedFeatureItem(
                        Icons.attach_money,
                        'Revenue & Commission Tracking',
                        'Track daily sales, commissions, and net profits',
                        isDarkMode,
                      ),
                      _buildEnhancedFeatureItem(
                        Icons.analytics,
                        'Advanced Analytics Dashboard',
                        'Interactive charts and performance insights',
                        isDarkMode,
                      ),
                      _buildEnhancedFeatureItem(
                        Icons.trending_up,
                        'Growth Trends & Forecasting',
                        'Identify patterns and optimize your strategy',
                        isDarkMode,
                      ),
                      _buildEnhancedFeatureItem(
                        Icons.history,
                        'Complete Sales History',
                        'Access all historical data and reports',
                        isDarkMode,
                      ),
                      _buildEnhancedFeatureItem(
                        Icons.location_on,
                        'Market Performance Analysis',
                        'Compare performance across different venues',
                        isDarkMode,
                      ),
                      const SizedBox(height: 24),
                      // CTA Button with gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: HiPopColors.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: HiPopColors.primaryDeepSage.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => ContextualUpgradePrompts.showFeatureLockedPrompt(
                              context,
                              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                              userType: 'vendor',
                              featureName: 'sales_tracking',
                              featureDisplayName: 'Sales Tracking',
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.rocket_launch,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Upgrade to Vendor Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Trust indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock,
                            size: 14,
                            color: isDarkMode
                                ? HiPopColors.darkTextTertiary
                                : HiPopColors.lightTextTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Secure payment · Cancel anytime',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDarkMode
                                  ? HiPopColors.darkTextTertiary
                                  : HiPopColors.lightTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Additional value proposition
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.infoBlueGray.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: HiPopColors.infoBlueGray,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Join hundreds of vendors using HiPop Premium to grow their business and increase revenue by an average of 35%.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                      height: 1.4,
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

  Widget _buildEnhancedFeatureItem(
    IconData icon,
    String title,
    String description,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 24,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? HiPopColors.darkTextPrimary
                        : HiPopColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? HiPopColors.darkTextTertiary
                        : HiPopColors.lightTextTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExistingSalesData() async {
    setState(() => _isLoading = true);
    
    try {
      final salesData = await _salesService.getSalesDataForDate(
        vendorId: FirebaseAuth.instance.currentUser!.uid,
        marketId: _selectedMarketId,
        date: _selectedDate,
        venueDetails: _selectedVenueDetails,
      );
      
      if (salesData != null && mounted) {
        setState(() {
          _existingSalesData = salesData;
          _totalRevenueController.text = salesData.revenue.toStringAsFixed(2);
          _transactionCountController.text = salesData.transactions.toString();
          _marketFeeController.text = salesData.marketFee.toStringAsFixed(2);
          
          // Set commission rate based on venue type and existing data
          final commissionRate = salesData.revenue > 0 
              ? (salesData.commissionPaid / salesData.revenue * 100) 
              : (_selectedVenueDetails?.type == VenueType.formalMarket ? 5.0 : 0.0);
          _commissionRateController.text = commissionRate.toStringAsFixed(2);
          
          _notesController.text = salesData.notes ?? '';
        });
      }
    } catch (e) {
      if (mounted) _showError('Error loading sales data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveSalesData() async {
    if (!_formKey.currentState!.validate() || _selectedVenueDetails == null) {
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedVenueDetails == null 
                ? 'Please select a sales venue first' 
                : 'Please fill in all required fields'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final revenue = double.tryParse(_totalRevenueController.text) ?? 0.0;
      final transactions = int.tryParse(_transactionCountController.text) ?? 0;
      final marketFee = double.tryParse(_marketFeeController.text) ?? 0.0;
      final commissionRate = double.tryParse(_commissionRateController.text) ?? 5.0;
      final commissionPaid = revenue * (commissionRate / 100);
      
      final salesData = VendorSalesData(
        id: _existingSalesData?.id ?? '',
        vendorId: FirebaseAuth.instance.currentUser!.uid,
        marketId: _selectedMarketId, // Now nullable
        venueDetails: _selectedVenueDetails!,
        date: _selectedDate,
        revenue: revenue,
        transactions: transactions,
        products: [], // Products are now managed in centralized Products & Market Items screen
        commissionPaid: commissionPaid,
        marketFee: marketFee,
        photoUrls: [], // Empty for now since no image picker
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: _existingSalesData?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        status: VendorSalesStatus.submitted,
      );
      
      if (_existingSalesData != null) {
        await _salesService.updateSalesData(salesData);
      } else {
        await _salesService.createSalesData(salesData);
      }
      
      // Track sales entry completion
      await RealTimeAnalyticsService.trackEvent(
        'sales_data_saved',
        {
          'marketId': _selectedMarketId,
          'venueType': _selectedVenueDetails!.type.name,
          'venueName': _selectedVenueDetails!.name,
          'date': _selectedDate.toIso8601String(),
          'revenue': revenue,
          'transactions': transactions,
          'commissionRate': commissionRate,
          'productsCount': 0, // Products now tracked separately in Products & Market Items
        },
      );
      
      // Refresh historical data and analytics
      _loadSalesHistory();
      _loadSalesAnalytics();
      
      if (mounted) {
        print('✅ Showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingSalesData != null ? 'Sales data updated!' : 'Sales data saved!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        
        Navigator.of(context).pop(salesData);
      }
      
    } catch (e) {
      if (mounted) _showError('Error saving sales data: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  Future<void> _loadSalesHistory() async {
    setState(() => _loadingHistory = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final history = await _salesService.getSalesDataForRange(
        vendorId: userId,
        marketId: _historyMarketFilter,
        startDate: _historyStartDate,
        endDate: _historyEndDate,
      );
      
      if (mounted) {
        setState(() {
          _salesHistory = history;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHistory = false);
        _showError('Error loading sales history: $e');
      }
    }
  }
  
  Future<void> _loadSalesAnalytics() async {
    setState(() => _loadingAnalytics = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final analytics = await _salesService.getSalesAnalytics(
        vendorId: userId,
        marketId: _historyMarketFilter,
        startDate: _historyStartDate,
        endDate: _historyEndDate,
      );
      
      if (mounted) {
        setState(() {
          _analyticsData = analytics;
          _loadingAnalytics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAnalytics = false);
        _showError('Error loading analytics: $e');
      }
    }
  }
  
  Future<void> _deleteSalesEntry(VendorSalesData salesData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sales Entry'),
        content: Text('Are you sure you want to delete the sales entry for ${_formatDate(salesData.date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _salesService.deleteSalesData(salesData.id);
        _loadSalesHistory();
        _loadSalesAnalytics();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sales entry deleted'),
              backgroundColor: HiPopColors.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) _showError('Error deleting sales entry: $e');
      }
    }
  }
  
  void _editSalesEntry(VendorSalesData salesData) {
    setState(() {
      _selectedDate = salesData.date;
      _selectedMarketId = salesData.marketId;
      _selectedVenueDetails = salesData.venueDetails;
      _existingSalesData = salesData;
      _totalRevenueController.text = salesData.revenue.toStringAsFixed(2);
      _transactionCountController.text = salesData.transactions.toString();
      _marketFeeController.text = salesData.marketFee.toStringAsFixed(2);
      
      // Set commission rate based on existing data
      final commissionRate = salesData.revenue > 0 
          ? (salesData.commissionPaid / salesData.revenue * 100) 
          : (salesData.venueDetails.type == VenueType.formalMarket ? 5.0 : 0.0);
      _commissionRateController.text = commissionRate.toStringAsFixed(2);
      
      _notesController.text = salesData.notes ?? '';
      _tabController.animateTo(0); // Switch to entry tab
    });
  }
  
  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: 24),
          _buildVenueSelector(),
          const SizedBox(height: 24),
          if (_quickEntryMode) _buildQuickEntryCard() else _buildDetailedRevenueForm(),
        ],
      ),
    );
  }
  
  Widget _buildDateSelector() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: HiPopColors.vendorAccent),
        title: const Text('Sales Date'),
        subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: HiPopColors.vendorAccent,
                    onPrimary: HiPopColors.darkTextPrimary,
                    surface: HiPopColors.darkSurface,
                    onSurface: HiPopColors.darkTextPrimary,
                    surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
                    onSurfaceVariant: HiPopColors.darkTextSecondary,
                    secondary: HiPopColors.accentMauve,
                    onSecondary: HiPopColors.darkTextPrimary,
                    error: HiPopColors.errorPlum,
                    onError: HiPopColors.darkTextPrimary,
                    outline: HiPopColors.darkBorder,
                    shadow: HiPopColors.darkShadow,
                  ),
                  dialogTheme: DialogThemeData(
                    backgroundColor: HiPopColors.darkSurface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: HiPopColors.darkSurface,
                    surfaceTintColor: Colors.transparent,
                    headerBackgroundColor: HiPopColors.darkSurfaceVariant,
                    headerForegroundColor: HiPopColors.darkTextPrimary,
                    weekdayStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                    dayStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                    yearStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                    todayBackgroundColor: WidgetStateProperty.all(HiPopColors.darkSurfaceElevated),
                    todayForegroundColor: WidgetStateProperty.all(HiPopColors.vendorAccent),
                    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return HiPopColors.vendorAccent;
                      }
                      return null;
                    }),
                    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return HiPopColors.darkTextPrimary;
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return HiPopColors.darkTextDisabled;
                      }
                      return HiPopColors.darkTextPrimary;
                    }),
                    yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return HiPopColors.vendorAccent;
                      }
                      return null;
                    }),
                    yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return HiPopColors.darkTextPrimary;
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return HiPopColors.darkTextDisabled;
                      }
                      return HiPopColors.darkTextPrimary;
                    }),
                    confirmButtonStyle: TextButton.styleFrom(
                      foregroundColor: HiPopColors.vendorAccent,
                    ),
                    cancelButtonStyle: TextButton.styleFrom(
                      foregroundColor: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
          
          if (date != null) {
            setState(() {
              _selectedDate = date;
              // Reset venue selection when date changes to avoid confusion
              _selectedVenueDetails = null;
              _selectedMarketId = null;
              _commissionRateController.text = '5.0'; // Default rate
            });
            _loadExistingSalesData();
          }
        },
      ),
    );
  }
  
  Widget _buildVenueSelector() {
    return Card(
      child: ListTile(
        leading: Icon(
          _getVenueIcon(),
          color: HiPopColors.vendorAccent,
        ),
        title: const Text('Sales Venue'),
        subtitle: Text(_selectedVenueDetails?.displayText ?? 'Select venue type'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedVenueDetails != null && _selectedVenueDetails!.type != VenueType.formalMarket)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HiPopColors.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '0% Commission',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: HiPopColors.successGreen,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: _showVenueSelectionDialog,
      ),
    );
  }
  
  IconData _getVenueIcon() {
    if (_selectedVenueDetails == null) return Icons.store;
    
    switch (_selectedVenueDetails!.type) {
      case VenueType.formalMarket:
        return Icons.local_grocery_store;
      case VenueType.independentEvent:
        return Icons.event;
      case VenueType.onlineSales:
        return Icons.computer;
      case VenueType.directSales:
        return Icons.delivery_dining;
    }
  }
  
  Widget _buildQuickEntryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Entry Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalRevenueController,
              decoration: const InputDecoration(
                labelText: 'Total Revenue',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (double.tryParse(value!) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _transactionCountController,
              decoration: const InputDecoration(
                labelText: 'Number of Transactions',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (int.tryParse(value!) == null) return 'Invalid number';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailedRevenueForm() {
    final revenue = double.tryParse(_totalRevenueController.text) ?? 0.0;
    final commissionRate = double.tryParse(_commissionRateController.text) ?? 5.0;
    final marketFee = double.tryParse(_marketFeeController.text) ?? 0.0;
    final commissionPaid = revenue * (commissionRate / 100);
    final netRevenue = revenue - commissionPaid - marketFee;
    
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revenue Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalRevenueController,
                  decoration: const InputDecoration(
                    labelText: 'Total Revenue',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    helperText: 'Gross sales before fees',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (double.tryParse(value!) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _transactionCountController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Transactions',
                    border: OutlineInputBorder(),
                    helperText: 'Total sales transactions',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (int.tryParse(value!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fees & Commissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commissionRateController,
                  decoration: InputDecoration(
                    labelText: 'Commission Rate',
                    suffixText: '%',
                    border: const OutlineInputBorder(),
                    helperText: _selectedVenueDetails?.type == VenueType.formalMarket 
                        ? 'Market commission percentage' 
                        : 'No commission for this venue type',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  readOnly: _selectedVenueDetails?.type != VenueType.formalMarket,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final rate = double.tryParse(value!);
                    if (rate == null || rate < 0 || rate > 50) {
                      return 'Rate must be between 0% and 50%';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _marketFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Market Fee',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    helperText: 'Fixed fees (booth, setup, etc.)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value?.isNotEmpty == true && double.tryParse(value!) == null) {
                      return 'Invalid amount';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Revenue Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('Gross Revenue', '\$${revenue.toStringAsFixed(2)}'),
                _buildSummaryRow('Commission (${commissionRate.toStringAsFixed(1)}%)', 
                    '-\$${commissionPaid.toStringAsFixed(2)}'),
                _buildSummaryRow('Market Fee', '-\$${marketFee.toStringAsFixed(2)}'),
                const Divider(),
                _buildSummaryRow('Net Revenue', '\$${netRevenue.toStringAsFixed(2)}', 
                    isTotal: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                helperText: 'Additional notes about this sales day',
              ),
              maxLines: 3,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  // Market selection methods
  
  Future<void> _loadApprovedMarkets() async {
    setState(() => _loadingMarkets = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final marketIds = await VendorMarketRelationshipService
          .getApprovedMarketsForVendor(userId);
      
      final markets = <Market>[];
      for (final marketId in marketIds) {
        final market = await MarketService.getMarket(marketId);
        if (market != null) {
          markets.add(market);
        }
      }
      
      if (mounted) {
        setState(() {
          _approvedMarkets = markets;
          _loadingMarkets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMarkets = false);
        _showError('Error loading markets: $e');
      }
    }
  }

  void _showVenueSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Sales Venue'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Market Event Option
              ListTile(
                leading: Icon(Icons.local_grocery_store, color: HiPopColors.vendorAccent),
                title: const Text('Market Event'),
                subtitle: const Text('At an organized farmers market (commission applies)'),
                onTap: () {
                  Navigator.pop(context);
                  _showMarketSelectionDialog();
                },
              ),
              const Divider(),
              // Independent Pop-up Option
              ListTile(
                leading: Icon(Icons.event, color: HiPopColors.accentMauve),
                title: const Text('Independent Pop-up'),
                subtitle: const Text('Private event, festival, or catering (no commission)'),
                onTap: () {
                  Navigator.pop(context);
                  _showIndependentEventDialog();
                },
              ),
              const Divider(),
              // Online Sales Option
              ListTile(
                leading: Icon(Icons.computer, color: HiPopColors.premiumGold),
                title: const Text('Online Sales'),
                subtitle: const Text('Website, social media, or online platform (no commission)'),
                onTap: () {
                  Navigator.pop(context);
                  _showOnlineSalesDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  IconData _getIconForVenueType(VenueType type) {
    switch (type) {
      case VenueType.formalMarket:
        return Icons.local_grocery_store;
      case VenueType.independentEvent:
        return Icons.event;
      case VenueType.onlineSales:
        return Icons.computer;
      case VenueType.directSales:
        return Icons.delivery_dining;
    }
  }
  
  
  void _showMarketSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Market'),
        content: SizedBox(
          width: double.maxFinite,
          child: _loadingMarkets
              ? const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    ))
              : _approvedMarkets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No approved markets found. Apply to markets first.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _approvedMarkets.length,
                      itemBuilder: (context, index) {
                        final market = _approvedMarkets[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(market.name),
                          subtitle: Text('${market.city}, ${market.state}'),
                          onTap: () {
                            setState(() {
                              _selectedMarketId = market.id;
                              _selectedVenueDetails = VenueDetails.formalMarket(
                                marketName: market.name,
                                marketLocation: '${market.city}, ${market.state}',
                              );
                              // Set default 5% commission for market events
                              _commissionRateController.text = '5.0';
                            });
                            Navigator.pop(context);
                            _loadExistingSalesData();
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showIndependentEventDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final typeController = TextEditingController();
    final organizerController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Independent Event Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event Name *',
                    hintText: 'e.g., Spring Festival, Private Catering',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., Downtown Park, Client Home',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                    hintText: 'e.g., Pop-up, Catering, Festival',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: organizerController,
                  decoration: const InputDecoration(
                    labelText: 'Organizer',
                    hintText: 'Who organized this event?',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _selectedMarketId = null; // No market for independent events
                  _selectedVenueDetails = VenueDetails.independentEvent(
                    eventName: nameController.text.trim(),
                    eventLocation: locationController.text.trim().isNotEmpty 
                        ? locationController.text.trim() 
                        : null,
                    eventType: typeController.text.trim().isNotEmpty 
                        ? typeController.text.trim() 
                        : null,
                    organizer: organizerController.text.trim().isNotEmpty 
                        ? organizerController.text.trim() 
                        : null,
                  );
                  // No commission for independent events
                  _commissionRateController.text = '0.0';
                });
                Navigator.pop(context);
                _loadExistingSalesData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showOnlineSalesDialog() {
    final platformController = TextEditingController();
    final orderRefController = TextEditingController();
    final shippingController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Online Sales Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: platformController,
                  decoration: const InputDecoration(
                    labelText: 'Platform *',
                    hintText: 'e.g., Website, Instagram, Facebook Marketplace',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: orderRefController,
                  decoration: const InputDecoration(
                    labelText: 'Order Reference',
                    hintText: 'Order number or reference',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: shippingController,
                  decoration: const InputDecoration(
                    labelText: 'Shipping Method',
                    hintText: 'e.g., Pickup, Local Delivery, Shipped',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (platformController.text.trim().isNotEmpty) {
                setState(() {
                  _selectedMarketId = null; // No market for online sales
                  _selectedVenueDetails = VenueDetails.onlineSales(
                    platform: platformController.text.trim(),
                    orderReference: orderRefController.text.trim().isNotEmpty 
                        ? orderRefController.text.trim() 
                        : null,
                    shippingMethod: shippingController.text.trim().isNotEmpty 
                        ? shippingController.text.trim() 
                        : null,
                  );
                  // No commission for online sales
                  _commissionRateController.text = '0.0';
                });
                Navigator.pop(context);
                _loadExistingSalesData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  

  
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoryFilters(),
          const SizedBox(height: 24),
          _buildHistorySummary(),
          const SizedBox(height: 24),
          _buildHistoryList(),
        ],
      ),
    );
  }
  
  Widget _buildHistoryFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDateRange(),
                    icon: Icon(Icons.date_range, color: HiPopColors.vendorAccent),
                    label: Text(
                      '${_formatShortDate(_historyStartDate)} - ${_formatDate(_historyEndDate)}',
                      style: TextStyle(color: HiPopColors.vendorAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectMarketFilter(),
                    icon: Icon(Icons.location_on, color: HiPopColors.vendorAccent),
                    label: Text(
                      _historyMarketFilter != null 
                          ? _approvedMarkets.firstWhere((m) => m.id == _historyMarketFilter).name
                          : 'All Markets',
                      style: TextStyle(color: HiPopColors.vendorAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHistorySummary() {
    if (_loadingHistory) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    )),
        ),
      );
    }
    
    final totalRevenue = _salesHistory.fold(0.0, (total, sale) => total + sale.revenue);
    final totalTransactions = _salesHistory.fold(0, (total, sale) => total + sale.transactions);
    final totalProfit = _salesHistory.fold(0.0, (total, sale) => total + sale.netProfit);
    final daysWithSales = _salesHistory.length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Period Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    'Total Revenue',
                    '\$${totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    HiPopColors.successGreen,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'Total Profit',
                    '\$${totalProfit.toStringAsFixed(2)}',
                    Icons.trending_up,
                    HiPopColors.vendorAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    'Transactions',
                    totalTransactions.toString(),
                    Icons.receipt,
                    HiPopColors.accentMauve,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'Sales Days',
                    daysWithSales.toString(),
                    Icons.calendar_today,
                    HiPopColors.premiumGold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryList() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    ));
    }
    
    if (_salesHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Sales History',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start entering sales data to see your history here!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales History (${_salesHistory.length} entries)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _salesHistory.length,
          itemBuilder: (context, index) {
            final sale = _salesHistory[index];
            return _buildHistoryItem(sale);
          },
        ),
      ],
    );
  }
  
  Widget _buildHistoryItem(VendorSalesData sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(sale.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getIconForVenueType(sale.venueDetails.type),
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sale.venueDetails.displayText,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        sale.venueDetails.type.displayName,
                        style: TextStyle(
                          color: HiPopColors.vendorAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _editSalesEntry(sale),
                      icon: Icon(Icons.edit, color: HiPopColors.vendorAccent),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _deleteSalesEntry(sale),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildHistoryMetric(
                    'Revenue',
                    '\$${sale.revenue.toStringAsFixed(2)}',
                    HiPopColors.successGreen,
                  ),
                ),
                Expanded(
                  child: _buildHistoryMetric(
                    'Profit',
                    '\$${sale.netProfit.toStringAsFixed(2)}',
                    HiPopColors.vendorAccent,
                  ),
                ),
                Expanded(
                  child: _buildHistoryMetric(
                    'Transactions',
                    sale.transactions.toString(),
                    HiPopColors.accentMauve,
                  ),
                ),
              ],
            ),
            if (sale.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sale.notes!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHistoryMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _historyStartDate,
        end: _historyEndDate,
      ),
    );
    
    if (picked != null) {
      setState(() {
        _historyStartDate = picked.start;
        _historyEndDate = picked.end;
      });
      _loadSalesHistory();
      _loadSalesAnalytics();
    }
  }
  
  void _selectMarketFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Market'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _approvedMarkets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('All Markets'),
                  selected: _historyMarketFilter == null,
                  onTap: () {
                    setState(() => _historyMarketFilter = null);
                    Navigator.pop(context);
                    _loadSalesHistory();
                    _loadSalesAnalytics();
                  },
                );
              }
              
              final market = _approvedMarkets[index - 1];
              return ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(market.name),
                subtitle: Text('${market.city}, ${market.state}'),
                selected: _historyMarketFilter == market.id,
                onTap: () {
                  setState(() => _historyMarketFilter = market.id);
                  Navigator.pop(context);
                  _loadSalesHistory();
                  _loadSalesAnalytics();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsTab() {
    if (!_hasPremiumAccess) {
      return _buildPremiumAnalyticsPrompt();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsOverview(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildPerformanceInsights(),
          const SizedBox(height: 24),
          _buildMarketPerformance(),
        ],
      ),
    );
  }
  
  Widget _buildPremiumAnalyticsPrompt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HiPopColors.premiumGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HiPopColors.premiumGold.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.analytics,
              size: 64,
              color: HiPopColors.premiumGold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sales Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.premiumGoldDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Advanced sales analytics with charts and insights are exclusively available to Vendor Premium subscribers.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to unlock revenue trends, market performance analysis, and detailed reporting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildAnalyticsFeatureList(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ContextualUpgradePrompts.showFeatureLockedPrompt(
                context,
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                userType: 'vendor',
                featureName: 'sales_analytics',
                featureDisplayName: 'Sales Analytics',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.premiumGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Upgrade to Vendor Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsFeatureList() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.surfaceSoftPink.withValues(alpha: isDarkMode ? 0.2 : 1.0),
            HiPopColors.surfacePalePink.withValues(alpha: isDarkMode ? 0.15 : 1.0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: HiPopColors.premiumGold.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.premiumGold.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        HiPopColors.premiumGold.withValues(alpha: 0.2),
                        HiPopColors.premiumGoldLight.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_graph,
                    color: HiPopColors.premiumGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Analytics',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? HiPopColors.darkTextPrimary
                              : HiPopColors.primaryDeepSage,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: HiPopColors.premiumGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '\$29/month',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildEnhancedFeatureItem(
              Icons.trending_up,
              'Revenue Growth Analysis',
              'Track trends and identify growth opportunities',
              isDarkMode,
            ),
            _buildEnhancedFeatureItem(
              Icons.location_on,
              'Market Performance Insights',
              'Compare results across different venues',
              isDarkMode,
            ),
            _buildEnhancedFeatureItem(
              Icons.calculate,
              'Transaction Analytics',
              'Average order value and customer metrics',
              isDarkMode,
            ),
            _buildEnhancedFeatureItem(
              Icons.pie_chart,
              'Financial Breakdown',
              'Detailed commission and fee analysis',
              isDarkMode,
            ),
            _buildEnhancedFeatureItem(
              Icons.calendar_view_week,
              'Pattern Recognition',
              'Identify your best performing days',
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsOverview() {
    if (_loadingAnalytics || _analyticsData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    )),
        ),
      );
    }
    
    final analytics = _analyticsData!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Analytics Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _loadSalesAnalytics();
                  },
                  icon: Icon(Icons.refresh, color: HiPopColors.vendorAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildAnalyticsCard(
                  'Total Revenue',
                  '\$${(analytics['totalRevenue'] as double).toStringAsFixed(2)}',
                  Icons.attach_money,
                  HiPopColors.successGreen,
                ),
                _buildAnalyticsCard(
                  'Net Profit',
                  '\$${(analytics['netRevenue'] as double).toStringAsFixed(2)}',
                  Icons.trending_up,
                  HiPopColors.vendorAccent,
                ),
                _buildAnalyticsCard(
                  'Avg. Transaction',
                  '\$${(analytics['averageTransactionValue'] as double).toStringAsFixed(2)}',
                  Icons.receipt,
                  HiPopColors.accentMauve,
                ),
                _buildAnalyticsCard(
                  'Profit Margin',
                  '${(analytics['profitMargin'] as double).toStringAsFixed(1)}%',
                  Icons.pie_chart,
                  HiPopColors.premiumGold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueChart() {
    if (_loadingAnalytics || _analyticsData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    )),
        ),
      );
    }
    
    final dailyRevenue = _analyticsData!['dailyRevenue'] as List<Map<String, dynamic>>;
    
    if (dailyRevenue.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Chart Data',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add more sales entries to see trends',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dailyRevenue.length) {
                            final date = dailyRevenue[index]['date'] as DateTime;
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                '${date.month}/${date.day}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  minX: 0,
                  maxX: (dailyRevenue.length - 1).toDouble(),
                  minY: 0,
                  maxY: _getMaxRevenueY(dailyRevenue),
                  lineBarsData: [
                    // Revenue line
                    LineChartBarData(
                      spots: _createRevenueSpots(dailyRevenue, 'revenue'),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          HiPopColors.successGreen.withValues(alpha: 0.8),
                          HiPopColors.successGreen,
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: HiPopColors.successGreen,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            HiPopColors.successGreen.withValues(alpha: 0.3),
                            HiPopColors.successGreen.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Net revenue line
                    LineChartBarData(
                      spots: _createRevenueSpots(dailyRevenue, 'netRevenue'),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          HiPopColors.vendorAccent.withValues(alpha: 0.8),
                          HiPopColors.vendorAccent,
                        ],
                      ),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: HiPopColors.vendorAccent,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.blueGrey.withValues(alpha: 0.8),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          if (index >= 0 && index < dailyRevenue.length) {
                            final date = dailyRevenue[index]['date'] as DateTime;
                            final lineIndex = barSpot.barIndex;
                            String lineLabel = lineIndex == 0 ? 'Revenue' : 'Net Revenue';
                            Color color = lineIndex == 0 ? HiPopColors.successGreen : HiPopColors.vendorAccent;
                            
                            return LineTooltipItem(
                              '${_formatShortDate(date)}\n$lineLabel: \$${barSpot.y.toStringAsFixed(2)}',
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegendItem('Revenue', HiPopColors.successGreen),
                const SizedBox(width: 20),
                _buildChartLegendItem('Net Revenue', HiPopColors.vendorAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  List<FlSpot> _createRevenueSpots(List<Map<String, dynamic>> dailyRevenue, String key) {
    return dailyRevenue.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final value = (data[key] as double?) ?? 0.0;
      return FlSpot(index.toDouble(), value);
    }).toList();
  }
  
  double _getMaxRevenueY(List<Map<String, dynamic>> dailyRevenue) {
    if (dailyRevenue.isEmpty) return 100;
    
    double maxValue = 0;
    for (final data in dailyRevenue) {
      final revenue = (data['revenue'] as double?) ?? 0.0;
      if (revenue > maxValue) maxValue = revenue;
    }
    
    // Add some padding to the max value
    return (maxValue * 1.2).clamp(50, double.infinity);
  }
  
  Widget _buildPerformanceInsights() {
    if (_loadingAnalytics || _analyticsData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    )),
        ),
      );
    }
    
    final analytics = _analyticsData!;
    final revenueGrowth = analytics['revenueGrowth'] as double;
    final avgDaily = analytics['averageDailyRevenue'] as double;
    final totalDays = analytics['daysWithSales'] as int;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInsightItem(
                    'Weekly Growth',
                    '${revenueGrowth >= 0 ? '+' : ''}${revenueGrowth.toStringAsFixed(1)}%',
                    revenueGrowth >= 0 ? Icons.trending_up : Icons.trending_down,
                    revenueGrowth >= 0 ? HiPopColors.successGreen : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildInsightItem(
                    'Daily Average',
                    '\$${avgDaily.toStringAsFixed(2)}',
                    Icons.today,
                    HiPopColors.vendorAccent,
                  ),
                ),
                Expanded(
                  child: _buildInsightItem(
                    'Sales Days',
                    totalDays.toString(),
                    Icons.event_available,
                    HiPopColors.accentMauve,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInsightItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMarketPerformance() {
    if (_loadingAnalytics || _analyticsData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    )),
        ),
      );
    }
    
    final topMarkets = _analyticsData!['topMarkets'] as List<Map<String, dynamic>>;
    
    if (topMarkets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.location_on, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Market Data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performing Markets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...topMarkets.take(3).map((market) => _buildMarketItem(market)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMarketItem(Map<String, dynamic> marketData) {
    final marketId = marketData['marketId'] as String;
    final revenue = marketData['revenue'] as double;
    final market = _approvedMarkets.cast<Market?>().firstWhere((m) => m?.id == marketId, orElse: () => null);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.location_on, color: HiPopColors.vendorAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  market?.name ?? 'Unknown Market',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (market != null)
                  Text(
                    '${market.city}, ${market.state}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '\$${revenue.toStringAsFixed(2)}',
              style: TextStyle(
                color: HiPopColors.successGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: HiPopColors.errorPlum),
    );
  }
}