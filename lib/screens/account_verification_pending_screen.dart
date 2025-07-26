import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/auth/auth_event.dart';
import '../models/user_profile.dart';

class AccountVerificationPendingScreen extends StatelessWidget {
  const AccountVerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Status')),
            body: const Center(
              child: Text('Please sign in to view your account status'),
            ),
          );
        }

        final userProfile = state.userProfile;
        if (userProfile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Status')),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check verification status and show appropriate screen
        switch (userProfile.verificationStatus) {
          case VerificationStatus.approved:
            // Redirect to appropriate dashboard
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (userProfile.userType == 'vendor') {
                context.go('/vendor');
              } else if (userProfile.userType == 'market_organizer') {
                context.go('/organizer');
              } else {
                context.go('/');
              }
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          
          case VerificationStatus.rejected:
            return _buildRejectedScreen(context, userProfile);
          
          case VerificationStatus.pending:
            return _buildPendingScreen(context, userProfile);
        }
      },
    );
  }

  Widget _buildPendingScreen(BuildContext context, UserProfile userProfile) {
    final isVendor = userProfile.userType == 'vendor';
    final title = isVendor ? 'Vendor Account Under Review' : 'Market Organizer Account Under Review';
    final businessName = isVendor 
        ? (userProfile.businessName ?? userProfile.displayName ?? 'Your Business')
        : (userProfile.organizationName ?? userProfile.displayName ?? 'Your Organization');
    final colorScheme = isVendor ? Colors.green : Colors.indigo;

    return Scaffold(
      backgroundColor: colorScheme.shade50,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colorScheme,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      size: 64,
                      color: colorScheme.shade600,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Under Review',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVendor 
                          ? 'Thanks for submitting your vendor profile! We\'re currently reviewing your account to ensure quality and authenticity.'
                          : 'Thanks for submitting your market organizer profile! We\'re currently reviewing your account to verify your organization and experience.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isVendor ? Icons.business : Icons.account_balance,
                                color: colorScheme.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  businessName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.email, color: colorScheme.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userProfile.email,
                                  style: TextStyle(color: colorScheme.shade700),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.person, color: colorScheme.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${isVendor ? 'Vendor' : 'Market Organizer'} Account',
                                  style: TextStyle(color: colorScheme.shade700),
                                ),
                              ),
                            ],
                          ),
                          if (userProfile.verificationRequestedAt != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule, color: colorScheme.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Submitted ${_formatDate(userProfile.verificationRequestedAt!)}',
                                    style: TextStyle(color: colorScheme.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'What\'s Next?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVendor
                          ? '• We\'ll review your business information\n'
                            '• Verify your contact details\n'
                            '• You\'ll receive an email when approved\n'
                            '• This usually takes 1-2 business days'
                          : '• We\'ll review your organization information\n'
                            '• Verify your market management experience\n'
                            '• You\'ll receive an email when approved\n'
                            '• This usually takes 1-2 business days',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _refresh(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(BuildContext context, UserProfile userProfile) {
    final isVendor = userProfile.userType == 'vendor';
    final title = isVendor ? 'Vendor Account Review' : 'Market Organizer Account Review';

    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cancel,
                      size: 64,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Not Approved',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVendor
                          ? 'Unfortunately, we weren\'t able to approve your vendor account at this time.'
                          : 'Unfortunately, we weren\'t able to approve your market organizer account at this time.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (userProfile.verificationNotes != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              userProfile.verificationNotes!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you believe this was a mistake or have questions, please contact our support team at support@hipop.app',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _contactSupport(),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Contact Support'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  void _signOut(BuildContext context) {
    context.read<AuthBloc>().add(LogoutEvent());
    context.go('/auth');
  }

  void _refresh(BuildContext context) {
    // Force a rebuild by navigating to the same route
    context.go('/account-verification-pending');
  }

  void _contactSupport() {
    // TODO: Implement support contact (email, in-app messaging, etc.)
  }
}