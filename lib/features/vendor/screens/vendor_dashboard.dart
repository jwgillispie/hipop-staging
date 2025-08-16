import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_calendar_widget.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:hipop/features/shared/widgets/debug_account_switcher.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VendorPostsRepository _vendorPostsRepository = VendorPostsRepository();
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPremiumAccess();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check premium access when dependencies change (e.g., after hot restart)
    _checkPremiumAccess();
  }

  Future<void> _checkPremiumAccess() async {
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    debugPrint('Checking premium access - Auth state: ${authState.runtimeType}');
    
    if (authState is Authenticated) {
      try {
        setState(() {
          _isCheckingPremium = true;
        });

        // Check user profile directly for premium status
        final userProfileService = UserProfileService();
        final userProfile = await userProfileService.getUserProfile(authState.user.uid);
        
        final hasAccess = userProfile?.isPremium == true && 
                         (userProfile?.subscriptionStatus == 'active' || 
                          userProfile?.stripeSubscriptionId?.isNotEmpty == true);
        
        debugPrint('');
        debugPrint('========= PREMIUM ACCESS CHECK =========');
        debugPrint('User ID: ${authState.user.uid}');
        debugPrint('User Email: ${authState.user.email}');
        debugPrint('Has Premium Access: $hasAccess');
        debugPrint('Profile isPremium: ${userProfile?.isPremium}');
        debugPrint('Subscription Status: ${userProfile?.subscriptionStatus}');
        debugPrint('Stripe Sub ID: ${userProfile?.stripeSubscriptionId}');
        debugPrint('Stripe Customer ID: ${userProfile?.stripeCustomerId}');
        debugPrint('Timestamp: ${DateTime.now()}');
        debugPrint('===================================');
        debugPrint('');
        
        if (mounted) {
          setState(() {
            _hasPremiumAccess = hasAccess;
            _isCheckingPremium = false;
          });
        }
      } catch (e) {
        debugPrint('');
        debugPrint('========= PREMIUM ACCESS ERROR =========');
        debugPrint('Error: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
        debugPrint('===================================');
        debugPrint('');
        
        if (mounted) {
          setState(() {
            _hasPremiumAccess = false;
            _isCheckingPremium = false;
          });
        }
      }
    } else {
      debugPrint('WARNING: User not authenticated - resetting premium access');
      if (mounted) {
        setState(() {
          _hasPremiumAccess = false;
          _isCheckingPremium = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // Re-check premium access when auth state changes (e.g., after hot restart)
        if (state is Authenticated) {
          _checkPremiumAccess();
        }
      },
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
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
                      context.go('/vendor/premium-dashboard');
                    }
                  },
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
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(context, state),
              _buildCalendarTab(context, state),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.go('/vendor/popup-creation'),
            backgroundColor: HiPopColors.primaryDeepSage,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildDashboardTab(BuildContext context, Authenticated state) {
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
                
                // Premium Access Debug Info
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCheckingPremium 
                      ? HiPopColors.infoBlueGrayLight.withValues(alpha: 0.1)
                      : _hasPremiumAccess 
                        ? HiPopColors.successGreenLight.withValues(alpha: 0.1) 
                        : HiPopColors.surfacePalePink,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isCheckingPremium 
                        ? HiPopColors.infoBlueGray
                        : _hasPremiumAccess 
                          ? HiPopColors.successGreen 
                          : HiPopColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isCheckingPremium) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Checking Premium Access...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.infoBlueGray,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          _hasPremiumAccess ? Icons.diamond : Icons.info_outline,
                          color: _hasPremiumAccess ? HiPopColors.successGreen : HiPopColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasPremiumAccess 
                            ? 'Premium Access: ACTIVE' 
                            : 'Premium Access: NOT ACTIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _hasPremiumAccess ? HiPopColors.successGreenDark : HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: HiPopColors.vendorAccent,
                              child: const Icon(Icons.store, color: Colors.white),
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
                                  state.user.displayName ?? state.user.email ?? 'Vendor',
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
                Text(
                  'Quick Actions',
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildListDelegate([
              _buildActionCard(
                context,
                'Create Pop-up',
                'Independent or market events',
                Icons.add_business,
                HiPopColors.vendorAccent,
                () => context.go('/vendor/popup-creation'),
              ),
              _buildActionCard(
                context,
                'My Pop-ups',
                'View and manage your pop-ups',
                Icons.event_available,
                HiPopColors.primaryDeepSage,
                () => context.go('/vendor/my-popups'),
              ),
              // TEMPORARILY HIDDEN: Vendor Applications (only showing permissions for now)
              // _buildActionCard(
              //   context,
              //   'My Applications',
              //   'View application status',
              //   Icons.assignment,
              //   Colors.indigo,
              //   () => context.go('/vendor/applications'),
              // ),
              _buildActionCard(
                context,
                'Market Discovery',
                'Find markets seeking vendors',
                Icons.search,
                HiPopColors.premiumGold,
                () => context.go('/vendor/market-discovery'),
                isPremium: !_hasPremiumAccess,
              ),
              _buildActionCard(
                context,
                'Products & Market Items',
                'Manage your products and market assignments',
                Icons.inventory_2,
                HiPopColors.accentDustyPlum,
                () => context.go('/vendor/products-management'),
              ),
              _buildActionCard(
                context,
                'Profile',
                'Edit your vendor profile',
                Icons.person,
                HiPopColors.accentMauve,
                () => context.go('/vendor/profile'),
              ),
              _buildActionCard(
                context,
                'Sales Tracker',
                'Track daily sales & revenue',
                Icons.attach_money,
                HiPopColors.successGreen,
                () => context.go('/vendor/sales-tracker'),
              ),
              _buildActionCard(
                context,
                'Analytics',
                'View performance insights',
                Icons.analytics,
                HiPopColors.accentMauveDark,
                () => context.go('/vendor/analytics'),
              ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16), // Bottom padding
        ),
      ],
    );
  }

  Widget _buildCalendarTab(BuildContext context, Authenticated state) {
    return StreamBuilder<List<VendorPost>>(
      stream: _vendorPostsRepository.getVendorPosts(state.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorDisplayWidget(
            title: 'Error Loading Events',
            message: 'Failed to load your events: ${snapshot.error}',
            onRetry: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          return const LoadingWidget(message: 'Loading your events...');
        }

        final posts = snapshot.data!;

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
                    onPressed: () => context.go('/vendor/create-popup'),
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
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isPremium = false,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isPremium) ...[
                      Icon(
                        Icons.diamond,
                        size: 16,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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