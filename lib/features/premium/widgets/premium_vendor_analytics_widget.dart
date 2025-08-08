import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/vendor/services/vendor_premium_analytics_service.dart';
import '../services/subscription_service.dart';
import '../widgets/upgrade_to_premium_button.dart';

/// Production-ready premium vendor analytics widget that integrates
/// advanced analytics directly into the vendor dashboard
class PremiumVendorAnalyticsWidget extends StatefulWidget {
  const PremiumVendorAnalyticsWidget({super.key});

  @override
  State<PremiumVendorAnalyticsWidget> createState() => _PremiumVendorAnalyticsWidgetState();
}

class _PremiumVendorAnalyticsWidgetState extends State<PremiumVendorAnalyticsWidget> {
  Map<String, dynamic>? _revenueAnalytics;
  Map<String, dynamic>? _customerInsights;
  Map<String, dynamic>? _marketComparison;
  bool _isLoading = false;
  bool _hasPremiumAccess = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _checkPremiumAccess();
  }

  Future<void> _checkPremiumAccess() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      final hasAccess = await SubscriptionService.hasFeature(
        _currentUserId,
        'advanced_analytics',
      );
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
        });
        
        if (hasAccess) {
          _loadAnalyticsData();
        }
      }
    }
  }

  Future<void> _loadAnalyticsData() async {
    if (!_hasPremiumAccess || _currentUserId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        VendorPremiumAnalyticsService.getRevenueAnalytics(vendorId: _currentUserId),
        VendorPremiumAnalyticsService.getCustomerInsights(vendorId: _currentUserId),
        VendorPremiumAnalyticsService.getMarketComparison(vendorId: _currentUserId),
      ]);

      if (mounted) {
        setState(() {
          _revenueAnalytics = futures[0] as Map<String, dynamic>;
          _customerInsights = futures[1] as Map<String, dynamic>;
          _marketComparison = futures[2] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading analytics...'),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasPremiumAccess) {
      return _buildUpgradePrompt();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue, size: 24),
            const SizedBox(width: 8),
            Text(
              'Premium Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.amber.shade700, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAnalyticsData,
              tooltip: 'Refresh Analytics',
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Analytics cards
        Row(
          children: [
            Expanded(
              child: _buildRevenueCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCustomerCard(),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        _buildMarketPerformanceCard(),
      ],
    );
  }

  Widget _buildUpgradePrompt() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.analytics,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock Advanced Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get detailed insights into your revenue, customers, and market performance',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureChip(Icons.monetization_on, 'Revenue Tracking'),
                const SizedBox(width: 8),
                _buildFeatureChip(Icons.people, 'Customer Insights'),
                const SizedBox(width: 8),
                _buildFeatureChip(Icons.trending_up, 'Performance Analytics'),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showUpgradeDialog,
              icon: const Icon(Icons.star),
              label: const Text('Upgrade to Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Revenue Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_revenueAnalytics != null) ...[
              _buildAnalyticItem(
                'Total Revenue',
                '\$${_revenueAnalytics!['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.attach_money,
              ),
              _buildAnalyticItem(
                'Daily Average',
                '\$${_revenueAnalytics!['averageDailyRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.today,
              ),
              _buildAnalyticItem(
                'Growth Rate',
                '${_revenueAnalytics!['revenueGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
                Icons.trending_up,
              ),
            ] else ...[
              const Text('Loading revenue data...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Customer Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_customerInsights != null) ...[
              _buildAnalyticItem(
                'Total Customers',
                '${_customerInsights!['totalCustomers'] ?? 0}',
                Icons.person,
              ),
              _buildAnalyticItem(
                'Return Rate',
                '${((_customerInsights!['returningCustomerRate'] ?? 0) * 100).toStringAsFixed(1)}%',
                Icons.replay,
              ),
              _buildAnalyticItem(
                'Avg Spend',
                '\$${_customerInsights!['averageSpend']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.shopping_cart,
              ),
            ] else ...[
              const Text('Loading customer data...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarketPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Market Performance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_marketComparison != null && _marketComparison!['marketComparisons'] != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticItem(
                      'Markets Active',
                      '${_marketComparison!['marketComparisons'].length}',
                      Icons.place,
                    ),
                  ),
                  Expanded(
                    child: _buildAnalyticItem(
                      'Best Market',
                      _marketComparison!['bestPerformingMarket']?['marketName'] ?? 'N/A',
                      Icons.star,
                    ),
                  ),
                  Expanded(
                    child: _buildAnalyticItem(
                      'Top Revenue',
                      '\$${_marketComparison!['bestPerformingMarket']?['revenue']?.toStringAsFixed(2) ?? '0.00'}',
                      Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text('Loading market performance...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Upgrade to Premium Vendor'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unlock comprehensive business analytics:'),
            const SizedBox(height: 16),
            _buildUpgradeFeature(Icons.analytics, 'Advanced revenue tracking & forecasting'),
            _buildUpgradeFeature(Icons.people, 'Detailed customer demographics & behavior'),
            _buildUpgradeFeature(Icons.compare_arrows, 'Multi-market performance comparison'),
            _buildUpgradeFeature(Icons.trending_up, 'Growth analytics & insights'),
            _buildUpgradeFeature(Icons.schedule, 'Historical data & trend analysis'),
            const SizedBox(height: 16),
            const UpgradeToPremiumButton(userType: 'vendor'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}