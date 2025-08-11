import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/widgets/upgrade_to_premium_button.dart';
import '../../services/vendor_following_service.dart';
import '../../../shared/services/user_profile_service.dart';


class VendorNotificationButton extends StatefulWidget {
  final String vendorId;
  final String vendorName;
  final bool isCompact;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const VendorNotificationButton({
    super.key,
    required this.vendorId,
    required this.vendorName,
    this.isCompact = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<VendorNotificationButton> createState() => _VendorNotificationButtonState();
}

// Keep backward compatibility
class VendorFollowButton extends VendorNotificationButton {
  const VendorFollowButton({
    super.key,
    required super.vendorId,
    required super.vendorName,
    super.isCompact = false,
    super.backgroundColor,
    super.foregroundColor,
  });
}

class _VendorNotificationButtonState extends State<VendorNotificationButton> {
  bool _isNotifying = false;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final isFollowing = await VendorFollowingService.isFollowing(
        shopperId: authState.user.uid,
        vendorId: widget.vendorId,
      );

      if (mounted) {
        setState(() {
          _isNotifying = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      _showLoginRequired();
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check if user has premium subscription for enhanced features (dual check system)
      final futures = await Future.wait([
        SubscriptionService.hasFeature(authState.user.uid, 'vendor_following_system'),
        _checkUserProfilePremiumStatus(authState.user.uid),
      ]);
      
      final hasFeatureAccess = futures[0];
      final hasProfilePremium = futures[1];
      
      // User is premium if either check returns true
      final hasFeature = hasFeatureAccess || hasProfilePremium;

      if (_isNotifying) {
        await VendorFollowingService.unfollowVendor(
          shopperId: authState.user.uid,
          vendorId: widget.vendorId,
          isPremium: hasFeature,
        );
      } else {
        await VendorFollowingService.followVendor(
          shopperId: authState.user.uid,
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
          isPremium: hasFeature,
        );
      }

      if (mounted) {
        setState(() {
          _isNotifying = !_isNotifying;
        });

        String message = _isNotifying 
            ? '🔔 ${hasFeature ? 'Notifications on for' : 'Saved'} ${widget.vendorName}' 
            : '🔕 ${hasFeature ? 'Notifications off for' : 'Removed'} ${widget.vendorName}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _isNotifying ? Colors.blue : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Only show premium dialog when user is trying to enable notifications without premium
        if (!hasFeature && _isNotifying) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showPremiumRequired();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isNotifying ? 'disable notifications for' : 'enable notifications for'} vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please log in to get notifications from vendors about their pop-ups.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  void _showPremiumRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Vendor saved! You can save vendors for free.'),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Shopper Premium (\$4/month) for notifications:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Get notified when vendors post new locations'),
            const Text('• Receive updates about vendor activities'),
            const Text('• Advanced category search'),
            const Text('• Get personalized vendor recommendations'),
            const SizedBox(height: 16),
            UpgradeToPremiumButton(
              userType: 'shopper',
              onSuccess: () {
                Navigator.pop(context);
                _checkFollowStatus(); // Recheck after upgrade
              },
              onError: () {
                // Error handled by the button
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.isCompact
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const CircularProgressIndicator();
    }

    if (widget.isCompact) {
      return InkWell(
        onTap: _isProcessing ? null : _toggleFollow,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isNotifying 
                ? (widget.backgroundColor ?? Colors.blue.shade100)
                : (widget.backgroundColor ?? Colors.grey.shade100),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isNotifying ? Colors.blue : Colors.grey,
              width: 1,
            ),
          ),
          child: Center(
            child: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Icon(
                    _isNotifying ? Icons.notifications : Icons.notifications_none,
                    size: 16,
                    color: widget.foregroundColor ?? (_isNotifying ? Colors.blue : Colors.grey.shade600),
                  ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _toggleFollow,
      icon: _isProcessing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isNotifying ? Icons.notifications : Icons.notifications_none,
              size: 18,
            ),
      label: Text(_isNotifying ? 'Updates On' : 'Get Updates'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isNotifying 
            ? (widget.backgroundColor ?? Colors.blue)
            : (widget.backgroundColor ?? Colors.grey),
        foregroundColor: widget.foregroundColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}