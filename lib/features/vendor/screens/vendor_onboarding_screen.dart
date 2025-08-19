import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/features/auth/services/onboarding_service.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() async {
    await OnboardingService.markVendorOnboardingComplete();
    if (mounted) {
      context.go('/vendor');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar and skip button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / _totalPages,
                      backgroundColor: HiPopColors.vendorAccent.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: HiPopColors.vendorAccentDark),
                    ),
                  ),
                ],
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildPopupCreationPage(),
                  _buildMarketApplicationsPage(),
                  _buildProductManagementPage(),
                  _buildAnalyticsPage(),
                  _buildGetStartedPage(),
                ],
              ),
            ),
            
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                border: Border(top: BorderSide(color: HiPopColors.darkBorder)),
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.vendorAccentDark,
                          side: BorderSide(color: HiPopColors.vendorAccent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.vendorAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(_currentPage == _totalPages - 1 ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront,
              size: 80,
              color: HiPopColors.vendorAccentDark,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Welcome to HiPop!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re now a Vendor! Let us show you how to grow your business and connect with customers at local markets.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.vendorAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HiPopColors.vendorAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: HiPopColors.warningAmber,
                  size: 24,
                ),
                const SizedBox(height: 12),
                Text(
                  'What you\'ll learn:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '• Creating vendor pop-up posts\n'
                  '• Discovering and joining markets\n'
                  '• Managing your product catalog\n'
                  '• Tracking sales and analytics\n'
                  '• Growing your vendor business',
                  style: TextStyle(fontSize: 14, color: HiPopColors.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupCreationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HiPopColors.infoBlueGray.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event,
              size: 70,
              color: HiPopColors.infoBlueGrayDark,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Create Pop-up Posts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Share your pop-up events with the community. Let customers know when and where to find you at markets.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.vendorAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.location_on,
                  'Set Your Location',
                  'Add precise location details for customers',
                  HiPopColors.errorPlum,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.schedule,
                  'Schedule Your Time',
                  'Set date, time, and duration',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.description,
                  'Describe Your Offerings',
                  'Tell customers what to expect',
                  HiPopColors.successGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.warningAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.warningAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: HiPopColors.warningAmber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free: 3 pop-up posts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.warningAmberDark,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Premium: Unlimited pop-up posts',
                        style: TextStyle(
                          color: HiPopColors.warningAmberDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketApplicationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.explore,
              size: 70,
              color: HiPopColors.successGreen,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Discover Markets',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Find farmers markets looking for vendors. Connect with market organizers and join markets that match your business.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.vendorAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.search,
                  'Browse Markets',
                  'Find markets actively recruiting vendors',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.campaign,
                  'View Recruitment Posts',
                  'See what markets are looking for',
                  HiPopColors.accentMauve,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.connect_without_contact,
                  'Connect with Organizers',
                  'Reach out to join their markets',
                  HiPopColors.successGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.infoBlueGray.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates, color: HiPopColors.infoBlueGray, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Complete your vendor profile to stand out to market organizers!',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.infoBlueGrayDark,
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

  Widget _buildProductManagementPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HiPopColors.accentMauve.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory,
              size: 70,
              color: HiPopColors.accentMauve,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Manage Products',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Showcase your products to customers. Add photos, descriptions, and pricing to attract buyers.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.vendorAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.add_photo_alternate,
                  'Add Product Photos',
                  'Showcase your items with images',
                  HiPopColors.accentDustyRose,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.description,
                  'Product Descriptions',
                  'Detailed info and pricing',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.category,
                  'Organize by Category',
                  'Group similar products together',
                  HiPopColors.successGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.surfacePalePink.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HiPopColors.vendorAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Free',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.vendorAccentDark,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '3 products',
                        style: TextStyle(
                          color: HiPopColors.vendorAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HiPopColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Vendor Premium',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.successGreen,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Unlimited products',
                        style: TextStyle(
                          color: HiPopColors.successGreen,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HiPopColors.primaryDeepSage.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics,
              size: 70,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Track Your Success',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Monitor your business performance with sales tracking, customer insights, and market analytics.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.vendorAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.trending_up,
                  'Sales Tracking',
                  'Monitor revenue and transactions',
                  HiPopColors.successGreen,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.people,
                  'Customer Insights',
                  'See who\'s engaging with your business',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.assessment,
                  'Market Analytics',
                  'Track your market performance',
                  HiPopColors.accentMauve,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.accentMauve.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.accentMauve.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: HiPopColors.accentMauve, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vendor Premium includes advanced analytics dashboard with detailed insights',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.accentMauve,
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

  Widget _buildGetStartedPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch,
              size: 80,
              color: HiPopColors.vendorAccentDark,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'You\'re Ready to Sell!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You now know how to grow your vendor business with HiPop. Let\'s set up your first pop-up post!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.vendorAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.checklist,
                  color: HiPopColors.vendorAccent,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  'Quick Start Checklist',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.lightTextPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildChecklistItem('✓ Complete your vendor profile'),
                _buildChecklistItem('✓ Add your product listings'),
                _buildChecklistItem('✓ Create your first pop-up post'),
                _buildChecklistItem('✓ Discover and join markets'),
                _buildChecklistItem('✓ Track your sales and analytics'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: HiPopColors.successGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Consider upgrading to Vendor Premium (\$29/month) for unlimited posts and advanced analytics!',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.infoBlueGray.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent, color: HiPopColors.infoBlueGray, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Need help? You can always replay this onboarding from the settings menu.',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.infoBlueGrayDark,
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

  Widget _buildFeatureItem(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: HiPopColors.lightTextPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: HiPopColors.lightTextSecondary,
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

  Widget _buildChecklistItem(String text) {
    final bool isChecked = text.startsWith('✓');
    final String displayText = isChecked ? text.substring(2) : text;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isChecked ? HiPopColors.successGreen : Colors.transparent,
              border: Border.all(
                color: isChecked ? HiPopColors.successGreen : HiPopColors.vendorAccent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isChecked
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.lightTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}