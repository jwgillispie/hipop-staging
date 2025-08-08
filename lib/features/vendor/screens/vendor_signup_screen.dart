import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../shared/services/user_profile_service.dart';

class VendorSignupScreen extends StatefulWidget {
  const VendorSignupScreen({super.key});

  @override
  State<VendorSignupScreen> createState() => _VendorSignupScreenState();
}

class _VendorSignupScreenState extends State<VendorSignupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;
  bool _isLoading = false;

  // Step 1: Basic Auth
  final _step1FormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2: Business Info
  final _step2FormKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _bioController = TextEditingController();
  List<String> _selectedCategories = [];

  // Step 3: Contact Details
  final _step3FormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();

  // Step 4: Products & Specialties
  final _step4FormKey = GlobalKey<FormState>();
  final _specificProductsController = TextEditingController();

  // Step 5: Additional Info
  final _step5FormKey = GlobalKey<FormState>();
  final _ccEmailController = TextEditingController();
  List<String> _ccEmails = [];

  // Available categories for vendors - match the detailed categories from vendor profile
  final List<String> _availableCategories = [
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
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _specificProductsController.dispose();
    _ccEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // Don't navigate to dashboard immediately - complete profile first
          _completeProfileSetup(state.user.uid);
        } else if (state is AuthError) {
          setState(() => _isLoading = false);
          _showErrorSnackBar(state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendor Account Setup'),
          centerTitle: true,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${((_currentStep + 1) / _totalSteps * 100).round()}% Complete',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _totalSteps,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BasicAuth(),
                  _buildStep2BusinessInfo(),
                  _buildStep3ContactDetails(),
                  _buildStep4ProductsSpecialties(),
                  _buildStep5AdditionalInfo(),
                ],
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _previousStep,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          : Text(_currentStep == _totalSteps - 1 ? 'Submit Profile' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1BasicAuth() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Create Your Vendor Account',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Let\'s start with your basic account information.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Confirm your password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2BusinessInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Business Information',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your business and what you sell.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                hintText: 'e.g., Fresh Farm Produce',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your business name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Business Description *',
                hintText: 'Describe your business, products, and what makes you special...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a business description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'What categories do you sell? *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableCategories.map((category) {
                final isSelected = _selectedCategories.contains(category);
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    });
                  },
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green.shade700,
                );
              }).toList(),
            ),
            if (_selectedCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Please select at least one category',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3ContactDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'How can market organizers and customers reach you?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '(555) 123-4567',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'https://your-website.com',
                prefixIcon: Icon(Icons.language),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instagramController,
              decoration: const InputDecoration(
                labelText: 'Instagram Handle',
                hintText: '@your_business_name',
                prefixIcon: Icon(Icons.camera_alt),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4ProductsSpecialties() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step4FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Products & Specialties',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Give us more details about what you offer.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _specificProductsController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Specific Products & Details',
                hintText: 'List your specific products, varieties, specialties, certifications (organic, etc.), seasonal availability, etc...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep5AdditionalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step5FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Any additional contact emails for notifications?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ccEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Additional Email',
                      hintText: 'partner@yourbusiness.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addCcEmail,
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Add email',
                ),
              ],
            ),
            if (_ccEmails.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Additional Emails:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._ccEmails.map((email) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(email),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeCcEmail(email),
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          tooltip: 'Remove email',
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.pending_actions, color: Colors.green.shade600, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to Submit!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'After you submit your profile, we\'ll review your account and get back to you soon. You\'ll receive an email when your account is approved!',
                    style: TextStyle(color: Colors.green.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCcEmail() {
    if (_ccEmailController.text.trim().isNotEmpty) {
      setState(() {
        _ccEmails.add(_ccEmailController.text.trim());
        _ccEmailController.clear();
      });
    }
  }

  void _removeCcEmail(String email) {
    setState(() {
      _ccEmails.remove(email);
    });
  }

  void _nextStep() {
    bool canProceed = false;

    switch (_currentStep) {
      case 0:
        canProceed = _step1FormKey.currentState?.validate() ?? false;
        break;
      case 1:
        canProceed = (_step2FormKey.currentState?.validate() ?? false) && _selectedCategories.isNotEmpty;
        break;
      case 2:
        canProceed = _step3FormKey.currentState?.validate() ?? false;
        break;
      case 3:
        canProceed = _step4FormKey.currentState?.validate() ?? false;
        break;
      case 4:
        // Final step - create account and submit profile
        _createAccountAndSubmitProfile();
        return;
    }

    if (canProceed && _currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createAccountAndSubmitProfile() async {
    setState(() => _isLoading = true);

    try {
      // Create the Firebase Auth account
      context.read<AuthBloc>().add(SignUpEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: 'vendor',
      ));
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error creating account: $e');
    }
  }

  Future<void> _completeProfileSetup(String userId) async {
    try {
      final userProfileService = UserProfileService();
      
      // Create comprehensive profile with all collected information
      final newProfile = await userProfileService.createUserProfile(
        userId: userId,
        userType: 'vendor',
        email: _emailController.text.trim(),
        displayName: _nameController.text.trim(),
      );

      // Update with all the collected information from all steps
      final updatedProfile = newProfile.copyWith(
        businessName: _businessNameController.text.trim(),
        bio: _bioController.text.trim(),
        categories: _selectedCategories,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        instagramHandle: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
        specificProducts: _specificProductsController.text.trim().isEmpty ? null : _specificProductsController.text.trim(),
        ccEmails: _ccEmails,
        profileSubmitted: true,
        verificationRequestedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userProfileService.updateUserProfile(updatedProfile);
      
      setState(() => _isLoading = false);
      
      // Show success message and navigate to pending screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile submitted successfully! We\'ll review your account soon.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Navigate to pending verification screen
        context.go('/vendor-verification-pending');
      }
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error setting up profile: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}