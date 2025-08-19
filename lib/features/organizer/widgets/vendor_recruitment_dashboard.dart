import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../../market/models/market.dart';
import '../../market/services/vendor_recruitment_service.dart';

/// Vendor Recruitment Dashboard for Market Organizers
/// Provides real-time insights and management tools for vendor recruitment
class VendorRecruitmentDashboard extends StatefulWidget {
  final Market market;
  final VoidCallback onRefresh;
  
  const VendorRecruitmentDashboard({
    super.key,
    required this.market,
    required this.onRefresh,
  });
  
  @override
  State<VendorRecruitmentDashboard> createState() => _VendorRecruitmentDashboardState();
}

class _VendorRecruitmentDashboardState extends State<VendorRecruitmentDashboard> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }
  
  Future<void> _loadAnalytics() async {
    try {
      final analytics = await VendorRecruitmentService.getRecruitmentAnalytics(
        widget.market.id,
      );
      
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _toggleRecruitment() async {
    final newStatus = !widget.market.isLookingForVendors;
    
    try {
      await VendorRecruitmentService.toggleRecruitmentStatus(
        widget.market.id,
        newStatus,
      );
      
      widget.onRefresh();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus 
                  ? 'Vendor recruitment enabled' 
                  : 'Vendor recruitment disabled',
            ),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating recruitment status: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final isRecruiting = widget.market.isLookingForVendors;
    final hasDeadline = widget.market.applicationDeadline != null;
    final isUrgent = widget.market.isApplicationDeadlineUrgent;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.surfacePalePink,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.lightShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRecruiting
                      ? HiPopColors.primaryDeepSage
                      : HiPopColors.lightTextDisabled,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor Recruitment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      isRecruiting 
                          ? 'Actively recruiting vendors' 
                          : 'Recruitment paused',
                      style: TextStyle(
                        color: isRecruiting 
                            ? HiPopColors.successGreen 
                            : HiPopColors.lightTextTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isRecruiting,
                onChanged: (_) => _toggleRecruitment(),
                activeColor: HiPopColors.primaryDeepSage,
              ),
            ],
          ),
          
          if (isRecruiting) ...[
            const SizedBox(height: 24),
            
            // Urgency Alert
            if (isUrgent && hasDeadline)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.warningAmber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: HiPopColors.warningAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.market.applicationDeadlineDisplay,
                        style: TextStyle(
                          color: HiPopColors.warningAmberDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  title: 'Available Spots',
                  value: '${widget.market.vendorSpotsAvailable ?? 0}',
                  subtitle: 'of ${widget.market.vendorSpotsTotal ?? 0} total',
                  icon: Icons.groups,
                  color: HiPopColors.primaryDeepSage,
                  progress: _calculateSpotsFillRate(),
                ),
                _buildMetricCard(
                  title: 'Applications',
                  value: '${_analytics?['totalApplications'] ?? 0}',
                  subtitle: '${_analytics?['pendingApplications'] ?? 0} pending',
                  icon: Icons.mail,
                  color: HiPopColors.accentMauve,
                ),
                _buildMetricCard(
                  title: 'Fill Rate',
                  value: '${_analytics?['fillRate'] ?? 0}%',
                  subtitle: 'Spots filled',
                  icon: Icons.trending_up,
                  color: HiPopColors.successGreen,
                ),
                _buildMetricCard(
                  title: 'Conversion',
                  value: '${_analytics?['conversionRate'] ?? 0}%',
                  subtitle: 'Accepted rate',
                  icon: Icons.check_circle,
                  color: HiPopColors.infoBlueGray,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Fee Information
            if (widget.market.applicationFee != null || 
                widget.market.dailyBoothFee != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HiPopColors.surfaceSoftPink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.accentDustyRose.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payments,
                          size: 18,
                          color: HiPopColors.accentMauve,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fee Structure',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.market.applicationFee != null)
                      _buildFeeRow(
                        'Application Fee',
                        widget.market.applicationFee! > 0
                            ? '\$${widget.market.applicationFee!.toStringAsFixed(2)}'
                            : 'Free',
                      ),
                    if (widget.market.dailyBoothFee != null)
                      _buildFeeRow(
                        'Daily Booth Fee',
                        widget.market.dailyBoothFee! > 0
                            ? '\$${widget.market.dailyBoothFee!.toStringAsFixed(2)}'
                            : 'Free',
                      ),
                  ],
                ),
              ),
            
            // Action Buttons
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showEditRecruitmentDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HiPopColors.primaryDeepSage,
                      side: BorderSide(color: HiPopColors.primaryDeepSage),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewApplications,
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text('View Applicants'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.primaryDeepSage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Not Recruiting State
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HiPopColors.lightTextDisabled.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 48,
                    color: HiPopColors.lightTextTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vendor Recruitment Paused',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enable recruitment to start accepting vendor applications',
                    style: TextStyle(
                      color: HiPopColors.lightTextTertiary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _toggleRecruitment,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Recruiting'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.primaryDeepSage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.lightTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: HiPopColors.lightTextTertiary,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: HiPopColors.lightTextSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: HiPopColors.lightTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculateSpotsFillRate() {
    final total = widget.market.vendorSpotsTotal ?? 0;
    final available = widget.market.vendorSpotsAvailable ?? 0;
    
    if (total == 0) return 0;
    
    final filled = total - available;
    return filled / total;
  }
  
  void _showEditRecruitmentDialog() {
    // Show edit dialog for recruitment details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Recruitment Details'),
        content: const Text('Edit functionality would be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _viewApplications() {
    // Navigate to applications view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigating to vendor applications...'),
      ),
    );
  }
}