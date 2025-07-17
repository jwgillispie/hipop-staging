import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../screens/change_password_screen.dart';
import '../../services/onboarding_service.dart';

class SettingsDropdown extends StatefulWidget {
  const SettingsDropdown({super.key});

  @override
  State<SettingsDropdown> createState() => _SettingsDropdownState();
}

class _SettingsDropdownState extends State<SettingsDropdown> {
  bool _isDeleting = false;

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

      // TODO: Delete user data from Firestore (favorites, profile, etc.)
      // This would typically call a backend service or cloud function

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
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete your account?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('This action will permanently:'),
              SizedBox(height: 8),
              Text('• Delete your favorites'),
              Text('• Remove your shopper profile'),
              Text('• Delete all account data'),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
          child: Row(
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
              Text(
                'Delete Account',
                style: TextStyle(
                  color: _isDeleting ? Colors.grey : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}