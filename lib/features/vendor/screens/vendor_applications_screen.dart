import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/vendor/vendor_applications_bloc.dart';
import 'package:hipop/features/vendor/models/vendor_application.dart';
import 'package:hipop/features/vendor/services/vendor_application_service.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_applications_calendar.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/vendor/models/post_type.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart';

class VendorApplicationsScreen extends StatefulWidget {
  const VendorApplicationsScreen({super.key});

  @override
  State<VendorApplicationsScreen> createState() => _VendorApplicationsScreenState();
}

class _VendorApplicationsScreenState extends State<VendorApplicationsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedMarketId;
  Map<String, String> _marketNames = {}; // marketId -> marketName
  List<String> _validMarketIds = []; // Only markets that actually exist
  bool _loadingMarketNames = true;
  bool _showCalendarView = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Removed pending tab
    _selectedMarketId = _getInitialMarketId();
    _loadMarketNames();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _getInitialMarketId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile?.isMarketOrganizer == true) {
      final managedMarketIds = authState.userProfile!.managedMarketIds;
      // Return first market ID, but _loadMarketNames() will validate and potentially change it
      return managedMarketIds.isNotEmpty ? managedMarketIds.first : null;
    }
    return null;
  }

  List<String> _getManagedMarketIds() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile?.isMarketOrganizer == true) {
      return authState.userProfile!.managedMarketIds;
    }
    return [];
  }

  String? _getCurrentMarketId() {
    return _selectedMarketId;
  }

  Future<void> _loadMarketNames() async {
    try {
      final managedMarketIds = _getManagedMarketIds();
      final Map<String, String> marketNames = {};
      final List<String> validMarketIds = [];
      
      
      for (String marketId in managedMarketIds) {
        try {
          final market = await MarketService.getMarket(marketId);
          if (market != null && market.isActive) {
            // Market exists and is active - include it
            marketNames[marketId] = market.name;
            validMarketIds.add(marketId);
          } else {
          }
        } catch (e) {
        }
      }
      
      if (mounted) {
        setState(() {
          _marketNames = marketNames;
          _validMarketIds = validMarketIds;
          _loadingMarketNames = false;
          
          // If current selected market is not valid, switch to first valid one
          if (_selectedMarketId != null && !validMarketIds.contains(_selectedMarketId)) {
            _selectedMarketId = validMarketIds.isNotEmpty ? validMarketIds.first : null;
          }
        });
        
        // Auto-reject expired applications for this market
        if (_selectedMarketId != null) {
          _autoRejectExpiredApplications(_selectedMarketId!);
        }
        
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMarketNames = false;
        });
      }
    }
  }

  Future<void> _autoRejectExpiredApplications(String marketId) async {
    try {
      final rejectedCount = await VendorApplicationService.autoRejectExpiredApplications(marketId);
      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Auto-rejected $rejectedCount applications with past dates'),
            backgroundColor: HiPopColors.warningAmber,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use valid market IDs instead of all managed market IDs
    final managedMarketIds = _loadingMarketNames ? _getManagedMarketIds() : _validMarketIds;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Connections'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6F9686), // Soft Sage
                Color(0xFF946C7E), // Mauve
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showCalendarView ? Icons.list : Icons.calendar_today),
            onPressed: () {
              setState(() {
                _showCalendarView = !_showCalendarView;
              });
            },
            tooltip: _showCalendarView ? 'Show List View' : 'Show Calendar View',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh Applications',
          ),
          if (kDebugMode) ...[
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _debugAllApplications,
              tooltip: 'Debug All Applications',
            ),
            IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: _addTestData,
              tooltip: 'Add Test Data',
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Market selector dropdown
              if (managedMarketIds.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Market: ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedMarketId,
                          dropdownColor: const Color(0xFF6F9686),
                          style: const TextStyle(color: Colors.white),
                          underline: Container(
                            height: 1,
                            color: Colors.white70,
                          ),
                          items: managedMarketIds.map((marketId) {
                            final marketName = _marketNames[marketId] ?? 
                                (_loadingMarketNames ? 'Loading...' : 'Market ${marketId.substring(0, 8)}...');
                            return DropdownMenuItem<String>(
                              value: marketId,
                              child: Text(
                                marketName,
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedMarketId = newValue;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _showCalendarView
          ? _buildCalendarView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPostApplicationsList(null),
                _buildPostApplicationsList('approved'), // Market posts are auto-approved
                _buildPostApplicationsList('denied'),
              ],
            ),
    );
  }

  Widget _buildCalendarView() {
    final marketId = _getCurrentMarketId();
    
    if (marketId == null) {
      return const Center(child: Text('No market selected'));
    }
    
    return StreamBuilder<List<VendorApplication>>(
      stream: VendorApplicationService.getApplicationsForMarket(marketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
            ),
          );
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

        final applications = snapshot.data ?? [];

        if (applications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No applications with dates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Applications with specific dates will appear here in calendar view.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return VendorApplicationsCalendar(
          applications: applications,
          onApplicationTap: (application) {
            _showApplicationDetails(application);
          },
        );
      },
    );
  }

  void _showApplicationDetails(VendorApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(application.vendorBusinessName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: ${application.status.name.toUpperCase()}'),
              const SizedBox(height: 8),
              if (application.specialMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Message: ${application.specialMessage}'),
              ],
              if (application.reviewNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Review Notes: ${application.reviewNotes}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (application.status == ApplicationStatus.pending) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showReviewDialog(application, ApplicationStatus.rejected);
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showReviewDialog(application, ApplicationStatus.approved);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  // New method to show vendor posts as applications with pagination
  Widget _buildPostApplicationsList(String? filterStatus) {
    final marketId = _getCurrentMarketId();
    
    if (marketId == null) {
      return const Center(child: Text('No market selected'));
    }
    
    // Convert filter status to ApplicationStatus enum
    ApplicationStatus? applicationStatus;
    if (filterStatus == 'approved') {
      applicationStatus = ApplicationStatus.approved;
    } else if (filterStatus == 'denied') {
      applicationStatus = ApplicationStatus.rejected;
    }
    
    return BlocProvider(
      create: (context) => VendorApplicationsBloc()..add(
        LoadApplications(
          marketId: marketId,
          filterStatus: applicationStatus,
        ),
      ),
      child: BlocBuilder<VendorApplicationsBloc, VendorApplicationsState>(
        builder: (context, state) {
          if (state is ApplicationsLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
              ),
            );
          }

          if (state is ApplicationsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<VendorApplicationsBloc>().add(
                        RefreshApplications(
                          marketId: marketId,
                          filterStatus: applicationStatus,
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ApplicationsLoaded) {
            final applications = state.applications;
            
            if (applications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${filterStatus ?? ""} applications',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vendor connections will appear here',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    _scrollController.position.extentAfter < 500 &&
                    !state.hasReachedEnd &&
                    !state.isLoadingMore) {
                  context.read<VendorApplicationsBloc>().add(
                    LoadMoreApplications(
                      marketId: marketId,
                      filterStatus: applicationStatus,
                    ),
                  );
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: applications.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == applications.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final application = applications[index];
                  return _buildApplicationCard(application);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
  
  Widget _buildPostApplicationCard(VendorPost post) {
    final isApproved = post.approvalStatus?.value == 'approved';
    final isDenied = post.approvalStatus?.value == 'denied';
    // Market posts are auto-approved, no pending state
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isApproved 
              ? Colors.green 
              : Colors.red,
          child: Icon(
            isApproved 
                ? Icons.check 
                : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          post.vendorName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatDateTime(post.popUpStartDateTime)} - ${_formatTime(post.popUpEndDateTime)}'),
            if (post.vendorNotes != null && post.vendorNotes!.isNotEmpty)
              Text(
                'Note: ${post.vendorNotes}',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Location', post.location),
                _buildDetailRow('Description', post.description),
                if (post.vendorNotes != null && post.vendorNotes!.isNotEmpty)
                  _buildDetailRow('Vendor Notes', post.vendorNotes!),
                if (post.approvalNote != null && post.approvalNote!.isNotEmpty)
                  _buildDetailRow('Organizer Notes', post.approvalNote!),
                if (post.instagramHandle != null && post.instagramHandle!.isNotEmpty)
                  _buildDetailRow('Instagram', '@${post.instagramHandle}'),
                if (post.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Photos:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: post.photoUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              post.photoUrls[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Market posts are auto-approved, no manual approval needed
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isApproved ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      isApproved ? 'Approved' : 'Denied',
                      style: TextStyle(
                        color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${_formatTime(dateTime)}';
  }
  
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }
  
  Future<void> _approvePost(VendorPost post) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    
    try {
      final repository = VendorPostsRepository();
      await repository.approvePost(post.id, authState.user.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _denyPost(VendorPost post) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    
    // Show dialog to get denial reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String reasonText = '';
        return AlertDialog(
          title: const Text('Deny Post Application'),
          content: TextField(
            onChanged: (value) => reasonText = value,
            decoration: const InputDecoration(
              labelText: 'Reason for denial (optional)',
              hintText: 'Enter reason...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reasonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Deny'),
            ),
          ],
        );
      },
    );
    
    if (reason != null) {
      try {
        final repository = VendorPostsRepository();
        await repository.denyPost(post.id, authState.user.uid, reason.isEmpty ? null : reason);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error denying post: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  // Keep the old method for compatibility but rename it
  Widget _buildLegacyApplicationsList(ApplicationStatus? filterStatus) {
    final marketId = _getCurrentMarketId();
    
    
    if (marketId == null) {
      return const Center(child: Text('No market selected'));
    }
    
    
    final stream = filterStatus == null
        ? VendorApplicationService.getApplicationsForMarket(marketId)
        : VendorApplicationService.getApplicationsByStatus(marketId, filterStatus);

    return StreamBuilder<List<VendorApplication>>(
      stream: stream,
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
            ),
          );
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

        final applications = snapshot.data ?? [];
        

        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  filterStatus == null 
                      ? 'No applications yet'
                      : 'No ${filterStatus.name} applications',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vendor connections will appear here when submitted.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            return _buildApplicationCard(application);
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(VendorApplication application) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              application.vendorBusinessName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: application.isMarketPermission 
                                  ? Colors.purple.shade100 
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              application.isMarketPermission ? 'Permission' : 'Event Application',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: application.isMarketPermission 
                                    ? Colors.purple.shade700 
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact: ${application.vendorDisplayName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (application.vendorEmail != null)
                        Text(
                          application.vendorEmail!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (application.vendorCategories.isNotEmpty)
                        Text(
                          'Categories: ${application.vendorCategories.join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      // Note: In the new 1:1 market-event system, each application is for a single market event
                      // No need to display requested dates since the market itself has the event date
                      if (application.isMarketPermission)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HiPopColors.warningAmber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.storefront, size: 16, color: HiPopColors.warningAmberDark),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Requesting ongoing permission to create pop-ups at this market',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: HiPopColors.warningAmberDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Type: ${application.isMarketPermission ? 'Permission Request' : 'Event Application'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(application.status),
              ],
            ),
            const SizedBox(height: 12),
            if (application.specialMessage?.isNotEmpty == true)
              Text(
                application.specialMessage!,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                'No special message provided',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Applied: ${_formatDate(application.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (application.status == ApplicationStatus.pending) ...[
                  TextButton(
                    onPressed: () => _showReviewDialog(application, ApplicationStatus.rejected),
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showReviewDialog(application, ApplicationStatus.approved),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ApplicationStatus status) {
    Color color;
    switch (status) {
      case ApplicationStatus.pending:
        color = HiPopColors.warningAmber;
        break;
      case ApplicationStatus.approved:
        color = Colors.green;
        break;
      case ApplicationStatus.rejected:
        color = Colors.red;
        break;
      case ApplicationStatus.waitlisted:
        color = Colors.blue;
        break;
    }

    return Chip(
      label: Text(
        status.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showReviewDialog(VendorApplication application, ApplicationStatus newStatus) {
    final controller = TextEditingController();
    bool isProcessing = false;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus.name.toUpperCase()} ${application.isMarketPermission ? 'Request' : 'Application'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vendor: ${application.vendorBusinessName}'),
            const SizedBox(height: 8),
            if (application.isMarketPermission && newStatus == ApplicationStatus.approved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will grant ${application.vendorBusinessName} ongoing permission to create pop-ups at your market.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Review Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Get the current organizer ID from auth state
                final authState = context.read<AuthBloc>().state;
                final organizerId = authState is Authenticated ? authState.user.uid : 'unknown';
                
                if (newStatus == ApplicationStatus.approved) {
                  await VendorApplicationService.approveApplication(
                    application.id,
                    organizerId,
                    notes: controller.text.trim().isEmpty ? null : controller.text.trim(),
                  );
                } else {
                  await VendorApplicationService.updateApplicationStatus(
                    application.id,
                    newStatus,
                    organizerId,
                    reviewNotes: controller.text.trim().isEmpty ? null : controller.text.trim(),
                  );
                }
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Application ${newStatus.name}'),
                      backgroundColor: newStatus == ApplicationStatus.approved ? Colors.green : Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == ApplicationStatus.approved ? Colors.green : Colors.red,
            ),
            child: Text(
              newStatus.name.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _addTestData() async {
    final marketId = _getCurrentMarketId();
    if (marketId == null) return;
    
    try {
      final applications = [
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_1',
          applicationType: ApplicationType.eventApplication,
          specialMessage: 'Need access to electrical outlet for display refrigerator',
          status: ApplicationStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_2',
          applicationType: ApplicationType.eventApplication,
          specialMessage: 'Would like corner spot for easy truck access',
          status: ApplicationStatus.approved,
          reviewedBy: 'organizer_1',
          reviewedAt: DateTime.now().subtract(const Duration(days: 1)),
          reviewNotes: 'Great addition to our market. Approved!',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_3',
          applicationType: ApplicationType.eventApplication,
          specialMessage: null,
          status: ApplicationStatus.waitlisted,
          reviewedBy: 'organizer_1',
          reviewedAt: DateTime.now().subtract(const Duration(hours: 12)),
          reviewNotes: 'Good application but crafts category is full. Added to waitlist.',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_4',
          applicationType: ApplicationType.eventApplication,
          specialMessage: 'Need large space for food truck and seating area',
          status: ApplicationStatus.rejected,
          reviewedBy: 'organizer_1',
          reviewedAt: DateTime.now().subtract(const Duration(hours: 6)),
          reviewNotes: 'Food trucks not permitted at this market location due to space constraints.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_5',
          applicationType: ApplicationType.eventApplication,
          specialMessage: null,
          status: ApplicationStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
        ),
      ];

      for (final application in applications) {
        await VendorApplicationService.submitApplication(application);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test data added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding test data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _debugAllApplications() async {
    try {
      // Get all applications from Firestore directly
      final snapshot = await FirebaseFirestore.instance
          .collection('vendor_applications')
          .get();
      
      final currentMarketId = _getCurrentMarketId();
      int matchingMarketCount = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        if (data['marketId'] == currentMarketId) {
          matchingMarketCount++;
        }
      }
      
      // Show market organizer info
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        // Debug info for current user and market
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${snapshot.docs.length} total applications, $matchingMarketCount for this market. Check console.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}