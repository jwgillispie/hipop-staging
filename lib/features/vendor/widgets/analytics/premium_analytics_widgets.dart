import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../../premium/widgets/vendor_premium_dashboard_components.dart';
import '../../../premium/models/user_subscription.dart';

/// Reusable analytics widgets for premium vendor dashboard
/// Provides sophisticated data visualization components
class PremiumAnalyticsWidgets {
  
  /// Revenue tracking line chart with trend analysis
  static Widget buildRevenueChart({
    required List<RevenueDatePoint> data,
    required String title,
    String? subtitle,
    bool showTrend = true,
  }) {
    return VendorPremiumDashboardComponents.buildPremiumFeatureCard(
      title: title,
      description: subtitle ?? 'Track your revenue performance over time',
      icon: Icons.trending_up,
      color: HiPopColors.successGreen,
      onTap: () {},
      showPremiumBadge: false,
      trailing: const SizedBox.shrink(),
    );
  }

  /// Sales performance bar chart
  static Widget buildSalesChart({
    required List<SalesDataPoint> salesData,
    required String period,
    bool showComparison = true,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: HiPopColors.primaryDeepSage,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sales Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        period,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: _buildSalesBarChart(salesData),
            ),
          ],
        ),
      ),
    );
  }

  /// Product performance matrix with detailed analytics
  static Widget buildProductPerformanceMatrix({
    required List<ProductPerformance> products,
    required VoidCallback onProductTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory,
                    color: HiPopColors.warningAmber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Product Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (products.isEmpty)
              _buildEmptyProductState()
            else
              ..._buildProductPerformanceList(products, onProductTap),
          ],
        ),
      ),
    );
  }

  /// Customer demographics pie chart
  static Widget buildCustomerDemographics({
    required Map<String, double> demographics,
    required String title,
  }) {
    return VendorPremiumDashboardComponents.buildPremiumFeatureCard(
      title: title,
      description: 'Understand your customer base distribution',
      icon: Icons.people,
      color: HiPopColors.accentMauve,
      onTap: () {},
      showPremiumBadge: false,
      trailing: SizedBox(
        height: 120,
        width: 120,
        child: _buildDemographicsPieChart(demographics),
      ),
    );
  }

  /// Usage statistics visualization
  static Widget buildUsageStatistics({
    required Map<String, dynamic> stats,
    required String period,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.teal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usage Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        period,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildUsageMetricsGrid(stats),
          ],
        ),
      ),
    );
  }

  /// Tier-specific analytics component that adapts based on subscription level
  static Widget buildTierSpecificAnalytics({
    required BuildContext context,
    required String userType,
    required Map<String, dynamic> analyticsData,
  }) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final userProfile = authState.userProfile;
        final isPremium = userProfile?.isPremium ?? false;
        
        // Build different analytics based on premium status
        if (isPremium) {
          // For premium users, show enhanced analytics
          switch (userType) {
            case 'vendor':
              return _buildVendorProAnalytics(context, analyticsData);
            case 'market_organizer':
              return _buildOrganizerProAnalytics(context, analyticsData);
            default:
              return _buildVendorProAnalytics(context, analyticsData);
          }
        } else {
          // For free users, show basic analytics
          return _buildFreeUserAnalytics(context, analyticsData);
        }
      },
    );
  }

  /// Access-controlled analytics wrapper
  static Widget buildSecureAnalyticsWidget({
    required BuildContext context,
    required String featureName,
    required Widget Function() builder,
    Widget Function()? fallbackBuilder,
  }) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final userProfile = authState.userProfile;
        final hasAccess = userProfile?.isPremium ?? false;
        
        if (hasAccess) {
          return builder();
        } else {
          return fallbackBuilder?.call() ?? 
              VendorPremiumDashboardComponents.buildUpgradePrompt(
                context,
                customMessage: 'Unlock $featureName with Vendor Pro',
              );
        }
      },
    );
  }

  // Private helper methods

  static Widget _buildSalesBarChart(List<SalesDataPoint> data) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isNotEmpty 
            ? data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2 
            : 100,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Text(
                    data[index].label,
                    style: const TextStyle(fontSize: 12),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: Colors.blue,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildDemographicsPieChart(Map<String, double> demographics) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(enabled: true),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: _buildPieChartSections(demographics),
      ),
    );
  }

  static List<PieChartSectionData> _buildPieChartSections(Map<String, double> data) {
    final colors = [
      HiPopColors.primaryDeepSage,
      HiPopColors.warningAmber,
      HiPopColors.successGreen,
      HiPopColors.errorPlum,
      HiPopColors.accentMauve,
    ];
    
    return data.entries.map((entry) {
      final index = data.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${entry.value.toStringAsFixed(1)}%',
        radius: 30,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  static Widget _buildUsageMetricsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: stats.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.value.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.key.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _buildEmptyProductState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Product Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start selling to see product performance',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildProductPerformanceList(
    List<ProductPerformance> products, 
    VoidCallback onProductTap
  ) {
    return products.take(5).map((product) {
      return InkWell(
        onTap: onProductTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HiPopColors.warningAmber.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HiPopColors.warningAmber.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.sales} sales • \$${product.revenue.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPerformanceColor(product.performanceScore).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${product.performanceScore.toStringAsFixed(1)}★',
                  style: TextStyle(
                    color: _getPerformanceColor(product.performanceScore),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  static Color _getPerformanceColor(double score) {
    if (score >= 4.0) return HiPopColors.successGreen;
    if (score >= 3.0) return HiPopColors.warningAmber;
    return HiPopColors.errorPlum;
  }

  // Tier-specific analytics builders

  static Widget _buildFreeUserAnalytics(BuildContext context, Map<String, dynamic> data) {
    return VendorPremiumDashboardComponents.buildUpgradePrompt(
      context,
      customMessage: 'Unlock detailed analytics with Vendor Pro',
      features: [
        'Revenue tracking & profit analysis',
        'Product performance insights', 
        'Customer demographics',
        'Sales trend analysis',
        'Market comparison data',
      ],
    );
  }

  static Widget _buildVendorProAnalytics(BuildContext context, Map<String, dynamic> data) {
    return Column(
      children: [
        buildRevenueChart(
          data: _parseRevenueData(data['revenue'] ?? {}),
          title: 'Revenue Trends',
          subtitle: 'Last 30 days performance',
        ),
        const SizedBox(height: 20),
        buildSalesChart(
          salesData: _parseSalesData(data['sales'] ?? {}),
          period: 'This Month',
        ),
        const SizedBox(height: 20),
        buildCustomerDemographics(
          demographics: _parseDemographicsData(data['demographics'] ?? {}),
          title: 'Customer Insights',
        ),
      ],
    );
  }

  static Widget _buildOrganizerProAnalytics(BuildContext context, Map<String, dynamic> data) {
    return Column(
      children: [
        buildUsageStatistics(
          stats: data['organizer_stats'] ?? {},
          period: 'Current Period',
        ),
        const SizedBox(height: 20),
        VendorPremiumDashboardComponents.buildPremiumMetricCard(
          title: 'Active Markets',
          value: (data['active_markets'] ?? 0).toString(),
          icon: Icons.store,
          color: Colors.blue,
        ),
      ],
    );
  }

  static Widget _buildEnterpriseAnalytics(BuildContext context, Map<String, dynamic> data) {
    return Column(
      children: [
        _buildVendorProAnalytics(context, data),
        const SizedBox(height: 20),
        VendorPremiumDashboardComponents.buildPremiumFeatureCard(
          title: 'Enterprise Dashboard',
          description: 'Advanced reporting and custom analytics',
          icon: Icons.business,
          color: Colors.deepPurple,
          onTap: () {},
        ),
      ],
    );
  }

  // Data parsing helpers

  static List<RevenueDatePoint> _parseRevenueData(Map<String, dynamic> revenueData) {
    // Mock data for now - in real implementation, parse actual revenue data
    return [
      RevenueDatePoint(DateTime.now().subtract(const Duration(days: 30)), 0),
      RevenueDatePoint(DateTime.now().subtract(const Duration(days: 20)), 150),
      RevenueDatePoint(DateTime.now().subtract(const Duration(days: 10)), 300),
      RevenueDatePoint(DateTime.now(), 450),
    ];
  }

  static List<SalesDataPoint> _parseSalesData(Map<String, dynamic> salesData) {
    // Mock data for now - in real implementation, parse actual sales data  
    return [
      SalesDataPoint('Mon', 12),
      SalesDataPoint('Tue', 19),
      SalesDataPoint('Wed', 3),
      SalesDataPoint('Thu', 5),
      SalesDataPoint('Fri', 22),
      SalesDataPoint('Sat', 34),
      SalesDataPoint('Sun', 18),
    ];
  }

  static Map<String, double> _parseDemographicsData(Map<String, dynamic> demographics) {
    // Mock data for now - in real implementation, parse actual demographics
    return {
      'Age 25-34': 35.0,
      'Age 35-44': 28.0,
      'Age 45-54': 22.0,
      'Age 55+': 10.0,
      'Age 18-24': 5.0,
    };
  }
}

// Data models for analytics

class RevenueDatePoint {
  final DateTime date;
  final double amount;
  
  RevenueDatePoint(this.date, this.amount);
}

class SalesDataPoint {
  final String label;
  final double value;
  
  SalesDataPoint(this.label, this.value);
}

class ProductPerformance {
  final String name;
  final int sales;
  final double revenue;
  final double performanceScore;
  
  ProductPerformance({
    required this.name,
    required this.sales,
    required this.revenue,
    required this.performanceScore,
  });
}