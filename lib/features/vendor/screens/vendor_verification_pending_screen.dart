import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:hipop/features/shared/widgets/common/support_contact_widget.dart';
import 'package:hipop/features/shared/services/support_service.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

class VendorVerificationPendingScreen extends StatelessWidget {
  const VendorVerificationPendingScreen({super.key});

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
            // Redirect to main app
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/vendor');
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
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Account Under Review'),
        backgroundColor: HiPopColors.vendorAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HiPopColors.darkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
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
                      color: HiPopColors.vendorAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Under Review',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Thanks for submitting your vendor profile! We\'re currently reviewing your account to ensure quality and authenticity.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HiPopColors.vendorAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business, color: HiPopColors.vendorAccent),
                              const SizedBox(width: 8),
                              Text(
                                userProfile.businessName ?? userProfile.displayName ?? 'Your Business',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.email, color: HiPopColors.vendorAccent),
                              const SizedBox(width: 8),
                              Text(
                                userProfile.email,
                                style: TextStyle(color: HiPopColors.vendorAccent),
                              ),
                            ],
                          ),
                          if (userProfile.verificationRequestedAt != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule, color: HiPopColors.vendorAccent),
                                const SizedBox(width: 8),
                                Text(
                                  'Submitted ${_formatDate(userProfile.verificationRequestedAt!)}',
                                  style: TextStyle(color: HiPopColors.vendorAccent),
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
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• We\'ll review your business information\n'
                      '• Verify your contact details\n'
                      '• You\'ll receive an email when approved\n'
                      '• This usually takes 1-2 business days',
                      style: TextStyle(color: HiPopColors.darkTextSecondary),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SupportContactWidgetFactory.forAccountVerification(
                userProfile: userProfile,
                primaryColor: HiPopColors.vendorAccent,
                compact: true,
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
                        backgroundColor: HiPopColors.vendorAccent,
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
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Account Review'),
        backgroundColor: HiPopColors.errorPlum,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HiPopColors.darkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
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
                      color: HiPopColors.errorPlum,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Not Approved',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.errorPlum,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unfortunately, we weren\'t able to approve your vendor account at this time.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (userProfile.verificationNotes != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HiPopColors.errorPlum.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HiPopColors.errorPlum.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.errorPlum,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              userProfile.verificationNotes!,
                              style: TextStyle(color: HiPopColors.errorPlum),
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
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SupportContactWidgetFactory.forAccountRejection(
                      userProfile: userProfile,
                      compact: true,
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
                        backgroundColor: HiPopColors.errorPlum,
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
    // Reload user profile to check for verification status updates
    context.read<AuthBloc>().add(ReloadUserEvent());
  }

  void _contactSupport() {
    SupportService.contactSupportByEmail(
      context: SupportContext.vendorVerification,
      userProfile: null, // Can be enhanced to pass actual user profile
      additionalDetails: 'I need help with vendor verification process.',
    );
  }

}