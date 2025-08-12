import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/features/vendor/services/vendor_premium_analytics_service.dart';
import 'package:hipop/features/vendor/services/vendor_customer_engagement_service.dart';
import 'package:hipop/features/vendor/services/vendor_premium_market_tools_service.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';

/// Demo screen showcasing premium vendor features
class VendorPremiumDemoScreen extends StatefulWidget {
  const VendorPremiumDemoScreen({super.key});

  @override
  State<VendorPremiumDemoScreen> createState() => _VendorPremiumDemoScreenState();
}

class _VendorPremiumDemoScreenState extends State<VendorPremiumDemoScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic> _revenueAnalytics = {};
  Map<String, dynamic> _customerInsights = {};
  Map<String, dynamic> _marketComparison = {};
  Map<String, dynamic> _directMessages = {};
  Map<String, dynamic> _loyaltyProgram = {};
  Map<String, dynamic> _customerFeedback = {};
  Map<String, dynamic> _bulkPostTemplates = {};
  Map<String, dynamic> _socialMediaStats = {};
  Map<String, dynamic> _brandingOptions = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load analytics data
      final revenueData = await VendorPremiumAnalyticsService.getRevenueAnalytics(
        vendorId: authState.user.uid,
      );
      final customerData = await VendorPremiumAnalyticsService.getCustomerInsights(
        vendorId: authState.user.uid,
      );
      final marketData = await VendorPremiumAnalyticsService.getMarketComparison(
        vendorId: authState.user.uid,
      );

      // Load engagement data
      final messagesData = await VendorCustomerEngagementService.getDirectMessages(
        vendorId: authState.user.uid,
      );
      final loyaltyData = await VendorCustomerEngagementService.getLoyaltyProgramAnalytics(
        vendorId: authState.user.uid,
      );
      final feedbackData = await VendorCustomerEngagementService.getCustomerFeedback(
        vendorId: authState.user.uid,
      );

      // Load market tools data
      final templatesData = await VendorPremiumMarketToolsService.getBulkPostTemplates(
        vendorId: authState.user.uid,
      );
      final socialData = await VendorPremiumMarketToolsService.getSocialMediaIntegration(
        vendorId: authState.user.uid,
      );
      final brandingData = await VendorPremiumMarketToolsService.getCustomBrandingOptions(
        vendorId: authState.user.uid,
      );

      if (mounted) {
        setState(() {
          _revenueAnalytics = revenueData;
          _customerInsights = customerData;
          _marketComparison = marketData;
          _directMessages = {'messages': messagesData};
          _loyaltyProgram = loyaltyData;
          _customerFeedback = feedbackData;
          _bulkPostTemplates = {'templates': templatesData};
          _socialMediaStats = socialData;
          _brandingOptions = brandingData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber),
            SizedBox(width: 8),
            Text('Vendor Pro Features'),
          ],
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.people), text: 'Customers'),
            Tab(icon: Icon(Icons.build), text: 'Tools'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading premium features...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAnalyticsTab(),
                _buildCustomerEngagementTab(),
                _buildMarketToolsTab(),
              ],
            ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Advanced Analytics Dashboard', Icons.analytics, Colors.blue),
          const SizedBox(height: 16),
          
          // Revenue Analytics
          _buildAnalyticsCard(
            'Revenue Tracking',
            'Track revenue across all markets',
            Icons.monetization_on,
            Colors.green,
            _revenueAnalytics.isNotEmpty ? [
              'Total Revenue: \$${_revenueAnalytics['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
              'Daily Average: \$${_revenueAnalytics['averageDailyRevenue']?.toStringAsFixed(2) ?? '0.00'}',
              'Growth Rate: ${_revenueAnalytics['revenueGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
            ] : ['Loading revenue data...'],
          ),
          
          const SizedBox(height: 16),
          
          // Customer Demographics
          _buildAnalyticsCard(
            'Customer Demographics',
            'Understand your customer base',
            Icons.people,
            Colors.purple,
            _customerInsights.isNotEmpty ? [
              'Total Customers: ${_customerInsights['totalCustomers'] ?? 0}',
              'Returning Rate: ${((_customerInsights['returningCustomerRate'] ?? 0) * 100).toStringAsFixed(1)}%',
              'Average Spend: \$${_customerInsights['averageSpend']?.toStringAsFixed(2) ?? '0.00'}',
              'Satisfaction: ${_customerInsights['customerSatisfaction']?.toStringAsFixed(1) ?? '0.0'}/5.0',
            ] : ['Loading customer data...'],
          ),
          
          const SizedBox(height: 16),
          
          // Market Performance
          _buildAnalyticsCard(
            'Market Performance',
            'Compare performance across markets',
            Icons.storefront,
            Colors.teal,
            _marketComparison.isNotEmpty && _marketComparison['marketComparisons'] != null ? [
              'Markets Analyzed: ${_marketComparison['marketComparisons'].length}',
              'Best Market: ${_marketComparison['bestPerformingMarket']?['marketName'] ?? 'N/A'}',
              'Top Revenue: \$${_marketComparison['bestPerformingMarket']?['revenue']?.toStringAsFixed(2) ?? '0.00'}',
            ] : ['Loading market data...'],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerEngagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Customer Engagement Tools', Icons.people, Colors.red),
          const SizedBox(height: 16),
          
          // Direct Messaging
          _buildEngagementCard(
            'Direct Messaging',
            'Communicate directly with customers',
            Icons.message,
            Colors.blue,
            _directMessages['messages'] != null ? [
              'Active Conversations: ${(_directMessages['messages'] as List).length}',
              'Unread Messages: ${(_directMessages['messages'] as List).fold(0, (sum, msg) => sum + ((msg['unreadCount'] ?? 0) as int))}',
              'Response Rate: 95%',
            ] : ['Loading messages...'],
            onTap: () => _showMessagingDemo(),
          ),
          
          const SizedBox(height: 16),
          
          // Loyalty Program
          _buildEngagementCard(
            'Loyalty Program Management',
            'Manage customer loyalty and rewards',
            Icons.loyalty,
            Colors.amber,
            _loyaltyProgram.isNotEmpty && _loyaltyProgram['programStats'] != null ? [
              'Total Members: ${_loyaltyProgram['programStats']['totalMembers'] ?? 0}',
              'Active Members: ${_loyaltyProgram['programStats']['activeMembers'] ?? 0}',
              'Retention Rate: ${((_loyaltyProgram['programStats']['memberRetentionRate'] ?? 0) * 100).toStringAsFixed(1)}%',
            ] : ['Loading loyalty data...'],
            onTap: () => _showLoyaltyProgramDemo(),
          ),
          
          const SizedBox(height: 16),
          
          // Customer Feedback
          _buildEngagementCard(
            'Customer Feedback Collection',
            'Gather and analyze customer reviews',
            Icons.feedback,
            Colors.orange,
            _customerFeedback.isNotEmpty ? [
              'Overall Rating: ${_customerFeedback['overallRating']?.toStringAsFixed(1) ?? '0.0'}/5.0',
              'Total Reviews: ${_customerFeedback['totalReviews'] ?? 0}',
              'Recent Reviews: ${_customerFeedback['recentReviews']?.length ?? 0} new',
            ] : ['Loading feedback data...'],
            onTap: () => _showFeedbackDemo(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Enhanced Market Tools', Icons.build, Colors.indigo),
          const SizedBox(height: 16),
          
          // Bulk Post Creation
          _buildToolCard(
            'Bulk Post Creation',
            'Create posts for multiple markets at once',
            Icons.post_add,
            Colors.green,
            _bulkPostTemplates['templates'] != null ? [
              'Saved Templates: ${(_bulkPostTemplates['templates'] as List).length}',
              'Most Used: ${(_bulkPostTemplates['templates'] as List).isNotEmpty ? (_bulkPostTemplates['templates'] as List).first['name'] : 'N/A'}',
              'Time Saved: ~5 hours/week',
            ] : ['Loading templates...'],
            onTap: () => _showBulkPostDemo(),
          ),
          
          const SizedBox(height: 16),
          
          // Custom Branding
          _buildToolCard(
            'Custom Branding Options',
            'Brand your posts with custom designs',
            Icons.palette,
            Colors.purple,
            _brandingOptions.isNotEmpty ? [
              'Branding: ${_brandingOptions['currentBranding']?['brandingEnabled'] == true ? 'Enabled' : 'Disabled'}',
              'Templates: ${_brandingOptions['availableTemplates']?.length ?? 0} available',
              'Customization: Full control',
            ] : ['Loading branding options...'],
            onTap: () => _showBrandingDemo(),
          ),
          
          const SizedBox(height: 16),
          
          // Social Media Integration
          _buildToolCard(
            'Social Media Integration',
            'Cross-post to social platforms automatically',
            Icons.share,
            Colors.pink,
            _socialMediaStats.isNotEmpty && _socialMediaStats['connectedPlatforms'] != null ? [
              'Connected Platforms: ${_getConnectedPlatformsCount(_socialMediaStats['connectedPlatforms'])}',
              'Total Followers: ${_getTotalFollowers(_socialMediaStats['connectedPlatforms'])}',
              'Cross-posting: ${_socialMediaStats['crossPostingStats']?['crossPostingEnabled'] == true ? 'Enabled' : 'Disabled'}',
            ] : ['Loading social media data...'],
            onTap: () => _showSocialMediaDemo(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String subtitle, IconData icon, Color color, List<String> stats) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...stats.map((stat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $stat',
                style: const TextStyle(fontSize: 14),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementCard(String title, String subtitle, IconData icon, Color color, List<String> stats, {VoidCallback? onTap}) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              ...stats.map((stat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $stat',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(String title, String subtitle, IconData icon, Color color, List<String> features, {VoidCallback? onTap}) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $feature',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // Demo dialog methods
  void _showMessagingDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Direct Messaging Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent customer messages:'),
            const SizedBox(height: 8),
            if (_directMessages['messages'] != null)
              ...(_directMessages['messages'] as List).take(3).map((msg) => 
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(msg['customerName'] ?? 'Customer'),
                  subtitle: Text(msg['lastMessage'] ?? 'Message'),
                  trailing: msg['unreadCount'] > 0 
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${msg['unreadCount']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      )
                    : null,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLoyaltyProgramDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Loyalty Program Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loyalty Program Tiers:'),
            const SizedBox(height: 8),
            if (_loyaltyProgram['tierDistribution'] != null)
              ...(_loyaltyProgram['tierDistribution'] as Map<String, dynamic>).entries.map((entry) =>
                ListTile(
                  leading: Icon(_getTierIcon(entry.key)),
                  title: Text('${entry.key} Members'),
                  trailing: Text('${entry.value}'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Feedback Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_customerFeedback['recentReviews'] != null)
              ...(_customerFeedback['recentReviews'] as List).take(2).map((review) =>
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(review['customerName'] ?? 'Customer'),
                  subtitle: Text(review['comment'] ?? 'Review'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text('${review['rating']}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBulkPostDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Post Creation Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Available Templates:'),
            const SizedBox(height: 8),
            if (_bulkPostTemplates['templates'] != null)
              ...(_bulkPostTemplates['templates'] as List).map((template) =>
                ListTile(
                  leading: const Icon(Icons.post_add),
                  title: Text(template['name'] ?? 'Template'),
                  subtitle: Text('Used ${template['useCount']} times'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBrandingDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Branding Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Available Branding Templates:'),
            const SizedBox(height: 8),
            if (_brandingOptions['availableTemplates'] != null)
              ...(_brandingOptions['availableTemplates'] as List).map((template) =>
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text(template['name'] ?? 'Template'),
                  subtitle: Text(template['description'] ?? 'Description'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSocialMediaDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Social Media Integration Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Connected Platforms:'),
            const SizedBox(height: 8),
            if (_socialMediaStats['connectedPlatforms'] != null)
              ...(_socialMediaStats['connectedPlatforms'] as Map<String, dynamic>).entries.map((entry) =>
                ListTile(
                  leading: Icon(_getSocialIcon(entry.key)),
                  title: Text(entry.key.toUpperCase()),
                  subtitle: Text('${entry.value['followers']} followers'),
                  trailing: entry.value['connected'] 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.circle_outlined, color: Colors.grey),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _getConnectedPlatformsCount(Map<String, dynamic> platforms) {
    return platforms.values.where((platform) => platform['connected'] == true).length;
  }

  int _getTotalFollowers(Map<String, dynamic> platforms) {
    return platforms.values.fold(0, (sum, platform) => sum + (platform['followers'] as int? ?? 0));
  }

  IconData _getTierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze': return Icons.looks_3;
      case 'silver': return Icons.looks_two;
      case 'gold': return Icons.looks_one;
      case 'platinum': return Icons.diamond;
      default: return Icons.person;
    }
  }

  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook': return Icons.facebook;
      case 'instagram': return Icons.camera_alt;
      case 'twitter': return Icons.alternate_email;
      default: return Icons.share;
    }
  }
}