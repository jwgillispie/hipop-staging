import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart';
import 'package:hipop/features/shared/services/share_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../models/vendor_post.dart';
import '../../market/models/market.dart';

class VendorMyPopups extends StatefulWidget {
  const VendorMyPopups({super.key});

  @override
  State<VendorMyPopups> createState() => _VendorMyPopupsState();
}

class _VendorMyPopupsState extends State<VendorMyPopups> {
  final VendorPostsRepository _vendorPostsRepository = VendorPostsRepository();
  final Map<String, Market?> _marketCache = {};
  String? _currentVendorId;

  @override
  void initState() {
    super.initState();
    _getCurrentVendorId();
  }

  void _getCurrentVendorId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentVendorId = authState.user.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pop-ups'),
        backgroundColor: HiPopColors.vendorAccent,
        foregroundColor: Colors.white,
      ),
      body: _currentVendorId == null
          ? const Center(child: Text('Please log in to view your pop-ups'))
          : StreamBuilder<List<VendorPost>>(
              stream: _vendorPostsRepository.getVendorPosts(_currentVendorId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: HiPopColors.errorPlum),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading pop-ups',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: TextStyle(color: HiPopColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: HiPopColors.lightTextTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Pop-ups Created Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first pop-up to get started!',
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/vendor/create-popup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HiPopColors.vendorAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Pop-up'),
                        ),
                      ],
                    ),
                  );
                }

                // Group posts by status
                final upcomingPosts = posts.where((p) => p.isUpcoming).toList();
                final livePosts = posts.where((p) => p.isHappening).toList();
                final pastPosts = posts.where((p) => p.isPast).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsCard(posts.length, upcomingPosts.length, livePosts.length),
                      const SizedBox(height: 24),
                      
                      if (livePosts.isNotEmpty) ...[
                        _buildSectionHeader('Live Now', livePosts.length, HiPopColors.successGreen),
                        const SizedBox(height: 16),
                        ...livePosts.map((post) => _buildPostCard(post)),
                        const SizedBox(height: 24),
                      ],
                      
                      if (upcomingPosts.isNotEmpty) ...[
                        _buildSectionHeader('Upcoming', upcomingPosts.length, HiPopColors.vendorAccent),
                        const SizedBox(height: 16),
                        ...upcomingPosts.map((post) => _buildPostCard(post)),
                        const SizedBox(height: 24),
                      ],
                      
                      if (pastPosts.isNotEmpty) ...[
                        _buildSectionHeader('Past Events', pastPosts.length, HiPopColors.lightTextSecondary),
                        const SizedBox(height: 16),
                        ...pastPosts.map((post) => _buildPostCard(post)),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/vendor/create-popup'),
        backgroundColor: HiPopColors.vendorAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsCard(int total, int upcoming, int live) {
    return Card(
      elevation: 4,
      color: HiPopColors.surfacePalePink,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildStatItem('Total', total.toString(), HiPopColors.primaryDeepSage),
            const SizedBox(width: 24),
            _buildStatItem('Live', live.toString(), HiPopColors.successGreen),
            const SizedBox(width: 24),
            _buildStatItem('Upcoming', upcoming.toString(), HiPopColors.vendorAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: HiPopColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(VendorPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: HiPopColors.surfacePalePink,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Market indicator for market posts
            if (post.isMarketPost) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HiPopColors.vendorAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront, size: 14, color: HiPopColors.vendorAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Market Vendor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HiPopColors.vendorAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Market name or location
                      Row(
                        children: [
                          Icon(
                            post.isMarketPost ? Icons.storefront : Icons.location_on, 
                            size: 16, 
                            color: HiPopColors.lightTextSecondary
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildLocationWidget(post),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: HiPopColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getFormattedDate(post),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: HiPopColors.lightTextSecondary,
                                  ),
                                ),
                                Text(
                                  post.formattedTimeRange,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: HiPopColors.lightTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: post.isHappening 
                        ? HiPopColors.successGreen 
                        : post.isUpcoming 
                            ? HiPopColors.vendorAccent 
                            : HiPopColors.lightTextSecondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    post.isHappening 
                        ? 'LIVE' 
                        : post.isUpcoming 
                            ? 'UPCOMING' 
                            : 'PAST',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (post.instagramHandle != null) ...[
                  Icon(Icons.alternate_email, size: 16, color: HiPopColors.lightTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    post.instagramHandle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.lightTextSecondary,
                    ),
                  ),
                  const Spacer(),
                ],
                IconButton(
                  onPressed: () => _showPostOptions(post),
                  icon: const Icon(Icons.more_vert),
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(VendorPost post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('editPopup', extra: post);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: HiPopColors.vendorAccent),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicatePost(post);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: HiPopColors.errorPlum),
              title: Text('Delete', style: TextStyle(color: HiPopColors.errorPlum)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _sharePost(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _duplicatePost(VendorPost post) {
    Navigator.pushNamed(
      context,
      '/create_popup',
      arguments: {
        'duplicateFrom': post,
      },
    );
  }

  void _confirmDelete(VendorPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pop-up'),
        content: Text('Are you sure you want to delete the pop-up at ${post.location}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _vendorPostsRepository.deletePost(post.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pop-up deleted successfully'),
                      backgroundColor: HiPopColors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete pop-up: $e'),
                      backgroundColor: HiPopColors.errorPlum,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: HiPopColors.errorPlum),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePost(VendorPost post) async {
    try {
      String? marketName;
      
      // Get market name if post is associated with a market
      if (post.marketId != null) {
        try {
          final market = await MarketService.getMarket(post.marketId!);
          marketName = market?.name;
        } catch (e) {
          // Continue without market name if there's an error
          marketName = null;
        }
      }
      
      // Share the popup
      final result = await ShareService.sharePopup(post, marketName: marketName);
      
      // Show success message
      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Pop-up shared successfully!'),
              ],
            ),
            backgroundColor: HiPopColors.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to share pop-up: $e')),
              ],
            ),
            backgroundColor: HiPopColors.errorPlum,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper method to build the location widget based on post type
  Widget _buildLocationWidget(VendorPost post) {
    if (post.isMarketPost) {
      // For market posts, show market name if available, otherwise loading state
      if (post.associatedMarketName != null && post.associatedMarketName!.isNotEmpty) {
        return Text(
          post.associatedMarketName!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      } else if (post.associatedMarketId != null) {
        // Load market data if we have the ID but not the name
        return FutureBuilder<Market?>(
          future: _loadMarketData(post.associatedMarketId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HiPopColors.vendorAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading market...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.lightTextSecondary,
                    ),
                  ),
                ],
              );
            } else if (snapshot.hasData && snapshot.data != null) {
              return Text(
                snapshot.data!.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              );
            } else {
              return Text(
                'Market not found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.errorPlum,
                ),
              );
            }
          },
        );
      } else {
        return Text(
          'Unknown market',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: HiPopColors.errorPlum,
          ),
        );
      }
    } else {
      // For independent posts, show the location
      return Text(
        post.location.isNotEmpty ? post.location : 'Location not specified',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  // Format the date for display
  String _getFormattedDate(VendorPost post) {
    final eventDate = post.popUpStartDateTime;
    
    // For market posts, always show the actual date
    if (post.isMarketPost) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      
      final month = months[eventDate.month - 1];
      final weekday = weekdays[eventDate.weekday % 7];
      
      return '$weekday, $month ${eventDate.day}, ${eventDate.year}';
    }
    
    // For independent posts, use relative time if it's upcoming
    if (post.isHappening) {
      return 'Happening now!';
    } else if (post.isPast) {
      return 'Past event';
    } else {
      // Show actual date for all posts
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      
      final month = months[eventDate.month - 1];
      final weekday = weekdays[eventDate.weekday % 7];
      
      return '$weekday, $month ${eventDate.day}, ${eventDate.year}';
    }
  }

  // Cache market data to avoid repeated API calls
  Future<Market?> _loadMarketData(String marketId) async {
    if (_marketCache.containsKey(marketId)) {
      return _marketCache[marketId];
    }

    try {
      final market = await MarketService.getMarket(marketId);
      _marketCache[marketId] = market;
      return market;
    } catch (e) {
      debugPrint('Error loading market data: $e');
      _marketCache[marketId] = null;
      return null;
    }
  }
}