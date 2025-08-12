import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import '../widgets/upgrade_to_premium_button.dart';

import '../services/subscription_success_service.dart';

/// Test screen for Stripe subscription functionality
/// This is a temporary screen for testing - remove before production
class SubscriptionTestScreen extends StatelessWidget {
  const SubscriptionTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Test'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! Authenticated) {
            return const Center(
              child: Text('Please log in to test subscriptions'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.science, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Stripe Integration Test',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Test subscription upgrades using Stripe test cards:\n'
                        '• Success: 4242 4242 4242 4242\n'
                        '• Decline: 4000 0000 0000 0002\n'
                        '• Any future expiry date and CVC',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // User Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current User',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Email: ${authState.user.email ?? 'No email'}'),
                      Text('User ID: ${authState.user.uid}'),
                      // TODO: Show actual user type from your user profile
                      Text('User Type: Testing (hardcoded as shopper)'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Test Shopper Subscription
                Text(
                  'Test Shopper Premium (\$4/month)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                UpgradeToPremiumButton(
                  userType: 'shopper',
                  onSuccess: () {
                    debugPrint('✅ Shopper upgrade successful!');
                  },
                  onError: () {
                    debugPrint('❌ Shopper upgrade failed!');
                  },
                ),

                const SizedBox(height: 24),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Testing Instructions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Tap "Upgrade Now" button\n'
                        '2. Use test card: 4242 4242 4242 4242\n'
                        '3. Enter any future expiry (e.g., 12/34)\n'
                        '4. Enter any 3-digit CVC (e.g., 123)\n'
                        '5. Complete the checkout process\n'
                        '6. Check console logs for success/failure',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Test Vendor Subscription
                Text(
                  'Test Vendor Pro (\$29/month)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                UpgradeToPremiumButton(
                  userType: 'vendor',
                  onSuccess: () {
                    debugPrint('✅ Vendor upgrade successful!');
                  },
                  onError: () {
                    debugPrint('❌ Vendor upgrade failed!');
                  },
                ),

                const SizedBox(height: 24),

                // Test Market Organizer Subscription
                Text(
                  'Test Market Organizer Premium (\$39/month)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                UpgradeToPremiumButton(
                  userType: 'market_organizer',
                  onSuccess: () {
                    debugPrint('✅ Market Organizer upgrade successful!');
                  },
                  onError: () {
                    debugPrint('❌ Market Organizer upgrade failed!');
                  },
                ),

                const SizedBox(height: 24),

                // Next Steps
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.rocket_launch, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Ready to Build Premium Features!',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '✅ All 3 subscription tiers configured\n'
                        '✅ Stripe checkout working perfectly\n'
                        '✅ Test environment ready\n\n'
                        'Next: Build premium features that justify these payments!\n'
                        '• Advanced Analytics Dashboards\n'
                        '• Smart Recruitment Tools\n'
                        '• Vendor Following System\n'
                        '• Multi-Market Management',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Test Success Callback Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Test Premium Upgrade',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Simulate successful payment callback:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _testPremiumUpgrade(context, authState.user.uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                          icon: const Icon(Icons.upgrade),
                          label: const Text('🧪 Test: Mark User as Premium'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _testPremiumUpgrade(BuildContext context, String userId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Upgrading to premium...'),
          ],
        ),
      ),
    );

    try {
      // Simulate successful subscription with test data
      final success = await SubscriptionSuccessService.handleSubscriptionSuccess(
        userId: userId,
        sessionId: 'cs_test_fake_session_for_testing_premium_upgrade',
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 User upgraded to premium successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to upgrade user to premium'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}