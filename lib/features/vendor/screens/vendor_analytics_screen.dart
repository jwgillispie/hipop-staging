import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/subscription/subscription_bloc.dart';
import 'package:hipop/blocs/subscription/subscription_state.dart';
import 'package:hipop/blocs/subscription/subscription_event.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/premium/widgets/vendor_premium_dashboard_components.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';
import 'package:hipop/core/widgets/metric_card.dart';
import 'package:hipop/core/widgets/premium_upgrade_card.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  Stream<List<VendorPost>>? _postsStream;
  Stream<Map<String, int>>? _analyticsStream;
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      _postsStream = _getVendorPosts(_currentUserId!);
      _analyticsStream = _getAnalytics(_currentUserId!);
      _checkPremiumAccessWithBloc(_currentUserId!);
    }
  }

  Future<void> _checkPremiumAccessWithBloc(String vendorId) async {
    // Check premium access using AuthBloc userProfile
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final userProfile = authState.userProfile;
      final hasAccess = userProfile?.isPremium ?? false;
      
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
          _isCheckingPremium = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasPremiumAccess = false;
          _isCheckingPremium = false;
        });
      }
    }
  }

  Stream<List<VendorPost>> _getVendorPosts(String vendorId) {
    return Stream.fromFuture(
      FirebaseFirestore.instance
        .collection('vendor_posts')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit results to prevent large queries
        .get()
        .timeout(const Duration(seconds: 10))
        .then((snapshot) {
          debugPrint('Loaded ${snapshot.docs.length} vendor posts');
          return snapshot.docs
              .map((doc) => VendorPost.fromFirestore(doc))
              .toList();
        })
        .catchError((error) {
          debugPrint('Error loading vendor posts: $error');
          return <VendorPost>[];
        }),
    );
  }

  Stream<Map<String, int>> _getAnalytics(String vendorId) {
    return Stream.fromFuture(
      Future.wait([
        // Get aggregated daily analytics
        FirebaseFirestore.instance
          .collection('vendor_daily_analytics')
          .where('vendorId', isEqualTo: vendorId)
          .where('date', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
          .get()
          .timeout(const Duration(seconds: 10)),
        // Get individual analytics events for more detailed analysis
        FirebaseFirestore.instance
          .collection('analytics')
          .where('vendorId', isEqualTo: vendorId)
          .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
          .limit(500) // Reduced limit for performance
          .get()
          .timeout(const Duration(seconds: 10)),
      ]).then((results) {
        final dailySnapshot = results[0];
        final eventsSnapshot = results[1];
        
        debugPrint('Loaded ${dailySnapshot.docs.length} daily analytics and ${eventsSnapshot.docs.length} events');
        
        // Sum up daily analytics
        int totalViews = 0;
        int totalFavorites = 0;
        int totalContacts = 0;
        int uniqueVisitors = 0;
        
        for (final doc in dailySnapshot.docs) {
          final data = doc.data();
          totalViews += (data['views'] as num? ?? 0).toInt();
          totalFavorites += (data['favorites'] as num? ?? 0).toInt();
          totalContacts += (data['contacts'] as num? ?? 0).toInt();
          uniqueVisitors += (data['unique_visitors'] as num? ?? 0).toInt();
        }
        
        // If no daily analytics, fall back to counting events
        if (dailySnapshot.docs.isEmpty && eventsSnapshot.docs.isNotEmpty) {
          final viewedPosts = <String>{};
          for (final doc in eventsSnapshot.docs) {
            final data = doc.data();
            final action = data['action'] as String?;
            final postId = data['postId'] as String?;
            
            if (action == 'view') {
              totalViews++;
              if (postId != null) viewedPosts.add(postId);
            }
            if (action == 'favorite') totalFavorites++;
            if (action == 'unfavorite') totalFavorites--;
            if (action == 'contact') totalContacts++;
          }
          uniqueVisitors = viewedPosts.length;
        }
        
        return <String, int>{
          'totalViews': totalViews,
          'totalFavorites': totalFavorites.clamp(0, double.infinity).toInt(),
          'totalContacts': totalContacts,
          'uniqueVisitors': uniqueVisitors,
          'totalPosts': 0, // Will be calculated from posts
        };
      })
      .catchError((error) {
        debugPrint('Error loading analytics: $error');
        return <String, int>{
          'totalViews': 0,
          'totalFavorites': 0,
          'totalContacts': 0,
          'uniqueVisitors': 0,
          'totalPosts': 0,
        };
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, subscriptionState) {
        
        if (authState is! Authenticated) {
          return const Scaffold(
            body: LoadingWidget(message: 'Loading analytics...'),
          );
        }

        // Update premium access based on subscription state
        if (subscriptionState is SubscriptionLoaded) {
          _hasPremiumAccess = subscriptionState.hasFeature('product_performance_analytics');
          _isCheckingPremium = false;
        } else if (subscriptionState is FeatureAccessResult) {
          if (subscriptionState.featureName == 'product_performance_analytics') {
            _hasPremiumAccess = subscriptionState.hasAccess;
            _isCheckingPremium = false;
          }
        }

        return Scaffold(
          appBar: HiPopAppBar(
            title: 'Analytics Dashboard',
            userRole: 'vendor',
            showPremiumBadge: _hasPremiumAccess,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (_currentUserId != null) {
                    setState(() {
                      _analyticsStream = _getAnalytics(_currentUserId!);
                      _postsStream = _getVendorPosts(_currentUserId!);
                    });
                  }
                },
              ),
            ],
          ),
          body: _buildAnalyticsBody(subscriptionState),
        );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsBody(SubscriptionState subscriptionState) {
    if (_analyticsStream == null || _postsStream == null) {
      return const LoadingWidget(message: 'Loading your analytics...');
    }

    if (_hasPremiumAccess) {
      return _buildPremiumAnalyticsView();
    } else if (!_isCheckingPremium) {
      return _buildFreeAnalyticsView();
    } else {
      return const LoadingWidget(message: 'Checking subscription...');
    }
  }

  Widget _buildPremiumAnalyticsView() {
    return StreamBuilder<Map<String, int>>(
      stream: _analyticsStream!,
      builder: (context, analyticsSnapshot) {
        return StreamBuilder<List<VendorPost>>(
          stream: _postsStream!,
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting ||
                analyticsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingWidget(message: 'Loading analytics...');
            }

            final posts = postsSnapshot.data ?? [];
            final analytics = analyticsSnapshot.data ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Only show premium header for non-premium users
                  if (!_hasPremiumAccess) ...[
                    VendorPremiumDashboardComponents.buildPremiumHeader(
                      context,
                      title: 'Vendor Premium Analytics',
                      subtitle: 'Track your market performance and application analytics',
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildBasicOverviewSection(analytics, posts),
                  const SizedBox(height: 24),
                  _buildPostPerformanceSection(posts),
                  const SizedBox(height: 24),
                  _buildLocationInsights(posts),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFreeAnalyticsView() {
    return StreamBuilder<Map<String, int>>(
      stream: _analyticsStream!,
      builder: (context, analyticsSnapshot) {
        return StreamBuilder<List<VendorPost>>(
          stream: _postsStream!,
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingWidget(message: 'Loading your analytics...');
            }

            if (postsSnapshot.hasError) {
              debugPrint('Vendor analytics error: ${postsSnapshot.error}');
              return _buildEmptyAnalyticsState();
            }

            final posts = postsSnapshot.data ?? [];
            final analytics = analyticsSnapshot.data ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPremiumOnlyMessage(),
                  const SizedBox(height: 24),
                  _buildBasicOverviewSection(analytics, posts),
                  const SizedBox(height: 24),
                  VendorPremiumDashboardComponents.buildUpgradePrompt(
                    context,
                    customMessage: 'Unlock advanced analytics to grow your vendor business!',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Basic overview for free users
  Widget _buildBasicOverviewSection(Map<String, int> analytics, List<VendorPost> posts) {
    final activePosts = posts.where((p) => p.isActive).length;
    final happeningNow = posts.where((p) => p.isHappening).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: HiPopColors.vendorAccent,
          ),
        ),
        const SizedBox(height: 16),
        MetricCardGrid(
          cards: [
            MetricCard(
              title: 'Total Views',
              value: '${analytics['totalViews'] ?? 0}',
              icon: Icons.visibility,
              type: MetricType.info,
            ),
            MetricCard(
              title: 'Total Favorites',
              value: '${analytics['totalFavorites'] ?? 0}',
              icon: Icons.favorite,
              type: MetricType.error,
            ),
            MetricCard(
              title: 'Active Pop-ups',
              value: '$activePosts',
              icon: Icons.event_available,
              type: MetricType.active,
            ),
            MetricCard(
              title: 'Happening Now',
              value: '$happeningNow',
              icon: Icons.play_circle_fill,
              type: MetricType.happening,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAnalyticsState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show demo analytics with zero values
          _buildBasicOverviewSection({'totalViews': 0, 'totalFavorites': 0}, []),
          const SizedBox(height: 24),
          
          // Empty state message
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Analytics Data Yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start creating pop-ups to see your analytics here!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Premium prompt if not premium
          if (!_hasPremiumAccess && !_isCheckingPremium) ...[
            VendorPremiumDashboardComponents.buildUpgradePrompt(context),
          ],
        ],
      ),
    );
  }

  Widget _buildPostPerformanceSection(List<VendorPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptySection(
        'No Posts Yet',
        'Create your first pop-up to see performance metrics!',
        Icons.add_box,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Post Performance',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: HiPopColors.vendorAccent,
          ),
        ),
        const SizedBox(height: 16),
        ...posts.take(5).map((post) => _buildPostPerformanceCard(post)),
      ],
    );
  }

  Widget _buildPostPerformanceCard(VendorPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.location,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.isHappening 
                        ? HiPopColors.successGreen 
                        : post.isUpcoming 
                            ? HiPopColors.accentMauve 
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    post.isHappening 
                        ? 'Live' 
                        : post.isUpcoming 
                            ? 'Upcoming' 
                            : 'Past',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPerformanceMetric(Icons.visibility, '0', 'Views'),
                const SizedBox(width: 24),
                _buildPerformanceMetric(Icons.favorite, '0', 'Favorites'),
                const Spacer(),
                Text(
                  post.formattedDateTime,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInsights(List<VendorPost> posts) {
    final locationCounts = <String, int>{};
    for (final post in posts) {
      locationCounts[post.location] = (locationCounts[post.location] ?? 0) + 1;
    }

    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Locations',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: HiPopColors.vendorAccent,
          ),
        ),
        const SizedBox(height: 16),
        if (sortedLocations.isEmpty)
          _buildEmptySection(
            'No Location Data',
            'Start creating pop-ups to see which locations work best!',
            Icons.location_on,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: sortedLocations
                    .take(5)
                    .map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: HiPopColors.vendorAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${entry.value} pop-ups',
                                  style: TextStyle(
                                    color: HiPopColors.vendorAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySection(String title, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOnlyMessage() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HiPopColors.premiumGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HiPopColors.premiumGold.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.analytics,
                size: 64,
                color: HiPopColors.premiumGold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Analytics Dashboard',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.premiumGoldDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Track your application performance with Vendor Premium (\$29/month).',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Get analytics on market applications, post views, and engagement tracking.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}