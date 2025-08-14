import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

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
/// - Export data for business reporting
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
  
  // Form controllers
  final _totalRevenueController = TextEditingController();
  final _transactionCountController = TextEditingController();
  final _marketFeeController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _notesController = TextEditingController();
  
  // State variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedMarketId;
  bool _isLoading = false;
  bool _isSaving = false;
  VendorSalesData? _existingSalesData;
  
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
    _tabController = TabController(length: 1, vsync: this);
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _selectedMarketId = widget.marketId;
    _commissionRateController.text = '5.0'; // Default 5% commission
    _checkPremiumAccess();
    _loadApprovedMarkets();
    _loadExistingSalesData();
    
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
  
  Future<void> _loadExistingSalesData() async {
    if (_selectedMarketId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final salesData = await _salesService.getSalesDataForDate(
        vendorId: FirebaseAuth.instance.currentUser!.uid,
        marketId: _selectedMarketId!,
        date: _selectedDate,
      );
      
      if (salesData != null && mounted) {
        setState(() {
          _existingSalesData = salesData;
          _totalRevenueController.text = salesData.revenue.toStringAsFixed(2);
          _transactionCountController.text = salesData.transactions.toString();
          _marketFeeController.text = salesData.marketFee.toStringAsFixed(2);
          _commissionRateController.text = (salesData.commissionPaid / salesData.revenue * 100).toStringAsFixed(2);
          _notesController.text = salesData.notes ?? '';
          // Products are now managed in the centralized Products & Market Items screen
        });
      }
    } catch (e) {
      if (mounted) _showError('Error loading sales data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveSalesData() async {
    if (!_formKey.currentState!.validate() || _selectedMarketId == null) {
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
        marketId: _selectedMarketId!,
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
          'date': _selectedDate.toIso8601String(),
          'revenue': revenue,
          'transactions': transactions,
          'productsCount': 0, // Products now tracked separately in Products & Market Items
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingSalesData != null ? 'Sales data updated!' : 'Sales data saved!'),
            backgroundColor: Colors.green,
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
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Tracker'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: 'Revenue'),
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
          ? const Center(child: CircularProgressIndicator())
          : !_hasPremiumAccess
              ? _buildPremiumRequiredScreen()
              : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRevenueTab(),
                        ],
                      ),
                    ),
      bottomNavigationBar: _hasPremiumAccess ? Container(
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
  
  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: 24),
          _buildMarketSelector(),
          const SizedBox(height: 24),
          if (_quickEntryMode) _buildQuickEntryCard() else _buildDetailedRevenueForm(),
        ],
      ),
    );
  }
  
  Widget _buildDateSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.blue),
        title: const Text('Sales Date'),
        subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
          );
          
          if (date != null) {
            setState(() => _selectedDate = date);
            _loadExistingSalesData();
          }
        },
      ),
    );
  }
  
  Widget _buildMarketSelector() {
    return Card(
      child: _loadingMarkets
          ? const ListTile(
              leading: Icon(Icons.location_on, color: Colors.green),
              title: Text('Market'),
              subtitle: Text('Loading markets...'),
              trailing: CircularProgressIndicator(),
            )
          : ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text('Market'),
              subtitle: Text(_getSelectedMarketName() ?? 'Select a market'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _approvedMarkets.isEmpty ? null : _showMarketSelectionDialog,
            ),
    );
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
                  decoration: const InputDecoration(
                    labelText: 'Commission Rate',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    helperText: 'Market commission percentage',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
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

  Widget _buildPremiumRequiredScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Icon(
              Icons.attach_money,
              size: 64,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sales Tracker',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Revenue tracking is a premium feature exclusively available to Vendor Pro subscribers.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to track your sales, revenue, commissions, and gain insights into your business performance.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildPremiumPrompt(),
        ],
      ),
    );
  }

  Widget _buildPremiumPrompt() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Unlock Vendor Pro Sales Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Vendor Pro (\$29/month) to unlock:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💰 Revenue & commission tracking'),
                SizedBox(height: 4),
                Text('📊 Sales performance analytics'),
                SizedBox(height: 4),
                Text('📈 Market-by-market revenue insights'),
                SizedBox(height: 4),
                Text('🧾 Transaction history & reporting'),
                SizedBox(height: 4),
                Text('📱 Mobile-optimized data entry'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => ContextualUpgradePrompts.showFeatureLockedPrompt(
                  context,
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  userType: 'vendor',
                  featureName: 'sales_tracking',
                  featureDisplayName: 'Sales Tracking',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Upgrade to Vendor Pro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
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

  void _showMarketSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Market'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _approvedMarkets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('No specific market'),
                  onTap: () {
                    setState(() => _selectedMarketId = null);
                    Navigator.pop(context);
                    _loadExistingSalesData();
                  },
                );
              }
              
              final market = _approvedMarkets[index - 1];
              return ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(market.name),
                subtitle: Text('${market.city}, ${market.state}'),
                onTap: () {
                  setState(() => _selectedMarketId = market.id);
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

  String? _getSelectedMarketName() {
    if (_selectedMarketId == null) return null;
    final market = _approvedMarkets
        .where((m) => m.id == _selectedMarketId)
        .firstOrNull;
    return market?.name;
  }
}