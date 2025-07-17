import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../models/vendor_post.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  late Stream<List<VendorPost>> _postsStream;
  late Stream<Map<String, int>> _analyticsStream;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final vendorId = authState.user.uid;
      _postsStream = _getVendorPosts(vendorId);
      _analyticsStream = _getAnalytics(vendorId);
    }
  }

  Stream<List<VendorPost>> _getVendorPosts(String vendorId) {
    return FirebaseFirestore.instance
        .collection('vendor_posts')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList());
  }

  Stream<Map<String, int>> _getAnalytics(String vendorId) {
    return FirebaseFirestore.instance
        .collection('analytics')
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .map((snapshot) {
          final Map<String, int> analytics = {
            'totalViews': 0,
            'totalFavorites': 0,
            'totalPosts': 0,
          };
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            analytics['totalViews'] = (analytics['totalViews'] ?? 0) + (data['views'] as int? ?? 0);
            analytics['totalFavorites'] = (analytics['totalFavorites'] ?? 0) + (data['favorites'] as int? ?? 0);
          }
          
          return analytics;
        });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: LoadingWidget(message: 'Loading analytics...'),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Analytics Dashboard'),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: StreamBuilder<Map<String, int>>(
            stream: _analyticsStream,
            builder: (context, analyticsSnapshot) {
              return StreamBuilder<List<VendorPost>>(
                stream: _postsStream,
                builder: (context, postsSnapshot) {
                  if (postsSnapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingWidget(message: 'Loading your analytics...');
                  }

                  if (postsSnapshot.hasError) {
                    return ErrorDisplayWidget.network(
                      onRetry: () => setState(() {}),
                    );
                  }

                  final posts = postsSnapshot.data ?? [];
                  final analytics = analyticsSnapshot.data ?? {};

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewSection(analytics, posts),
                        const SizedBox(height: 24),
                        _buildPostPerformanceSection(posts),
                        const SizedBox(height: 24),
                        _buildEngagementInsights(posts),
                        const SizedBox(height: 24),
                        _buildLocationInsights(posts),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOverviewSection(Map<String, int> analytics, List<VendorPost> posts) {
    final activePosts = posts.where((p) => p.isActive).length;
    final upcomingPosts = posts.where((p) => p.isUpcoming).length;
    final happeningNow = posts.where((p) => p.isHappening).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildMetricCard(
              'Total Views',
              '${analytics['totalViews'] ?? 0}',
              Icons.visibility,
              Colors.blue,
            ),
            _buildMetricCard(
              'Total Favorites',
              '${analytics['totalFavorites'] ?? 0}',
              Icons.favorite,
              Colors.red,
            ),
            _buildMetricCard(
              'Active Pop-ups',
              '$activePosts',
              Icons.event_available,
              Colors.green,
            ),
            _buildMetricCard(
              'Happening Now',
              '$happeningNow',
              Icons.play_circle_fill,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
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
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            color: Colors.orange[700],
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
                        ? Colors.green 
                        : post.isUpcoming 
                            ? Colors.orange 
                            : Colors.grey,
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
              style: TextStyle(color: Colors.grey[600]),
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
                    color: Colors.grey[500],
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
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementInsights(List<VendorPost> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engagement Insights',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInsightRow(
                  'Best Time to Post',
                  'Weekdays 10-11 AM',
                  Icons.schedule,
                  Colors.blue,
                ),
                const Divider(),
                _buildInsightRow(
                  'Most Popular Day',
                  'Saturday',
                  Icons.calendar_today,
                  Colors.green,
                ),
                const Divider(),
                _buildInsightRow(
                  'Average Engagement',
                  '12 favorites per post',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
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
            color: Colors.orange[700],
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
                              Icon(Icons.location_on, color: Colors.orange[600]),
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
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${entry.value} pop-ups',
                                  style: TextStyle(
                                    color: Colors.orange[700],
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

  Widget _buildInsightRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
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
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}