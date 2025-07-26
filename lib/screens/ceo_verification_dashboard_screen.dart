import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class CeoVerificationDashboardScreen extends StatefulWidget {
  const CeoVerificationDashboardScreen({super.key});

  @override
  State<CeoVerificationDashboardScreen> createState() => _CeoVerificationDashboardScreenState();
}

class _CeoVerificationDashboardScreenState extends State<CeoVerificationDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedUserType;
  VerificationStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // Force Firebase index creation by running all queries immediately
    _triggerIndexCreation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Force all the queries that need indexes to run immediately
  // This will trigger Firebase to show index creation links in console
  void _triggerIndexCreation() {
    print('🔥 TRIGGERING FIREBASE INDEX CREATION...');
    print('Check browser console for Firebase index creation links!');
    
    // Query 1: profileSubmitted + verificationRequestedAt
    FirebaseFirestore.instance
        .collection('user_profiles')
        .where('profileSubmitted', isEqualTo: true)
        .orderBy('verificationRequestedAt', descending: true)
        .limit(1)
        .get()
        .catchError((error) {
      print('🔗 INDEX NEEDED: profileSubmitted + verificationRequestedAt');
      print('Error: $error');
      return <QueryDocumentSnapshot>[];
    });

    // Query 2: verificationStatus + verificationRequestedAt  
    FirebaseFirestore.instance
        .collection('user_profiles')
        .where('verificationStatus', isEqualTo: 'pending')
        .orderBy('verificationRequestedAt', descending: true)
        .limit(1)
        .get()
        .catchError((error) {
      print('🔗 INDEX NEEDED: verificationStatus + verificationRequestedAt');
      print('Error: $error');
      return <QueryDocumentSnapshot>[];
    });

    // Query 3: userType + verificationStatus + verificationRequestedAt
    FirebaseFirestore.instance
        .collection('user_profiles')
        .where('userType', isEqualTo: 'vendor')
        .where('verificationStatus', isEqualTo: 'pending')
        .orderBy('verificationRequestedAt', descending: true)
        .limit(1)
        .get()
        .catchError((error) {
      print('🔗 INDEX NEEDED: userType + verificationStatus + verificationRequestedAt');
      print('Error: $error');
      return <QueryDocumentSnapshot>[];
    });

    print('🔥 INDEX CREATION QUERIES SENT - CHECK CONSOLE FOR LINKS!');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Verification')),
            body: const Center(child: Text('Please sign in to access this dashboard')),
          );
        }

        final userProfile = state.userProfile;
        if (userProfile == null || !userProfile.isCEO) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Verification')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This dashboard is only accessible to authorized personnel.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Account Verification Dashboard'),
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(child: _buildAccountsList()),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _refreshData,
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search by name, email, or business...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUserType,
                  decoration: InputDecoration(
                    labelText: 'User Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Types'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'vendor',
                      child: Text('Vendors'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'market_organizer',
                      child: Text('Market Organizers'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUserType = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<VerificationStatus>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem<VerificationStatus>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    DropdownMenuItem<VerificationStatus>(
                      value: VerificationStatus.pending,
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem<VerificationStatus>(
                      value: VerificationStatus.approved,
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem<VerificationStatus>(
                      value: VerificationStatus.rejected,
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_profiles')
          .where('profileSubmitted', isEqualTo: true)
          .orderBy('verificationRequestedAt', descending: true)
          .snapshots(),
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

        var accounts = snapshot.data?.docs
                .map((doc) => UserProfile.fromFirestore(doc))
                .toList() ??
            [];

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          accounts = accounts.where((account) {
            final searchLower = _searchQuery.toLowerCase();
            return (account.displayName?.toLowerCase().contains(searchLower) ?? false) ||
                (account.businessName?.toLowerCase().contains(searchLower) ?? false) ||
                (account.organizationName?.toLowerCase().contains(searchLower) ?? false) ||
                account.email.toLowerCase().contains(searchLower);
          }).toList();
        }

        if (_selectedUserType != null) {
          accounts = accounts.where((account) => account.userType == _selectedUserType).toList();
        }

        if (_selectedStatus != null) {
          accounts = accounts.where((account) => account.verificationStatus == _selectedStatus).toList();
        }

        if (accounts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return _buildAccountCard(account);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Accounts Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedUserType != null || _selectedStatus != null
                ? 'Try adjusting your search or filters'
                : 'No accounts are currently awaiting verification',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(UserProfile account) {
    final isVendor = account.userType == 'vendor';
    final businessName = isVendor
        ? (account.businessName ?? account.displayName ?? 'Unknown Business')
        : (account.organizationName ?? account.displayName ?? 'Unknown Organization');
    
    final statusColor = _getStatusColor(account.verificationStatus);
    final userTypeColor = isVendor ? Colors.green : Colors.indigo;

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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  businessName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: userTypeColor.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVendor ? Icons.store : Icons.account_balance,
                                      size: 14,
                                      color: userTypeColor.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVendor ? 'Vendor' : 'Organizer',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: userTypeColor.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  account.verificationStatusDisplayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contact: ${account.displayName ?? account.email.split('@').first}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            account.email,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (account.bio != null && account.bio!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              account.bio!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isVendor && account.categories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: account.categories.take(3).map((category) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                if (account.verificationRequestedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Submitted ${_formatDate(account.verificationRequestedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (account.verificationNotes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notes: ${account.verificationNotes!}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                if (account.isPendingVerification) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveAccount(account),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectAccount(account),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _viewAccountDetails(account),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _viewAccountDetails(account),
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More options',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MaterialColor _getStatusColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return Colors.orange;
      case VerificationStatus.approved:
        return Colors.green;
      case VerificationStatus.rejected:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Clear All Filters'),
              leading: const Icon(Icons.clear),
              onTap: () {
                setState(() {
                  _selectedUserType = null;
                  _selectedStatus = null;
                  _searchController.clear();
                  _searchQuery = '';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _approveAccount(UserProfile account) {
    showDialog(
      context: context,
      builder: (context) => _ReviewDialog(
        account: account,
        isApproval: true,
        onSubmit: (notes) => _processApproval(account, notes),
      ),
    );
  }

  void _rejectAccount(UserProfile account) {
    showDialog(
      context: context,
      builder: (context) => _ReviewDialog(
        account: account,
        isApproval: false,
        onSubmit: (notes) => _processRejection(account, notes),
      ),
    );
  }

  Future<void> _processApproval(UserProfile account, String? notes) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      final updatedProfile = account.approveVerification(
        authState.user.uid,
        notes: notes,
      );

      await UserProfileService().updateUserProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.displayTitle} approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processRejection(UserProfile account, String? notes) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      final updatedProfile = account.rejectVerification(
        authState.user.uid,
        notes: notes,
      );

      await UserProfileService().updateUserProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.displayTitle} rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewAccountDetails(UserProfile account) {
    showDialog(
      context: context,
      builder: (context) => _AccountDetailsDialog(account: account),
    );
  }

  void _refreshData() {
    setState(() {});
  }
}

class _ReviewDialog extends StatefulWidget {
  final UserProfile account;
  final bool isApproval;
  final Function(String?) onSubmit;

  const _ReviewDialog({
    required this.account,
    required this.isApproval,
    required this.onSubmit,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isApproval ? 'Approve Account' : 'Reject Account',
        style: TextStyle(
          color: widget.isApproval ? Colors.green : Colors.red,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account: ${widget.account.displayTitle}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Email: ${widget.account.email}'),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.isApproval ? 'Approval Notes (Optional)' : 'Rejection Reason',
              hintText: widget.isApproval
                  ? 'Welcome message or additional info...'
                  : 'Please explain why this account was rejected...',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSubmit(_notesController.text.trim().isEmpty ? null : _notesController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isApproval ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.isApproval ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}

class _AccountDetailsDialog extends StatelessWidget {
  final UserProfile account;

  const _AccountDetailsDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: account.userType == 'vendor' ? Colors.green : Colors.indigo,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    account.userType == 'vendor' ? Icons.store : Icons.account_balance,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account Details',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Name', account.displayName ?? 'N/A'),
                    _buildDetailRow('Email', account.email),
                    _buildDetailRow('User Type', account.userType == 'vendor' ? 'Vendor' : 'Market Organizer'),
                    if (account.businessName != null)
                      _buildDetailRow('Business Name', account.businessName!),
                    if (account.organizationName != null)
                      _buildDetailRow('Organization Name', account.organizationName!),
                    if (account.bio != null)
                      _buildDetailRow('Description', account.bio!),
                    if (account.phoneNumber != null)
                      _buildDetailRow('Phone', account.phoneNumber!),
                    if (account.website != null)
                      _buildDetailRow('Website', account.website!),
                    if (account.instagramHandle != null)
                      _buildDetailRow('Instagram', account.instagramHandle!),
                    if (account.categories.isNotEmpty)
                      _buildDetailRow('Categories', account.categories.join(', ')),
                    if (account.specificProducts != null)
                      _buildDetailRow('Specific Products', account.specificProducts!),
                    if (account.ccEmails.isNotEmpty)
                      _buildDetailRow('Additional Emails', account.ccEmails.join(', ')),
                    _buildDetailRow('Status', account.verificationStatusDisplayName),
                    if (account.verificationRequestedAt != null)
                      _buildDetailRow('Submitted', account.verificationRequestedAt!.toString()),
                    if (account.verifiedAt != null)
                      _buildDetailRow('Reviewed', account.verifiedAt!.toString()),
                    if (account.verificationNotes != null)
                      _buildDetailRow('Notes', account.verificationNotes!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}