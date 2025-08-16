import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/features/auth/services/onboarding_service.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class OrganizerOnboardingScreen extends StatefulWidget {
  const OrganizerOnboardingScreen({super.key});

  @override
  State<OrganizerOnboardingScreen> createState() => _OrganizerOnboardingScreenState();
}

class _OrganizerOnboardingScreenState extends State<OrganizerOnboardingScreen> {
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
    await OnboardingService.markOrganizerOnboardingComplete();
    if (mounted) {
      context.go('/organizer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.surfacePalePink.withValues(alpha: 0.3),
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
                      backgroundColor: HiPopColors.organizerAccent.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.organizerAccent),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: HiPopColors.organizerAccentDark),
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
                  _buildMarketManagementPage(),
                  _buildVendorApplicationsPage(),
                  _buildAnalyticsPage(),
                  _buildCalendarPage(),
                  _buildGetStartedPage(),
                ],
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.organizerAccentDark,
                          side: BorderSide(color: HiPopColors.organizerAccent.withValues(alpha: 0.4)),
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
                        backgroundColor: HiPopColors.organizerAccent,
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
              color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront,
              size: 80,
              color: HiPopColors.organizerAccentDark,
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
          const SizedBox(height: 40),
          Text(
            'You\'re now a Market Organizer! Let us show you how to manage your farmers market with ease.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.organizerAccentDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HiPopColors.organizerAccent.withValues(alpha: 0.3)),
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
                  '• How to create and manage your market\n'
                  '• Processing vendor applications\n'
                  '• Viewing analytics and insights\n'
                  '• Using the market calendar\n'
                  '• Getting started with your first market',
                  style: TextStyle(fontSize: 14, color: HiPopColors.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketManagementPage() {
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
              Icons.storefront,
              size: 70,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Market Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Create and manage your farmers markets with detailed information, operating schedules, and location data.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.organizerAccentDark,
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
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.add_location,
                  'Add Market Details',
                  'Name, address, and description',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.schedule,
                  'Set Operating Hours',
                  'Days and times your market is open',
                  HiPopColors.vendorAccent,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.visibility,
                  'Make It Public',
                  'Shoppers can discover your market',
                  HiPopColors.successGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorApplicationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HiPopColors.vendorAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_turned_in,
              size: 70,
              color: HiPopColors.vendorAccentDark,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Vendor Connections',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Manage vendor connections with ease. Share application links and review connections in one place.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.organizerAccentDark,
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
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.share,
                  'Share Application Links',
                  'Send vendors a direct link to apply',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.rate_review,
                  'Review Applications',
                  'Approve, reject, or waitlist vendors',
                  HiPopColors.accentMauve,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.notifications,
                  'Get Notified',
                  'Receive new applications instantly',
                  HiPopColors.successGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
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
                    'Tip: The application form collects all vendor info automatically - no paper forms needed!',
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

  Widget _buildAnalyticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics,
              size: 70,
              color: HiPopColors.organizerAccentDark,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Analytics Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Track your market\'s performance with analytics. Upgrade to Market Organizer Pro (\$69/month) for advanced insights, vendor directory, and unlimited features.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.organizerAccentDark,
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
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.trending_up,
                  'Vendor Metrics',
                  'Active, pending, and approved vendors',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.download,
                  'Export Data',
                  'Download reports for offline analysis',
                  HiPopColors.accentMauve,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.workspace_premium,
                  'Vendor Directory (Pro)',
                  'Search & filter all vendors with premium',
                  HiPopColors.warningAmber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '24',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.organizerAccentDark,
                        ),
                      ),
                      Text(
                        'Active Vendors',
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.organizerAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '12',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.vendorAccentDark,
                        ),
                      ),
                      Text(
                        'Pending Apps',
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.vendorAccent,
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

  Widget _buildCalendarPage() {
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
              Icons.calendar_today,
              size: 70,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Market Calendar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Visualize your market schedules and operating days in an easy-to-read calendar format.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.organizerAccentDark,
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
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.event,
                  'Operating Schedule',
                  'See all your market operating days',
                  HiPopColors.infoBlueGray,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.schedule,
                  'Real-time Status',
                  'Know which markets are open now',
                  HiPopColors.successGreen,
                ),
                const Divider(),
                _buildFeatureItem(
                  Icons.calendar_view_month,
                  'Monthly View',
                  'Plan ahead with calendar overview',
                  HiPopColors.accentMauve,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.lightBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: HiPopColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Market Operating', style: TextStyle(fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: HiPopColors.vendorAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Selected Day', style: TextStyle(fontSize: 12))),
                  ],
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
              color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch,
              size: 80,
              color: HiPopColors.organizerAccentDark,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'You\'re All Set!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You now know how to manage your farmers market with HiPop. Let\'s create your first market!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HiPopColors.organizerAccentDark,
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
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.checklist,
                  color: HiPopColors.organizerAccent,
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
                _buildChecklistItem('Create your first market'),
                _buildChecklistItem('Set operating hours and location'),
                _buildChecklistItem('Share the vendor application link'),
                _buildChecklistItem('Review and approve applications'),
                _buildChecklistItem('Monitor analytics and growth'),
                _buildChecklistItem('Consider Pro for vendor directory access'),
              ],
            ),
          ),
          const SizedBox(height: 40),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: HiPopColors.organizerAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: HiPopColors.darkTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}