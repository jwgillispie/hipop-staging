import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../models/vendor_application.dart';
import '../services/vendor_application_service.dart';
import '../services/market_service.dart';
import '../widgets/vendor_applications_calendar.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedMarketId = _getInitialMarketId();
    _loadMarketNames();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      
      if (kDebugMode) {
        print('DEBUG: Checking ${managedMarketIds.length} managed markets: $managedMarketIds');
      }
      
      for (String marketId in managedMarketIds) {
        try {
          final market = await MarketService.getMarket(marketId);
          if (market != null && market.isActive) {
            // Market exists and is active - include it
            marketNames[marketId] = market.name;
            validMarketIds.add(marketId);
            if (kDebugMode) {
              print('DEBUG: Found valid market: ${market.name} ($marketId)');
            }
          } else {
            if (kDebugMode) {
              print('DEBUG: Market $marketId not found or inactive - excluding from list');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('DEBUG: Error loading market $marketId: $e - excluding from list');
          }
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
            if (kDebugMode) {
              print('DEBUG: Switched to valid market: $_selectedMarketId');
            }
          }
        });
        
        // Auto-reject expired applications for this market
        if (_selectedMarketId != null) {
          _autoRejectExpiredApplications(_selectedMarketId!);
        }
        
        if (kDebugMode) {
          print('DEBUG: Valid markets: $_marketNames');
          print('DEBUG: Selected market: $_selectedMarketId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error loading market names: $e');
      }
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
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error auto-rejecting expired applications: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use valid market IDs instead of all managed market IDs
    final managedMarketIds = _loadingMarketNames ? _getManagedMarketIds() : _validMarketIds;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Applications'),
        backgroundColor: Colors.green,
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
                          dropdownColor: Colors.green.shade700,
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
                  Tab(text: 'Pending'),
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
                _buildApplicationsList(null),
                _buildApplicationsList(ApplicationStatus.pending),
                _buildApplicationsList(ApplicationStatus.approved),
                _buildApplicationsList(ApplicationStatus.rejected),
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

        final applications = snapshot.data ?? [];
        final applicationsWithDates = applications.where((app) => app.hasRequestedDates).toList();

        if (applicationsWithDates.isEmpty) {
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
          applications: applicationsWithDates,
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
              if (application.hasRequestedDates)
                Text('Requested Dates: ${application.requestedDatesDisplayString}'),
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

  Widget _buildApplicationsList(ApplicationStatus? filterStatus) {
    final marketId = _getCurrentMarketId();
    
    if (kDebugMode) {
      print('DEBUG: Selected market ID: $marketId');
      print('DEBUG: Valid markets: $_validMarketIds');
      print('DEBUG: Filter status: $filterStatus');
    }
    
    if (marketId == null) {
      return const Center(child: Text('No market selected'));
    }
    
    if (kDebugMode) {
      print('DEBUG: Building applications list for market: $marketId');
      print('DEBUG: Filter status: $filterStatus');
    }
    
    final stream = filterStatus == null
        ? VendorApplicationService.getApplicationsForMarket(marketId)
        : VendorApplicationService.getApplicationsByStatus(marketId, filterStatus);

    return StreamBuilder<List<VendorApplication>>(
      stream: stream,
      builder: (context, snapshot) {
        if (kDebugMode) {
          print('DEBUG: StreamBuilder - Connection state: ${snapshot.connectionState}');
          print('DEBUG: StreamBuilder - Has error: ${snapshot.hasError}');
          if (snapshot.hasError) {
            print('DEBUG: StreamBuilder - Error: ${snapshot.error}');
          }
          print('DEBUG: StreamBuilder - Has data: ${snapshot.hasData}');
          if (snapshot.hasData) {
            print('DEBUG: StreamBuilder - Data count: ${snapshot.data?.length}');
          }
        }
        
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

        final applications = snapshot.data ?? [];
        
        if (kDebugMode) {
          print('DEBUG: Received ${applications.length} applications');
          for (var app in applications) {
            print('DEBUG: Application ID: ${app.id}, Vendor: ${app.vendorBusinessName}, Market: ${app.marketId}');
          }
        }

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
                  'Vendor applications will appear here when submitted.',
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
                              application.isMarketPermission ? 'Permission Request' : 'Event Application',
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
                      if (application.isEventApplication && application.hasRequestedDates)
                        Text(
                          'Requested Dates: ${application.requestedDatesDisplayString}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (application.isMarketPermission)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.storefront, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Requesting ongoing permission to create pop-ups at this market',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (application.operatingDays.isNotEmpty)
                        Text(
                          'Days: ${application.operatingDays.join(', ')}',
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
        color = Colors.orange;
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
        title: Text('${newStatus.name.toUpperCase()} ${application.isMarketPermission ? 'Permission Request' : 'Application'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${application.isMarketPermission ? 'Permission Request' : 'Application'} ${application.id.substring(0, 8)}...'),
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
      final now = DateTime.now();
      
      final applications = [
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_1',
          operatingDays: ['Saturday', 'Sunday'],
          requestedDates: [
            now.add(const Duration(days: 7)), // Next Saturday
            now.add(const Duration(days: 8)), // Next Sunday
            now.add(const Duration(days: 14)), // Following Saturday
            now.add(const Duration(days: 15)), // Following Sunday
          ],
          specialMessage: 'Need access to electrical outlet for display refrigerator',
          status: ApplicationStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        VendorApplication(
          id: '',
          marketId: marketId,
          vendorId: 'vendor_2',
          operatingDays: ['Wednesday', 'Saturday'],
          requestedDates: [
            now.add(const Duration(days: 3)), // Next Wednesday
            now.add(const Duration(days: 7)), // Next Saturday
            now.add(const Duration(days: 10)), // Following Wednesday
            now.add(const Duration(days: 14)), // Following Saturday
          ],
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
          operatingDays: ['Friday', 'Saturday'],
          requestedDates: [
            now.add(const Duration(days: 5)), // Next Friday
            now.add(const Duration(days: 6)), // Next Saturday
            now.add(const Duration(days: 12)), // Following Friday
          ],
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
          operatingDays: ['Thursday', 'Friday', 'Saturday'],
          requestedDates: [
            now.add(const Duration(days: 4)), // Next Thursday
            now.add(const Duration(days: 5)), // Next Friday
            now.add(const Duration(days: 6)), // Next Saturday
          ],
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
          operatingDays: ['Saturday'],
          requestedDates: [
            now.add(const Duration(days: 7)), // Next Saturday
            now.add(const Duration(days: 21)), // Saturday in 3 weeks
          ],
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
      
      print('DEBUG: Found ${snapshot.docs.length} total applications in Firestore');
      
      final currentMarketId = _getCurrentMarketId();
      int matchingMarketCount = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('DEBUG: App ${doc.id}: Market=${data['marketId']}, Vendor=${data['vendorId']}, Status=${data['status']}');
        
        if (data['marketId'] == currentMarketId) {
          matchingMarketCount++;
          print('  ✅ MATCHES current market!');
        }
      }
      
      // Show market organizer info
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        print('DEBUG: Current user: ${authState.userProfile?.email}');
        print('DEBUG: Current user type: ${authState.userType}');
        print('DEBUG: Managed markets: ${authState.userProfile?.managedMarketIds}');
        print('DEBUG: Currently viewing market: $currentMarketId');
        print('DEBUG: Applications for this market: $matchingMarketCount');
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
      print('DEBUG: Error getting all applications: $e');
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