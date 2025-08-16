import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

/// Vendor Pro specific dashboard component
class VendorProDashboard extends StatelessWidget {
  final Map<String, dynamic> data;

  const VendorProDashboard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(context),
          const SizedBox(height: 24),
          _buildGrowthMetricsSection(context),
          const SizedBox(height: 24),
          _buildRecommendationsSection(context),
          const SizedBox(height: 24),
          _buildAlertsSection(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Growth Score',
            '${summary['growthScore']?.toStringAsFixed(1) ?? '0.0'}',
            Icons.trending_up,
            HiPopColors.successGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context,
            'CAC/CLV Ratio',
            '1:${(summary['clvRatio'] ?? 3.2).toStringAsFixed(1)}',
            Icons.people,
            HiPopColors.infoBlueGray,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Profit Margin',
            '${(summary['profitMargin'] ?? 0.35 * 100).toStringAsFixed(1)}%',
            Icons.attach_money,
            HiPopColors.accentMauve,
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

  Widget _buildGrowthMetricsSection(BuildContext context) {
    final growthMetrics = data['growthMetrics'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Growth Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Revenue Growth',
                    '${((growthMetrics['revenueGrowthRate'] ?? 0.12) * 100).toStringAsFixed(1)}%',
                    HiPopColors.successGreen,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Customer Growth',
                    '${((growthMetrics['customerGrowthRate'] ?? 0.18) * 100).toStringAsFixed(1)}%',
                    HiPopColors.infoBlueGray,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Market Share',
                    '${((growthMetrics['marketShareGrowth'] ?? 0.08) * 100).toStringAsFixed(1)}%',
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

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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

  Widget _buildRecommendationsSection(BuildContext context) {
    final recommendations = data['recommendations'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Growth Recommendations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (recommendations.isEmpty)
              const Text('No recommendations available')
            else
              ...recommendations.take(3).map((rec) => 
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lightbulb, color: Colors.amber),
                  title: Text(rec.toString()),
                  dense: true,
                ),
              ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    final alerts = data['alerts'] as List<dynamic>? ?? [];
    
    if (alerts.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Growth Alerts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...alerts.take(2).map((alert) => 
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _getAlertIcon(alert['urgency']),
                  color: _getAlertColor(alert['urgency']),
                ),
                title: Text(alert['message'] ?? 'Alert'),
                subtitle: alert['action'] != null ? Text(alert['action']) : null,
                dense: true,
              ),
            ).toList(),
          ],
        ),
      ),
    );
  }

  IconData _getAlertIcon(String? urgency) {
    switch (urgency) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getAlertColor(String? urgency) {
    switch (urgency) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}