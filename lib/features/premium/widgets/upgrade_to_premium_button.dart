import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../services/stripe_service.dart';


class UpgradeToPremiumButton extends StatefulWidget {
  final String userType;
  final VoidCallback? onSuccess;
  final VoidCallback? onError;

  const UpgradeToPremiumButton({
    super.key,
    required this.userType,
    this.onSuccess,
    this.onError,
  });

  @override
  State<UpgradeToPremiumButton> createState() => _UpgradeToPremiumButtonState();
}

class _UpgradeToPremiumButtonState extends State<UpgradeToPremiumButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return const SizedBox.shrink();
        }

        final pricing = StripeService.getPricingForUserType(widget.userType);
        
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.diamond,
                      color: HiPopColors.premiumGold,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pricing['name'],
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: HiPopColors.primaryDeepSage,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '\$${pricing['price'].toStringAsFixed(0)}/month',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pricing['description'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ...((pricing['features'] as List).take(3).map((feature) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: HiPopColors.primaryDeepSage,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                if ((pricing['features'] as List).length > 3)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '+ ${(pricing['features'] as List).length - 3} more features',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleUpgrade(authState.user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.primaryDeepSage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Upgrade Now',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Cancel anytime • 30-day money back guarantee',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleUpgrade(dynamic user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userEmail = user.email ?? '';
      final userId = user.uid ?? '';

      if (userEmail.isEmpty) {
        throw Exception('User email is required for subscription');
      }

      debugPrint('🚀 Starting upgrade process for ${widget.userType}');
      debugPrint('👤 User: $userEmail ($userId)');

      await StripeService.launchSubscriptionCheckout(
        userType: widget.userType,
        userId: userId,
        userEmail: userEmail,
        context: context,
      );

      widget.onSuccess?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Welcome to Premium!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Upgrade failed: $e');
      
      widget.onError?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upgrade failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}