import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../blocs/subscription/subscription_bloc.dart';
import '../blocs/subscription/subscription_state.dart';
import '../features/premium/widgets/feature_gate_widget.dart';
import '../features/premium/widgets/subscription_tier_badge.dart';
import '../features/premium/widgets/premium_access_controls.dart';
import '../features/premium/widgets/vendor_premium_dashboard_components.dart';
import '../features/premium/models/user_subscription.dart';

/// Example screen demonstrating Phase 2 premium features integration
/// 
/// This example showcases:
/// - FeatureGateWidget for access control
/// - SubscriptionTierBadge for status display
/// - Advanced analytics with fl_chart
/// - Real-time subscription state management
/// - Premium access controls and upgrade flows
class PremiumFeaturesExampleScreen extends StatefulWidget {
  const PremiumFeaturesExampleScreen({super.key});

  @override
  State<PremiumFeaturesExampleScreen> createState() => _PremiumFeaturesExampleScreenState();
}

class _PremiumFeaturesExampleScreenState extends State<PremiumFeaturesExampleScreen> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Features Demo'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          // Subscription tier badge in app bar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
              builder: (context, state) {
                if (state is SubscriptionLoaded) {
                  return SubscriptionTierBadge(
                    subscription: state.subscription,
                    size: BadgeSize.small,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription status overview
            _buildSubscriptionStatusSection(),
            const SizedBox(height: 24),
            
            // Premium feature examples
            _buildPremiumFeatureExamples(),
            const SizedBox(height: 24),
            
            // Advanced analytics (gated feature)
            _buildAdvancedAnalyticsSection(),
            const SizedBox(height: 24),
            
            // Usage tracking and limits
            _buildUsageTrackingSection(),
            const SizedBox(height: 24),
            
            // Premium teasers and upgrade prompts
            _buildPremiumTeasersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscription Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Real-time subscription status
            PremiumAccessControls.buildSubscriptionStatus(
              context: context,
              showTierBadge: true,
              showExpirationInfo: true,
              showUsageIndicators: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeatureExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feature Access Control Examples',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Example 1: Premium Analytics Feature
        FeatureGateWidget(
          featureName: 'product_performance_analytics',
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.analytics, size: 48, color: Colors.green.shade600),
                  const SizedBox(height: 8),
                  const Text(
                    'Premium Analytics Unlocked!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('You have access to advanced analytics features.'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Example 2: Revenue Tracking Feature
        FeatureGateWidget(
          featureName: 'revenue_tracking',
          showUsageLimit: true,
          usageLimitName: 'revenue_entries',
          currentUsage: 15,
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.attach_money, size: 48, color: Colors.blue.shade600),
                  const SizedBox(height: 8),
                  const Text(
                    'Revenue Tracking Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Track your sales and revenue in real-time.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Advanced Analytics (Premium Feature)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Wrap analytics in feature gate
        FeatureGateWidget(
          featureName: 'product_performance_analytics',
          child: Column(
            children: [
              // Revenue chart example
              VendorPremiumDashboardComponents.buildAdvancedAnalyticsChart(
                title: 'Revenue Trends',
                subtitle: 'Last 30 days',
                dataPoints: _generateSampleData(),
                primaryColor: Colors.green,
                showAreaChart: true,
                height: 250,
              ),
              const SizedBox(height: 16),
              
              // Pie chart example
              VendorPremiumDashboardComponents.buildPieChart(
                title: 'Market Distribution',
                subtitle: 'Revenue by market',
                sections: _generatePieChartData(),
                height: 200,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageTrackingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Usage Tracking & Limits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Usage tracking widget
        VendorPremiumDashboardComponents.buildUsageTracking(
          title: 'Current Usage',
          usageData: {
            'Markets Joined': {'current': 3, 'limit': 5},
            'Product Lists': {'current': 1, 'limit': 1},
            'Photo Uploads': {'current': 8, 'limit': 10},
            'Global Products': {'current': 2, 'limit': 3},
          },
        ),
        const SizedBox(height: 16),
        
        // Usage limit warning example
        PremiumAccessControls.buildUsageLimitWarning(
          context: context,
          limitName: 'global_products',
          currentUsage: 3,
          limit: 3,
          customMessage: 'You\'ve reached your limit for global products. Upgrade to add unlimited products!',
        ),
      ],
    );
  }

  Widget _buildPremiumTeasersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premium Features Available',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Feature teaser 1
        PremiumAccessControls.buildPremiumFeatureTeaser(
          context: context,
          title: 'Market Discovery',
          description: 'Find premium markets tailored to your products with AI-powered matching.',
          icon: Icons.explore,
          color: Colors.purple,
          benefits: [
            'Access to exclusive markets',
            'Smart market recommendations',
            'Priority vendor placement',
            'Early market notifications',
          ],
        ),
        const SizedBox(height: 16),
        
        // Feature teaser 2
        PremiumAccessControls.buildPremiumFeatureTeaser(
          context: context,
          title: 'Bulk Messaging',
          description: 'Send personalized messages to all your customers at once.',
          icon: Icons.message,
          color: Colors.orange,
          benefits: [
            'Unlimited customer messaging',
            'Template management',
            'Scheduled sending',
            'Engagement analytics',
          ],
        ),
        const SizedBox(height: 16),
        
        // General upgrade prompt
        VendorPremiumDashboardComponents.buildUpgradePrompt(
          context,
          customMessage: 'Ready to unlock all premium features?',
        ),
        const SizedBox(height: 16),
        
        // Upgrade button
        Center(
          child: PremiumAccessControls.buildUpgradeButton(
            context: context,
            userType: 'vendor',
            size: ButtonSize.large,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _generateSampleData() {
    return [
      const FlSpot(0, 100),
      const FlSpot(1, 120),
      const FlSpot(2, 80),
      const FlSpot(3, 150),
      const FlSpot(4, 200),
      const FlSpot(5, 180),
      const FlSpot(6, 250),
      const FlSpot(7, 300),
      const FlSpot(8, 280),
      const FlSpot(9, 320),
      const FlSpot(10, 350),
      const FlSpot(11, 400),
    ];
  }

  List<PieChartSectionData> _generatePieChartData() {
    return [
      PieChartSectionData(
        value: 40,
        color: Colors.blue,
        title: 'Downtown',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 30,
        color: Colors.green,
        title: 'Farmers Market',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 20,
        color: Colors.orange,
        title: 'Art District',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 10,
        color: Colors.purple,
        title: 'Others',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }
}

/// Example widget showing subscription state integration
class SubscriptionStateExample extends StatelessWidget {
  const SubscriptionStateExample({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subscription State Debug',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                Text('State: ${state.runtimeType}'),
                
                if (state is SubscriptionLoaded) ...[
                  Text('Tier: ${state.subscription.tier.name}'),
                  Text('Status: ${state.subscription.status.name}'),
                  Text('Is Premium: ${state.subscription.isPremium}'),
                  Text('Features: ${state.featureAccess.length}'),
                  Text('Limits: ${state.usageLimits.length}'),
                ],
                
                if (state is SubscriptionError) ...[
                  Text('Error: ${state.message}'),
                ],
                
                if (state is SubscriptionExpirationWarning) ...[
                  Text('Warning: ${state.message}'),
                  Text('Severity: ${state.severity.name}'),
                ],
                
                if (state is BillingIssueDetected) ...[
                  Text('Billing Issue: ${state.issueMessage}'),
                  Text('Severity: ${state.severity.name}'),
                  Text('Action Required: ${state.actionRequired}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}