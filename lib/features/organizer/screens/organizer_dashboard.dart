import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/auth/services/onboarding_service.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import 'package:hipop/features/shared/services/welcome_notification_service.dart';
import 'package:hipop/features/shared/widgets/welcome_notification_dialog.dart';
import 'package:hipop/features/shared/widgets/debug_account_switcher.dart';
import 'package:hipop/features/shared/widgets/debug_database_cleaner.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  final WelcomeNotificationService _welcomeService = WelcomeNotificationService();
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _checkPremiumAccess();
    _checkWelcomeNotification();
  }
  
  Future<void> _checkWelcomeNotification() async {
    // Delay slightly to let the dashboard render first
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    
    try {
      final ceoNotes = await _welcomeService.checkAndGetWelcomeNotes(authState.user.uid);
      
      if (ceoNotes != null && mounted) {
        await WelcomeNotificationDialog.show(
          context: context,
          ceoNotes: ceoNotes,
          userType: 'market_organizer',
          onDismiss: () async {
            await _welcomeService.markWelcomeNotificationShown(authState.user.uid);
          },
        );
      }
    } catch (e) {
      debugPrint('Error checking welcome notification: $e');
    }
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
          appBar: HiPopAppBar(
            title: 'Market Dashboard',
            userRole: 'organizer',
            centerTitle: true,
            actions: [
              if (_isCheckingPremium) ...[
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ] else if (_hasPremiumAccess) ...[
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
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () => context.read<AuthBloc>().add(LogoutEvent()),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Debug Account Switcher
                      const DebugAccountSwitcher(),
                      // Debug Database Cleaner
                      const DebugDatabaseCleaner(),
                      
                      // Welcome Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: HiPopColors.organizerAccent,
                                    child: const Icon(Icons.storefront, color: Colors.white),
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
                      const SizedBox(height: 16),
                      
                      // Trust-Based System Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HiPopColors.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HiPopColors.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              color: HiPopColors.successGreen,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trust-Based System Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: HiPopColors.successGreen,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'All markets and vendor posts are automatically approved',
                                    style: TextStyle(
                                      color: HiPopColors.darkTextSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Prominent Create Market button
                    _buildCreateMarketButton(context),
                    const SizedBox(height: 20),
                    _buildDashboardOption(
                      context,
                      'My Markets',
                      'View and manage your markets',
                      Icons.storefront,
                      HiPopColors.organizerAccent,
                      () => context.pushNamed('marketManagement'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Analytics',
                      'View performance insights',
                      Icons.analytics,
                      Colors.deepPurple,
                      () => context.pushNamed('organizerPremiumDashboard'),
                      isPremium: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Vendor Management',
                      'Manage vendors and their posts',
                      Icons.store_mall_directory,
                      HiPopColors.primaryDeepSage,
                      () => context.pushNamed('vendorManagement'),
                    ),
                    const SizedBox(height: 12),
                    // _buildDashboardOption(
                    //   context,
                    //   'Vendor Connections',
                    //   'Review and manage vendor connections',
                    //   Icons.people_alt,
                    //   HiPopColors.accentMauve,
                    //   () => context.pushNamed('vendorApplications'),
                    // ),
                    // const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Event Management',
                      'Create and manage special events',
                      Icons.event,
                      HiPopColors.warningAmber,
                      () => context.pushNamed('eventManagement'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Market Calendar',
                      'View market schedules and events',
                      Icons.calendar_today,
                      HiPopColors.infoBlueGray,
                      () => context.pushNamed('organizerCalendar'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Settings',
                      'Manage account and preferences',
                      Icons.settings,
                      HiPopColors.accentDustyPlum,
                      () => _showSettingsMenu(context),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Profile',
                      'Edit your organizer profile',
                      Icons.person,
                      HiPopColors.successGreen,
                      () => context.pushNamed('organizerProfile'),
                    ),
                  ]),
                ),
              ),
            ],
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

  Widget _buildCreateMarketButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.organizerAccent,
            HiPopColors.primaryDeepSage,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.organizerAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed('marketManagement'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_business,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Market',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Post a new market!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap, {
    bool isPremium = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.lightShadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon container on the left
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Title and description in the middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPremium) ...[
                            Icon(
                              Icons.diamond,
                              size: 16,
                              color: HiPopColors.premiumGold,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow indicator on the right
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blue),
              title: const Text('View Tutorial'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('organizerOnboarding');
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Reset Tutorial'),
              onTap: () {
                Navigator.pop(context);
                _resetOnboarding();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.grey),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('organizerChangePassword');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(LogoutEvent());
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


}

