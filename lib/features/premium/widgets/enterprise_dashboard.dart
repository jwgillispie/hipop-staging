import 'package:flutter/material.dart';

/// Enterprise tier specific dashboard component
class EnterpriseDashboard extends StatelessWidget {
  final Map<String, dynamic> data;

  const EnterpriseDashboard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExecutiveSummary(context),
          const SizedBox(height: 24),
          _buildMultiMarketAnalytics(context),
          const SizedBox(height: 24),
          _buildFinancialPerformance(context),
          const SizedBox(height: 24),
          _buildVendorEcosystem(context),
          const SizedBox(height: 24),
          _buildSystemStatus(context),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummary(BuildContext context) {
    final summary = data['executiveSummary'] as Map<String, dynamic>? ?? {};
    final keyMetrics = summary['keyMetrics'] as Map<String, dynamic>? ?? {};
    
    return Card(
      elevation: 6,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Executive Summary',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildExecutiveMetric(
                      'Total Revenue',
                      '\$${(keyMetrics['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                      Icons.attach_money,
                    ),
                  ),
                  Expanded(
                    child: _buildExecutiveMetric(
                      'Monthly Growth',
                      '${((keyMetrics['monthlyGrowth'] ?? 0) * 100).toStringAsFixed(1)}%',
                      Icons.trending_up,
                    ),
                  ),
                  Expanded(
                    child: _buildExecutiveMetric(
                      'Market Health',
                      '${(keyMetrics['marketHealth'] ?? 0).toStringAsFixed(1)}%',
                      Icons.health_and_safety,
                    ),
                  ),
                  Expanded(
                    child: _buildExecutiveMetric(
                      'Customer Sat.',
                      '${((keyMetrics['customerSatisfaction'] ?? 0) * 100).toStringAsFixed(0)}%',
                      Icons.sentiment_satisfied,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildHighlights(summary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHighlights(Map<String, dynamic> summary) {
    final highlights = summary['highlights'] as List<dynamic>? ?? [];
    final concerns = summary['concerns'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (highlights.isNotEmpty) ...[
          const Text(
            'Key Highlights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...highlights.take(2).map((highlight) => 
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highlight.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (concerns.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Areas of Concern',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...concerns.take(2).map((concern) => 
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    concern.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiMarketAnalytics(BuildContext context) {
    final multiMarket = data['multiMarketAnalytics'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Multi-Market Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${multiMarket['totalMarkets'] ?? 0} Markets',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Total Revenue',
                    '\$${(multiMarket['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Total Vendors',
                    '${multiMarket['totalVendors'] ?? 0}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Total Events',
                    '${multiMarket['totalEvents'] ?? 0}',
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Avg Health',
                    '${(multiMarket['averageMarketHealth'] ?? 0).toStringAsFixed(1)}%',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFinancialPerformance(BuildContext context) {
    final financial = data['financialPerformance'] as Map<String, dynamic>? ?? {};
    final revenueStreams = financial['revenueStreams'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildFinancialMetric(
                        'Total Revenue',
                        '\$${(financial['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildFinancialMetric(
                        'Monthly Growth',
                        '${((financial['monthlyGrowth'] ?? 0) * 100).toStringAsFixed(1)}%',
                        Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildFinancialMetric(
                        'Profit Margin',
                        '${((financial['profitMargin'] ?? 0) * 100).toStringAsFixed(1)}%',
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Revenue Streams',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...revenueStreams.entries.map((entry) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '\$${entry.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildFinancialMetric(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildVendorEcosystem(BuildContext context) {
    final vendorEcosystem = data['vendorEcosystem'] as Map<String, dynamic>? ?? {};
    final categoryDistribution = vendorEcosystem['categoryDistribution'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Ecosystem',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildVendorMetric(
                        'Total Vendors',
                        '${vendorEcosystem['totalVendors'] ?? 0}',
                        Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildVendorMetric(
                        'Active Vendors',
                        '${vendorEcosystem['activeVendors'] ?? 0}',
                        Colors.green,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildVendorMetric(
                        'Top Performers',
                        '${vendorEcosystem['topPerformers'] ?? 0}',
                        Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      _buildVendorMetric(
                        'Retention Rate',
                        '${((vendorEcosystem['retentionRate'] ?? 0) * 100).toStringAsFixed(0)}%',
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category Distribution',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...categoryDistribution.entries.take(4).map((entry) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                '${entry.value}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildVendorMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSystemStatus(BuildContext context) {
    final integrationStatus = data['integrationStatus'] as Map<String, dynamic>? ?? {};
    final apiUsage = data['apiUsage'] as Map<String, dynamic>? ?? {};
    final whiteLabel = data['whiteLabel'] as Map<String, dynamic>? ?? {};
    final alerts = data['realTimeAlerts'] as List<dynamic>? ?? [];
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusItem(
                    'API Usage',
                    '${apiUsage['monthlyRequests'] ?? 0}/${_calculateApiLimit(apiUsage)}',
                    (apiUsage['rateLimitUtilization'] ?? 0.0) < 0.8 ? Colors.green : Colors.orange,
                  ),
                  _buildStatusItem(
                    'Integrations',
                    '${integrationStatus['activeIntegrations'] ?? 0}/${integrationStatus['totalIntegrations'] ?? 0}',
                    integrationStatus['syncHealth'] == 'good' ? Colors.green : Colors.orange,
                  ),
                  _buildStatusItem(
                    'White-Label',
                    whiteLabel['isConfigured'] == true ? 'Active' : 'Inactive',
                    whiteLabel['isConfigured'] == true ? Colors.green : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Real-Time Alerts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (alerts.isEmpty)
                    const Text(
                      'No active alerts',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    )
                  else
                    ...alerts.take(3).map((alert) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              _getAlertIcon(alert['priority']),
                              color: _getAlertColor(alert['priority']),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert['message'] ?? 'Alert',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(String? priority) {
    switch (priority) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getAlertColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  /// Calculate API limit safely, avoiding division by zero and NaN values
  int _calculateApiLimit(Map<String, dynamic> apiUsage) {
    final monthlyRequests = (apiUsage['monthlyRequests'] as num?)?.toInt() ?? 0;
    final rateLimitUtilization = (apiUsage['rateLimitUtilization'] as num?)?.toDouble();
    
    // Handle null or zero utilization to avoid division by zero
    if (rateLimitUtilization == null || rateLimitUtilization <= 0.0) {
      return 10000; // Default API limit
    }
    
    // Calculate the limit: requests / utilization = total limit
    // Since utilization = requests / limit, then limit = requests / utilization
    final calculatedLimit = monthlyRequests / rateLimitUtilization;
    
    // Ensure we don't return NaN or infinite values
    if (calculatedLimit.isNaN || calculatedLimit.isInfinite || calculatedLimit <= 0) {
      return 10000; // Fallback to default
    }
    
    return calculatedLimit.round();
  }
}