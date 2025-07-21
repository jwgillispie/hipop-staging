import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../models/vendor_post.dart';
import '../repositories/vendor_posts_repository.dart';
import '../widgets/vendor/vendor_calendar_widget.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/debug_account_switcher.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VendorPostsRepository _vendorPostsRepository = VendorPostsRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            title: const Text('Vendor Dashboard'),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            actions: [
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
            backgroundColor: Colors.orange,
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.store, color: Colors.white),
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
                Colors.orange,
                () => context.go('/vendor/popup-creation'),
              ),
              _buildActionCard(
                context,
                'My Pop-ups',
                'View and manage your pop-ups',
                Icons.event_available,
                Colors.teal,
                () => context.go('/vendor/my-popups'),
              ),
              _buildActionCard(
                context,
                'My Applications',
                'View application status',
                Icons.assignment,
                Colors.indigo,
                () => context.go('/vendor/applications'),
              ),
              _buildActionCard(
                context,
                'Market Invitations',
                'Manage market permissions',
                Icons.storefront,
                Colors.deepOrange,
                () => context.go('/vendor/market-permissions'),
              ),
              _buildActionCard(
                context,
                'Profile',
                'Edit your vendor profile',
                Icons.person,
                Colors.purple,
                () => context.go('/vendor/profile'),
              ),
              _buildActionCard(
                context,
                'Calendar',
                'View your events',
                Icons.calendar_today,
                Colors.blue,
                () => _tabController.animateTo(1), // Switch to calendar tab
              ),
              _buildActionCard(
                context,
                'Analytics',
                'View your performance',
                Icons.analytics,
                Colors.green,
                () => _showComingSoon(context),
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
                      backgroundColor: Colors.orange,
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
    VoidCallback onTap,
  ) {
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


  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('This feature is under development and will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
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