import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/shared/services/share_service.dart';
import 'package:share_plus/share_plus.dart';

class VendorMyPopupsScreen extends StatefulWidget {
  const VendorMyPopupsScreen({super.key});

  @override
  State<VendorMyPopupsScreen> createState() => _VendorMyPopupsScreenState();
}

class _VendorMyPopupsScreenState extends State<VendorMyPopupsScreen> {
  final VendorPostsRepository _vendorPostsRepository = VendorPostsRepository();
  final Map<String, String> _marketNames = {}; // Cache for market names
  String _selectedFilter = 'All';

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
            title: const Text('My Pop-ups'),
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter Pop-ups',
                onSelected: (String value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'All',
                    child: Text('All Pop-ups'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Upcoming',
                    child: Text('Upcoming'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Live',
                    child: Text('Live Now'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Past',
                    child: Text('Past'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Active',
                    child: Text('Active Only'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter chip bar
              Container(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Upcoming'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Live'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Past'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active'),
                    ],
                  ),
                ),
              ),
              // Pop-ups list
              Expanded(
                child: StreamBuilder<List<VendorPost>>(
                  stream: _vendorPostsRepository.getVendorPosts(state.user.uid),
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
                            Text('Error: ${snapshot.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    var popups = snapshot.data ?? [];

                    // Apply filter
                    popups = _filterPopups(popups);

                    if (popups.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: popups.length,
                      itemBuilder: (context, index) {
                        final popup = popups[index];
                        return _buildPopupCard(popup);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('/vendor/create-popup'),
            backgroundColor: HiPopColors.primaryDeepSage,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Create Pop-up'),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(filter),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: HiPopColors.primaryOpacity(0.1),
      checkmarkColor: HiPopColors.primaryDeepSage,
    );
  }

  List<VendorPost> _filterPopups(List<VendorPost> popups) {
    final now = DateTime.now();
    
    switch (_selectedFilter) {
      case 'Upcoming':
        return popups.where((popup) => popup.popUpStartDateTime.isAfter(now)).toList();
      case 'Live':
        return popups.where((popup) => 
          popup.popUpStartDateTime.isBefore(now) && 
          popup.popUpEndDateTime.isAfter(now)
        ).toList();
      case 'Past':
        return popups.where((popup) => popup.popUpEndDateTime.isBefore(now)).toList();
      case 'Active':
        return popups.where((popup) => popup.isActive).toList();
      case 'All':
      default:
        return popups;
    }
  }

  Widget _buildEmptyState() {
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
          Text(
            _selectedFilter == 'All' ? 'No Pop-ups Yet' : 'No $_selectedFilter Pop-ups',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All' 
                ? 'Create your first pop-up to get started!'
                : 'Try changing the filter to see other pop-ups.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_selectedFilter == 'All')
            ElevatedButton.icon(
              onPressed: () => context.go('/vendor/create-popup'),
              icon: const Icon(Icons.add),
              label: const Text('Create First Pop-up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopupCard(VendorPost popup) {
    final now = DateTime.now();
    final isUpcoming = popup.popUpStartDateTime.isAfter(now);
    final isLive = popup.popUpStartDateTime.isBefore(now) && popup.popUpEndDateTime.isAfter(now);
    final isPast = popup.popUpEndDateTime.isBefore(now);

    // Determine status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isLive) {
      statusColor = HiPopColors.successGreen;
      statusText = 'LIVE NOW';
      statusIcon = Icons.live_tv;
    } else if (isUpcoming) {
      statusColor = HiPopColors.infoBlueGray;
      statusText = 'UPCOMING';
      statusIcon = Icons.schedule;
    } else if (isPast) {
      statusColor = HiPopColors.backgroundWarmGray;
      statusText = 'ENDED';
      statusIcon = Icons.event_busy;
    } else {
      statusColor = HiPopColors.warningAmber;
      statusText = 'SCHEDULED';
      statusIcon = Icons.event;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and Active badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!popup.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HiPopColors.errorPlumLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'INACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.errorPlum,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (popup.marketId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HiPopColors.accentMauve.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront, size: 12, color: HiPopColors.accentMauve),
                            const SizedBox(width: 4),
                            Text(
                              'Market',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: HiPopColors.accentMauve,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  popup.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        popup.location,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Date and Time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(popup.popUpStartDateTime, popup.popUpEndDateTime),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                // Market name (if associated with market)
                if (popup.marketId != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: _getMarketName(popup.marketId!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Row(
                          children: [
                            Icon(Icons.storefront, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'At ${snapshot.data}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _editPopup(popup),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleActiveStatus(popup),
                  icon: Icon(
                    popup.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(popup.isActive ? 'Deactivate' : 'Activate'),
                ),
                const Spacer(),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: ListTile(
                        leading: Icon(Icons.copy),
                        title: Text('Duplicate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: HiPopColors.errorPlum),
                        title: Text('Delete', style: TextStyle(color: HiPopColors.errorPlum)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'share':
                        _sharePopup(popup);
                        break;
                      case 'duplicate':
                        _duplicatePopup(popup);
                        break;
                      case 'delete':
                        _deletePopup(popup);
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime start, DateTime end) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    String formatDate(DateTime date) {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    
    String formatTime(DateTime time) {
      final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    }
    
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      // Same day
      return '${formatDate(start)} • ${formatTime(start)} - ${formatTime(end)}';
    } else {
      // Multi-day
      return '${formatDate(start)} ${formatTime(start)} - ${formatDate(end)} ${formatTime(end)}';
    }
  }

  Future<String> _getMarketName(String marketId) async {
    if (_marketNames.containsKey(marketId)) {
      return _marketNames[marketId]!;
    }

    try {
      final market = await MarketService.getMarket(marketId);
      final marketName = market?.name ?? 'Unknown Market';
      _marketNames[marketId] = marketName;
      return marketName;
    } catch (e) {
      return 'Unknown Market';
    }
  }

  void _editPopup(VendorPost popup) {
    context.pushNamed('editPopup', extra: popup);
  }

  void _toggleActiveStatus(VendorPost popup) async {
    try {
      await _vendorPostsRepository.updatePost(
        popup.copyWith(isActive: !popup.isActive),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              popup.isActive 
                  ? 'Pop-up deactivated' 
                  : 'Pop-up activated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating pop-up: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _sharePopup(VendorPost popup) async {
    try {
      String? marketName;
      
      // Get market name if popup is associated with a market
      if (popup.marketId != null) {
        try {
          final market = await MarketService.getMarket(popup.marketId!);
          marketName = market?.name;
        } catch (e) {
          // Continue without market name if there's an error
          marketName = null;
        }
      }
      
      // Share the popup
      final result = await ShareService.sharePopup(popup, marketName: marketName);
      
      // Show success message
      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

  void _duplicatePopup(VendorPost popup) {
    // TODO: Implement duplicate functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Duplicate functionality coming soon!'),
      ),
    );
  }

  void _deletePopup(VendorPost popup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pop-up'),
        content: Text(
          'Are you sure you want to delete "${popup.description}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _vendorPostsRepository.deletePost(popup.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pop-up deleted successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting pop-up: $e'),
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
}