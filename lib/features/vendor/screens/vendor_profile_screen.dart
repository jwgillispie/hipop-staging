import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import 'package:hipop/features/shared/services/user_data_deletion_service.dart';


class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _displayNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _specificProductsController = TextEditingController();
  
  final UserProfileService _profileService = UserProfileService();
  final UserDataDeletionService _deletionService = UserDataDeletionService();
  UserProfile? _currentProfile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;
  String? _successMessage;
  String _deletionProgress = '';
  List<String> _ccEmails = [];
  List<String> _selectedProductCategories = [];
  
  // Common product categories for farmers markets
  final List<String> _productCategories = [
    'Fresh Produce',
    'Organic Vegetables',
    'Fruits',
    'Herbs',
    'Dairy Products',
    'Meat & Poultry',
    'Eggs',
    'Baked Goods',
    'Bread & Pastries',
    'Honey',
    'Jams & Preserves',
    'Pickles & Fermented Foods',
    'Prepared Foods',
    'Beverages',
    'Coffee & Tea',
    'Flowers',
    'Plants & Seeds',
    'Crafts & Artwork',
    'Skincare Products',
    'Clothing & Accessories',
    'Jewelry',
    'Woodworking',
    'Pottery',
    'Candles & Soaps',
    'Spices & Seasonings',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _businessNameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _phoneNumberController.dispose();
    _specificProductsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to get existing profile
        UserProfile? profile = await _profileService.getUserProfile(user.uid);
        
        // If no profile exists, create one
        if (profile == null) {
          profile = await _profileService.ensureUserProfile(
            userType: 'vendor',
            displayName: user.displayName,
          );
        }

        setState(() {
          _currentProfile = profile;
          _displayNameController.text = profile!.displayName ?? '';
          _businessNameController.text = profile.businessName ?? '';
          _bioController.text = profile.bio ?? '';
          _instagramController.text = profile.instagramHandle ?? '';
          _websiteController.text = profile.website ?? '';
          _phoneNumberController.text = profile.phoneNumber ?? '';
          _specificProductsController.text = profile.specificProducts ?? '';
          _ccEmails = List.from(profile.ccEmails);
          _selectedProductCategories = List.from(profile.categories);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _currentProfile == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Update the profile with new values
      final updatedProfile = _currentProfile!.copyWith(
        displayName: _displayNameController.text.trim().isEmpty 
            ? null 
            : _displayNameController.text.trim(),
        businessName: _businessNameController.text.trim().isEmpty 
            ? null 
            : _businessNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty 
            ? null 
            : _bioController.text.trim(),
        instagramHandle: _instagramController.text.trim().isEmpty 
            ? null 
            : _instagramController.text.trim(),
        website: _websiteController.text.trim().isEmpty 
            ? null 
            : _websiteController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty 
            ? null 
            : _phoneNumberController.text.trim(),
        specificProducts: _specificProductsController.text.trim().isEmpty 
            ? null 
            : _specificProductsController.text.trim(),
        ccEmails: _ccEmails,
        categories: _selectedProductCategories,
      );

      // Save to Firestore (this will also update Firebase Auth display name)
      final savedProfile = await _profileService.updateUserProfile(updatedProfile);

      setState(() {
        _currentProfile = savedProfile;
        _isEditing = false;
        _successMessage = 'Profile updated successfully';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;

    // Show confirmation dialog first
    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
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

      // Delete vendor-specific data using our comprehensive service
      try {
        debugPrint('🗑️  Starting vendor data deletion...');
        
        final result = await _deletionService.deleteAllUserData(
          user.uid,
          userType: 'vendor',
          onProgress: (operation, completed, total) {
            setState(() {
              _deletionProgress = '$operation ($completed/$total)';
            });
          },
        );
        
        if (result.success) {
          debugPrint('✅ Vendor data deletion completed successfully');
          debugPrint('📊 Deleted ${result.totalDocumentsDeleted} documents');
        } else {
          debugPrint('⚠️  Vendor data deletion completed with errors: ${result.errors}');
        }
      } catch (e) {
        debugPrint('❌ Error deleting vendor data: $e');
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
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get deletion preview
    UserDataDeletionPreview? preview;
    try {
      preview = await _deletionService.getDeletePreview(user.uid, userType: 'vendor');
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
              Text('Delete Vendor Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete your vendor account?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text('This action will permanently delete:'),
                const SizedBox(height: 12),
                const Text('• Your vendor profile and business information'),
                const Text('• All your pop-up events and posts'),
                const Text('• Your vendor applications and market relationships'),
                const Text('• All customer favorites of your business'),
                const Text('• Your analytics and business insights'),
                const Text('• All account data and preferences'),
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
                            Icon(Icons.business, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Vendor Data Summary',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${preview.totalDocumentsToDelete} total business records to delete'),
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
                          'This action cannot be undone. All your business data will be permanently lost.',
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vendor Profile'),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            actions: [
              if (_isEditing)
                TextButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                )
              else
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  icon: const Icon(Icons.edit),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(
                          Icons.store,
                          size: 50,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.user.email ?? 'No email',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Error/Success Messages
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Profile Form
                _buildProfileForm(),

                const SizedBox(height: 32),

                // Account Management Section
                _buildAccountManagementSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Information',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Display Name
        TextField(
          controller: _displayNameController,
          enabled: _isEditing,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
            helperText: 'This name will be shown on your pop-up events',
          ),
        ),

        const SizedBox(height: 16),

        // Business Name (placeholder for future implementation)
        TextField(
          controller: _businessNameController,
          enabled: _isEditing,
          decoration: const InputDecoration(
            labelText: 'Business Name (Optional)',
            border: OutlineInputBorder(),
            helperText: 'Your official business name',
          ),
        ),

        const SizedBox(height: 16),

        // Bio
        TextField(
          controller: _bioController,
          enabled: _isEditing,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Bio (Optional)',
            border: OutlineInputBorder(),
            helperText: 'Tell shoppers about your business',
          ),
        ),

        const SizedBox(height: 16),

        // Instagram Handle
        TextField(
          controller: _instagramController,
          enabled: _isEditing,
          decoration: const InputDecoration(
            labelText: 'Instagram Handle (Optional)',
            border: OutlineInputBorder(),
            helperText: 'Your Instagram username (without @)',
            prefixIcon: Icon(Icons.camera_alt),
          ),
        ),

        const SizedBox(height: 16),

        // Website
        TextField(
          controller: _websiteController,
          enabled: _isEditing,
          decoration: const InputDecoration(
            labelText: 'Website (Optional)',
            border: OutlineInputBorder(),
            helperText: 'Your business website URL',
            prefixIcon: Icon(Icons.web),
          ),
        ),

        const SizedBox(height: 16),

        // Phone Number
        TextField(
          controller: _phoneNumberController,
          enabled: _isEditing,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
            helperText: 'Your business contact number',
          ),
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 16),

        // Product Categories
        if (_isEditing) ...[
          _buildProductCategoriesField(),
          const SizedBox(height: 16),
        ] else if (_selectedProductCategories.isNotEmpty) ...[
          _buildProductCategoriesDisplay(),
          const SizedBox(height: 16),
        ],

        // Specific Products
        TextField(
          controller: _specificProductsController,
          enabled: _isEditing,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Additional Product Details',
            border: OutlineInputBorder(),
            helperText: 'Add any specific details about your products not covered above',
          ),
        ),

        const SizedBox(height: 16),

        // CC Emails
        if (_isEditing) ...[
          _buildCCEmailsField(),
          const SizedBox(height: 16),
        ] else if (_ccEmails.isNotEmpty) ...[
          _buildCCEmailsDisplay(),
          const SizedBox(height: 16),
        ],

        if (_isEditing) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      // Reset form to original values
                      if (_currentProfile != null) {
                        _displayNameController.text = _currentProfile!.displayName ?? '';
                        _businessNameController.text = _currentProfile!.businessName ?? '';
                        _bioController.text = _currentProfile!.bio ?? '';
                        _instagramController.text = _currentProfile!.instagramHandle ?? '';
                        _websiteController.text = _currentProfile!.website ?? '';
                        _phoneNumberController.text = _currentProfile!.phoneNumber ?? '';
                        _specificProductsController.text = _currentProfile!.specificProducts ?? '';
                        _ccEmails = List.from(_currentProfile!.ccEmails);
                        _selectedProductCategories = List.from(_currentProfile!.categories);
                      }
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAccountManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Management',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Change Password
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          subtitle: const Text('Update your account password'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            context.go('/vendor/change-password');
          },
        ),

        const Divider(),

        // Delete Account
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red),
          ),
          subtitle: _isDeleting && _deletionProgress.isNotEmpty
              ? Text(
                  _deletionProgress,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                )
              : const Text('Permanently delete your vendor account and all business data'),
          trailing: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, color: Colors.red),
          onTap: _isDeleting ? null : _deleteAccount,
        ),
      ],
    );
  }

  Widget _buildCCEmailsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Additional Contacts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton.icon(
              onPressed: _addCCEmail,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add email addresses for others who should be included in market communications',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (_ccEmails.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No additional contacts',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ccEmails.map((email) => Chip(
              label: Text(email),
              onDeleted: () {
                setState(() {
                  _ccEmails.remove(email);
                });
              },
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildCCEmailsDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Contacts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ccEmails.map((email) => Chip(
            label: Text(email),
          )).toList(),
        ),
      ],
    );
  }

  void _addCCEmail() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Contact Email'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter email address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final email = controller.text.trim();
                if (email.isNotEmpty && email.contains('@') && !_ccEmails.contains(email)) {
                  setState(() {
                    _ccEmails.add(email);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductCategoriesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What Products Do You Sell?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select all categories that apply to your business',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _productCategories.map((category) {
            final isSelected = _selectedProductCategories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedProductCategories.add(category);
                  } else {
                    _selectedProductCategories.remove(category);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedProductCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Products (${_selectedProductCategories.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _selectedProductCategories.map((category) => Chip(
                    label: Text(category),
                    backgroundColor: Colors.green.shade100,
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedProductCategories.remove(category);
                      });
                    },
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductCategoriesDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Products Sold',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedProductCategories.map((category) => Chip(
            label: Text(category),
            backgroundColor: Colors.green.shade100,
          )).toList(),
        ),
      ],
    );
  }
}