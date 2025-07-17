import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../models/vendor_post.dart';
import '../repositories/vendor_posts_repository.dart';

class VendorMyPopups extends StatefulWidget {
  const VendorMyPopups({super.key});

  @override
  State<VendorMyPopups> createState() => _VendorMyPopupsState();
}

class _VendorMyPopupsState extends State<VendorMyPopups> {
  final VendorPostsRepository _vendorPostsRepository = VendorPostsRepository();
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
        backgroundColor: Colors.orange,
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
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading pop-ups',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: TextStyle(color: Colors.grey[600]),
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
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Pop-ups Created Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first pop-up to get started!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                        _buildSectionHeader('Live Now', livePosts.length, Colors.green),
                        const SizedBox(height: 16),
                        ...livePosts.map((post) => _buildPostCard(post)),
                        const SizedBox(height: 24),
                      ],
                      
                      if (upcomingPosts.isNotEmpty) ...[
                        _buildSectionHeader('Upcoming', upcomingPosts.length, Colors.orange),
                        const SizedBox(height: 16),
                        ...upcomingPosts.map((post) => _buildPostCard(post)),
                        const SizedBox(height: 24),
                      ],
                      
                      if (pastPosts.isNotEmpty) ...[
                        _buildSectionHeader('Past Events', pastPosts.length, Colors.grey),
                        const SizedBox(height: 16),
                        ...pastPosts.map((post) => _buildPostCard(post)),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsCard(int total, int upcoming, int live) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildStatItem('Total', total.toString(), Colors.blue),
            const SizedBox(width: 24),
            _buildStatItem('Live', live.toString(), Colors.green),
            const SizedBox(width: 24),
            _buildStatItem('Upcoming', upcoming.toString(), Colors.orange),
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
              color: Colors.grey[600],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.location,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.formattedDateTime,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  post.formattedTimeRange,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
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
                        ? Colors.green 
                        : post.isUpcoming 
                            ? Colors.orange 
                            : Colors.grey,
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
                  const Icon(Icons.alternate_email, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    post.instagramHandle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
                // TODO: Navigate to edit screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit functionality coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.orange),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicatePost(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
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
                // TODO: Share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share functionality coming soon!')),
                );
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
                    const SnackBar(
                      content: Text('Pop-up deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete pop-up: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}