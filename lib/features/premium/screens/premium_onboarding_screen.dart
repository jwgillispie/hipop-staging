import 'package:flutter/material.dart';
import '../models/user_subscription.dart';
import '../services/subscription_service.dart';
import '../services/stripe_service.dart';

/// Premium onboarding screen that guides users through tier selection and setup
class PremiumOnboardingScreen extends StatefulWidget {
  final String userId;
  final String userType;

  const PremiumOnboardingScreen({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  State<PremiumOnboardingScreen> createState() => _PremiumOnboardingScreenState();
}

class _PremiumOnboardingScreenState extends State<PremiumOnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  SubscriptionTier? _selectedTier;
  Map<String, dynamic>? _selectedPlan;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              child: const Text('Back'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildWelcomePage(),
                _buildTierSelectionPage(),
                _buildFeatureOverviewPage(),
                _buildPaymentPage(),
                _buildSuccessPage(),
              ],
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(5, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentPage ? Colors.blue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch,
              size: 80,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Ready to Supercharge Your Business?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock powerful analytics, growth insights, and advanced features designed to help you succeed in the farmers market ecosystem.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),
          _buildBenefitItem(
            Icons.analytics,
            'Advanced Analytics',
            'Deep insights into your performance and growth opportunities',
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(
            Icons.trending_up,
            'Growth Optimization',
            'AI-powered recommendations to maximize your revenue',
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(
            Icons.support_agent,
            'Priority Support',
            'Get help when you need it with dedicated customer success',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.green.shade600, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierSelectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Plan',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the plan that best fits your business needs',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ..._buildTierCards(),
        ],
      ),
    );
  }

  List<Widget> _buildTierCards() {
    final availableTiers = _getAvailableTiers();
    
    return availableTiers.map((tierData) {
      final tier = tierData['tier'] as SubscriptionTier;
      final isSelected = _selectedTier == tier;
      final isRecommended = tierData['recommended'] == true;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedTier = tier;
            _selectedPlan = tierData;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? Colors.blue.shade50 : Colors.white,
            ),
            child: Stack(
              children: [
                if (isRecommended)
                  Positioned(
                    top: 0,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'RECOMMENDED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tierData['title'],
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.blue.shade700 : null,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Colors.blue.shade600,
                              size: 24,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tierData['description'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tierData['price'],
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/month',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Key Features:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...((tierData['features'] as List<String>).take(4).map((feature) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check,
                                color: Colors.green.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList()),
                      if ((tierData['features'] as List<String>).length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${(tierData['features'] as List<String>).length - 4} more features',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getAvailableTiers() {
    switch (widget.userType) {
      case 'vendor':
        return [
          {
            'tier': SubscriptionTier.vendorPro,
            'title': 'Vendor Pro',
            'price': '\$19.99',
            'description': 'Perfect for growing food vendors and artisans',
            'recommended': true,
            'features': [
              'Full vendor analytics dashboard',
              'Unlimited market participation',
              'Customer acquisition analysis',
              'Profit optimization insights',
              'Market expansion recommendations',
              'Seasonal business planning',
              'Weather correlation data',
              'Priority customer support',
            ],
          },
          {
            'tier': SubscriptionTier.enterprise,
            'title': 'Enterprise',
            'price': '\$199.99',
            'description': 'For large vendor operations and multi-market presence',
            'features': [
              'Everything in Vendor Pro',
              'White-label analytics platform',
              'Custom API access',
              'Advanced data integrations',
              'Dedicated account manager',
              'Custom reporting and branding',
              'Enterprise-grade SLA',
              'Multi-location management',
            ],
          },
        ];
      case 'market_organizer':
        return [
          {
            'tier': SubscriptionTier.marketOrganizerPro,
            'title': 'Market Organizer Pro',
            'price': '\$49.99',
            'description': 'Comprehensive tools for market management',
            'recommended': true,
            'features': [
              'Multi-market management dashboard',
              'Vendor performance analytics',
              'Financial forecasting tools',
              'Automated vendor recruitment',
              'Market intelligence reports',
              'Budget planning and tracking',
              'Vendor ranking system',
              'Advanced reporting suite',
            ],
          },
          {
            'tier': SubscriptionTier.enterprise,
            'title': 'Enterprise',
            'price': '\$199.99',
            'description': 'For market management companies and large operations',
            'features': [
              'Everything in Market Organizer Pro',
              'White-label platform',
              'Custom API access',
              'Advanced integrations',
              'Dedicated account manager',
              'Custom branding and reports',
              'Enterprise SLA',
              'Multi-tenant management',
            ],
          },
        ];
      default:
        return [
          {
            'tier': SubscriptionTier.vendorPro,
            'title': 'Vendor Pro',
            'price': '\$19.99',
            'description': 'Great for individual vendors',
            'features': [
              'Advanced analytics',
              'Growth optimization',
              'Market insights',
              'Priority support',
            ],
          },
        ];
    }
  }

  Widget _buildFeatureOverviewPage() {
    if (_selectedPlan == null) return const SizedBox();

    final features = _selectedPlan!['features'] as List<String>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedPlan!['title']} Features',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what you\'ll get with your ${_selectedPlan!['title']} subscription:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ...features.map((feature) => 
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFeatureIcon(feature),
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFeatureDescription(feature),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).toList(),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can cancel anytime. Your subscription will remain active until the end of your billing period.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
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

  IconData _getFeatureIcon(String feature) {
    if (feature.toLowerCase().contains('analytics')) return Icons.analytics;
    if (feature.toLowerCase().contains('dashboard')) return Icons.dashboard;
    if (feature.toLowerCase().contains('support')) return Icons.support_agent;
    if (feature.toLowerCase().contains('api')) return Icons.api;
    if (feature.toLowerCase().contains('white-label')) return Icons.palette;
    if (feature.toLowerCase().contains('forecast')) return Icons.trending_up;
    if (feature.toLowerCase().contains('vendor')) return Icons.people;
    if (feature.toLowerCase().contains('market')) return Icons.store;
    return Icons.star;
  }

  String _getFeatureDescription(String feature) {
    // Simplified feature descriptions
    if (feature.toLowerCase().contains('analytics')) {
      return 'Comprehensive data insights to understand your business performance';
    }
    if (feature.toLowerCase().contains('optimization')) {
      return 'AI-powered recommendations to increase your revenue and efficiency';
    }
    if (feature.toLowerCase().contains('support')) {
      return 'Get help from our expert team when you need it most';
    }
    if (feature.toLowerCase().contains('api')) {
      return 'Connect your data with other tools and build custom integrations';
    }
    if (feature.toLowerCase().contains('white-label')) {
      return 'Customize the platform with your own branding and colors';
    }
    return 'Advanced feature to help grow your business';
  }

  Widget _buildPaymentPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complete Your Subscription',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          if (_selectedPlan != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Summary',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Plan:', style: TextStyle(color: Colors.grey.shade600)),
                      Text(
                        _selectedPlan!['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Billing:', style: TextStyle(color: Colors.grey.shade600)),
                      Text(
                        'Monthly',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_selectedPlan!['price']}/month',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Subscribe Now - ${_selectedPlan!['price']}/month',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'By subscribing, you agree to our Terms of Service and Privacy Policy. You can cancel anytime from your account settings.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Premium!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your ${_selectedPlan?['title']} subscription is now active. You can start exploring all the premium features right away.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/premium/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Explore Premium Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue with Current Screen'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: const Text('Previous'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentPage == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _getNextButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getNextButtonAction() {
    switch (_currentPage) {
      case 0:
        return () => _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      case 1:
        return _selectedTier != null ? () => _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ) : null;
      case 2:
        return () => _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      case 3:
        return null; // Payment page has its own button
      case 4:
        return () => Navigator.pop(context);
      default:
        return null;
    }
  }

  String _getNextButtonText() {
    switch (_currentPage) {
      case 0:
        return 'Get Started';
      case 1:
        return _selectedTier != null ? 'Continue' : 'Select a Plan';
      case 2:
        return 'Proceed to Payment';
      case 3:
        return 'Processing...';
      case 4:
        return 'Done';
      default:
        return 'Next';
    }
  }

  Future<void> _processSubscription() async {
    if (_selectedTier == null || _selectedPlan == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // In a real implementation, this would integrate with Stripe
      // For now, we'll simulate the subscription upgrade
      await SubscriptionService.upgradeToTier(widget.userId, _selectedTier!);
      
      // Navigate to success page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process subscription: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }
}