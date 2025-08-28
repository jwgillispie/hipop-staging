import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/user_subscription.dart';
import '../services/staging_test_service.dart';
import '../services/payment_service.dart';
import '../services/revenuecat_service.dart';
import '../services/promotional_offers_service.dart';
import '../widgets/stripe_payment_form.dart';

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
  SubscriptionPricing? _selectedPricing;
  bool _isProcessing = false;
  bool _useRealPayments = true; // ENABLED for real payments!

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _isProcessing = false; // Explicitly ensure processing state is false
    debugPrint('🔄 PremiumOnboardingScreen initState - _isProcessing: $_isProcessing');
    _checkPaymentMode();
  }

  void _checkPaymentMode() {
    // Check if we should use real payments (production) or staging
    final isStaging = StagingTestService.isStagingEnvironment;
    setState(() {
      _useRealPayments = !isStaging;
      _isProcessing = false; // Ensure processing state is reset
    });
    debugPrint('💳 Payment mode: ${_useRealPayments ? 'REAL' : 'STAGING'}');
    debugPrint('🔄 _checkPaymentMode - _isProcessing reset to: $_isProcessing');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Upgrade to Premium',
          style: TextStyle(
            color: HiPopColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: HiPopColors.lightTextPrimary,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Use GoRouter navigation instead of Navigator.pop
            if (context.canPop()) {
              context.pop();
            } else {
              // If we can't pop, navigate to a safe route based on user type
              switch (widget.userType) {
                case 'vendor':
                  context.go('/vendor');
                  break;
                case 'market_organizer':
                  context.go('/organizer');
                  break;
                default:
                  context.go('/shopper');
                  break;
              }
            }
          },
        ),
        actions: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  color: HiPopColors.primaryDeepSage,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                color: index <= _currentPage ? HiPopColors.primaryDeepSage : HiPopColors.backgroundWarmGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32), // Top spacing instead of center alignment
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: HiPopColors.primaryOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch,
              size: 80,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _getWelcomeTitle(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getWelcomeDescription(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.lightTextSecondary,
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
          const SizedBox(height: 32), // Bottom spacing
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
            color: HiPopColors.primaryOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: HiPopColors.primaryDeepSage, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: HiPopColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: HiPopColors.lightTextSecondary,
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
              color: HiPopColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the plan that best fits your business needs',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.lightTextSecondary,
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
          onTap: () {
            debugPrint('\n📱 === PLAN TAPPED ===');
            debugPrint('🎯 Tier: $tier');
            debugPrint('👤 User type: ${widget.userType}');
            debugPrint('📋 Tier data: $tierData');
            
            setState(() {
              _selectedTier = tier;
              _selectedPlan = tierData;
              // Load pricing when tier is selected
              try {
                debugPrint('💳 Loading pricing for ${widget.userType}...');
                _selectedPricing = PaymentService.getPricingForUserType(widget.userType);
                debugPrint('✅ Pricing loaded successfully');
                debugPrint('💰 Price ID: ${_selectedPricing?.priceId}');
              } catch (e, stack) {
                debugPrint('❌ Error loading pricing for $tier: $e');
                debugPrint('📍 Stack trace: $stack');
              }
            });
            debugPrint('📱 === END PLAN TAP ===\n');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? HiPopColors.primaryDeepSage : HiPopColors.backgroundWarmGray.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? HiPopColors.primaryOpacity(0.05) : Colors.white,
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
                        color: HiPopColors.warningAmber,
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
                              color: isSelected ? HiPopColors.primaryDeepSage : HiPopColors.lightTextPrimary,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: HiPopColors.primaryDeepSage,
                              size: 24,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tierData['description'],
                        style: TextStyle(
                          color: HiPopColors.lightTextSecondary,
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
                              color: HiPopColors.primaryDeepSage,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/month',
                            style: TextStyle(
                              color: HiPopColors.lightTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Key Features:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: HiPopColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...((tierData['features'] as List<String>).map((feature) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check,
                                color: HiPopColors.primaryDeepSage,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: HiPopColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
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
            'tier': SubscriptionTier.vendorPremium,
            'title': 'Vendor Premium',
            'price': '\$29.00',
            'description': 'Perfect for growing food vendors and artisans',
            'recommended': true,
            'features': [
              'Advanced vendor analytics dashboard',
              'Unlimited market application posts',
              'Customer acquisition cost analysis',
              'Profit optimization strategies',
              'Market expansion recommendations',
              'Seasonal trends and planning tools',
              'Performance correlation insights',
              'Priority customer support',
            ],
          },
        ];
      case 'market_organizer':
        return [
          {
            'tier': SubscriptionTier.marketOrganizerPremium,
            'title': 'Market Organizer Premium',
            'price': '\$69.00',
            'description': 'Comprehensive tools for market management',
            'recommended': true,
            'features': [
              'Unlimited "Looking for Vendors" posts',
              'Vendor directory and discovery tools',
              'Vendor invitation and contact system',
              'Market performance analytics',
              'Vendor response management system',
              'Post performance tracking',
              'Vendor application insights',
              'Priority customer support',
            ],
          },
        ];
      default:
        return [
          {
            'tier': SubscriptionTier.vendorPremium,
            'title': 'Vendor Premium',
            'price': '\$29.00',
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

    final features = (_selectedPlan?['features'] as List<dynamic>?)?.cast<String>() ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedPlan?['title'] ?? 'Premium'} Features',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what you\'ll get with your ${_selectedPlan?['title'] ?? 'Premium'} subscription:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.lightTextSecondary,
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
                    color: HiPopColors.backgroundWarmGray.withValues(alpha: 0.2),
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
                      color: HiPopColors.primaryOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFeatureIcon(feature),
                      color: HiPopColors.primaryDeepSage,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: HiPopColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFeatureDescription(feature),
                          style: TextStyle(
                            color: HiPopColors.lightTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.accentMauve.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: HiPopColors.accentMauve,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can cancel anytime. Your subscription will remain active until the end of your billing period.',
                    style: TextStyle(
                      color: HiPopColors.lightTextPrimary,
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
    // Specific feature descriptions based on actual implementation
    final lower = feature.toLowerCase();
    
    // Vendor features
    if (lower.contains('customer acquisition cost')) {
      return 'Track and optimize your cost per customer with detailed CAC analysis';
    }
    if (lower.contains('profit optimization')) {
      return 'Data-driven strategies to maximize your profit margins and efficiency';
    }
    if (lower.contains('market expansion')) {
      return 'AI-powered recommendations for new markets based on your performance';
    }
    if (lower.contains('seasonal trends')) {
      return 'Plan your inventory and marketing around seasonal demand patterns';
    }
    
    // Market organizer features
    if (lower.contains('vendor directory')) {
      return 'Search and discover vendors with advanced filtering and analytics';
    }
    if (lower.contains('vendor invitation')) {
      return 'Send invitations directly to vendors for your market events';
    }
    if (lower.contains('unlimited') && lower.contains('posts')) {
      return 'Create as many vendor recruitment posts as needed';
    }
    if (lower.contains('vendor response')) {
      return 'Manage and track responses to your vendor recruitment posts';
    }
    
    // General features
    if (lower.contains('analytics') || lower.contains('dashboard')) {
      return 'Comprehensive insights into your performance and growth opportunities';
    }
    if (lower.contains('support') && lower.contains('priority')) {
      return 'Get priority help from our support team when you need it';
    }
    if (lower.contains('api')) {
      return 'Connect your data with other tools and build custom integrations';
    }
    if (lower.contains('enterprise') && lower.contains('sla')) {
      return 'Guaranteed uptime and response times for business-critical operations';
    }
    if (lower.contains('multi-location') || lower.contains('multi-market')) {
      return 'Manage multiple locations or markets from a single dashboard';
    }
    if (lower.contains('branding') || lower.contains('custom')) {
      return 'Customize the platform appearance and reports with your branding';
    }
    
    return 'Advanced feature to help grow your business';
  }

  Widget _buildPaymentPage() {
    try {
      debugPrint('\n🎨 === BUILDING PAYMENT PAGE ===');
      debugPrint('📊 _selectedPlan is null? ${_selectedPlan == null}');
      debugPrint('💳 _selectedPricing is null? ${_selectedPricing == null}');
      debugPrint('🌐 Platform: ${kIsWeb ? "Web" : "Mobile"}');
      
      if (_selectedPlan == null || _selectedPricing == null) {
        debugPrint('⚠️ Missing plan or pricing data');
        return const Center(
          child: Text('Please select a plan first'),
        );
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ User not authenticated');
        return const Center(
          child: Text('Please sign in to continue'),
        );
      }
      
      debugPrint('✅ All checks passed, building ${kIsWeb ? "Stripe" : "RevenueCat"} payment page');
      debugPrint('🎨 === END PAYMENT PAGE BUILD ===\n');
      
      // Check platform: Use RevenueCat for mobile, Stripe for web
      if (!kIsWeb) {
        return _buildRevenueCatPaymentPage();
      }
    } catch (e, stackTrace) {
      debugPrint('\n❌ === ERROR IN _buildPaymentPage ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace:\n$stackTrace');
      debugPrint('❌ === END ERROR ===\n');
      
      return Center(
        child: Text('Error: ${e.toString()}', style: const TextStyle(color: Colors.red)),
      );
    }
    
    // Stripe payment path for web
    final currentUser = FirebaseAuth.instance.currentUser!;
      
      // Use the price ID from the selected pricing
      String priceId = _selectedPricing?.priceId ?? '';
      
      // If no price ID from pricing, fall back to constructing it
      if (priceId.isEmpty && _selectedTier != null) {
        final isMonthly = _selectedPricing?.interval == 'month';
        switch (_selectedTier) {
          case SubscriptionTier.vendorPremium:
            priceId = isMonthly 
              ? 'price_vendorPremium_monthly' 
              : 'price_vendorPremium_annual';
            break;
          case SubscriptionTier.marketOrganizerPremium:
            priceId = isMonthly
              ? 'price_marketOrganizerPremium_monthly'
              : 'price_marketOrganizerPremium_annual';
            break;
          case SubscriptionTier.shopperPremium:
            priceId = isMonthly
              ? 'price_shopperPremium_monthly'
              : 'price_shopperPremium_annual';
            break;
          default:
            priceId = '';
        }
      }
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: StripePaymentForm(
          userId: currentUser.uid,
          userEmail: currentUser.email ?? '',
        userType: widget.userType,
        priceId: priceId,
        tier: _selectedPlan?['title'] ?? 'Premium',
        onSuccess: () {
          debugPrint('✅ Payment success callback triggered');
          try {
            if (mounted) {
              setState(() {
                _currentPage = 4; // Go to success page
                _isProcessing = false;
              });
              _pageController.animateToPage(
                4,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } catch (e) {
            debugPrint('❌ Error in onSuccess callback: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Payment error received: $error');
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            // Show error in a snackbar or dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: HiPopColors.errorPlum,
              ),
            );
          }
        },
      ),
    );
  }


  Widget _buildRevenueCatPaymentPage() {
    try {
      debugPrint('\n🔍 === BUILDING REVENUECAT PAYMENT PAGE ===');
      debugPrint('📊 _selectedPlan: $_selectedPlan');
      debugPrint('🎯 _selectedTier: $_selectedTier');
      debugPrint('💳 _selectedPricing: $_selectedPricing');
      
      // Set default plan if not already set
      if (_selectedPlan == null) {
        debugPrint('⚠️ _selectedPlan is null, attempting to set default...');
        final availableTiers = _getAvailableTiers();
        debugPrint('📋 Available tiers count: ${availableTiers.length}');
        
        if (availableTiers.isNotEmpty) {
          _selectedPlan = availableTiers.first;
          _selectedTier = _selectedPlan?['tier'];
          debugPrint('🌟 Setting default plan: ${_selectedPlan?['title']}');
        } else {
          debugPrint('❌ No available tiers found for user type: ${widget.userType}');
          return Center(
            child: Text('No subscription plans available for ${widget.userType}'),
          );
        }
      }
      
      // Debug each field access
      debugPrint('🔍 Accessing _selectedPlan fields...');
      final title = _selectedPlan?['title'];
      debugPrint('  - title: $title (type: ${title.runtimeType})');
      final price = _selectedPlan?['price'];
      debugPrint('  - price: $price (type: ${price.runtimeType})');
      final description = _selectedPlan?['description'];
      debugPrint('  - description: $description (type: ${description.runtimeType})');
      final features = _selectedPlan?['features'];
      debugPrint('  - features: $features (type: ${features.runtimeType})');
      debugPrint('🔍 === END PAYMENT PAGE BUILD ===\n');
      
      return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complete Your Purchase',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your payment will be processed securely through the App Store',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Show selected plan details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.primaryOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.primaryDeepSage.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPlan?['title'] ?? 'Premium Subscription',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_selectedPlan?['price'] ?? '\$29.00'}/month',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.primaryDeepSage,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedPlan?['subtitle'] ?? 'Premium subscription for your business',
                  style: TextStyle(
                    color: HiPopColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Purchase button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleRevenueCatPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
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
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Subscribe for ${_selectedPlan?['price'] ?? '\$29.00'}/month',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Restore purchases button
          Center(
            child: TextButton(
              onPressed: _isProcessing ? null : _handleRestorePurchases,
              child: Text(
                'Restore Previous Purchases',
                style: TextStyle(color: HiPopColors.primaryDeepSage),
              ),
            ),
          ),
          
          // Promo code button
          Center(
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _handlePromoCode,
              icon: const Icon(Icons.local_offer),
              label: const Text('Have a promo code?'),
              style: TextButton.styleFrom(
                foregroundColor: HiPopColors.primaryDeepSage,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Terms and conditions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HiPopColors.backgroundWarmGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Subscription Terms',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: HiPopColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Payment will be charged to your Apple ID account\n'
                  '• Subscription automatically renews monthly\n'
                  '• Cancel anytime in your device settings\n'
                  '• No refunds for partial months',
                  style: TextStyle(
                    fontSize: 11,
                    color: HiPopColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    } catch (e, stackTrace) {
      debugPrint('\n❌ === ERROR IN _buildRevenueCatPaymentPage ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace:\n$stackTrace');
      debugPrint('❌ === END ERROR ===\n');
      
      // Return an error widget instead of crashing
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Payment Page',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Error: ${e.toString()}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {
                  // Reset and try again
                  _selectedPlan = null;
                  _selectedTier = null;
                }),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleRevenueCatPurchase() async {
    debugPrint('🔄 _handleRevenueCatPurchase started');
    debugPrint('👤 User type: ${widget.userType}');
    debugPrint('🎯 Selected tier: $_selectedTier');
    
    setState(() => _isProcessing = true);
    
    try {
      // Initialize RevenueCat if not already done
      debugPrint('🔄 Initializing RevenueCat...');
      await RevenueCatService().initialize();
      debugPrint('✅ RevenueCat initialized');
      
      // Purchase subscription based on user type
      debugPrint('🛒 Starting purchase for user type: ${widget.userType}');
      final result = await RevenueCatService().purchaseSubscription(widget.userType);
      debugPrint('📦 Purchase result - Success: ${result.success}, Error: ${result.errorMessage}');
      
      if (result.success) {
        // Navigate to success page
        debugPrint('✅ Purchase successful, navigating to success page');
        
        // Add a delay to ensure RevenueCat has fully processed the purchase
        debugPrint('⏳ Waiting 2 seconds for RevenueCat processing...');
        await Future.delayed(const Duration(seconds: 2));
        
        // Force a manual sync to ensure Firebase is updated
        debugPrint('🔧 Forcing manual sync to Firebase...');
        try {
          await RevenueCatService().forceSyncToFirebase();
          debugPrint('✅ Manual sync completed');
        } catch (e) {
          debugPrint('❌ Manual sync failed: $e');
        }
        
        // Trigger auth reload to update premium status
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && mounted) {
          debugPrint('🔄 Triggering auth refresh after purchase');
          context.read<AuthBloc>().add(AuthUserChanged(currentUser));
        }
        
        if (mounted) {
          setState(() {
            _currentPage = 4; // Success page
            _isProcessing = false;
          });
          _pageController.animateToPage(
            4,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else {
        // Show error
        debugPrint('❌ Purchase failed: ${result.errorMessage}');
        if (mounted) {
          // Don't show error for cancellations
          final errorMessage = result.errorMessage ?? 'Purchase failed';
          if (!errorMessage.toLowerCase().contains('cancel')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: HiPopColors.errorPlum,
              ),
            );
          }
          setState(() => _isProcessing = false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Purchase error: $e');
      debugPrint('📝 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handlePromoCode() async {
    try {
      // This opens the native iOS promo code redemption sheet
      await Purchases.presentCodeRedemptionSheet();
      
      // After user enters code, check if they now have premium
      await Future.delayed(const Duration(seconds: 2));
      final hasSubscription = await RevenueCatService().hasActiveSubscription();
      
      if (hasSubscription && mounted) {
        // Navigate to success
        setState(() {
          _currentPage = 4;
          _isProcessing = false;
        });
        _pageController.animateToPage(
          4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint('❌ Promo code error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isProcessing = true);
    
    try {
      final customerInfo = await RevenueCatService().restorePurchases();
      
      if (customerInfo != null && customerInfo.entitlements.active.isNotEmpty) {
        // Purchases restored successfully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to success or close
          Navigator.of(context).pop(true);
        }
      } else {
        // No purchases to restore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No previous subscription found'),
              backgroundColor: HiPopColors.warningAmber,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Restore error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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
              color: HiPopColors.primaryOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Premium!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.primaryDeepSage,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your ${_selectedPlan?['title']} subscription is now active. You can start exploring all the premium features right away.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to appropriate premium dashboard based on user type
                switch (widget.userType) {
                  case 'market_organizer':
                    context.go('/organizer/premium-dashboard');
                    break;
                  case 'vendor':
                    context.go('/vendor/premium-dashboard');
                    break;
                  default:
                    // Fallback to main dashboard
                    _navigateToUserDashboard();
                    break;
                }
              },
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
            color: HiPopColors.backgroundWarmGray.withValues(alpha: 0.2),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: HiPopColors.primaryDeepSage,
                  side: BorderSide(color: HiPopColors.primaryDeepSage),
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
                backgroundColor: HiPopColors.primaryDeepSage,
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
        return _selectedTier != null ? () {
          // Load pricing information when moving to feature overview
          if (_selectedTier != null) {
            try {
              _selectedPricing = PaymentService.getPricingForUserType(widget.userType);
            } catch (e) {
              debugPrint('❌ Error loading pricing: $e');
            }
          }
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } : null;
      case 2:
        return () => _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      case 3:
        return null; // Payment page has its own button
      case 4:
        return () => _navigateToUserDashboard();
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
        return 'Go to Dashboard';
      default:
        return 'Next';
    }
  }


  String _getWelcomeTitle() {
    switch (widget.userType) {
      case 'market_organizer':
        return 'Ready to Transform Your Market Management?';
      case 'vendor':
        return 'Ready to Supercharge Your Vendor Business?';
      default:
        return 'Ready to Supercharge Your Business?';
    }
  }

  String _getWelcomeDescription() {
    switch (widget.userType) {
      case 'market_organizer':
        return 'Unlock powerful vendor recruitment tools, market analytics, and advanced features designed to help you build thriving markets.';
      case 'vendor':
        return 'Unlock powerful analytics, growth insights, and advanced features designed to help you succeed as a vendor for your pop-ps.';
      default:
        return 'Unlock powerful analytics, growth insights, and advanced features designed to help you succeed in the market ecosystem.';
    }
  }

  void _navigateToUserDashboard() {
    // Navigate back to the main dashboard front screen
    // Use GoRouter to properly navigate and clear the entire navigation stack
    switch (widget.userType) {
      case 'market_organizer':
        // Take them back to the organizer dashboard front screen
        context.go('/organizer');
        break;
      case 'vendor':
        // Take them back to the vendor dashboard front screen
        context.go('/vendor');
        break;
      case 'shopper':
        // Take them back to the shopper home screen
        context.go('/shopper');
        break;
      default:
        // Fallback - go to the auth landing page
        context.go('/auth');
        break;
    }
  }
}