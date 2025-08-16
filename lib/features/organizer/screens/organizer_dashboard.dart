import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/auth/services/onboarding_service.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import 'package:hipop/features/shared/widgets/debug_account_switcher.dart';
import 'package:hipop/features/shared/widgets/debug_database_cleaner.dart';

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _checkPremiumAccess();
  }

  Future<void> _checkOnboarding() async {
    try {
      final authState = context.read<AuthBloc>().state;
      
      // Only check onboarding for authenticated market organizers
      if (authState is! Authenticated || authState.userType != 'market_organizer') {
        return;
      }
      
      final isCompleted = await OnboardingService.isOrganizerOnboardingComplete();
      
      if (!isCompleted && mounted) {
        // Show onboarding after a short delay to let the dashboard load
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.pushNamed('organizerOnboarding');
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking onboarding: $e');
    }
  }

  Future<void> _checkPremiumAccess() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      try {
        // Check user profile directly for premium status (same logic as vendor dashboard)
        final userProfileService = UserProfileService();
        final userProfile = await userProfileService.getUserProfile(authState.user.uid);
        
        final hasAccess = userProfile?.isPremium ?? false;
        debugPrint('Organizer Premium access check: $hasAccess');
        debugPrint('Organizer User profile isPremium: ${userProfile?.isPremium}');
        debugPrint('Organizer User subscription status: ${userProfile?.subscriptionStatus}');
        
        if (mounted) {
          setState(() {
            _hasPremiumAccess = hasAccess;
            _isCheckingPremium = false;
          });
        }
      } catch (e) {
        debugPrint('ERROR: Error checking organizer premium access: $e');
        if (mounted) {
          setState(() {
            _hasPremiumAccess = false;
            _isCheckingPremium = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingPremium = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Market Organizer Dashboard'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            actions: [
              if (_hasPremiumAccess) ...[ 
                IconButton(
                  icon: const Icon(Icons.diamond),
                  tooltip: 'Premium Dashboard',
                  onPressed: () {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is Authenticated) {
                      context.go('/organizer/premium-dashboard');
                    }
                  },
                ),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onSelected: (String value) {
                  switch (value) {
                    case 'onboarding':
                      context.pushNamed('organizerOnboarding');
                      break;
                    case 'reset-onboarding':
                      _resetOnboarding();
                      break;
                    case 'profile':
                      context.pushNamed('organizerProfile');
                      break;
                    case 'change-password':
                      context.pushNamed('organizerChangePassword');
                      break;
                    case 'logout':
                      context.read<AuthBloc>().add(LogoutEvent());
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'onboarding',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Text('View Tutorial'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'change-password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Text('Change Password'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.grey),
                        SizedBox(width: 12),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Debug Account Switcher
                const DebugAccountSwitcher(),
                // Debug Database Cleaner
                const DebugDatabaseCleaner(),
                // Debug Market Creator

                // Welcome Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.storefront, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back!',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  state.user.displayName ?? state.user.email ?? 'Organizer',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildActionCard(
                      'Market Management',
                      'Create and manage markets',
                      Icons.storefront,
                      Colors.teal,
                      () => context.pushNamed('marketManagement'),
                    ),
                    _buildActionCard(
                      'Vendor Management',
                      'Create and manage vendors',
                      Icons.store_mall_directory,
                      Colors.indigo,
                      () => context.pushNamed('vendorManagement'),
                    ),
                    _buildActionCard(
                      'Event Management',
                      'Create special events',
                      Icons.event,
                      Colors.red,
                      () => context.pushNamed('eventManagement'),
                    ),
                    _buildActionCard(
                      'Vendor Connections',
                      'Connect with vendors',
                      Icons.people_alt,
                      Colors.orange,
                      () => context.pushNamed('vendorApplications'),
                    ),
                    _buildPremiumActionCard(
                      'Pro Dashboard',
                      'Premium analytics & insights',
                      Icons.analytics,
                      Colors.deepPurple,
                      () => context.pushNamed('organizerPremiumDashboard'),
                    ),
                    _buildActionCard(
                      'Market Calendar',
                      'View market schedules',
                      Icons.calendar_today,
                      Colors.teal,
                      () => context.pushNamed('organizerCalendar'),
                    ),
                    // Custom Items feature temporarily disabled
                    // _buildActionCard(
                    //   'Custom Items',
                    //   'Manage custom content',
                    //   Icons.tune,
                    //   Colors.purple,
                    //   () => context.pushNamed('customItems'),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _resetOnboarding() async {
    await OnboardingService.resetOrganizerOnboarding();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutorial reset! It will show again next time you open the dashboard.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVendorDiscoveryUpgrade() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Vendor Discovery - Premium Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Discovery helps you find and invite qualified vendors to your markets using intelligent matching algorithms.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Premium features include:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Smart vendor matching by categories'),
            Text('• Vendor ratings and performance metrics'),
            Text('• Bulk invitation capabilities'),
            Text('• Response tracking and analytics'),
            Text('• Advanced filtering and search'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                context.go('/premium/upgrade?tier=marketOrganizerPro&userId=${authState.user.uid}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade to Pro - \$69/month'),
          ),
        ],
      ),
    );
  }


}

