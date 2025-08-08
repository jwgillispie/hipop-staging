import 'package:flutter/material.dart';

/// Market Organizer Pro specific dashboard component
class MarketOrganizerProDashboard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MarketOrganizerProDashboard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(context),
          const SizedBox(height: 24),
          _buildMarketOverview(context),
          const SizedBox(height: 24),
          _buildVendorPerformance(context),
          const SizedBox(height: 24),
          _buildFinancialSummary(context),
          const SizedBox(height: 24),
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Total Revenue',
            '\$${(summary['totalRevenue'] ?? 0).toStringAsFixed(0)}',
            Icons.attach_money,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Total Markets',
            '${data['totalMarkets'] ?? 0}',
            Icons.store,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Total Vendors',
            '${summary['totalVendors'] ?? 0}',
            Icons.people,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Market Health',
            '${(summary['averageMarketHealth'] ?? 0).toStringAsFixed(1)}%',
            Icons.health_and_safety,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketOverview(BuildContext context) {
    final markets = data['markets'] as List<dynamic>? ?? [];
    
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
                  'Market Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to detailed market view
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (markets.isEmpty)
              const Center(
                child: Text('No markets configured'),
              )
            else
              ...markets.take(3).map((market) => 
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.store, color: Colors.blue.shade700),
                  ),
                  title: Text(market['name'] ?? 'Unknown Market'),
                  subtitle: Text('${market['vendorCount'] ?? 0} vendors'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(market['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      market['status'] ?? 'unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorPerformance(BuildContext context) {
    final vendorPerformance = data['vendorPerformance'] as Map<String, dynamic>? ?? {};
    final topPerformers = vendorPerformance['topPerformers'] as List<dynamic>? ?? [];
    
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
                  'Vendor Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Avg Score: ${vendorPerformance['averagePerformanceScore']?.toStringAsFixed(1) ?? '0.0'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (topPerformers.isEmpty)
              const Center(
                child: Text('No vendor performance data available'),
              )
            else
              ...topPerformers.take(3).map((vendor) => 
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.person, color: Colors.green.shade700),
                  ),
                  title: Text(vendor['name'] ?? 'Unknown Vendor'),
                  subtitle: Text('Score: ${vendor['score']?.toStringAsFixed(1) ?? '0.0'}'),
                  trailing: const Icon(Icons.trending_up, color: Colors.green),
                ),
              ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(BuildContext context) {
    final financialSummary = data['financialSummary'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialMetric(
                    'Total Revenue',
                    '\$${(financialSummary['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildFinancialMetric(
                    'Monthly Growth',
                    '${((financialSummary['monthlyGrowth'] ?? 0) * 100).toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildFinancialMetric(
                    'Profit Margin',
                    '${((financialSummary['profitMargin'] ?? 0) * 100).toStringAsFixed(1)}%',
                    Colors.purple,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final quickActions = data['quickActions'] as List<dynamic>? ?? [];
    
    if (quickActions.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...quickActions.take(3).map((action) => 
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _getActionIcon(action['action']),
                  color: _getUrgencyColor(action['urgency']),
                ),
                title: Text(action['action'] ?? 'Action'),
                subtitle: Text(action['description'] ?? ''),
                trailing: ElevatedButton(
                  onPressed: () {
                    // Handle action
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getUrgencyColor(action['urgency']),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text(
                    'Act',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                dense: true,
              ),
            ).toList(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String? action) {
    if (action?.contains('vendor') == true) {
      return Icons.people;
    } else if (action?.contains('application') == true) {
      return Icons.assignment;
    } else if (action?.contains('market') == true) {
      return Icons.store;
    } else {
      return Icons.task_alt;
    }
  }

  Color _getUrgencyColor(String? urgency) {
    switch (urgency) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}