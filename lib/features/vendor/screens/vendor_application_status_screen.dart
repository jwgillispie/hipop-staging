import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart' show AuthBloc;
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';

import 'package:hipop/features/vendor/models/vendor_application.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/vendor/services/vendor_application_service.dart';
import 'package:hipop/features/market/services/market_service.dart';


class VendorApplicationStatusScreen extends StatefulWidget {
  const VendorApplicationStatusScreen({super.key});

  @override
  State<VendorApplicationStatusScreen> createState() => _VendorApplicationStatusScreenState();
}

class _VendorApplicationStatusScreenState extends State<VendorApplicationStatusScreen> {
  late String _currentUserId;
  final Map<String, Market> _marketCache = {};

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
    } else {
      // Handle unauthenticated state
      _currentUserId = '';
    }
  }

  Future<Market?> _getMarket(String marketId) async {
    if (_marketCache.containsKey(marketId)) {
      return _marketCache[marketId];
    }
    
    try {
      final market = await MarketService.getMarket(marketId);
      if (market != null) {
        _marketCache[marketId] = market;
      }
      return market;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Applications'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Please log in to view your applications',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<VendorApplication>>(
        stream: VendorApplicationService.getApplicationsForVendor(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Loading your applications...');
          }

          if (snapshot.hasError) {
            return ErrorDisplayWidget.network(
              onRetry: () => setState(() {}),
            );
          }

          final applications = snapshot.data ?? [];

          if (applications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final application = applications[index];
              return _buildApplicationCard(application);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyToMarketsDialog,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Apply to Market'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Applications Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t applied to any markets yet. Apply directly to markets or browse to explore opportunities.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showApplyToMarketsDialog,
              icon: const Icon(Icons.add),
              label: const Text('Apply to Market'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard(VendorApplication application) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(application.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(application.status),
                    color: _getStatusColor(application.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Market?>(
                        future: _getMarket(application.marketId),
                        builder: (context, snapshot) {
                          final marketName = snapshot.data?.name ?? 'Loading...';
                          return Text(
                            marketName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Application Type: ${application.isMarketPermission ? 'Market Permission' : 'Event Application'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(application.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    application.statusDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Application Details
            _buildDetailRow('Applied', _formatDate(application.createdAt)),
            if (application.hasBeenReviewed) ...[
              _buildDetailRow('Reviewed', _formatDate(application.reviewedAt!)),
              if (application.reviewNotes != null && application.reviewNotes!.isNotEmpty)
                _buildDetailRow('Notes', application.reviewNotes!),
            ],
            
            const SizedBox(height: 12),
            
            // Special Message
            if (application.specialMessage?.isNotEmpty == true) ...[
              Text(
                'Special Message:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  application.specialMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                if (application.isPending) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editApplication(application),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _withdrawApplication(application),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewApplicationDetails(application),
                      icon: const Icon(Icons.info, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(

                  child: ElevatedButton.icon(
                    onPressed: () => _contactMarket(application),
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Contact Market'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.approved:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.waitlisted:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return Icons.schedule;
      case ApplicationStatus.approved:
        return Icons.check_circle;
      case ApplicationStatus.rejected:
        return Icons.cancel;
      case ApplicationStatus.waitlisted:
        return Icons.hourglass_empty;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editApplication(VendorApplication application) {
    // Navigate to edit application form
    context.push('/apply/${application.marketId}');
  }

  void _withdrawApplication(VendorApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text(
          'Are you sure you want to withdraw this application? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await VendorApplicationService.deleteApplication(application.id);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Application withdrawn successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error withdrawing application: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _viewApplicationDetails(VendorApplication application) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Application Type', application.isMarketPermission ? 'Market Permission Request' : 'Event Application'),
              if (application.specialMessage?.isNotEmpty == true)
                _buildDetailRow('Special Message', application.specialMessage!),
              _buildDetailRow('Status', application.statusDisplayName),
              _buildDetailRow('Applied', _formatDate(application.createdAt)),
              if (application.hasBeenReviewed)
                _buildDetailRow('Reviewed', _formatDate(application.reviewedAt!)),
              const SizedBox(height: 16),
              if (application.reviewNotes?.isNotEmpty == true) ...[
                Text(
                  'Review Notes:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  application.reviewNotes!,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _contactMarket(VendorApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Market'),
        content: const Text(
          'Contact feature is coming soon. You can reach out to the market organizer through their website or social media.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApplyToMarketsDialog() async {
    try {
      // Get all active markets
      final activeMarkets = await MarketService.getAllActiveMarkets();
      
      if (!mounted) return;
      
      if (activeMarkets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active markets available at this time.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get existing applications to filter out markets already applied to
      final existingApplications = await VendorApplicationService.getApplicationsForVendor(_currentUserId).first;
      final appliedMarketIds = existingApplications.map((app) => app.marketId).toSet();
      
      final availableMarkets = activeMarkets.where((market) => !appliedMarketIds.contains(market.id)).toList();
      
      if (!mounted) return;
      
      if (availableMarkets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied to all available markets.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apply to Market'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select a market to apply to:'),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableMarkets.length,
                    itemBuilder: (context, index) {
                      final market = availableMarkets[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.store_mall_directory, color: Colors.green),
                          title: Text(market.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${market.city}, ${market.state}'),
                              Text('Event: ${market.eventDisplayInfo}'),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.of(context).pop();
                            _applyToMarket(market);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading markets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyToMarket(Market market) {
    context.push('/apply/${market.id}');
  }
}