import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/features/shopper/services/personalized_recommendation_service.dart';
import '../services/subscription_service.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../vendor/widgets/vendor/vendor_follow_button.dart';
import '../../shared/services/user_profile_service.dart';
import '../widgets/upgrade_to_premium_button.dart';

/// Seamlessly integrates premium features into the main feed experience
/// Shows premium content to premium users, upgrade prompts to free users
class PremiumFeedEnhancements extends StatefulWidget {
  const PremiumFeedEnhancements({super.key});

  @override
  State<PremiumFeedEnhancements> createState() => _PremiumFeedEnhancementsState();
}

class _PremiumFeedEnhancementsState extends State<PremiumFeedEnhancements> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  bool _hasPremiumAccess = false;
  String _currentUserId = '';
  bool _showRecommendations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPremiumAccessAndLoadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh premium status when app becomes active
      _checkPremiumAccessAndLoadData();
    }
  }

  Future<void> _checkPremiumAccessAndLoadData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      
      // Check both feature access AND user profile premium status
      final futures = await Future.wait([
        SubscriptionService.hasFeature(_currentUserId, 'vendor_following_system'),
        _checkUserProfilePremiumStatus(_currentUserId),
      ]);
      
      final hasFeatureAccess = futures[0];
      final hasProfilePremium = futures[1];
      
      // User is premium if either check returns true
      final hasAccess = hasFeatureAccess || hasProfilePremium;
      
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
        });
        
        if (hasAccess) {
          _loadPremiumContent();
        }
      }
    }
  }
  
  Future<bool> _checkUserProfilePremiumStatus(String userId) async {
    try {
      final userProfileService = UserProfileService();
      return await userProfileService.hasPremiumAccess(userId);
    } catch (e) {
      debugPrint('Error checking user profile premium status: $e');
      return false;
    }
  }

  Future<void> _loadPremiumContent() async {
    if (!_hasPremiumAccess || _currentUserId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final recommendations = await PersonalizedRecommendationService.generateRecommendations(
        shopperId: _currentUserId,
        limit: 6,
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading premium content: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(
                'Loading personalized content...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPremiumAccess) {
      return _buildUpgradePrompt();
    }

    return Column(
      children: [
        if (_recommendations.isNotEmpty && _showRecommendations) ...[
          _buildRecommendationsSection(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildUpgradePrompt() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.purple.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find Your Perfect Pop-Ups',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover amazing pop-up markets and vendors near you',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMiniFeature(Icons.search, 'Enhanced Search'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniFeature(Icons.notifications, 'Get Notifications'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniFeature(Icons.auto_awesome, 'Smart Recommendations'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showDetailedUpgradeDialog,
                icon: const Icon(Icons.star),
                label: const Text('Try Premium Free for 7 Days'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only \$4/month after trial • Cancel anytime',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniFeature(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecommendationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.purple.shade600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended For You',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showRecommendations ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _showRecommendations = !_showRecommendations;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vendors we think you\'ll love based on your interests',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...(_recommendations.take(3).map((vendor) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: vendor['profileImageUrl'] != null
                        ? NetworkImage(vendor['profileImageUrl'])
                        : null,
                    child: vendor['profileImageUrl'] == null
                        ? const Icon(Icons.store, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor['businessName'] ?? 'Vendor',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (vendor['reasonDetails'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            vendor['reasonDetails'],
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (vendor['bio'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            vendor['bio'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  VendorFollowButton(
                    vendorId: vendor['vendorId'],
                    vendorName: vendor['businessName'] ?? 'Vendor',
                    isCompact: true,
                  ),
                ],
              ),
            ))),
          ],
        ),
      ),
    );
  }

  void _showDetailedUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Unlock Premium Shopper'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transform your local shopping experience:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _buildDialogFeature(Icons.notifications, 'Get vendor notifications', 
                    'Receive instant updates when they post new locations'),
                _buildDialogFeature(Icons.auto_awesome, 'AI-powered recommendations', 
                    'Discover new vendors based on your preferences'),
                _buildDialogFeature(Icons.search, 'Advanced search filters', 
                    'Search by product, category, and location'),
                _buildDialogFeature(Icons.history, 'Search history & saved searches', 
                    'Never lose track of great finds'),
                _buildDialogFeature(Icons.priority_high, 'Priority access to events', 
                    'Get early access to limited vendor spots'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.celebration, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '7-day free trial • Only \$4/month after',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const UpgradeToPremiumButton(userType: 'shopper'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFeature(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}