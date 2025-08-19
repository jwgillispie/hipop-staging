import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../shared/services/user_profile_service.dart';
import '../../../core/theme/hipop_colors.dart';

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
          backgroundColor: HiPopColors.vendorAccent,
          foregroundColor: Colors.white,
        ),
        backgroundColor: HiPopColors.darkBackground,
        body: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                border: Border(bottom: BorderSide(color: HiPopColors.darkBorder)),
              ),
                child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: TextStyle(fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
                      ),
                      Text(
                        '${((_currentStep + 1) / _totalSteps * 100).round()}% Complete',
                        style: TextStyle(color: HiPopColors.darkTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _totalSteps,
                    backgroundColor: HiPopColors.darkBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
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
                color: HiPopColors.darkSurface,
                border: Border(top: BorderSide(color: HiPopColors.darkBorder)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.vendorAccent,
                          side: BorderSide(color: HiPopColors.vendorAccent.withValues(alpha: 0.5)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.vendorAccent,
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
    return Container(
      color: HiPopColors.darkBackground,
      child: SingleChildScrollView(
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
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Let\'s start with your basic account information.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'Enter your full name',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.person, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
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
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'Enter your email address',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.email, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
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
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'Enter your password',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.lock, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
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
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'Confirm your password',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.lock_outline, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
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
      ),
    );
  }

  Widget _buildStep2BusinessInfo() {
    return Container(
      color: HiPopColors.darkBackground,
      child: SingleChildScrollView(
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
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your business and what you sell.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _businessNameController,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Business Name *',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'e.g., Fresh Farm Produce',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.business, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
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
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Business Description *',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'Describe your business, products, and what makes you special...',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
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
            Text(
              'What categories do you sell? *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableCategories.map((category) {
                final isSelected = _selectedCategories.contains(category);
                return FilterChip(
                  label: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: HiPopColors.vendorAccent,
                  backgroundColor: HiPopColors.darkSurface,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? HiPopColors.vendorAccent : HiPopColors.darkBorder,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Please select at least one category',
                  style: TextStyle(
                    color: HiPopColors.errorPlum,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStep3ContactDetails() {
    return Container(
      color: HiPopColors.darkBackground,
      child: SingleChildScrollView(
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
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'How can market organizers and customers reach you?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: '(555) 123-4567',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.phone, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Website',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'https://your-website.com',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.language, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instagramController,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Instagram Handle',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: '@your_business_name',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.camera_alt, color: HiPopColors.vendorAccent),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStep4ProductsSpecialties() {
    return Container(
      color: HiPopColors.darkBackground,
      child: SingleChildScrollView(
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
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Give us more details about what you offer.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _specificProductsController,
              maxLines: 5,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Specific Products & Details',
                labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                hintText: 'List your specific products, varieties, specialties, certifications (organic, etc.), seasonal availability, etc...',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                ),
                fillColor: HiPopColors.darkSurface,
                filled: true,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStep5AdditionalInfo() {
    return Container(
      color: HiPopColors.darkBackground,
      child: SingleChildScrollView(
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
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Any additional contact emails for notifications?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
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
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Additional Email',
                      labelStyle: TextStyle(color: HiPopColors.vendorAccent),
                      hintText: 'partner@yourbusiness.com',
                      hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                      prefixIcon: Icon(Icons.email_outlined, color: HiPopColors.vendorAccent),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                      ),
                      fillColor: HiPopColors.darkSurface,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addCcEmail,
                  icon: Icon(Icons.add_circle, color: HiPopColors.vendorAccent),
                  tooltip: 'Add email',
                ),
              ],
            ),
            if (_ccEmails.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Additional Emails:',
                style: TextStyle(fontWeight: FontWeight.w500, color: HiPopColors.darkTextPrimary),
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
                              color: HiPopColors.darkSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HiPopColors.darkBorder),
                            ),
                            child: Text(email, style: TextStyle(color: HiPopColors.darkTextPrimary)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeCcEmail(email),
                          icon: Icon(Icons.remove_circle, color: HiPopColors.errorPlum),
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
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HiPopColors.vendorAccent.withValues(alpha: 0.3)),
              ),
                child: Column(
                children: [
                  Icon(Icons.pending_actions, color: HiPopColors.vendorAccent, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to Submit!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'After you submit your profile, we\'ll review your account and get back to you soon. You\'ll receive an email when your account is approved!',
                    style: TextStyle(color: HiPopColors.darkTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
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