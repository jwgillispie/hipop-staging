import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/vendor/vendor_dashboard_bloc.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_calendar_widget.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:hipop/features/shared/widgets/debug_account_switcher.dart';
import 'package:hipop/features/shared/services/welcome_notification_service.dart';
import 'package:hipop/features/shared/widgets/welcome_notification_dialog.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WelcomeNotificationService _welcomeService = WelcomeNotificationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkWelcomeNotification();
  }
  
  Future<void> _checkWelcomeNotification() async {
    // Delay slightly to let the dashboard render first
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    
    try {
      final ceoNotes = await _welcomeService.checkAndGetWelcomeNotes(authState.user.uid);
      
      if (ceoNotes != null && mounted) {
        await WelcomeNotificationDialog.show(
          context: context,
          ceoNotes: ceoNotes,
          userType: 'vendor',
          onDismiss: () async {
            await _welcomeService.markWelcomeNotificationShown(authState.user.uid);
          },
        );
      }
    } catch (e) {
      debugPrint('Error checking welcome notification: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated) {
          return VendorDashboardBloc()..add(LoadVendorDashboard(authState.user.uid));
        }
        return VendorDashboardBloc();
      },
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, authState) {
          // Re-check premium access when auth state changes
          if (authState is Authenticated) {
            context.read<VendorDashboardBloc>().add(CheckPremiumAccess(authState.user.uid));
          }
        },
        builder: (context, authState) {
          if (authState is! Authenticated) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return BlocBuilder<VendorDashboardBloc, VendorDashboardState>(
            builder: (context, vendorState) {
              return Scaffold(
                appBar: _buildAppBar(context, authState, vendorState),
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(context, authState, vendorState),
                    _buildCalendarTab(context, authState, vendorState),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Authenticated authState,
    VendorDashboardState vendorState,
  ) {
    final bool isCheckingPremium = vendorState is VendorDashboardLoaded && vendorState.isCheckingPremium;
    final bool hasPremiumAccess = vendorState is VendorDashboardLoaded && vendorState.hasPremiumAccess;

    return AppBar(
      title: const Text('Vendor Dashboard'),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HiPopColors.secondarySoftSage,
              HiPopColors.accentMauve,
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (isCheckingPremium) ...[
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
        ] else if (hasPremiumAccess) ...[
          IconButton(
            icon: const Icon(Icons.diamond),
            tooltip: 'Premium Dashboard',
            onPressed: () => context.push('/vendor/premium-dashboard'),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(context),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
          Tab(text: 'Calendar', icon: Icon(Icons.calendar_today)),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    Authenticated authState,
    VendorDashboardState vendorState,
  ) {
    final bool isCheckingPremium = vendorState is VendorDashboardLoaded && vendorState.isCheckingPremium;
    final bool hasPremiumAccess = vendorState is VendorDashboardLoaded && vendorState.hasPremiumAccess;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Debug Account Switcher
                const DebugAccountSwitcher(),
                
                // Premium Dashboard Button (shown only when premium is active)
                if (hasPremiumAccess) ...[
                  GestureDetector(
                    onTap: () => context.push('/vendor/premium-dashboard'),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            HiPopColors.premiumGold,
                            HiPopColors.premiumGold.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: HiPopColors.premiumGold.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.diamond,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Premium Dashboard',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Access exclusive tools & insights',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Welcome Back Card with dark design
                Card(
                  color: HiPopColors.darkSurface,
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: HiPopColors.vendorAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.store,
                            color: HiPopColors.vendorAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authState.user.displayName ?? authState.user.email ?? 'Vendor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
              // Prominent Create Pop-up button
              _buildCreatePopupButton(context),
              const SizedBox(height: 20),
              _buildDashboardOption(
                context,
                'My Pop-ups',
                'View and manage your pop-ups',
                Icons.event_available,
                HiPopColors.primaryDeepSage,
                () => context.push('/vendor/my-popups'),
              ),
              const SizedBox(height: 12),
              _buildDashboardOption(
                context,
                'Analytics',
                'View performance insights',
                Icons.analytics,
                HiPopColors.accentMauveDark,
                () => context.push('/vendor/analytics'),
                isPremium: true,
              ),
              const SizedBox(height: 12),
              _buildDashboardOption(
                context,
                'Products & Market Items',
                'Manage your products and market assignments',
                Icons.inventory_2,
                HiPopColors.accentDustyPlum,
                () => context.push('/vendor/products-management'),
              ),
              const SizedBox(height: 12),
              _buildDashboardOption(
                context,
                'Market Discovery',
                'Find markets seeking vendors',
                Icons.search,
                HiPopColors.premiumGold,
                () => context.push('/vendor/market-discovery'),
              ),
              const SizedBox(height: 12),
              _buildDashboardOption(
                context,
                'Sales Tracker',
                'Track daily sales & revenue',
                Icons.attach_money,
                HiPopColors.successGreen,
                () => context.push('/vendor/sales-tracker'),
              ),
              const SizedBox(height: 12),
              _buildDashboardOption(
                context,
                'Settings',
                'Manage your account and preferences',
                Icons.settings,
                HiPopColors.infoBlueGray,
                () => context.push('/vendor/settings'),
              ),
              const SizedBox(height: 12),
              _buildDashboardOption(
                context,
                'Profile',
                'Edit your vendor profile',
                Icons.person,
                HiPopColors.accentMauve,
                () => context.push('/vendor/profile'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab(
    BuildContext context,
    Authenticated authState,
    VendorDashboardState vendorState,
  ) {
    if (vendorState is VendorDashboardLoading) {
      return const LoadingWidget(message: 'Loading your events...');
    }

    if (vendorState is VendorDashboardError) {
      return ErrorDisplayWidget(
        title: 'Error Loading Events',
        message: 'Failed to load your events: ${vendorState.message}',
        onRetry: () {
          context.read<VendorDashboardBloc>().add(LoadVendorDashboard(authState.user.uid));
        },
      );
    }

    if (vendorState is VendorDashboardLoaded) {
      final posts = vendorState.vendorPosts;

      if (posts.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No events yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first pop-up event to see it in the calendar.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/vendor/create-popup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.primaryDeepSage,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Pop-up'),
                ),
              ],
            ),
          ),
        );
      }

      return SingleChildScrollView(
        child: VendorCalendarWidget(
          posts: posts,
          onDateSelected: (date, postsForDay) {
            // Optional: Add functionality for date selection
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCreatePopupButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.vendorAccent,
            HiPopColors.primaryDeepSage,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.vendorAccent.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/vendor/popup-creation'),
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
                        'Create Pop-up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start a new independent or market event',
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
            blurRadius: 4,
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(LogoutEvent());
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}