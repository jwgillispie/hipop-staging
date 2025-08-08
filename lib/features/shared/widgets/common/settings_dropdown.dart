import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_event.dart';
import '../../../auth/screens/change_password_screen.dart';
import '../../../auth/services/onboarding_service.dart';
import '../../services/user_data_deletion_service.dart';

class SettingsDropdown extends StatefulWidget {
  const SettingsDropdown({super.key});

  @override
  State<SettingsDropdown> createState() => _SettingsDropdownState();
}

class _SettingsDropdownState extends State<SettingsDropdown> {
  bool _isDeleting = false;
  final UserDataDeletionService _deletionService = UserDataDeletionService();
  String _deletionProgress = '';

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;

    // Show confirmation dialog first
    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Re-authenticate the user before deletion (required by Firebase)
      final credentials = await _promptForPasswordConfirmation();
      if (credentials == null) {
        setState(() {
          _isDeleting = false;
        });
        return;
      }

      // Re-authenticate with Firebase
      await user.reauthenticateWithCredential(credentials);

      // Delete user data from Firestore using our comprehensive service
      try {
        debugPrint('🗑️  Starting user data deletion...');
        
        final result = await _deletionService.deleteAllUserData(
          user.uid,
          onProgress: (operation, completed, total) {
            setState(() {
              _deletionProgress = '$operation ($completed/$total)';
            });
          },
        );
        
        if (result.success) {
          debugPrint('✅ User data deletion completed successfully');
          debugPrint('📊 Deleted ${result.totalDocumentsDeleted} documents');
        } else {
          debugPrint('⚠️  User data deletion completed with errors: ${result.errors}');
        }
      } catch (e) {
        debugPrint('❌ Error deleting user data: $e');
        // Continue with account deletion even if data deletion fails
        // to prevent account lock-out, but log the error
      }

      // Delete the Firebase account
      await user.delete();

      // Sign out and navigate to login
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.read<AuthBloc>().add(LogoutEvent());
        context.go('/');
      }

    } catch (e) {
      setState(() {
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get deletion preview
    UserDataDeletionPreview? preview;
    try {
      preview = await _deletionService.getDeletePreview(user.uid);
    } catch (e) {
      debugPrint('❌ Error getting deletion preview: $e');
    }

    if (!mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Delete Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete your account?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text('This action will permanently delete:'),
                const SizedBox(height: 12),
                const Text('• Your user profile and settings'),
                const Text('• All your favorites and bookmarks'),
                const Text('• Your search history and preferences'),
                const Text('• All analytics and usage data'),
                if (preview != null && preview.totalDocumentsToDelete > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Data Summary',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${preview.totalDocumentsToDelete} total records to delete'),
                        if (preview.estimatedTimeMinutes > 0)
                          Text('Estimated time: ${preview.estimatedTimeMinutes} minute${preview.estimatedTimeMinutes == 1 ? '' : 's'}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This action cannot be undone. All your data will be permanently lost.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<AuthCredential?> _promptForPasswordConfirmation() async {
    AuthCredential? credential;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final passwordController = TextEditingController();
        bool obscurePassword = true;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Your Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'For security reasons, please enter your password to confirm account deletion.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    onSubmitted: (value) => _processPasswordConfirmation(
                      passwordController.text,
                      dialogContext,
                      (cred) => credential = cred,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _processPasswordConfirmation(
                    passwordController.text,
                    dialogContext,
                    (cred) => credential = cred,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    return credential;
  }

  void _processPasswordConfirmation(
    String password,
    BuildContext dialogContext,
    Function(AuthCredential) setCredential,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && password.isNotEmpty) {
      setCredential(EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      ));
    }
    Navigator.pop(dialogContext);
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
          return 'The password you entered is incorrect.';
        case 'requires-recent-login':
          return 'For security reasons, please log out and log back in before deleting your account.';
        case 'user-not-found':
          return 'User account not found.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        default:
          return 'Authentication error: ${error.message}';
      }
    }
    return error.toString();
  }

  Future<void> _resetOnboarding() async {
    try {
      await OnboardingService.resetShopperOnboarding();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutorial reset! It will show again next time you restart the app.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting tutorial: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onSelected: (String value) {
        switch (value) {
          case 'change-password':
            _showChangePasswordDialog();
            break;
          case 'reset-onboarding':
            _resetOnboarding();
            break;
          case 'logout':
            context.read<AuthBloc>().add(LogoutEvent());
            break;
          case 'delete':
            _deleteAccount();
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'change-password',
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.grey),
              SizedBox(width: 12),
              Text('Change Password'),
            ],
          ),
        ),
        if (kDebugMode) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'reset-onboarding',
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.grey),
                SizedBox(width: 12),
                Text('Reset Tutorial'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.grey),
              SizedBox(width: 12),
              Text('Sign Out'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          enabled: !_isDeleting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isDeleting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  else
                    const Icon(Icons.delete_forever, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Account',
                      style: TextStyle(
                        color: _isDeleting ? Colors.grey : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isDeleting && _deletionProgress.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    _deletionProgress,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}